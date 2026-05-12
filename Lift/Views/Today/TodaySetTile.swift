import SwiftUI
import UIKit

struct TodaySetTile: View {
    let set: DraftSet
    let isNextUp: Bool
    let onTap: () -> Void
    let onEditWeight: ((Double) -> Void)?
    let onEditReps: ((Int) -> Void)?
    let onDelete: (() -> Void)?
    let weightLoading: WeightLoading?

    @State private var isShowingWeightEditor = false
    @State private var isShowingWarmupEditor = false

    init(
        set: DraftSet,
        isNextUp: Bool = false,
        onTap: @escaping () -> Void,
        onEditWeight: ((Double) -> Void)? = nil,
        onEditReps: ((Int) -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        weightLoading: WeightLoading? = nil
    ) {
        self.set = set
        self.isNextUp = isNextUp
        self.onTap = onTap
        self.onEditWeight = onEditWeight
        self.onEditReps = onEditReps
        self.onDelete = onDelete
        self.weightLoading = weightLoading
    }

    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(labelColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                statusIcon
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(stateBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(stateBorder, lineWidth: stateBorderWidth)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if set.kind == .warmup, onEditWeight != nil || onEditReps != nil {
                Button("Edit warmup", systemImage: "pencil") {
                    isShowingWarmupEditor = true
                }
            } else if set.kind == .working, onEditWeight != nil {
                Button("Edit weight for this set", systemImage: "pencil") {
                    isShowingWeightEditor = true
                }
            }
            if let onDelete {
                Button("Delete set", systemImage: "trash", role: .destructive, action: onDelete)
            }
        }
        .sheet(isPresented: $isShowingWeightEditor) {
            if let onEditWeight {
                WeightEditorSheet(
                    title: "Edit set weight",
                    initialWeightKg: set.weightKg,
                    onCommit: onEditWeight,
                    weightLoading: weightLoading
                )
            }
        }
        .sheet(isPresented: $isShowingWarmupEditor) {
            WarmupSetEditorSheet(
                initialWeightKg: set.weightKg,
                initialReps: set.targetReps,
                onCommit: { newWeight, newReps in
                    if let onEditWeight, newWeight != set.weightKg {
                        onEditWeight(newWeight)
                    }
                    if let onEditReps, newReps != set.targetReps {
                        onEditReps(newReps)
                    }
                }
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityAction(named: Text("Tap"), handleTap)
    }

    private var label: String {
        if case let .partial(reps) = cellState, reps != set.targetReps {
            return "\(formattedWeight) × \(reps)"
        }
        return "\(formattedWeight) × \(set.targetReps)"
    }

    private var formattedWeight: String {
        self.set.weightKg.formatted(
            .number.precision(
                .fractionLength(self.set.weightKg.rounded(.down) == self.set.weightKg ? 0 : 1)
            )
        )
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch cellState {
        case .complete:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.white, LiftTheme.accent)
        case let .partial(reps) where reps == 0:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.white, LiftTheme.danger)
        case .partial:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.white, LiftTheme.warning)
        case .pending:
            Image(systemName: "circle")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(LiftTheme.textTertiary)
        }
    }

    private var cellState: SetCellState {
        SetTapStateMachine.state(for: self.set.actualReps, targetReps: self.set.targetReps)
    }

    private var stateBackground: Color {
        switch cellState {
        case .complete: return LiftTheme.accentMuted
        case let .partial(reps) where reps == 0: return LiftTheme.danger.opacity(0.16)
        case .partial: return LiftTheme.warning.opacity(0.16)
        case .pending: return LiftTheme.raisedFill
        }
    }

    private var stateBorder: Color {
        switch cellState {
        case .complete: return LiftTheme.accentBorder
        case let .partial(reps) where reps == 0: return LiftTheme.danger.opacity(0.55)
        case .partial: return LiftTheme.warning.opacity(0.55)
        case .pending: return isNextUp ? LiftTheme.accentBorder : Color.white.opacity(0.10)
        }
    }

    private var stateBorderWidth: CGFloat {
        switch cellState {
        case .complete, .partial: return 1
        case .pending: return isNextUp ? 1.5 : 1
        }
    }

    private var labelColor: Color {
        switch cellState {
        case .complete: return LiftTheme.textPrimary
        case .partial: return LiftTheme.textPrimary
        case .pending: return isNextUp ? LiftTheme.textPrimary : LiftTheme.textSecondary
        }
    }

    private var accessibilityLabel: String {
        let kindDescription = self.set.kind == .warmup ? "Warmup set" : "Working set"
        let nextUpSuffix = isNextUp ? ", next up" : ""
        return "\(kindDescription)\(nextUpSuffix), \(formattedWeight) kilograms, target \(self.set.targetReps) reps"
    }

    private var accessibilityValue: String {
        switch cellState {
        case .pending: return "Pending"
        case .complete: return "\(self.set.targetReps) reps complete"
        case let .partial(reps) where reps == 0: return "Zero reps recorded"
        case let .partial(reps): return "\(reps) reps partial"
        }
    }

    private func handleTap() {
        let nextState = SetTapStateMachine.tap(current: cellState, targetReps: self.set.targetReps, kind: self.set.kind).newState
        onTap()
        UIAccessibility.post(notification: .announcement, argument: announcement(for: nextState))
    }

    private func announcement(for state: SetCellState) -> String {
        switch state {
        case .pending: return "Set cleared"
        case .complete: return "\(self.set.targetReps) reps complete"
        case let .partial(reps) where reps == 0: return "Zero reps recorded"
        case let .partial(reps): return "\(reps) reps partial"
        }
    }
}

struct WeightEditorSheet: View {
    let title: String
    let initialWeightKg: Double
    let onCommit: (Double) -> Void
    let weightLoading: WeightLoading?

    @Environment(\.dismiss) private var dismiss
    @State private var weightText: String

    init(
        title: String,
        initialWeightKg: Double,
        onCommit: @escaping (Double) -> Void,
        weightLoading: WeightLoading? = nil
    ) {
        self.title = title
        self.initialWeightKg = initialWeightKg
        self.onCommit = onCommit
        self.weightLoading = weightLoading
        _weightText = State(
            initialValue: initialWeightKg.formatted(
                .number.precision(.fractionLength(initialWeightKg.rounded(.down) == initialWeightKg ? 0 : 1))
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Weight (kg)", text: $weightText)
                        .keyboardType(.decimalPad)

                    HStack {
                        Button("−2.5") {
                            adjust(by: -2.5)
                        }
                        Spacer()
                        Button("+2.5") {
                            adjust(by: 2.5)
                        }
                    }
                }

                if weightLoading != nil {
                    Section("Shortcuts") {
                        if let bar = weightLoading?.barWeightKg {
                            Button {
                                setWeight(bar)
                            } label: {
                                Label("Empty bar (\(formatted(bar)) kg)", systemImage: "minus")
                            }
                        }

                        Button {
                            if let next = weightLoading?.nextLowerLoadable(currentWeight) {
                                setWeight(next)
                            }
                        } label: {
                            Label("Next loadable ↓", systemImage: "arrow.down")
                        }
                        .disabled(weightLoading?.nextLowerLoadable(currentWeight) == nil)

                        Button {
                            if let next = weightLoading?.nextHigherLoadable(currentWeight) {
                                setWeight(next)
                            }
                        } label: {
                            Label("Next loadable ↑", systemImage: "arrow.up")
                        }
                        .disabled(weightLoading?.nextHigherLoadable(currentWeight) == nil)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let value = Double(weightText.replacingOccurrences(of: ",", with: ".")) else { return }
                        onCommit(value)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var currentWeight: Double {
        Double(weightText.replacingOccurrences(of: ",", with: ".")) ?? initialWeightKg
    }

    private func adjust(by delta: Double) {
        setWeight(max(0, currentWeight + delta))
    }

    private func setWeight(_ value: Double) {
        weightText = formatted(value)
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(value.rounded(.down) == value ? 0 : 1)))
    }
}

struct WarmupSetEditorSheet: View {
    let initialWeightKg: Double
    let initialReps: Int
    let onCommit: (Double, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var weightText: String
    @State private var reps: Int

    init(initialWeightKg: Double, initialReps: Int, onCommit: @escaping (Double, Int) -> Void) {
        self.initialWeightKg = initialWeightKg
        self.initialReps = initialReps
        self.onCommit = onCommit
        _weightText = State(
            initialValue: initialWeightKg.formatted(
                .number.precision(.fractionLength(initialWeightKg.rounded(.down) == initialWeightKg ? 0 : 1))
            )
        )
        _reps = State(initialValue: initialReps)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Weight") {
                    TextField("Weight (kg)", text: $weightText)
                        .keyboardType(.decimalPad)

                    HStack {
                        Button("−2.5") {
                            adjustWeight(by: -2.5)
                        }
                        Spacer()
                        Button("+2.5") {
                            adjustWeight(by: 2.5)
                        }
                    }
                }

                Section("Reps") {
                    Stepper(value: $reps, in: 1...20) {
                        Text("\(reps) reps")
                            .monospacedDigit()
                    }
                }
            }
            .navigationTitle("Edit warmup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let value = Double(weightText.replacingOccurrences(of: ",", with: ".")) else { return }
                        onCommit(value, reps)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func adjustWeight(by delta: Double) {
        let currentValue = Double(weightText.replacingOccurrences(of: ",", with: ".")) ?? initialWeightKg
        let updated = max(0, currentValue + delta)
        weightText = updated.formatted(.number.precision(.fractionLength(updated.rounded(.down) == updated ? 0 : 1)))
    }
}

#Preview {
    HStack(spacing: 8) {
        TodaySetTile(
            set: DraftSet(id: UUID(), kind: .working, index: 0, weightKg: 60, targetReps: 5, actualReps: 5),
            onTap: {},
            onEditWeight: { _ in },
            onDelete: {}
        )
        TodaySetTile(
            set: DraftSet(id: UUID(), kind: .working, index: 1, weightKg: 60, targetReps: 5, actualReps: 4),
            onTap: {},
            onEditWeight: { _ in },
            onDelete: {}
        )
        TodaySetTile(
            set: DraftSet(id: UUID(), kind: .working, index: 2, weightKg: 60, targetReps: 5),
            isNextUp: true,
            onTap: {},
            onEditWeight: { _ in },
            onDelete: {}
        )
    }
    .padding()
    .background(LiftTheme.canvas)
}
