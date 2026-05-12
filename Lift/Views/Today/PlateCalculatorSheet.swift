import SwiftUI

struct PlateCalculatorSheet: View {
    let initialWeightKg: Double
    let weightLoading: WeightLoading
    let onUseWeight: ((Double) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var weightKg: Double

    init(
        initialWeightKg: Double,
        weightLoading: WeightLoading,
        onUseWeight: ((Double) -> Void)? = nil
    ) {
        self.initialWeightKg = initialWeightKg
        self.weightLoading = weightLoading
        self.onUseWeight = onUseWeight
        _weightKg = State(initialValue: initialWeightKg)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                weightHeader

                BarVisualization(weightKg: weightKg, weightLoading: weightLoading)
                    .frame(maxWidth: .infinity)

                loadingDescription

                stepperRow

                Spacer(minLength: 0)

                if onUseWeight != nil, !approxEqual(weightKg, initialWeightKg) {
                    Button {
                        onUseWeight?(weightKg)
                        dismiss()
                    } label: {
                        Text("Use \(formatted(weightKg)) kg")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(20)
            .navigationTitle("Plate calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var weightHeader: some View {
        VStack(spacing: 4) {
            Text("\(formatted(weightKg)) kg")
                .font(.largeTitle.weight(.bold))
                .monospacedDigit()
            if !approxEqual(weightKg, initialWeightKg) {
                Text("from \(formatted(initialWeightKg)) kg")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var loadingDescription: some View {
        switch weightLoading.plates(for: weightKg) {
        case let .exact(perSidePlatesKg):
            if perSidePlatesKg.isEmpty {
                Text("Bar only")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 4) {
                    Text("Per side")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(perSidePlatesKg.map(formatted).joined(separator: " + ") + " kg")
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                }
            }
        case let .closest(belowKg, aboveKg):
            VStack(spacing: 4) {
                Text("Not exactly loadable")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.orange)
                let parts = [belowKg, aboveKg].compactMap { $0 }
                if !parts.isEmpty {
                    Text("Closest: \(parts.map(formatted).joined(separator: " / ")) kg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var stepperRow: some View {
        HStack(spacing: 8) {
            stepperButton("−2.5", delta: -2.5)
            stepperButton("−1.25", delta: -1.25)
            Spacer()
            stepperButton("+1.25", delta: 1.25)
            stepperButton("+2.5", delta: 2.5)
        }
    }

    private func stepperButton(_ label: String, delta: Double) -> some View {
        Button(label) {
            weightKg = max(weightLoading.barWeightKg, weightKg + delta)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(
            .number.precision(
                .fractionLength(value.rounded(.down) == value ? 0 : 1)
            )
        )
    }

    private func approxEqual(_ a: Double, _ b: Double) -> Bool {
        abs(a - b) <= 0.0001
    }
}

private struct BarVisualization: View {
    let weightKg: Double
    let weightLoading: WeightLoading

    var body: some View {
        let plates = perSidePlates
        HStack(alignment: .center, spacing: 1) {
            collar
            ForEach(Array(plates.reversed().enumerated()), id: \.offset) { _, plate in
                PlateView(weightKg: plate)
            }
            barSegment
            ForEach(Array(plates.enumerated()), id: \.offset) { _, plate in
                PlateView(weightKg: plate)
            }
            collar
        }
        .frame(height: 110)
        .frame(maxWidth: .infinity)
    }

    private var collar: some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(Color.gray.opacity(0.5))
            .frame(width: 8, height: 28)
    }

    private var barSegment: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(LinearGradient(
                colors: [Color.gray.opacity(0.7), Color.gray.opacity(0.4), Color.gray.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            ))
            .frame(minWidth: 60, maxWidth: 100)
            .frame(height: 8)
    }

    private var perSidePlates: [Double] {
        switch weightLoading.plates(for: weightKg) {
        case let .exact(plates):
            return plates
        case .closest:
            return []
        }
    }
}

private struct PlateView: View {
    let weightKg: Double

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(plateColor)
            .frame(width: 22, height: plateHeight)
            .overlay(
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(plateLabelColor)
                    .rotationEffect(.degrees(-90))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            )
    }

    private var plateHeight: CGFloat {
        switch weightKg {
        case 25...: return 110
        case 20..<25: return 100
        case 15..<20: return 86
        case 10..<15: return 70
        case 5..<10: return 52
        case 2.5..<5: return 36
        default: return 26
        }
    }

    private var plateColor: Color {
        switch weightKg {
        case 25...: return .red
        case 20..<25: return .blue
        case 15..<20: return .yellow
        case 10..<15: return .green
        case 5..<10: return Color(white: 0.9)
        case 2.5..<5: return Color.red.opacity(0.55)
        default: return Color.gray.opacity(0.4)
        }
    }

    private var plateLabelColor: Color {
        switch weightKg {
        case 5..<10: return .black
        case 1.0..<2.5: return .black
        default: return .white
        }
    }

    private var label: String {
        weightKg.formatted(
            .number.precision(
                .fractionLength(weightKg.rounded(.down) == weightKg ? 0 : 1)
            )
        )
    }
}

#Preview("Loadable 60kg") {
    if let weightLoading = PreviewSupport.todayViewModel().weightLoading {
        PlateCalculatorSheet(
            initialWeightKg: 60,
            weightLoading: weightLoading,
            onUseWeight: { _ in }
        )
    }
}

#Preview("Bar only") {
    if let weightLoading = PreviewSupport.todayViewModel().weightLoading {
        PlateCalculatorSheet(
            initialWeightKg: 20,
            weightLoading: weightLoading,
            onUseWeight: { _ in }
        )
    }
}
