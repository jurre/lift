import Observation
import SwiftUI

private enum OnboardingStep: Hashable {
    case equipment
    case startingWeights
    case done
}

struct FirstRunWizard: View {
    @Bindable var persistenceService: PersistenceService
    @State private var path: [OnboardingStep] = []
    @State private var displayName = ""

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeStep(displayName: $displayName) {
                path.append(.equipment)
            }
            .navigationDestination(for: OnboardingStep.self) { step in
                switch step {
                case .equipment:
                    EquipmentStep(persistenceService: persistenceService) {
                        path.append(.startingWeights)
                    }
                case .startingWeights:
                    StartingWeightsStep(persistenceService: persistenceService) {
                        path.append(.done)
                    }
                case .done:
                    DoneStep(displayName: displayName, persistenceService: persistenceService)
                }
            }
        }
    }
}

private struct WelcomeStep: View {
    @Binding var displayName: String
    let onNext: () -> Void

    var body: some View {
        Form {
            Section("Welcome") {
                Text("Lift keeps a simple A/B strength program ready to log, with your next weights and setup saved on-device.")
                TextField("Display name (optional)", text: $displayName)
                    .textInputAutocapitalization(.words)
            }
        }
        .navigationTitle("Welcome")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Next", action: onNext)
            }
        }
    }
}

private struct EquipmentStep: View {
    @Bindable var persistenceService: PersistenceService
    let onNext: () -> Void

    var body: some View {
        Form {
            if let user = persistenceService.user {
                Section("Bar weight") {
                    Stepper(value: Binding(
                        get: { user.barWeightKg },
                        set: { persistenceService.updateBarWeight(to: $0) }
                    ), in: 0 ... 100, step: 1.25) {
                        Text("\(user.barWeightKg.formatted(.number.precision(.fractionLength(0 ... 2)))) kg")
                    }
                }

                Section("Plate inventory") {
                    ForEach(user.plates.indices, id: \.self) { index in
                        PlateInventoryRow(
                            item: user.plates[index],
                            onDelete: { persistenceService.removePlateInventoryItem(user.plates[index]) }
                        )
                    }

                    Button("Add plate size") {
                        persistenceService.addPlateInventoryItem()
                    }
                }
            }
        }
        .navigationTitle("Equipment")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Next", action: onNext)
            }
        }
    }
}

private struct PlateInventoryRow: View {
    let item: PlateInventoryItem
    let onDelete: () -> Void

    var body: some View {
        HStack {
            TextField("Weight", value: Binding(
                get: { item.weightKg },
                set: { item.weightKg = max(0, $0) }
            ), format: .number)
            .keyboardType(.decimalPad)

            Text("kg")
                .foregroundStyle(.secondary)

            Spacer()

            Stepper(value: Binding(
                get: { item.countTotal },
                set: { item.countTotal = max(0, $0) }
            ), in: 0 ... 20) {
                Text("Count: \(item.countTotal)")
            }
            .frame(maxWidth: 160)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
        }
    }
}

private struct StartingWeightsStep: View {
    @Bindable var persistenceService: PersistenceService
    let onNext: () -> Void

    var body: some View {
        Form {
            Section("Starting weights") {
                ForEach(persistenceService.exerciseProgressions, id: \.persistentModelID) { progression in
                    Stepper(value: Binding(
                        get: { progression.currentWeightKg },
                        set: { progression.currentWeightKg = max(0, $0) }
                    ), in: 0 ... 500, step: progression.incrementKg) {
                        VStack(alignment: .leading) {
                            Text(progression.exercise?.name ?? "Exercise")
                            Text("\(progression.currentWeightKg.formatted(.number.precision(.fractionLength(0 ... 2)))) kg")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Starting weights")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Next", action: onNext)
            }
        }
    }
}

private struct DoneStep: View {
    let displayName: String
    @Bindable var persistenceService: PersistenceService

    var body: some View {
        Form {
            Section("Ready to lift") {
                Text("You're set up. You can change your bar, plates, and starting weights later in settings.")
                Text("Name: \(resolvedDisplayName)")
                Text("Exercises: \(persistenceService.exerciseProgressions.count)")
            }

            Section {
                Button("Finish") {
                    try? persistenceService.finishOnboarding(displayName: displayName)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("Done")
    }

    private var resolvedDisplayName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Lifter" : trimmed
    }
}
