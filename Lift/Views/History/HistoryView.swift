import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = HistoryViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("History")
        }
        .task {
            viewModel.setModelContext(modelContext)
            viewModel.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.sections.isEmpty {
            ContentUnavailableView(
                "No completed workouts yet",
                systemImage: "clock.arrow.circlepath",
                description: Text("Finish a workout from the Today tab and it’ll show up here.")
            )
        } else {
            List {
                ForEach(viewModel.sections) { section in
                    Section {
                        ForEach(section.sessions, id: \.id) { session in
                            NavigationLink {
                                SessionDetailView(session: session, viewModel: viewModel)
                            } label: {
                                HistorySessionRow(session: session)
                            }
                        }
                    } header: {
                        Text(HistorySectionBuilder.title(forMonthKey: section.monthKey))
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

private struct HistorySessionRow: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(dateString)
                    .font(.headline)
                Spacer()
                Text(workoutName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let badge = statusBadge {
                    Text(badge)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2), in: Capsule())
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                ForEach(orderedExerciseLogs, id: \.id) { log in
                    let summary = ExerciseLogSummary.make(from: log)
                    HStack(spacing: 6) {
                        Image(systemName: summary.didSucceed ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .foregroundStyle(summary.didSucceed ? Color.green : Color.secondary)
                        Text(summary.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var orderedExerciseLogs: [ExerciseLog] {
        session.exerciseLogs
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("EEE MMM d")
        return formatter.string(from: session.startedAt)
    }

    private var workoutName: String {
        session.programDay?.name ?? "Workout"
    }

    private var statusBadge: String? {
        switch session.status {
        case .completed, .draft:
            return nil
        case .endedNoProgression:
            return "NO PROGRESSION"
        case .abandoned:
            return "ABANDONED"
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(PreviewSupport.container)
}
