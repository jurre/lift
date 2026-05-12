import Testing
@testable import Lift

@Suite("WeightLoading")
struct WeightLoadingTests {
    @Test("bar weight is loadable")
    func barWeightIsLoadable() {
        let loading = WeightLoading(barWeightKg: 20, inventory: standardInventory())

        #expect(loading.isLoadable(20))
        #expect(loading.plates(for: 20) == .exact(perSidePlatesKg: []))
    }

    @Test("22.5kg is loadable with 1.25kg plates")
    func twentyTwoPointFiveIsLoadable() {
        let loading = WeightLoading(barWeightKg: 20, inventory: standardInventory())

        #expect(loading.isLoadable(22.5))
        #expect(loading.plates(for: 22.5) == .exact(perSidePlatesKg: [1.25]))
    }

    @Test("unloadable weight rounds to the nearest loadable option")
    func unloadableWeightUsesNearestLoadable() {
        let loading = WeightLoading(barWeightKg: 20, inventory: standardInventory())

        #expect(!loading.isLoadable(21))
        #expect(loading.nearestLoadable(21) == 20)
        #expect(loading.nearestLoadable(22.4) == 22.5)
        #expect(loading.nearestLoadable(21.25) == 20)
        #expect(loading.nearestLoadable(15) == 20)
    }

    @Test("higher and lower neighbors are discovered from the loadable set")
    func higherAndLowerNeighbors() {
        let loading = WeightLoading(barWeightKg: 20, inventory: standardInventory())

        #expect(loading.nextHigherLoadable(60) == 62.5)
        #expect(loading.nextLowerLoadable(60) == 57.5)
    }

    @Test("exact plate plan is returned per side in descending order")
    func exactPlatePlan() {
        let loading = WeightLoading(barWeightKg: 20, inventory: standardInventory())

        #expect(loading.plates(for: 80) == .exact(perSidePlatesKg: [20, 10]))
    }

    @Test("closest loading returns neighbors when target is not exactly loadable")
    func closestLoading() {
        let loading = WeightLoading(barWeightKg: 20, inventory: standardInventory())

        #expect(loading.plates(for: 81) == .closest(belowKg: 80, aboveKg: 82.5))
    }

    @Test("restricted inventory respects bounded pair counts")
    func restrictedInventoryUsesAvailablePairsOnly() {
        let loading = WeightLoading(
            barWeightKg: 20,
            inventory: [PlateInventoryItem(weightKg: 20, countTotal: 2)]
        )

        #expect(loading.plates(for: 60) == .exact(perSidePlatesKg: [20]))
        #expect(loading.plates(for: 100) == .closest(belowKg: 60, aboveKg: nil))
    }

    @Test("filtered loading drops plates below the minimum")
    func filteredLoadingDropsSmallPlates() {
        let loading = WeightLoading(barWeightKg: 20, inventory: standardInventory())
        let warmupOnly = loading.filtered(minimumPlateKg: 5)

        #expect(!warmupOnly.isLoadable(22.5))
        #expect(!warmupOnly.isLoadable(27.5))
        #expect(warmupOnly.isLoadable(30))
        #expect(warmupOnly.isLoadable(40))
        #expect(warmupOnly.barWeightKg == 20)
    }

    @Test("filtered loading collapses to bar when no plates qualify")
    func filteredLoadingFallsBackToBar() {
        let loading = WeightLoading(barWeightKg: 20, inventory: standardInventory())
        let bareBar = loading.filtered(minimumPlateKg: 50)

        #expect(bareBar.isLoadable(20))
        #expect(bareBar.nextHigherLoadable(20) == nil)
    }

    private func standardInventory() -> [PlateInventoryItem] {
        [25, 20, 15, 10, 5, 2.5, 1.25].map { PlateInventoryItem(weightKg: $0, countTotal: 2) }
    }
}
