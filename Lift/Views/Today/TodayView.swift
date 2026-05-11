import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TodayViewModel()
    @State private var undoCoordinator = UndoCoordinator()
    @State private var isShowingFinishSheet = false
    let draftReopenCoordinator: DraftReopenCoordinator

    var body: some View {
        NavigationStack {
            Group {
                if let draftPlan = viewModel.draftPlan {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            header

                            ForEach(draftPlan.exerciseLogs, id: \.id) { exerciseLog in
                                TodayExerciseCard(
                                    exerciseLog: exerciseLog,
                                    plateSuggestion: viewModel.plateSuggestion(for: exerciseLog),
                                    onTapSet: { setID in
                                        perform { try viewModel.tapSet(setID) }
                                    },
                                    onEditWorkingWeight: { newWeight in
                                        perform { try viewModel.editWeight(forExerciseLog: exerciseLog.id, newWeightKg: newWeight) }
                                    },
                                    onEditSetWeight: { setID, newWeight in
                                        perform { try viewModel.editWeight(forSet: setID, newWeightKg: newWeight) }
                                    },
                                    onDeleteSet: { setID in
                                        perform { try viewModel.deleteSet(setID) }
                                    }
                                )
                            }

                            footer
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                    }
                    .background(Color(.systemGroupedBackground))
                } else if viewModel.isLoading {
                    ProgressView("Loading today’s workout…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView(
                        "No program configured",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("Finish setup to see today’s workout.")
                    )
                }
            }
            .navigationTitle("Today")
            .task(id: draftReopenCoordinator.refreshToken) {
                viewModel.setModelContext(modelContext)
                viewModel.setReopenedDraftID(draftReopenCoordinator.resumedDraftID)
                viewModel.setUndoCoordinator(undoCoordinator)
                viewModel.load()
            }
            .safeAreaInset(edge: .bottom) {
                if let snackbar = undoCoordinator.currentSnackbar {
                    SnackbarView(message: snackbar.message, actionTitle: "Undo") {
                        guard let action = undoCoordinator.undo() else { return }
                        perform { try viewModel.restoreSet(action.setID, actualReps: action.restoreReps) }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
            }
            .task(id: undoCoordinator.currentSnackbar?.id) {
                guard undoCoordinator.currentSnackbar != nil else { return }
                try? await Task.sleep(for: .seconds(4))
                undoCoordinator.tick()
            }
            .sheet(isPresented: $isShowingFinishSheet) {
                if let preview = viewModel.finishWorkoutPreview {
                    FinishWorkoutSheet(
                        preview: preview,
                        onFinish: {
                            perform {
                                _ = try viewModel.finalizeCurrentSession()
                                draftReopenCoordinator.presentConfirmation("Progression applied")
                            }
                            isShowingFinishSheet = false
                        },
                        onEndWithoutProgression: {
                            perform {
                                try viewModel.endCurrentSessionWithoutProgression()
                                draftReopenCoordinator.presentConfirmation("Workout ended without progression")
                            }
                            isShowingFinishSheet = false
                        },
                        onCancel: {
                            isShowingFinishSheet = false
                        }
                    )
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            WorkoutPicker(
                selectedDayName: viewModel.selectedProgramDay?.name ?? "Choose workout",
                availableProgramDays: viewModel.availableProgramDays,
                isLocked: viewModel.isProgramDayLocked,
                onSelect: viewModel.select(day:)
            )

            if let programDayLockHint = viewModel.programDayLockHint {
                Text(programDayLockHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(Date.now.formatted(date: .complete, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 4)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Finish workout") {
                isShowingFinishSheet = true
            }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canOpenFinishSheet)
                .frame(maxWidth: .infinity)

            if let hint = viewModel.finishWorkoutHint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            assertionFailure("Today action failed: \(error)")
        }
    }
}

private struct FinishWorkoutSheet: View {
    let preview: FinishWorkoutPreview
    let onFinish: () -> Void
    let onEndWithoutProgression: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Finish workout?")
                    .font(.title2.weight(.semibold))

                if preview.pendingWorkingSetCount > 0 {
                    Text("\(preview.pendingWorkingSetCount) working sets not yet logged")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.orange)
                }

                DraftFinishPreviewSummary(preview: preview, compact: false)

                Spacer(minLength: 0)

                VStack(spacing: 12) {
                    Button("Finish & apply progression", action: onFinish)
                        .buttonStyle(.borderedProminent)
                        .disabled(!preview.canApplyProgression)

                    Button("End without progression", action: onEndWithoutProgression)
                        .buttonStyle(.bordered)
                        .tint(.orange)

                    Button("Cancel", role: .cancel, action: onCancel)
                        .buttonStyle(.bordered)
                }
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct DraftFinishPreviewSummary: View {
    let preview: FinishWorkoutPreview
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(preview.perExercise.enumerated()), id: \.offset) { _, exercise in
                VStack(alignment: .leading, spacing: 4) {
                    if !compact {
                        Text(exercise.setSummary.isEmpty ? "—" : exercise.setSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(compact ? compactLine(for: exercise) : detailLine(for: exercise))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }

            if let nextProgramDayName = preview.nextProgramDayName {
                Text(nextSummary(dayName: nextProgramDayName, exerciseNames: preview.nextProgramExerciseNames))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func detailLine(for exercise: FinishWorkoutPreview.PerExercise) -> String {
        switch exercise.state {
        case .incomplete:
            return "\(exercise.exerciseName) — incomplete"
        case .willProgress:
            return "\(exercise.exerciseName) \(formatted(exercise.oldWeightKg)) → \(formatted(exercise.newWeightKg)) kg"
        case .stalled:
            return "\(exercise.exerciseName) \(formatted(exercise.oldWeightKg)) kg (stalled, \(sessionLabel(exercise.stalledCount)))"
        case .unchanged:
            return "\(exercise.exerciseName) \(formatted(exercise.oldWeightKg)) kg (load unchanged)"
        }
    }

    private func compactLine(for exercise: FinishWorkoutPreview.PerExercise) -> String {
        switch exercise.state {
        case .incomplete:
            return "\(exercise.exerciseName) — incomplete"
        case .willProgress:
            return "\(exercise.exerciseName) \(formatted(exercise.oldWeightKg)) → \(formatted(exercise.newWeightKg))"
        case .stalled:
            return "\(exercise.exerciseName) \(formatted(exercise.oldWeightKg)) stalled"
        case .unchanged:
            return "\(exercise.exerciseName) \(formatted(exercise.oldWeightKg)) unchanged"
        }
    }

    private func nextSummary(dayName: String, exerciseNames: [String]) -> String {
        guard !exerciseNames.isEmpty else { return "Next time: \(dayName)" }
        return "Next time: \(dayName) — \(exerciseNames.joined(separator: ", "))"
    }

    private func formatted(_ weight: Double) -> String {
        weight.formatted(.number.precision(.fractionLength(1)))
    }

    private func sessionLabel(_ count: Int) -> String {
        count == 1 ? "1 session" : "\(count) sessions"
    }
}

#Preview {
    TodayView(draftReopenCoordinator: DraftReopenCoordinator())
        .modelContainer(PreviewSupport.container)
}
