import SwiftUI
import UIKit

struct TodaySetTile: View {
    let set: DraftSet
    let onTap: () -> Void
    let onEditWeight: ((Double) -> Void)?
    let onDelete: (() -> Void)?

    @State private var isShowingWeightEditor = false
    @State private var isShowingAdjustHint = false

    var body: some View {
        Button(action: handleTap) {
            VStack(spacing: 8) {
                statusIcon
                    .frame(height: 30)

                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if set.kind == .working {
                    Text("tap to adjust")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .opacity(isShowingAdjustHint ? 1 : 0)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 6)
            .background(stateBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(stateBorder, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if set.kind == .working, onEditWeight != nil {
                Button("Edit weight for this set", systemImage: "pencil") {
                    isShowingWeightEditor = true
                }
            }
            if set.kind == .working, let onDelete {
                Button("Delete set", systemImage: "trash", role: .destructive, action: onDelete)
            }
        }
        .sheet(isPresented: $isShowingWeightEditor) {
            if let onEditWeight {
                WeightEditorSheet(
                    title: "Edit set weight",
                    initialWeightKg: set.weightKg,
                    onCommit: onEditWeight
                )
            }
        }
        .task(id: hintTaskID) {
            guard shouldShowAdjustHint else {
                withAnimation { isShowingAdjustHint = false }
                return
            }

            withAnimation { isShowingAdjustHint = true }
            try? await Task.sleep(for: .seconds(5))
            guard hintTaskID == self.hintTaskID else { return }
            withAnimation { isShowingAdjustHint = false }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityAction(named: Text("Tap"), handleTap)
    }

    private var label: String {
        "\(formattedWeight)×\(self.set.targetReps)"
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
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.green)
        case let .partial(reps):
            ZStack {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 30, height: 30)
                Text("\(reps)")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
        case .pending:
            Image(systemName: "circle")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.secondary)
        }
    }

    private var cellState: SetCellState {
        SetTapStateMachine.state(for: self.set.actualReps, targetReps: self.set.targetReps)
    }

    private var stateBackground: Color {
        switch cellState {
        case .complete: return Color.green.opacity(0.12)
        case .partial: return Color.orange.opacity(0.12)
        case .pending: return Color.secondary.opacity(0.10)
        }
    }

    private var stateBorder: Color {
        switch cellState {
        case .complete: return Color.green.opacity(0.35)
        case .partial: return Color.orange.opacity(0.35)
        case .pending: return Color.secondary.opacity(0.20)
        }
    }

    private var shouldShowAdjustHint: Bool {
        guard self.set.kind == .working else { return false }
        if case let .partial(reps) = cellState {
            return reps < self.set.targetReps
        }
        return false
    }

    private var hintTaskID: String {
        "\(self.set.id.uuidString)-\(self.set.actualReps?.description ?? "pending")"
    }

    private var accessibilityLabel: String {
        let kindDescription = self.set.kind == .warmup ? "Warmup set" : "Working set"
        return "\(kindDescription), \(formattedWeight) kilograms, target \(self.set.targetReps) reps"
    }

    private var accessibilityValue: String {
        switch cellState {
        case .pending: return "Pending"
        case .complete: return "\(self.set.targetReps) reps complete"
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
        case let .partial(reps): return "\(reps) reps partial"
        }
    }
}

struct WeightEditorSheet: View {
    let title: String
    let initialWeightKg: Double
    let onCommit: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var weightText: String

    init(title: String, initialWeightKg: Double, onCommit: @escaping (Double) -> Void) {
        self.title = title
        self.initialWeightKg = initialWeightKg
        self.onCommit = onCommit
        _weightText = State(
            initialValue: initialWeightKg.formatted(
                .number.precision(.fractionLength(initialWeightKg.rounded(.down) == initialWeightKg ? 0 : 1))
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
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

    private func adjust(by delta: Double) {
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
            onTap: {},
            onEditWeight: { _ in },
            onDelete: {}
        )
    }
    .padding()
}
