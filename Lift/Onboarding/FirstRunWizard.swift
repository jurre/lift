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

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeStep {
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
                    DoneStep(persistenceService: persistenceService)
                }
            }
        }
    }
}

private struct WelcomeStep: View {
    let onNext: () -> Void

    var body: some View {
        Form {
            Section("Welcome") {
                Text("Lift keeps a simple A/B strength program ready to log, with your next weights and setup saved on-device.")
                Text("On the next screens you'll set your bar, plates, and starting weights. You can change them later in Settings.")
                    .foregroundStyle(.secondary)
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
        HStack(spacing: 12) {
            TextField("Weight", value: Binding(
                get: { item.weightKg },
                set: { item.weightKg = max(0, $0) }
            ), format: .number)
            .keyboardType(.decimalPad)
            .frame(width: 64)

            Text("kg")
                .foregroundStyle(.secondary)

            Spacer()

            Stepper(value: Binding(
                get: { item.countTotal },
                set: { item.countTotal = max(0, $0) }
            ), in: 0 ... 20) {
                Text("× \(item.countTotal)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .fixedSize()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }
}

private struct StartingWeightsStep: View {
    @Bindable var persistenceService: PersistenceService
    let onNext: () -> Void

    @State private var editing: ExerciseProgression?

    var body: some View {
        Form {
            Section {
                ForEach(persistenceService.exerciseProgressions, id: \.persistentModelID) { progression in
                    Button {
                        editing = progression
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(progression.exercise?.name ?? "Exercise")
                                    .foregroundStyle(.primary)
                                Text("Tap to set weight")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(progression.currentWeightKg.formatted(.number.precision(.fractionLength(0 ... 2)))) kg")
                                .font(.body.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Starting weights")
            } footer: {
                Text("Tap a row to enter the weight directly. We'll snap it to your loadable plates.")
            }
        }
        .navigationTitle("Starting weights")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Next", action: onNext)
            }
        }
        .sheet(item: $editing) { progression in
            WeightEditorSheet(
                title: progression.exercise?.name ?? "Starting weight",
                initialWeightKg: progression.currentWeightKg,
                onCommit: { newWeight in
                    let loading = currentWeightLoading()
                    let snapped = loading?.nearestLoadable(newWeight) ?? max(0, newWeight)
                    progression.currentWeightKg = snapped
                },
                weightLoading: currentWeightLoading()
            )
        }
    }

    private func currentWeightLoading() -> WeightLoading? {
        guard let user = persistenceService.user else { return nil }
        return WeightLoading(barWeightKg: user.barWeightKg, inventory: user.orderedPlates)
    }
}

private struct DoneStep: View {
    @Bindable var persistenceService: PersistenceService

    var body: some View {
        Form {
            Section("Ready to lift") {
                Text("You're set up. You can change your bar, plates, and starting weights later in settings.")
                Text("Exercises: \(persistenceService.exerciseProgressions.count)")
            }

            Section {
                Button("Finish") {
                    try? persistenceService.finishOnboarding(displayName: "")
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("Done")
    }
}
