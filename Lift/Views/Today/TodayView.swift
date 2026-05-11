import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TodayViewModel()
    @State private var undoCoordinator = UndoCoordinator()
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
            Button("Finish workout") {}
                .buttonStyle(.borderedProminent)
                .disabled(true)
                .frame(maxWidth: .infinity)

            Text("Finish workout lands in Phase 4c")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
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

#Preview {
    TodayView(draftReopenCoordinator: DraftReopenCoordinator())
        .modelContainer(PreviewSupport.container)
}
