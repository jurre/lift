import Foundation

enum Loading: Equatable, Sendable {
    case exact(perSidePlatesKg: [Double])
    case closest(belowKg: Double?, aboveKg: Double?)
}

final class WeightLoading: Sendable {
    let barWeightKg: Double

    private let platesByWeightDescending: [PlatePair]
    private let loadableEntries: [LoadableEntry]
    private let loadableWeightsKg: [Double]

    convenience init(barWeightKg: Double, inventory: [PlateInventoryItem]) {
        let pairs = inventory
            .map { PlatePair(weightKg: $0.weightKg, availablePairs: max(0, $0.countTotal / 2)) }
            .filter { $0.availablePairs > 0 && $0.weightKg > 0 }
            .sorted { $0.weightKg > $1.weightKg }
        self.init(barWeightKg: barWeightKg, plates: pairs)
    }

    private init(barWeightKg: Double, plates: [PlatePair]) {
        self.barWeightKg = barWeightKg
        self.platesByWeightDescending = plates

        let entries = WeightLoading.enumerateLoadableEntries(barWeightKg: barWeightKg, plates: platesByWeightDescending)
        self.loadableEntries = entries.sorted { $0.totalKg < $1.totalKg }
        self.loadableWeightsKg = self.loadableEntries.map(\.totalKg)
    }

    func filtered(minimumPlateKg: Double) -> WeightLoading {
        let allowed = platesByWeightDescending.filter { $0.weightKg >= minimumPlateKg }
        return WeightLoading(barWeightKg: barWeightKg, plates: allowed)
    }

    func isLoadable(_ kg: Double) -> Bool {
        loadableWeightsKg.contains { $0.isApprox(kg) }
    }

    func nearestLoadable(_ kg: Double) -> Double {
        guard kg > barWeightKg else { return barWeightKg }
        guard let lower = nextLowerOrEqualLoadable(to: kg) else {
            return loadableWeightsKg.first ?? barWeightKg
        }
        guard let higher = nextHigherOrEqualLoadable(to: kg) else {
            return lower
        }

        if lower.isApprox(higher) {
            return lower
        }

        let lowerDelta = abs(kg - lower)
        let higherDelta = abs(higher - kg)
        if lowerDelta.isApprox(higherDelta) {
            return min(lower, higher)
        }
        return lowerDelta < higherDelta ? lower : higher
    }

    func nextHigherLoadable(_ kg: Double) -> Double? {
        loadableWeightsKg.first { $0 > kg && !$0.isApprox(kg) }
    }

    func nextLowerLoadable(_ kg: Double) -> Double? {
        loadableWeightsKg.last { $0 < kg && !$0.isApprox(kg) }
    }

    func plates(for kg: Double) -> Loading {
        if let exact = exactLoading(at: kg) {
            return .exact(perSidePlatesKg: exact)
        }
        return .closest(
            belowKg: nextLowerOrEqualLoadable(to: kg, allowingExact: false),
            aboveKg: nextHigherOrEqualLoadable(to: kg, allowingExact: false)
        )
    }

    private func exactLoading(at kg: Double) -> [Double]? {
        loadableEntries.first(where: { $0.totalKg.isApprox(kg) })?.perSidePlatesKg
    }

    private func nextLowerOrEqualLoadable(to kg: Double, allowingExact: Bool = true) -> Double? {
        loadableWeightsKg.last { candidate in
            candidate < kg || (allowingExact && candidate.isApprox(kg))
        }
    }

    private func nextHigherOrEqualLoadable(to kg: Double, allowingExact: Bool = true) -> Double? {
        loadableWeightsKg.first { candidate in
            candidate > kg || (allowingExact && candidate.isApprox(kg))
        }
    }

    private static func enumerateLoadableEntries(barWeightKg: Double, plates: [PlatePair]) -> [LoadableEntry] {
        var perSideByKey: [Int: [Double]] = [roundedKey(0): []]

        func search(index: Int, perSideTotal: Double, chosen: [Double]) {
            let key = roundedKey(perSideTotal)
            if
                let current = perSideByKey[key],
                !isPreferred(chosen, over: current)
            {
                // Keep the existing loading for this exact per-side total.
            } else {
                perSideByKey[key] = chosen
            }

            guard index < plates.count else { return }
            let plate = plates[index]
            guard plate.availablePairs > 0 else {
                search(index: index + 1, perSideTotal: perSideTotal, chosen: chosen)
                return
            }

            for count in stride(from: plate.availablePairs, through: 0, by: -1) {
                let extraWeight = Double(count) * plate.weightKg
                let extraPlates = Array(repeating: plate.weightKg, count: count)
                search(index: index + 1, perSideTotal: perSideTotal + extraWeight, chosen: chosen + extraPlates)
            }
        }

        search(index: 0, perSideTotal: 0, chosen: [])

        return perSideByKey.map { key, perSidePlates in
            let perSideTotal = Double(key) / WeightLoading.precisionScale
            return LoadableEntry(
                totalKg: barWeightKg + (perSideTotal * 2),
                perSidePlatesKg: perSidePlates
            )
        }
    }

    private static func isPreferred(_ candidate: [Double], over current: [Double]) -> Bool {
        if candidate.count != current.count {
            return candidate.count < current.count
        }

        let candidateSpread = (candidate.first ?? 0) - (candidate.last ?? 0)
        let currentSpread = (current.first ?? 0) - (current.last ?? 0)
        if !candidateSpread.isApprox(currentSpread) {
            return candidateSpread < currentSpread
        }

        for (lhs, rhs) in zip(candidate, current) {
            if lhs.isApprox(rhs) { continue }
            return lhs < rhs
        }
        return false
    }

    private static let precisionScale = 10_000.0

    private static func roundedKey(_ value: Double) -> Int {
        Int((value * precisionScale).rounded())
    }
}

private struct PlatePair: Sendable {
    let weightKg: Double
    let availablePairs: Int
}

private struct LoadableEntry: Sendable {
    let totalKg: Double
    let perSidePlatesKg: [Double]
}

private extension Double {
    func isApprox(_ other: Double) -> Bool {
        abs(self - other) <= 0.0001
    }
}
