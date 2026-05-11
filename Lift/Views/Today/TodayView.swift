import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TodayViewModel()

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
                                    plateSuggestion: viewModel.plateSuggestion(for: exerciseLog)
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
            .task {
                viewModel.setModelContext(modelContext)
                viewModel.load()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            WorkoutPicker(
                selectedDayName: viewModel.selectedProgramDay?.name ?? "Choose workout",
                availableProgramDays: viewModel.availableProgramDays,
                onSelect: viewModel.select(day:)
            )

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

            Text("Logging starts in Phase 4")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.top, 8)
        .padding(.bottom, 24)
    }
}

#Preview {
    TodayView()
        .modelContainer(PreviewSupport.container)
}
