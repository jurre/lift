import SwiftData
import SwiftUI

struct ExerciseSettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    let progression: ExerciseProgression

    @Environment(\.haptics) private var haptics
    @State private var showWeightEditor = false
    @State private var showDeloadConfirm = false
    @State private var showResetConfirm = false
    @State private var actionError: String?

    var body: some View {
        Form {
            if viewModel.hasActiveDraft {
                Section {
                    Label("Locked while a workout is in progress", systemImage: "lock.fill")
                        .foregroundStyle(.orange)
                        .font(.subheadline)
                }
            }

            if progression.stalledCount > 0 {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Stalled \(progression.stalledCount) session\(progression.stalledCount == 1 ? "" : "s")")
                                .font(.subheadline.weight(.semibold))
                            Text("Consider deloading to break the stall.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section("Working weight") {
                HStack {
                    Text("Current")
                    Spacer()
                    Text("\(formatted(progression.currentWeightKg)) kg")
                        .foregroundStyle(.secondary)
                }

                Button {
                    showWeightEditor = true
                } label: {
                    Label("Edit weight", systemImage: "pencil")
                }
                .disabled(viewModel.hasActiveDraft)
            }

            Section("Targets") {
                Stepper(value: Binding(
                    get: { progression.workingSets },
                    set: { try? viewModel.editWorkingSets(progression: progression, count: $0) }
                ), in: 1 ... 10) {
                    HStack {
                        Text("Working sets")
                        Spacer()
                        Text("\(progression.workingSets)").foregroundStyle(.secondary)
                    }
                }

                Stepper(value: Binding(
                    get: { progression.workingReps },
                    set: { try? viewModel.editWorkingReps(progression: progression, reps: $0) }
                ), in: 1 ... 30) {
                    HStack {
                        Text("Reps per set")
                        Spacer()
                        Text("\(progression.workingReps)").foregroundStyle(.secondary)
                    }
                }
            }

            Section("Progression") {
                Stepper(value: Binding(
                    get: { progression.incrementKg },
                    set: { try? viewModel.editIncrement(progression: progression, kg: $0) }
                ), in: 0.25 ... 10, step: 0.25) {
                    HStack {
                        Text("Increment")
                        Spacer()
                        Text("\(formatted(progression.incrementKg)) kg").foregroundStyle(.secondary)
                    }
                }
            }

            Section("Rest timer") {
                Stepper(value: Binding(
                    get: { progression.restSeconds },
                    set: { try? viewModel.editRestSeconds(progression: progression, seconds: $0) }
                ), in: 0 ... 600, step: 30) {
                    HStack {
                        Text("Default rest")
                        Spacer()
                        Text(formatRest(progression.restSeconds)).foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeloadConfirm = true
                } label: {
                    Label("Manual deload (−10%)", systemImage: "arrow.down.circle")
                }
                .disabled(viewModel.hasActiveDraft)

                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label("Reset to bar weight", systemImage: "arrow.counterclockwise")
                }
                .disabled(viewModel.hasActiveDraft)
            } footer: {
                Text("Deload drops the weight ~10% (rounded to a loadable weight, never below the bar). Reset returns the weight to your bar weight and clears stall history.")
            }
        }
        .navigationTitle(progression.exercise?.name ?? "Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showWeightEditor) {
            WeightEditorSheet(
                title: "Edit weight",
                initialWeightKg: progression.currentWeightKg,
                onCommit: { newValue in
                    do {
                        try viewModel.editCurrentWeight(progression: progression, newWeightKg: newValue)
                    } catch {
                        actionError = "Could not update weight: \(error.localizedDescription)"
                    }
                },
                weightLoading: viewModel.weightLoading
            )
        }
        .confirmationDialog(
            "Deload \(progression.exercise?.name ?? "exercise")?",
            isPresented: $showDeloadConfirm,
            titleVisibility: .visible
        ) {
            Button("Deload", role: .destructive) {
                do {
                    try viewModel.deload(progression: progression)
                    haptics.deloadApplied()
                } catch {
                    actionError = "Could not deload: \(error.localizedDescription)"
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Drops to roughly 90% of \(formatted(progression.currentWeightKg)) kg. Stall count will reset.")
        }
        .confirmationDialog(
            "Reset \(progression.exercise?.name ?? "exercise")?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                do {
                    try viewModel.resetProgression(progression)
                } catch {
                    actionError = "Could not reset: \(error.localizedDescription)"
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Returns the working weight to your bar weight and clears stall history. Past sessions are kept.")
        }
        .alert("Action failed", isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })) {
            Button("OK") { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
    }

    private func formatted(_ kg: Double) -> String {
        kg.formatted(.number.precision(.fractionLength(0 ... 2)))
    }

    private func formatRest(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let m = seconds / 60
        let s = seconds % 60
        return s == 0 ? "\(m)m" : "\(m)m \(s)s"
    }
}
