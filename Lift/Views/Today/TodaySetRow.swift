import SwiftUI

struct TodaySetRow: View {
    let set: DraftSet

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.secondary)

            Text("\(formattedWeight) kg × \(set.targetReps)")
                .font(.body.weight(.medium))

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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(set.targetReps) reps at \(formattedWeight) kilograms, \(set.kind == .warmup ? "warmup set" : "working set")")
    }

    private var formattedWeight: String {
        self.set.weightKg.formatted(.number.precision(.fractionLength(self.set.weightKg.rounded(.down) == self.set.weightKg ? 0 : 1)))
    }
}

#Preview {
    VStack(spacing: 16) {
        TodaySetRow(set: DraftSet(id: UUID(), kind: .warmup, index: 0, weightKg: 20, targetReps: 5))
        TodaySetRow(set: DraftSet(id: UUID(), kind: .working, index: 1, weightKg: 60, targetReps: 5))
    }
    .padding()
}
