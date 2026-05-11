import Foundation
import SwiftData

@MainActor
struct DraftSessionFactory {
    func makeDraft(
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

    static func makeDraft(
        programDay: ProgramDay,
        startedAt: Date,
        timeZone: TimeZone,
        warmupCalculator: WarmupCalculator
    ) -> DraftSessionPlan {
        Self().makeDraft(
            programDay: programDay,
            startedAt: startedAt,
            timeZone: timeZone,
            warmupCalculator: warmupCalculator
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

    init(
        id: UUID,
        workoutDayID: String,
        timeZoneIdentifier: String,
        startedAt: Date,
        programDay: ProgramDay,
        exerciseLogs: [DraftExerciseLog]
    ) {
        self.id = id
        self.workoutDayID = workoutDayID
        self.timeZoneIdentifier = timeZoneIdentifier
        self.startedAt = startedAt
        self.programDay = programDay
        self.exerciseLogs = exerciseLogs
    }

    init(session: WorkoutSession) {
        self.init(
            id: session.id,
            workoutDayID: session.workoutDayID,
            timeZoneIdentifier: session.timeZoneIdentifierAtStart,
            startedAt: session.startedAt,
            programDay: session.programDay ?? ProgramDay(name: "Workout", orderInRotation: 0),
            exerciseLogs: session.orderedExerciseLogs.map(DraftExerciseLog.init(log:))
        )
    }
}

@MainActor
struct DraftExerciseLog {
    let id: UUID
    let exercise: Exercise?
    let exerciseNameSnapshot: String
    let targetWeightKgSnapshot: Double
    let targetSetsSnapshot: Int
    let targetRepsSnapshot: Int
    let sets: [DraftSet]

    init(
        id: UUID,
        exercise: Exercise?,
        exerciseNameSnapshot: String,
        targetWeightKgSnapshot: Double,
        targetSetsSnapshot: Int,
        targetRepsSnapshot: Int,
        sets: [DraftSet]
    ) {
        self.id = id
        self.exercise = exercise
        self.exerciseNameSnapshot = exerciseNameSnapshot
        self.targetWeightKgSnapshot = targetWeightKgSnapshot
        self.targetSetsSnapshot = targetSetsSnapshot
        self.targetRepsSnapshot = targetRepsSnapshot
        self.sets = sets
    }

    init(log: ExerciseLog) {
        self.init(
            id: log.id,
            exercise: log.exercise,
            exerciseNameSnapshot: log.exerciseNameSnapshot,
            targetWeightKgSnapshot: log.targetWeightKgSnapshot,
            targetSetsSnapshot: log.targetSetsSnapshot,
            targetRepsSnapshot: log.targetRepsSnapshot,
            sets: log.orderedSets.map(DraftSet.init(set:))
        )
    }
}

struct DraftSet: Sendable {
    let id: UUID
    let kind: SetKind
    let index: Int
    let weightKg: Double
    let targetReps: Int
    let actualReps: Int?

    init(
        id: UUID,
        kind: SetKind,
        index: Int,
        weightKg: Double,
        targetReps: Int,
        actualReps: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.index = index
        self.weightKg = weightKg
        self.targetReps = targetReps
        self.actualReps = actualReps
    }

    init(set: LoggedSet) {
        self.init(
            id: set.id,
            kind: set.kind,
            index: set.index,
            weightKg: set.weightKg,
            targetReps: set.targetReps,
            actualReps: set.actualReps
        )
    }
}

private extension WorkoutSession {
    var orderedExerciseLogs: [ExerciseLog] {
        guard let programDay else { return exerciseLogs }

        let slotOrder: [PersistentIdentifier: Int] = .init(
            uniqueKeysWithValues: programDay.orderedSlots.enumerated().compactMap { index, slot in
                guard let exercise = slot.exerciseProgression?.exercise else {
                    return nil
                }
                return (exercise.persistentModelID, index)
            }
        )

        return exerciseLogs.sorted { lhs, rhs in
            let lhsOrder = lhs.exercise.flatMap { slotOrder[$0.persistentModelID] } ?? .max
            let rhsOrder = rhs.exercise.flatMap { slotOrder[$0.persistentModelID] } ?? .max
            if lhsOrder != rhsOrder {
                return lhsOrder < rhsOrder
            }
            return lhs.exerciseNameSnapshot < rhs.exerciseNameSnapshot
        }
    }
}

private extension ExerciseLog {
    var orderedSets: [LoggedSet] {
        sets.sorted { lhs, rhs in
            if lhs.kind != rhs.kind {
                return lhs.kind == .warmup
            }
            return lhs.index < rhs.index
        }
    }
}
