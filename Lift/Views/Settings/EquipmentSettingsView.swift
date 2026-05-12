import SwiftData
import SwiftUI

struct EquipmentSettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var actionError: String?

    var body: some View {
        Form {
            if let user = viewModel.user {
                Section {
                    Stepper(value: Binding(
                        get: { user.barWeightKg },
                        set: { try? viewModel.updateBarWeight(to: $0) }
                    ), in: 0 ... 100, step: 1.25) {
                        HStack {
                            Text("Bar weight")
                            Spacer()
                            Text("\(formatted(user.barWeightKg)) kg").foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("Changing the bar weight does not retro-update existing exercise weights.")
                }

                Section {
                    PlateInventorySectionContent(
                        plates: user.orderedPlates,
                        onChange: { try? viewModel.savePlateEdits() },
                        onDelete: { item in
                            do { try viewModel.removePlate(item) } catch {
                                actionError = "Could not delete plate: \(error.localizedDescription)"
                            }
                        },
                        onAdd: {
                            do { try viewModel.addPlate() } catch {
                                actionError = "Could not add plate: \(error.localizedDescription)"
                            }
                        }
                    )
                } header: {
                    Text("Plate inventory")
                } footer: {
                    Text("Count is total plates owned (the calculator uses pairs). Edits apply immediately.")
                }
            }
        }
        .navigationTitle("Equipment")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Action failed", isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })) {
            Button("OK") { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
    }

    private func formatted(_ kg: Double) -> String {
        kg.formatted(.number.precision(.fractionLength(0 ... 2)))
    }
}

private struct PlateInventorySectionContent: View {
    let plates: [PlateInventoryItem]
    let onChange: () -> Void
    let onDelete: (PlateInventoryItem) -> Void
    let onAdd: () -> Void

    var body: some View {
        if plates.isEmpty {
            Text("No plates configured").foregroundStyle(.secondary)
        } else {
            ForEach(plates, id: \.persistentModelID) { item in
                EquipmentPlateRow(
                    item: item,
                    onChange: onChange,
                    onDelete: { onDelete(item) }
                )
            }
        }

        Button(action: onAdd) {
            Label("Add plate size", systemImage: "plus.circle")
        }
    }
}

private struct EquipmentPlateRow: View {
    @Bindable var item: PlateInventoryItem
    let onChange: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            TextField("Weight", value: Binding(
                get: { item.weightKg },
                set: { newValue in
                    item.weightKg = max(0, newValue)
                    onChange()
                }
            ), format: .number)
            .keyboardType(.decimalPad)
            .frame(maxWidth: 80)

            Text("kg").foregroundStyle(.secondary)

            Spacer()

            Stepper(value: Binding(
                get: { item.countTotal },
                set: { newValue in
                    item.countTotal = max(0, newValue)
                    onChange()
                }
            ), in: 0 ... 20) {
                Text("× \(item.countTotal)")
            }
            .frame(maxWidth: 130)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }
}
