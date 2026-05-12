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

    @Environment(\.restTimer) private var restTimer
    @State private var isShowingWarmups = false
    @State private var hasInitializedWarmupExpansion = false
    @State private var hasUserToggledWarmupExpansion = false
    @State private var isShowingWorkingWeightEditor = false
    @State private var isShowingPlateCalculator = false

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
                    HStack(spacing: 8) {
                        Text("\(formattedWeight) kg")
                            .font(.title2.weight(.bold))

                        Button {
                            isShowingWorkingWeightEditor = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.body.weight(.semibold))
                                .padding(8)
                                .background(Color.secondary.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit working weight for today")
                    }

                    Button {
                        if weightLoading != nil {
                            isShowingPlateCalculator = true
                        }
                    } label: {
                        Text(plateSuggestion)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(weightLoading == nil)
                    .accessibilityLabel("Plate calculator: \(plateSuggestion)")
                }
            }

            DisclosureGroup(isExpanded: warmupExpansionBinding) {
                VStack(alignment: .leading, spacing: 12) {
                    if warmupSets.isEmpty {
                        Text("No warmup sets")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 8) {
                                ForEach(warmupSets, id: \.id) { set in
                                    TodaySetTile(
                                        set: set,
                                        onTap: { onTapSet(set.id) },
                                        onEditWeight: { onEditSetWeight(set.id, $0) },
                                        onEditReps: { onEditSetReps(set.id, $0) },
                                        onDelete: { onDeleteSet(set.id) },
                                        weightLoading: weightLoading
                                    )
                                    .frame(width: 86)
                                }
                            }
                            .padding(.top, 8)
                            .padding(.horizontal, 1)
                        }
                    }

                    Button {
                        onAddWarmup()
                    } label: {
                        Label("Add warmup", systemImage: "plus.circle")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } label: {
                sectionLabel(title: "Warmup", count: warmupSets.count)
            }

            VStack(alignment: .leading, spacing: 12) {
                sectionLabel(title: "Working sets", count: workingSets.count)

                HStack(alignment: .top, spacing: 8) {
                    ForEach(workingSets, id: \.id) { set in
                        TodaySetTile(
                            set: set,
                            onTap: { onTapSet(set.id) },
                            onEditWeight: { onEditSetWeight(set.id, $0) },
                            onDelete: { onDeleteSet(set.id) },
                            weightLoading: weightLoading
                        )
                    }
                }

                if let restTimer,
                   let activeRest = restTimer.active,
                   workingSets.contains(where: { $0.id == activeRest.setID }) {
                    RestTimerInlineView(restTimer: restTimer, setID: activeRest.setID)
                }
            }
        }
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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

    private var warmupSets: [DraftSet] {
        exerciseLog.sets.filter { $0.kind == .warmup }
    }

    private var workingSets: [DraftSet] {
        exerciseLog.sets.filter { $0.kind == .working }
    }

    private var allWarmupsComplete: Bool {
        guard !warmupSets.isEmpty else { return false }
        return warmupSets.allSatisfy { set in
            SetTapStateMachine.state(for: set.actualReps, targetReps: set.targetReps) == .complete
        }
    }

    private var warmupExpansionBinding: Binding<Bool> {
        Binding(
            get: { isShowingWarmups },
            set: { newValue in
                hasUserToggledWarmupExpansion = true
                isShowingWarmups = newValue
            }
        )
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

private struct RestTimerInlineView: View {
    @Bindable var restTimer: RestTimerService
    let setID: UUID

    @Environment(\.haptics) private var haptics
    @Environment(\.scenePhase) private var scenePhase
    @State private var completedSetID: UUID?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let activeRest = activeRest {
                inlineContent(activeRest: activeRest, now: context.date)
            } else if completedSetID == setID {
                restedContent
            }
        }
        .task(id: completionTaskID) {
            guard let activeRest else { return }

            let remaining = restTimer.remaining() ?? 0
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }

            guard scenePhase == .active,
                  restTimer.active?.setID == activeRest.setID,
                  restTimer.hasFinished() else {
                return
            }

            completedSetID = activeRest.setID
            haptics.restCompleted()

            try? await Task.sleep(for: .seconds(3))
            guard restTimer.active?.setID == activeRest.setID else {
                completedSetID = nil
                return
            }
            await restTimer.clearIfFinished()
            completedSetID = nil
        }
    }

    @ViewBuilder
    private func inlineContent(activeRest: RestTimerService.ActiveRest, now: Date) -> some View {
        if restTimer.hasFinished(now: now) {
            restedContent
        } else {
            let remaining = max(restTimer.remaining(now: now) ?? 0, 0)
            let progress = Double(remaining) / Double(max(activeRest.durationSeconds, 1))

            VStack(alignment: .leading, spacing: 12) {
                Text(formatted(remaining))
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                ProgressView(value: progress)
                    .tint(.accentColor)

                HStack(spacing: 12) {
                    Button("Skip") {
                        Task {
                            await restTimer.skip()
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("+30s") {
                        Task {
                            await restTimer.extend(bySeconds: 30)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .font(.caption.weight(.semibold))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var restedContent: some View {
        HStack {
            Text("Rested!")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.green)
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var activeRest: RestTimerService.ActiveRest? {
        let active = restTimer.active
        guard active?.setID == setID else { return nil }
        return active
    }

    private var completionTaskID: String? {
        guard let activeRest else { return nil }
        return "\(activeRest.setID.uuidString)-\(activeRest.durationSeconds)-\(scenePhase == .active)"
    }

    private func formatted(_ remainingSeconds: Int) -> String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return "\(minutes):\(seconds.formatted(.number.precision(.integerLength(2))))"
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
    .background(Color(.systemGroupedBackground))
}
