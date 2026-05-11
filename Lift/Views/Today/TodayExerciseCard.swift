import SwiftUI

struct TodayExerciseCard: View {
    let exerciseLog: DraftExerciseLog
    let plateSuggestion: String

    @State private var isShowingWarmups = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(exerciseLog.exerciseNameSnapshot)
                        .font(.title3.weight(.semibold))
                    Text("\(exerciseLog.targetSetsSnapshot) × \(exerciseLog.targetRepsSnapshot)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text("\(formattedWeight) kg")
                        .font(.title2.weight(.bold))
                    Text(plateSuggestion)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                        .foregroundStyle(.secondary)
                }
            }

            if !warmupSets.isEmpty {
                DisclosureGroup(isExpanded: $isShowingWarmups) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(warmupSets, id: \.id) { set in
                            TodaySetRow(set: set)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    sectionLabel(title: "Warmup", count: warmupSets.count)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                sectionLabel(title: "Working sets", count: workingSets.count)
                ForEach(workingSets, id: \.id) { set in
                    TodaySetRow(set: set)
                }
            }
        }
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var warmupSets: [DraftSet] {
        exerciseLog.sets.filter { $0.kind == .warmup }
    }

    private var workingSets: [DraftSet] {
        exerciseLog.sets.filter { $0.kind == .working }
    }

    private var formattedWeight: String {
        exerciseLog.targetWeightKgSnapshot.formatted(
            .number.precision(.fractionLength(exerciseLog.targetWeightKgSnapshot.rounded(.down) == exerciseLog.targetWeightKgSnapshot ? 0 : 1))
        )
    }

    @ViewBuilder
    private func sectionLabel(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text("\(count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    let draftPlan = PreviewSupport.draftPlan()

    ScrollView {
        TodayExerciseCard(
            exerciseLog: draftPlan.exerciseLogs[0],
            plateSuggestion: PreviewSupport.todayViewModel().plateSuggestion(for: draftPlan.exerciseLogs[0])
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
