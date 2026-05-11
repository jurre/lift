import Foundation

struct WarmupCalculator: Sendable {
    let weightLoading: WeightLoading

    func warmupSets(forWorkingWeightKg working: Double) -> [(weightKg: Double, reps: Int)] {
        let bar = weightLoading.barWeightKg
        guard working > bar + 10 else {
            return [(bar, 5)]
        }

        var sets: [(weightKg: Double, reps: Int)] = [(bar, 5)]
        let scheme: [(multiplier: Double, reps: Int)] = [
            (0.40, 5),
            (0.60, 3),
            (0.80, 2)
        ]

        for step in scheme {
            let rounded = weightLoading.nearestLoadable(working * step.multiplier)
            guard rounded > bar, rounded < working else { continue }
            guard sets.last?.weightKg != rounded else { continue }
            sets.append((rounded, step.reps))
        }

        return sets
    }
}
