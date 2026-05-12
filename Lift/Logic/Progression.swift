import Foundation

struct WorkingSetResult: Sendable {
    let targetReps: Int
    let actualReps: Int
}

/// Working-set attempt where `actualReps == nil` means the set was never logged.
/// Used by history/edit code that needs to reason about completion in addition to success.
struct WorkingSetAttempt: Equatable, Sendable {
    let targetReps: Int
    let actualReps: Int?

    init(targetReps: Int, actualReps: Int?) {
        self.targetReps = targetReps
        self.actualReps = actualReps
    }
}

enum ProgressionOutcome: Equatable, Sendable {
    case advanced(newWeightKg: Double)
    case stalled
    case noWorkingSetsLogged
}

enum Progression {
    /// Evaluates whether the working sets justify advancing the weight, and if so,
    /// returns the new weight rounded UP to the next loadable value.
    ///
    /// The rounding policy here is intentionally different from `WeightLoading.nearestLoadable`,
    /// which rounds toward the nearest value (and rounds down on ties). For progression we want:
    ///
    /// 1. If `current + increment` is exactly loadable → use it.
    /// 2. Otherwise, snap UP to the next loadable weight strictly greater than `current + increment`.
    /// 3. If no loadable weight exists at or above `current + increment` (i.e. `current + increment`
    ///    exceeds the gym's max loadable weight), fall back to the smallest loadable weight strictly
    ///    greater than `current` so the user still advances when there is any headroom.
    /// 4. If the user is already at the gym's max loadable weight, return `current` unchanged so the
    ///    session can finish cleanly without writing a meaningless progression event.
    ///
    /// Why round UP rather than down: a successful session must always result in forward progress
    /// when the equipment allows it. Rounding down on ties (the `nearestLoadable` policy, which is
    /// correct for the plate calculator) silently turns a 1.25kg increment with 1.25kg pair plates
    /// into a no-op — the proposed weight ties between current and current+2.5, and ties favor the
    /// lower value, so the user never moves. Rounding up always honors the spirit of "you earned a
    /// jump," even if the smallest physically loadable jump is larger than the configured increment.
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
        if weightLoading.isLoadable(proposed) {
            return .advanced(newWeightKg: proposed)
        }

        if let higher = weightLoading.nextHigherLoadable(proposed) {
            return .advanced(newWeightKg: higher)
        }

        if let smallestAboveCurrent = weightLoading.nextHigherLoadable(currentWeightKg) {
            return .advanced(newWeightKg: smallestAboveCurrent)
        }

        return .advanced(newWeightKg: currentWeightKg)
    }

    static func deload(
        currentWeightKg: Double,
        weightLoading: WeightLoading
    ) -> Double {
        max(weightLoading.barWeightKg, weightLoading.nearestLoadable(currentWeightKg * 0.9))
    }

    /// Returns true iff every working set was logged AND hit its target. The empty list is treated
    /// as failure so deleting all working sets in History never silently flips an exercise to success.
    static func didExerciseSucceed(workingSets: [WorkingSetAttempt]) -> Bool {
        guard !workingSets.isEmpty else { return false }
        return workingSets.allSatisfy { attempt in
            guard let actual = attempt.actualReps else { return false }
            return actual >= attempt.targetReps
        }
    }
}
