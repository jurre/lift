import SwiftUI
import SwiftData

struct SessionDetailView: View {
    let session: WorkoutSession
    let viewModel: HistoryViewModel

    @State private var workingSetEditTarget: LoggedSet?
    @State private var warmupSetEditTarget: LoggedSet?
    @State private var transientFlippedExerciseLogID: UUID?
    @State private var bannerDismissalTask: Task<Void, Never>?
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let banner = bannerCopy {
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(banner)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.orange.opacity(0.12))
                }
            }

            if let statusNote {
                Section {
                    Text(statusNote)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(orderedExerciseLogs, id: \.id) { log in
                Section {
                    let workingSets = sortedSets(in: log, kind: .working)
                    ForEach(workingSets, id: \.id) { set in
                        HistorySetRow(
                            set: set,
                            onEditWorkingSet: { workingSetEditTarget = $0 },
                            onEditWarmupSet: { _ in }
                        )
                    }

                    let warmupSets = sortedSets(in: log, kind: .warmup)
                    if !warmupSets.isEmpty {
                        DisclosureGroup("Warmup (\(warmupSets.count))") {
                            ForEach(warmupSets, id: \.id) { set in
                                HistorySetRow(
                                    set: set,
                                    onEditWorkingSet: { _ in },
                                    onEditWarmupSet: { warmupSetEditTarget = $0 }
                                )
                            }
                        }
                    }
                } header: {
                    headerView(for: log)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Couldn’t save", isPresented: errorAlertBinding) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(item: $workingSetEditTarget) { set in
            HistoryWorkingSetEditorSheet(
                title: set.log?.exerciseNameSnapshot ?? "Edit set",
                initialWeightKg: set.weightKg,
                initialActualReps: set.actualReps,
                targetReps: set.targetReps,
                weightLoading: viewModel.weightLoading
            ) { newWeight, newReps in
                applyWorkingSetEdit(setID: set.id, weightKg: newWeight, actualReps: newReps)
            }
        }
        .sheet(item: $warmupSetEditTarget) { set in
            WarmupSetEditorSheet(
                initialWeightKg: set.weightKg,
                initialReps: set.actualReps ?? set.targetReps
            ) { newWeight, newReps in
                applyWarmupSetEdit(setID: set.id, weightKg: newWeight, reps: newReps)
            }
        }
        .onDisappear {
            bannerDismissalTask?.cancel()
        }
    }

    private var navigationTitle: String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("EEE MMM d")
        return formatter.string(from: session.startedAt)
    }

    private var orderedExerciseLogs: [ExerciseLog] {
        // Stable display order by exerciseName, falling back to insertion order.
        // ExerciseLog has no explicit `order`, so preserve session.exerciseLogs ordering.
        session.exerciseLogs
    }

    private func sortedSets(in log: ExerciseLog, kind: SetKind) -> [LoggedSet] {
        log.sets.filter { $0.kind == kind }.sorted { $0.index < $1.index }
    }

    private func headerView(for log: ExerciseLog) -> some View {
        HStack(spacing: 8) {
            Text(log.exerciseNameSnapshot)
            if transientFlippedExerciseLogID == log.id {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Outcome changed")
            }
        }
    }

    private var bannerCopy: String? {
        guard transientFlippedExerciseLogID != nil else { return nil }
        switch session.status {
        case .completed:
            return "This change flips whether progression should have applied for this exercise. Current weights are NOT auto-recalculated — adjust manually in Settings if needed."
        case .endedNoProgression, .abandoned:
            return "This change updates the historical record. Progression was never applied for this session, so current weights are unaffected."
        case .draft:
            return nil
        }
    }

    private var statusNote: String? {
        switch session.status {
        case .completed, .draft:
            return nil
        case .endedNoProgression:
            return "Ended without progression. This session is in the record but did not bump weights or advance the A/B rotation."
        case .abandoned:
            return "Marked abandoned. This session is in the record but did not bump weights or advance the A/B rotation."
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { newValue in if !newValue { errorMessage = nil } }
        )
    }

    private func applyWorkingSetEdit(setID: UUID, weightKg: Double, actualReps: Int?) {
        do {
            let weightResult = try viewModel.editWeight(setID: setID, weightKg: weightKg)
            let repsResult = try viewModel.editActualReps(setID: setID, actualReps: actualReps)
            let flipped = weightResult.flippedSuccessForExercise || repsResult.flippedSuccessForExercise
            if flipped {
                surfaceTransientFlip(exerciseLogID: repsResult.exerciseLogID)
            }
        } catch {
            errorMessage = describe(error)
        }
    }

    private func applyWarmupSetEdit(setID: UUID, weightKg: Double, reps: Int) {
        do {
            _ = try viewModel.editWeight(setID: setID, weightKg: weightKg)
            _ = try viewModel.editActualReps(setID: setID, actualReps: reps)
        } catch {
            errorMessage = describe(error)
        }
    }

    private func surfaceTransientFlip(exerciseLogID: UUID) {
        bannerDismissalTask?.cancel()
        transientFlippedExerciseLogID = exerciseLogID
        bannerDismissalTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(8))
            if !Task.isCancelled {
                transientFlippedExerciseLogID = nil
            }
        }
    }

    private func describe(_ error: Error) -> String {
        if let historyError = error as? HistoryViewModelError {
            switch historyError {
            case .missingModelContext:
                return "The history view isn’t connected yet. Try again."
            case .missingSet:
                return "That set was removed before the edit could be saved."
            }
        }
        return error.localizedDescription
    }
}
