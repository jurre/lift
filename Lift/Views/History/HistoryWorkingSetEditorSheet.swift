import SwiftUI

struct HistoryWorkingSetEditorSheet: View {
    let title: String
    let initialWeightKg: Double
    let initialActualReps: Int?
    let targetReps: Int
    let weightLoading: WeightLoading?
    let onCommit: (Double, Int?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var weightText: String
    @State private var repsField: Int
    @State private var isMarkedPending: Bool

    init(
        title: String,
        initialWeightKg: Double,
        initialActualReps: Int?,
        targetReps: Int,
        weightLoading: WeightLoading? = nil,
        onCommit: @escaping (Double, Int?) -> Void
    ) {
        self.title = title
        self.initialWeightKg = initialWeightKg
        self.initialActualReps = initialActualReps
        self.targetReps = targetReps
        self.weightLoading = weightLoading
        self.onCommit = onCommit
        _weightText = State(initialValue: Self.format(initialWeightKg))
        _repsField = State(initialValue: initialActualReps ?? targetReps)
        _isMarkedPending = State(initialValue: initialActualReps == nil)
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

                    if let weightLoading {
                        Button {
                            if let next = weightLoading.nextLowerLoadable(currentWeight) {
                                weightText = Self.format(next)
                            }
                        } label: {
                            Label("Next loadable ↓", systemImage: "arrow.down")
                        }
                        .disabled(weightLoading.nextLowerLoadable(currentWeight) == nil)

                        Button {
                            if let next = weightLoading.nextHigherLoadable(currentWeight) {
                                weightText = Self.format(next)
                            }
                        } label: {
                            Label("Next loadable ↑", systemImage: "arrow.up")
                        }
                        .disabled(weightLoading.nextHigherLoadable(currentWeight) == nil)
                    }
                }

                Section("Reps") {
                    Toggle("Mark as not logged", isOn: $isMarkedPending)

                    if !isMarkedPending {
                        Stepper(value: $repsField, in: 0...30) {
                            Text("\(repsField) of \(targetReps) reps")
                                .monospacedDigit()
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let value = Double(weightText.replacingOccurrences(of: ",", with: ".")) else { return }
                        let reps: Int? = isMarkedPending ? nil : repsField
                        onCommit(value, reps)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var currentWeight: Double {
        Double(weightText.replacingOccurrences(of: ",", with: ".")) ?? initialWeightKg
    }

    private func adjustWeight(by delta: Double) {
        let updated = max(0, currentWeight + delta)
        weightText = Self.format(updated)
    }

    private static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(value.rounded(.down) == value ? 0 : 2)))
    }
}
