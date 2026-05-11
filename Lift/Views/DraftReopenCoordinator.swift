import Foundation
import Observation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class DraftReopenCoordinator {
    private var modelContext: ModelContext?

    var pendingDraft: WorkoutSession?
    var pendingDraftPreview: FinishWorkoutPreview?
    var resumedDraftID: UUID?
    var refreshToken = 0
    var confirmationMessage: String?

    var canFinalizePendingDraft: Bool {
        pendingDraftPreview?.canApplyProgression ?? false
    }

    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
    }

    func setModelContext(_ modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func load(now: Date = .now, calendar: Calendar = .current) {
        guard let service = makeService() else {
            pendingDraft = nil
            pendingDraftPreview = nil
            return
        }

        let todayID = LocalDay.id(for: now, in: calendar.timeZone)
        pendingDraft = service.allDrafts().first(where: { $0.workoutDayID < todayID })
        pendingDraftPreview = pendingDraft.flatMap { try? service.finishWorkoutPreview(for: $0) }
    }

    func resumePendingDraft() {
        resumedDraftID = pendingDraft?.id
        pendingDraft = nil
        pendingDraftPreview = nil
        refreshToken += 1
    }

    func finalizePendingDraft(now: Date = .now) {
        guard let pendingDraft, let service = makeService() else { return }
        guard canFinalizePendingDraft else { return }
        do {
            _ = try service.finalize(pendingDraft, now: now)
        } catch {
            assertionFailure("Failed to finalize stale draft: \(error)")
            return
        }
        resumedDraftID = nil
        self.pendingDraft = nil
        pendingDraftPreview = nil
        confirmationMessage = "Progression applied"
        refreshToken += 1
    }

    func endPendingDraftWithoutProgression(now: Date = .now) {
        guard let pendingDraft, let service = makeService() else { return }
        service.endWithoutProgression(pendingDraft, now: now)
        resumedDraftID = nil
        self.pendingDraft = nil
        pendingDraftPreview = nil
        confirmationMessage = "Workout ended without progression"
        refreshToken += 1
    }

    func discardPendingDraft() {
        guard let pendingDraft, let service = makeService() else { return }
        service.discard(pendingDraft)
        resumedDraftID = nil
        self.pendingDraft = nil
        pendingDraftPreview = nil
        refreshToken += 1
    }

    func presentConfirmation(_ message: String) {
        confirmationMessage = message
    }

    func clearConfirmationMessage() {
        confirmationMessage = nil
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
                    if let preview = coordinator.pendingDraftPreview {
                        DraftFinishPreviewSummary(preview: preview, compact: true)
                    }

                    Button("Resume") {
                        coordinator.resumePendingDraft()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Finish and apply progression") {
                        coordinator.finalizePendingDraft()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!coordinator.canFinalizePendingDraft)

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
