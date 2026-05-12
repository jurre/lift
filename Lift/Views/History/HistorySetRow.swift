import SwiftUI

struct HistorySetRow: View {
    let set: LoggedSet
    let onEditWorkingSet: (LoggedSet) -> Void
    let onEditWarmupSet: (LoggedSet) -> Void

    var body: some View {
        Button {
            switch set.kind {
            case .working:
                onEditWorkingSet(set)
            case .warmup:
                onEditWarmupSet(set)
            }
        } label: {
            HStack(spacing: 12) {
                statusIcon
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(setLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let detail = setDetail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(weightText)
                    .font(.body.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var statusIcon: some View {
        Group {
            switch (set.actualReps, set.targetReps) {
            case (nil, _):
                Image(systemName: "circle")
                    .foregroundStyle(.tertiary)
            case let (.some(actual), target) where actual >= target:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case (.some, _):
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
            }
        }
        .imageScale(.large)
    }

    private var setLabel: String {
        let kindPrefix = set.kind == .warmup ? "Warmup" : "Set"
        return "\(kindPrefix) \(set.index + 1)"
    }

    private var setDetail: String? {
        if let actual = set.actualReps {
            return "\(actual) of \(set.targetReps) reps"
        }
        return "Target: \(set.targetReps) reps · not logged"
    }

    private var weightText: String {
        let kg = set.weightKg
        let formatted = (kg.rounded(.down) == kg)
            ? String(format: "%.0f", kg)
            : String(format: "%.2f", kg).trimmingTrailingZeros()
        return "\(formatted) kg"
    }
}

private extension String {
    func trimmingTrailingZeros() -> String {
        guard contains(".") else { return self }
        var result = self
        while result.hasSuffix("0") { result.removeLast() }
        if result.hasSuffix(".") { result.removeLast() }
        return result
    }
}
