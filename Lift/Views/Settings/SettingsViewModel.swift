import Foundation
import Observation
import SwiftData

enum SettingsViewModelError: Error, Equatable {
    case missingModelContext
    case missingUser
    case lockedDuringActiveDraft
}

@MainActor
@Observable
final class SettingsViewModel {
    private(set) var user: User?
    private(set) var progressions: [ExerciseProgression] = []
    private(set) var hasActiveDraft = false
    private(set) var weightLoading: WeightLoading?

    @ObservationIgnored
    private var modelContext: ModelContext?

    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
    }

    func setModelContext(_ modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func refresh() {
        guard let modelContext else {
            user = nil
            progressions = []
            hasActiveDraft = false
            weightLoading = nil
            return
        }

        do {
            user = try modelContext.fetch(FetchDescriptor<User>()).first
            progressions = try modelContext
                .fetch(FetchDescriptor<ExerciseProgression>())
                .sorted { ($0.exercise?.name ?? "") < ($1.exercise?.name ?? "") }
            let allSessions = try modelContext.fetch(FetchDescriptor<WorkoutSession>())
            hasActiveDraft = allSessions.contains { $0.status == .draft }
            weightLoading = user.map { WeightLoading(barWeightKg: $0.barWeightKg, inventory: $0.orderedPlates) }
        } catch {
            assertionFailure("SettingsViewModel.refresh failed: \(error)")
        }
    }

    func ensureNoActiveDraft() throws {
        if hasActiveDraft {
            throw SettingsViewModelError.lockedDuringActiveDraft
        }
    }

    // MARK: - Progression-affecting edits (gated)

    func editCurrentWeight(progression: ExerciseProgression, newWeightKg: Double) throws {
        try ensureNoActiveDraft()
        guard let modelContext, let weightLoading else { throw SettingsViewModelError.missingModelContext }

        let snapped = weightLoading.nearestLoadable(max(0, newWeightKg))
        let oldWeightKg = progression.currentWeightKg
        if snapped.isApproxSettings(oldWeightKg) { return }

        if snapped < oldWeightKg {
            progression.stalledCount = 0
        }
        progression.currentWeightKg = snapped

        let event = ProgressionEvent(
            exerciseProgression: progression,
            session: nil,
            oldWeightKg: oldWeightKg,
            newWeightKg: snapped,
            reason: .manualEdit
        )
        modelContext.insert(event)
        try modelContext.save()
        refresh()
    }

    func deload(progression: ExerciseProgression) throws {
        try ensureNoActiveDraft()
        guard let modelContext, let weightLoading else { throw SettingsViewModelError.missingModelContext }

        let oldWeightKg = progression.currentWeightKg
        let newWeightKg = Progression.deload(currentWeightKg: oldWeightKg, weightLoading: weightLoading)
        progression.currentWeightKg = newWeightKg
        progression.stalledCount = 0

        if !newWeightKg.isApproxSettings(oldWeightKg) {
            let event = ProgressionEvent(
                exerciseProgression: progression,
                session: nil,
                oldWeightKg: oldWeightKg,
                newWeightKg: newWeightKg,
                reason: .manualDeload
            )
            modelContext.insert(event)
        }
        try modelContext.save()
        refresh()
    }

    func resetProgression(_ progression: ExerciseProgression) throws {
        try ensureNoActiveDraft()
        guard let modelContext, let user else { throw SettingsViewModelError.missingUser }

        let oldWeightKg = progression.currentWeightKg
        let newWeightKg = user.barWeightKg
        progression.currentWeightKg = newWeightKg
        progression.stalledCount = 0
        progression.lastProgressionAt = nil

        let event = ProgressionEvent(
            exerciseProgression: progression,
            session: nil,
            oldWeightKg: oldWeightKg,
            newWeightKg: newWeightKg,
            reason: .reset
        )
        modelContext.insert(event)
        try modelContext.save()
        refresh()
    }

    // MARK: - Gated metadata edits (locked while a draft is active)

    func editIncrement(progression: ExerciseProgression, kg: Double) throws {
        guard let modelContext else { throw SettingsViewModelError.missingModelContext }
        try ensureNoActiveDraft()
        progression.incrementKg = max(0.25, kg)
        try modelContext.save()
        refresh()
    }

    // MARK: - Future-only edits (always allowed)

    func editRestSeconds(progression: ExerciseProgression, seconds: Int) throws {
        guard let modelContext else { throw SettingsViewModelError.missingModelContext }
        progression.restSeconds = max(0, seconds)
        try modelContext.save()
        refresh()
    }

    func editWorkingSets(progression: ExerciseProgression, count: Int) throws {
        guard let modelContext else { throw SettingsViewModelError.missingModelContext }
        progression.workingSets = max(1, count)
        try modelContext.save()
        refresh()
    }

    func editWorkingReps(progression: ExerciseProgression, reps: Int) throws {
        guard let modelContext else { throw SettingsViewModelError.missingModelContext }
        progression.workingReps = max(1, reps)
        try modelContext.save()
        refresh()
    }

    // MARK: - Equipment (no draft gate per design)

    func updateBarWeight(to newValueKg: Double) throws {
        guard let modelContext, let user else { throw SettingsViewModelError.missingUser }
        let clamped = max(0, newValueKg)
        guard user.barWeightKg != clamped else { return }
        user.barWeightKg = clamped
        try modelContext.save()
        refresh()
    }

    func addPlate() throws {
        guard let modelContext, let user else { throw SettingsViewModelError.missingUser }
        let item = PlateInventoryItem(weightKg: 1.25, countTotal: 2, user: user)
        modelContext.insert(item)
        user.plates.append(item)
        sortPlates(user)
        try modelContext.save()
        refresh()
    }

    func removePlate(_ item: PlateInventoryItem) throws {
        guard let modelContext, let user else { throw SettingsViewModelError.missingUser }
        user.plates.removeAll { $0.persistentModelID == item.persistentModelID }
        modelContext.delete(item)
        sortPlates(user)
        try modelContext.save()
        refresh()
    }

    func savePlateEdits() throws {
        guard let modelContext, let user else { throw SettingsViewModelError.missingUser }
        sortPlates(user)
        try modelContext.save()
        refresh()
    }

    private func sortPlates(_ user: User) {
        user.plates.sort { $0.weightKg > $1.weightKg }
    }

    // MARK: - Reset all data

    func resetAllData() throws {
        guard let modelContext else { throw SettingsViewModelError.missingModelContext }

        try Self.deleteAll(WorkoutSession.self, in: modelContext)
        try Self.deleteAll(ExerciseLog.self, in: modelContext)
        try Self.deleteAll(LoggedSet.self, in: modelContext)
        try Self.deleteAll(ProgressionEvent.self, in: modelContext)
        try Self.deleteAll(ProgramExerciseSlot.self, in: modelContext)
        try Self.deleteAll(ProgramDay.self, in: modelContext)
        try Self.deleteAll(ExerciseProgression.self, in: modelContext)
        try Self.deleteAll(PlateInventoryItem.self, in: modelContext)
        try Self.deleteAll(Exercise.self, in: modelContext)
        try Self.deleteAll(User.self, in: modelContext)

        try modelContext.save()
        try LiftSeeder().seedIfNeeded(in: modelContext)
        refresh()
    }

    private static func deleteAll<T: PersistentModel>(_: T.Type, in context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<T>())
        for item in items {
            context.delete(item)
        }
    }
}

private extension Double {
    func isApproxSettings(_ other: Double, tolerance: Double = 0.0001) -> Bool {
        Swift.abs(self - other) <= tolerance
    }
}
