import Foundation

struct WorkingSetResult: Sendable {
    let targetReps: Int
    let actualReps: Int
}

enum ProgressionOutcome: Equatable, Sendable {
    case advanced(newWeightKg: Double)
    case stalled
    case noWorkingSetsLogged
}

enum Progression {
    static func evaluate(
        workingSets: [WorkingSetResult],
        currentWeightKg: Double,
        incrementKg: Double,
        weightLoading: WeightLoading
    ) -> ProgressionOutcome {
        guard !workingSets.isEmpty else { return .noWorkingSetsLogged }
        guard workingSets.allSatisfy({ $0.actualReps >= $0.targetReps }) else {
            return .stalled
        }

        let proposed = currentWeightKg + incrementKg
        let rounded = weightLoading.nearestLoadable(proposed)
        return .advanced(newWeightKg: rounded)
    }

    static func deload(
        currentWeightKg: Double,
        weightLoading: WeightLoading
    ) -> Double {
        max(weightLoading.barWeightKg, weightLoading.nearestLoadable(currentWeightKg * 0.9))
    }
}
