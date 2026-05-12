import SwiftUI

struct TodayExerciseCard: View {
    let exerciseLog: DraftExerciseLog
    let plateSuggestion: String
    let weightLoading: WeightLoading?
    let onTapSet: (UUID) -> Void
    let onEditWorkingWeight: (Double) -> Void
    let onEditSetWeight: (UUID, Double) -> Void
    let onEditSetReps: (UUID, Int) -> Void
    let onDeleteSet: (UUID) -> Void
    let onAddWarmup: () -> Void

    @State private var isShowingWarmups = false
    @State private var hasInitializedWarmupExpansion = false
    @State private var hasUserToggledWarmupExpansion = false
    @State private var isShowingWorkingWeightEditor = false
    @State private var isShowingPlateCalculator = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerRow

            Divider().background(LiftTheme.cardBorder)

            warmupSection

            Divider().background(LiftTheme.cardBorder)

            workingSection
        }
        .padding(20)
        .background(LiftTheme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(LiftTheme.cardBorder, lineWidth: 1)
        )
        .sheet(isPresented: $isShowingWorkingWeightEditor) {
            WeightEditorSheet(
                title: "Edit working weight",
                initialWeightKg: exerciseLog.targetWeightKgSnapshot,
                onCommit: onEditWorkingWeight,
                weightLoading: weightLoading
            )
        }
        .sheet(isPresented: $isShowingPlateCalculator) {
            if let weightLoading {
                PlateCalculatorSheet(
                    initialWeightKg: exerciseLog.targetWeightKgSnapshot,
                    weightLoading: weightLoading,
                    onUseWeight: onEditWorkingWeight
                )
            }
        }
        .onAppear {
            guard !hasInitializedWarmupExpansion else { return }
            hasInitializedWarmupExpansion = true
            isShowingWarmups = !warmupSets.isEmpty && !allWarmupsComplete
        }
        .onChange(of: allWarmupsComplete) { _, isComplete in
            guard isComplete, !hasUserToggledWarmupExpansion, isShowingWarmups else { return }
            withAnimation(.easeInOut) {
                isShowingWarmups = false
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(exerciseLog.exerciseNameSnapshot)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(LiftTheme.textPrimary)

                Text("\(exerciseLog.targetSetsSnapshot) × \(exerciseLog.targetRepsSnapshot)")
                    .font(.subheadline)
                    .foregroundStyle(LiftTheme.textSecondary)
            }

            Spacer(minLength: 12)

            Button {
                isShowingWorkingWeightEditor = true
            } label: {
                HStack(spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(formattedWeight)
                            .font(.title.weight(.bold))
                            .foregroundStyle(LiftTheme.accent)
                        Text("kg")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(LiftTheme.textSecondary)
                    }
                    Image(systemName: "pencil")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(LiftTheme.textSecondary)
                        .padding(8)
                        .background(LiftTheme.raisedFill, in: Circle())
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit working weight, currently \(formattedWeight) kilograms")
        }
    }

    private var warmupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "Warmup",
                count: warmupSets.count,
                isExpanded: warmupSets.isEmpty ? false : isShowingWarmups,
                isToggleable: !warmupSets.isEmpty
            ) {
                hasUserToggledWarmupExpansion = true
                withAnimation(.easeInOut) {
                    isShowingWarmups.toggle()
                }
            }

            if warmupSets.isEmpty || isShowingWarmups {
                if warmupSets.isEmpty {
                    Text("No warmup sets")
                        .font(.subheadline)
                        .foregroundStyle(LiftTheme.textSecondary)
                } else {
                    setRow(sets: warmupSets, nextUpID: nil)
                }

                Button {
                    onAddWarmup()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.body.weight(.semibold))
                        Text("Add warmup")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(LiftTheme.accent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(LiftTheme.accentMuted.opacity(0.5), in: Capsule())
                    .overlay(Capsule().strokeBorder(LiftTheme.accentBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var workingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "Working sets",
                count: workingSets.count,
                isExpanded: true,
                isToggleable: false,
                onToggle: nil
            )

            setRow(sets: workingSets, nextUpID: nextUpWorkingSetID)
        }
    }

    @ViewBuilder
    private func setRow(sets: [DraftSet], nextUpID: UUID?) -> some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(sets, id: \.id) { set in
                TodaySetTile(
                    set: set,
                    isNextUp: set.id == nextUpID,
                    onTap: { onTapSet(set.id) },
                    onEditWeight: { onEditSetWeight(set.id, $0) },
                    onEditReps: set.kind == .warmup ? { onEditSetReps(set.id, $0) } : nil,
                    onDelete: { onDeleteSet(set.id) },
                    weightLoading: weightLoading
                )
            }
        }
    }

    private var warmupSets: [DraftSet] {
        exerciseLog.sets.filter { $0.kind == .warmup }
    }

    private var workingSets: [DraftSet] {
        exerciseLog.sets.filter { $0.kind == .working }
    }

    private var nextUpWorkingSetID: UUID? {
        workingSets.first { set in
            SetTapStateMachine.state(for: set.actualReps, targetReps: set.targetReps) == .pending
        }?.id
    }

    private var allWarmupsComplete: Bool {
        guard !warmupSets.isEmpty else { return false }
        return warmupSets.allSatisfy { set in
            SetTapStateMachine.state(for: set.actualReps, targetReps: set.targetReps) == .complete
        }
    }

    private var formattedWeight: String {
        exerciseLog.targetWeightKgSnapshot.formatted(
            .number.precision(.fractionLength(exerciseLog.targetWeightKgSnapshot.rounded(.down) == exerciseLog.targetWeightKgSnapshot ? 0 : 1))
        )
    }

    private func completedCount(in sets: [DraftSet]) -> Int {
        sets.reduce(into: 0) { count, set in
            if SetTapStateMachine.state(for: set.actualReps, targetReps: set.targetReps) == .complete {
                count += 1
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(
        title: String,
        count: Int,
        isExpanded: Bool,
        isToggleable: Bool,
        onToggle: (() -> Void)? = nil
    ) -> some View {
        let progressLine = "\(completedCount(in: title == "Warmup" ? warmupSets : workingSets))/\(count)"

        HStack(alignment: .center) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(LiftTheme.textPrimary)

            Spacer()

            if isToggleable, let onToggle {
                Button(action: onToggle) {
                    HStack(spacing: 6) {
                        Text(progressLine)
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(LiftTheme.accent)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(LiftTheme.accent)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(title) — \(progressLine) complete. \(isExpanded ? "Collapse" : "Expand")")
            } else {
                Text(progressLine)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(LiftTheme.accent)
                    .accessibilityLabel("\(title) — \(progressLine) complete")
            }
        }
    }
}

#Preview {
    let viewModel = PreviewSupport.todayViewModel()
    let draftPlan = PreviewSupport.draftPlan()

    ScrollView {
        TodayExerciseCard(
            exerciseLog: draftPlan.exerciseLogs[0],
            plateSuggestion: viewModel.plateSuggestion(for: draftPlan.exerciseLogs[0]),
            weightLoading: viewModel.weightLoading,
            onTapSet: { _ in },
            onEditWorkingWeight: { _ in },
            onEditSetWeight: { _, _ in },
            onEditSetReps: { _, _ in },
            onDeleteSet: { _ in },
            onAddWarmup: {}
        )
        .padding()
    }
    .background(LiftTheme.canvas)
}
