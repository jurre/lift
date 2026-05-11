import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class PersistenceService {
    let container: ModelContainer

    var isBootstrapped = false
    var shouldShowOnboarding = false
    var user: User?
    var exerciseProgressions: [ExerciseProgression] = []

    init(container: ModelContainer = LiftModelContainer.shared) {
        self.container = container
    }

    func bootstrap() {
        guard !isBootstrapped else { return }

        do {
            try LiftSeeder().seedIfNeeded(in: container.mainContext)
            try refreshState()
        } catch {
            assertionFailure("Failed to bootstrap persistence: \(error)")
        }

        isBootstrapped = true
    }

    func finishOnboarding(displayName: String) throws {
        guard let user else { return }

        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        user.displayName = trimmedName.isEmpty ? "Lifter" : trimmedName
        sortPlateInventory()
        try save()
        shouldShowOnboarding = false
    }

    func addPlateInventoryItem() {
        guard let user else { return }

        let item = PlateInventoryItem(weightKg: 1.25, countTotal: 2, user: user)
        container.mainContext.insert(item)
        user.plates.append(item)
        sortPlateInventory()
    }

    func removePlateInventoryItem(_ item: PlateInventoryItem) {
        guard let user else { return }

        user.plates.removeAll { $0.persistentModelID == item.persistentModelID }
        container.mainContext.delete(item)
        sortPlateInventory()
    }

    func updateBarWeight(to newValue: Double) {
        guard let user else { return }

        let oldValue = user.barWeightKg
        guard oldValue != newValue else { return }

        user.barWeightKg = newValue
        for progression in exerciseProgressions where progression.currentWeightKg == oldValue {
            progression.currentWeightKg = newValue
        }
    }

    func sortPlateInventory() {
        user?.plates.sort { $0.weightKg > $1.weightKg }
    }

    func save() throws {
        sortPlateInventory()
        try container.mainContext.save()
        try refreshState()
    }

    private func refreshState() throws {
        user = try container.mainContext.fetch(FetchDescriptor<User>()).first
        sortPlateInventory()
        exerciseProgressions = try container.mainContext.fetch(FetchDescriptor<ExerciseProgression>())
            .sorted { lhs, rhs in
                (lhs.exercise?.name ?? "") < (rhs.exercise?.name ?? "")
            }

        shouldShowOnboarding = shouldPresentOnboarding(user: user, progressions: exerciseProgressions)
    }

    private func shouldPresentOnboarding(user: User?, progressions: [ExerciseProgression]) -> Bool {
        guard let user else { return false }
        return user.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && progressions.allSatisfy { $0.currentWeightKg == user.barWeightKg }
    }
}
