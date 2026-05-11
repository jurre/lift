import Foundation

@MainActor
enum DraftSessionFactory {
    static func makeDraft(
        programDay: ProgramDay,
        startedAt: Date,
        timeZone: TimeZone,
        warmupCalculator: WarmupCalculator
    ) -> DraftSessionPlan {
        var exerciseLogs: [DraftExerciseLog] = []

        for slot in programDay.orderedSlots {
            guard
                let progression = slot.exerciseProgression,
                let exercise = progression.exercise
            else {
                continue
            }

            let warmups = warmupCalculator
                .warmupSets(forWorkingWeightKg: progression.currentWeightKg)
                .enumerated()
                .map { index, set in
                    DraftSet(
                        id: UUID(),
                        kind: .warmup,
                        index: index,
                        weightKg: set.weightKg,
                        targetReps: set.reps
                    )
                }

            let workingSets = (0..<progression.workingSets).map { index in
                DraftSet(
                    id: UUID(),
                    kind: .working,
                    index: index,
                    weightKg: progression.currentWeightKg,
                    targetReps: progression.workingReps
                )
            }

            exerciseLogs.append(DraftExerciseLog(
                id: UUID(),
                exercise: exercise,
                exerciseNameSnapshot: exercise.name,
                targetWeightKgSnapshot: progression.currentWeightKg,
                targetSetsSnapshot: progression.workingSets,
                targetRepsSnapshot: progression.workingReps,
                sets: warmups + workingSets
            ))
        }

        return DraftSessionPlan(
            id: UUID(),
            workoutDayID: LocalDay.id(for: startedAt, in: timeZone),
            timeZoneIdentifier: timeZone.identifier,
            startedAt: startedAt,
            programDay: programDay,
            exerciseLogs: exerciseLogs
        )
    }
}

@MainActor
struct DraftSessionPlan {
    let id: UUID
    let workoutDayID: String
    let timeZoneIdentifier: String
    let startedAt: Date
    let programDay: ProgramDay
    let exerciseLogs: [DraftExerciseLog]
}

@MainActor
struct DraftExerciseLog {
    let id: UUID
    let exercise: Exercise
    let exerciseNameSnapshot: String
    let targetWeightKgSnapshot: Double
    let targetSetsSnapshot: Int
    let targetRepsSnapshot: Int
    let sets: [DraftSet]
}

struct DraftSet: Sendable {
    let id: UUID
    let kind: SetKind
    let index: Int
    let weightKg: Double
    let targetReps: Int
}
