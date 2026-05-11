import Foundation
import SwiftData

@Model
final class User {
    var displayName: String
    var barWeightKg: Double
    var defaultIncrementKg: Double

    @Relationship(deleteRule: .cascade, inverse: \PlateInventoryItem.user)
    var plates: [PlateInventoryItem]

    init(
        displayName: String,
        barWeightKg: Double,
        defaultIncrementKg: Double,
        plates: [PlateInventoryItem] = []
    ) {
        self.displayName = displayName
        self.barWeightKg = barWeightKg
        self.defaultIncrementKg = defaultIncrementKg
        self.plates = plates
    }

    var orderedPlates: [PlateInventoryItem] {
        plates.sorted { $0.weightKg > $1.weightKg }
    }
}

@Model
final class PlateInventoryItem {
    var weightKg: Double
    var countTotal: Int
    var user: User?

    init(weightKg: Double, countTotal: Int, user: User? = nil) {
        self.weightKg = weightKg
        self.countTotal = countTotal
        self.user = user
    }
}
