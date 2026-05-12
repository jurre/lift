import Foundation

struct WarmupPolicy: Sendable, Equatable {
    var includesBarWarmup: Bool
    var minimumWarmupPlateKg: Double
    var maxWarmupRatio: Double

    static let `default` = WarmupPolicy(
        includesBarWarmup: true,
        minimumWarmupPlateKg: 5.0,
        maxWarmupRatio: 0.85
    )

    static let deadlift = WarmupPolicy(
        includesBarWarmup: false,
        minimumWarmupPlateKg: 5.0,
        maxWarmupRatio: 0.85
    )
}

struct WarmupCalculator: Sendable {
    let weightLoading: WeightLoading

    func warmupSets(
        forWorkingWeightKg working: Double,
        policy: WarmupPolicy = .default
    ) -> [(weightKg: Double, reps: Int)] {
        let bar = weightLoading.barWeightKg
        guard working > bar + 10 else {
            return policy.includesBarWarmup ? [(bar, 5)] : []
        }

        let warmupLoading = weightLoading.filtered(minimumPlateKg: policy.minimumWarmupPlateKg)
        let maxAllowed = working * policy.maxWarmupRatio

        var sets: [(weightKg: Double, reps: Int)] = []
        if policy.includesBarWarmup {
            sets.append((bar, 5))
        }

        let scheme: [(multiplier: Double, reps: Int)] = [
            (0.40, 5),
            (0.60, 3),
            (0.80, 2)
        ]

        for step in scheme {
            var snapped = warmupLoading.nearestLoadable(working * step.multiplier)
            if snapped > maxAllowed {
                guard let lower = warmupLoading.nextLowerLoadable(snapped),
                      lower > bar,
                      lower <= maxAllowed
                else { continue }
                snapped = lower
            }
            guard snapped > bar, snapped < working else { continue }
            guard sets.last?.weightKg != snapped else { continue }
            sets.append((snapped, step.reps))
        }

        return sets
    }
}

extension Exercise {
    var warmupPolicy: WarmupPolicy {
        switch key {
        case "deadlift": return .deadlift
        default: return .default
        }
    }
}
