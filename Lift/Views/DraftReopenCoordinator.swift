import Foundation
import Observation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class DraftReopenCoordinator {
    private var modelContext: ModelContext?

    var pendingDraft: WorkoutSession?
    var resumedDraftID: UUID?
    var refreshToken = 0

    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
    }

    func setModelContext(_ modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func load(now: Date = .now, calendar: Calendar = .current) {
        guard let service = makeService() else {
            pendingDraft = nil
            return
        }

        let todayID = LocalDay.id(for: now, in: calendar.timeZone)
        pendingDraft = service.allDrafts().first(where: { $0.workoutDayID < todayID })
    }

    func resumePendingDraft() {
        resumedDraftID = pendingDraft?.id
        pendingDraft = nil
        refreshToken += 1
    }

    func finalizePendingDraft(now: Date = .now) {
        guard let pendingDraft, let service = makeService() else { return }
        service.finalize(pendingDraft, now: now)
        resumedDraftID = nil
        self.pendingDraft = nil
        refreshToken += 1
    }

    func endPendingDraftWithoutProgression(now: Date = .now) {
        guard let pendingDraft, let service = makeService() else { return }
        service.endWithoutProgression(pendingDraft, now: now)
        resumedDraftID = nil
        self.pendingDraft = nil
        refreshToken += 1
    }

    func discardPendingDraft() {
        guard let pendingDraft, let service = makeService() else { return }
        service.discard(pendingDraft)
        resumedDraftID = nil
        self.pendingDraft = nil
        refreshToken += 1
    }

    private func makeService() -> DraftSessionService? {
        guard let modelContext else { return nil }
        return try? DraftSessionService(modelContext: modelContext)
    }
}

struct DraftReopenSheet: View {
    let coordinator: DraftReopenCoordinator

    @State private var isConfirmingDiscard = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text(title)
                    .font(.title2.weight(.semibold))

                Text(summary)
                    .font(.body)
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    Button("Resume") {
                        coordinator.resumePendingDraft()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Finish and apply progression") {
                        coordinator.finalizePendingDraft()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!(coordinator.pendingDraft?.allWorkingSetsComplete ?? false))

                    Button("End without progression") {
                        coordinator.endPendingDraftWithoutProgression()
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)

                    Button("Discard", role: .destructive) {
                        isConfirmingDiscard = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }

                Spacer(minLength: 0)
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "Discard unfinished workout?",
                isPresented: $isConfirmingDiscard,
                titleVisibility: .visible
            ) {
                Button("Discard Workout", role: .destructive) {
                    coordinator.discardPendingDraft()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This deletes the draft and all logged sets.")
            }
        }
        .interactiveDismissDisabled()
    }

    private var title: String {
        guard let pendingDraft = coordinator.pendingDraft else {
            return "Unfinished workout"
        }
        return "Unfinished workout from \(formattedDate(for: pendingDraft.workoutDayID))"
    }

    private var summary: String {
        guard let pendingDraft = coordinator.pendingDraft else {
            return ""
        }
        let dayName = pendingDraft.programDay?.name ?? "Workout"
        return "\(dayName) — \(pendingDraft.completedWorkingSetCount) of \(pendingDraft.totalWorkingSetCount) sets complete"
    }

    private func formattedDate(for workoutDayID: String) -> String {
        let parts = workoutDayID.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return workoutDayID }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = DateComponents(
            timeZone: .current,
            year: parts[0],
            month: parts[1],
            day: parts[2],
            hour: 12
        )
        guard let date = calendar.date(from: components) else {
            return workoutDayID
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

private extension WorkoutSession {
    var completedWorkingSetCount: Int {
        exerciseLogs
            .flatMap(\.sets)
            .filter { $0.kind == .working && $0.actualReps != nil }
            .count
    }

    var totalWorkingSetCount: Int {
        exerciseLogs
            .flatMap(\.sets)
            .filter { $0.kind == .working }
            .count
    }

    var allWorkingSetsComplete: Bool {
        let workingSets = exerciseLogs.flatMap(\.sets).filter { $0.kind == .working }
        return !workingSets.isEmpty && workingSets.allSatisfy { $0.actualReps != nil }
    }
}
