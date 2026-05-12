import Foundation

/// Compact, human-readable view-model for an `ExerciseLog` row in the History list.
///
/// Display rules:
/// - all working sets share a weight → "Squat · 60 kg · 3×5 ✓"
/// - mixed working-set weights → "Squat · mixed · 3×5 ✓"
/// - some sets logged but not all hit target → "Squat · 60 kg · 2/3 sets · last 3/5"
/// - no working sets logged → "Squat · 60 kg · 0/3 logged"
struct ExerciseLogSummary: Equatable, Sendable {
    let name: String
    let weightDisplay: String
    let didSucceed: Bool
    let summary: String

    @MainActor
    static func make(from log: ExerciseLog) -> ExerciseLogSummary {
        let workingSets = log.sets
            .filter { $0.kind == .working }
            .sorted { $0.index < $1.index }
        let attempts = workingSets.map { WorkingSetAttempt(targetReps: $0.targetReps, actualReps: $0.actualReps) }

        let didSucceed = Progression.didExerciseSucceed(workingSets: attempts)
        let weightDisplay = makeWeightDisplay(workingSets: workingSets, fallbackKg: log.targetWeightKgSnapshot)
        let body = makeBody(
            workingSets: workingSets,
            targetSets: log.targetSetsSnapshot,
            targetReps: log.targetRepsSnapshot,
            didSucceed: didSucceed
        )

        return ExerciseLogSummary(
            name: log.exerciseNameSnapshot,
            weightDisplay: weightDisplay,
            didSucceed: didSucceed,
            summary: "\(log.exerciseNameSnapshot) · \(weightDisplay) · \(body)"
        )
    }

    private static func makeWeightDisplay(workingSets: [LoggedSet], fallbackKg: Double) -> String {
        let weights = workingSets.map(\.weightKg)
        guard let first = weights.first else { return formatKg(fallbackKg) }
        if weights.allSatisfy({ abs($0 - first) <= 0.0001 }) {
            return formatKg(first)
        }
        return "mixed"
    }

    private static func makeBody(
        workingSets: [LoggedSet],
        targetSets: Int,
        targetReps: Int,
        didSucceed: Bool
    ) -> String {
        let logged = workingSets.filter { $0.actualReps != nil }
        let denominator = max(targetSets, workingSets.count)

        if didSucceed {
            return "\(workingSets.count)×\(targetReps) ✓"
        }

        if logged.isEmpty {
            return "0/\(denominator) logged"
        }

        let hits = logged.filter { ($0.actualReps ?? 0) >= $0.targetReps }.count
        let lastLogged = logged.last
        if let last = lastLogged, (last.actualReps ?? 0) < last.targetReps {
            return "\(hits)/\(denominator) sets · last \(last.actualReps ?? 0)/\(last.targetReps)"
        }
        return "\(logged.count)/\(denominator) logged"
    }

    private static func formatKg(_ kg: Double) -> String {
        let rounded = (kg * 100).rounded() / 100
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = "."
        formatter.usesGroupingSeparator = false
        let value = formatter.string(from: NSNumber(value: rounded)) ?? String(rounded)
        return "\(value) kg"
    }
}
