import SwiftUI
import UIKit

struct TodaySetRow: View {
    let set: DraftSet
    let onTap: () -> Void
    let onEditWeight: ((Double) -> Void)?
    let onDelete: (() -> Void)?

    @State private var isShowingWeightEditor = false
    @State private var isShowingAdjustHint = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Button(action: handleTap) {
                    statusIcon
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(formattedWeight) kg × \(set.targetReps)")
                        .font(.body.weight(.medium))

                    if isShowingAdjustHint && set.kind == .working {
                        Text("tap to adjust")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                }

                Spacer()

                if set.kind == .warmup {
                    Text("Warmup")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
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
                withAnimation {
                    isShowingAdjustHint = false
                }
                return
            }

            withAnimation {
                isShowingAdjustHint = true
            }
            try? await Task.sleep(for: .seconds(5))
            guard hintTaskID == self.hintTaskID else { return }
            withAnimation {
                isShowingAdjustHint = false
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityAction(named: Text("Tap"), handleTap)
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
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.green)
        case let .partial(reps):
            ZStack {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 34, height: 34)
                Text("\(reps)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
        case .pending:
            Image(systemName: "circle")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.secondary)
        }
    }

    private var cellState: SetCellState {
        SetTapStateMachine.state(for: set.actualReps, targetReps: set.targetReps)
    }

    private var shouldShowAdjustHint: Bool {
        guard set.kind == .working else { return false }
        if case let .partial(reps) = cellState {
            return reps < set.targetReps
        }
        return false
    }

    private var hintTaskID: String {
        "\(set.id.uuidString)-\(set.actualReps?.description ?? "pending")"
    }

    private var accessibilityLabel: String {
        let kindDescription = set.kind == .warmup ? "Warmup set" : "Working set"
        return "\(kindDescription), \(formattedWeight) kilograms, target \(set.targetReps) reps"
    }

    private var accessibilityValue: String {
        switch cellState {
        case .pending:
            return "Pending"
        case .complete:
            return "\(set.targetReps) reps complete"
        case let .partial(reps):
            return "\(reps) reps partial"
        }
    }

    private func handleTap() {
        let nextState = SetTapStateMachine.tap(current: cellState, targetReps: set.targetReps, kind: set.kind).newState
        onTap()
        UIAccessibility.post(notification: .announcement, argument: announcement(for: nextState))
    }

    private func announcement(for state: SetCellState) -> String {
        switch state {
        case .pending:
            return "Set cleared"
        case .complete:
            return "\(set.targetReps) reps complete"
        case let .partial(reps):
            return "\(reps) reps partial"
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
    VStack(spacing: 16) {
        TodaySetRow(
            set: DraftSet(id: UUID(), kind: .warmup, index: 0, weightKg: 20, targetReps: 5),
            onTap: {},
            onEditWeight: nil,
            onDelete: nil
        )
        TodaySetRow(
            set: DraftSet(id: UUID(), kind: .working, index: 1, weightKg: 60, targetReps: 5, actualReps: 4),
            onTap: {},
            onEditWeight: { _ in },
            onDelete: {}
        )
    }
    .padding()
}
