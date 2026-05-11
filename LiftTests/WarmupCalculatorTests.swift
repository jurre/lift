import Testing
@testable import Lift

@Suite("WarmupCalculator")
struct WarmupCalculatorTests {
    @Test("100kg working weight produces the standard warmup ramp")
    func standardWarmupRamp() {
        let calculator = WarmupCalculator(weightLoading: WeightLoading(barWeightKg: 20, inventory: standardInventory()))

        #expect(calculator.warmupSets(forWorkingWeightKg: 100).elementsEqual(
            [(20.0, 5), (40.0, 5), (60.0, 3), (80.0, 2)],
            by: { ($0.weightKg, $0.reps) == ($1.0, $1.1) }
        ))
    }

    @Test("light working weights only do a bar warmup")
    func lightWorkingWeight() {
        let calculator = WarmupCalculator(weightLoading: WeightLoading(barWeightKg: 20, inventory: standardInventory()))

        #expect(calculator.warmupSets(forWorkingWeightKg: 25).elementsEqual(
            [(20.0, 5)],
            by: { ($0.weightKg, $0.reps) == ($1.0, $1.1) }
        ))
        #expect(calculator.warmupSets(forWorkingWeightKg: 22.5).elementsEqual(
            [(20.0, 5)],
            by: { ($0.weightKg, $0.reps) == ($1.0, $1.1) }
        ))
    }

    @Test("working weights at the light threshold only do a bar warmup")
    func lightThresholdOnlyUsesBarWarmup() {
        let calculator = WarmupCalculator(weightLoading: WeightLoading(barWeightKg: 20, inventory: standardInventory()))

        #expect(calculator.warmupSets(forWorkingWeightKg: 30).elementsEqual(
            [(20.0, 5)],
            by: { ($0.weightKg, $0.reps) == ($1.0, $1.1) }
        ))
    }

    @Test("working weight of 40kg uses rounded intermediate warmups")
    func roundedIntermediateWarmups() {
        let calculator = WarmupCalculator(weightLoading: WeightLoading(barWeightKg: 20, inventory: standardInventory()))

        #expect(calculator.warmupSets(forWorkingWeightKg: 40).elementsEqual(
            [(20.0, 5), (25.0, 3), (32.5, 2)],
            by: { ($0.weightKg, $0.reps) == ($1.0, $1.1) }
        ))
    }

    private func standardInventory() -> [PlateInventoryItem] {
        [25, 20, 15, 10, 5, 2.5, 1.25].map { PlateInventoryItem(weightKg: $0, countTotal: 2) }
    }
}
