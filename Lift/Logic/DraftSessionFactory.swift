import Foundation
import CryptoKit
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

            let exerciseLogID = stableUUID(
                namespace: "exercise-log",
                components: [
                    LocalDay.id(for: startedAt, in: timeZone),
                    timeZone.identifier,
                    programDay.name,
                    String(slot.order),
                    exercise.key
                ]
            )

            let warmups = warmupCalculator
                .warmupSets(forWorkingWeightKg: progression.currentWeightKg, policy: exercise.warmupPolicy)
                .enumerated()
                .map { index, set in
                    DraftSet(
                        id: stableUUID(
                            namespace: "set",
                            components: [
                                exerciseLogID.uuidString,
                                SetKind.warmup.rawValue,
                                String(index)
                            ]
                        ),
                        kind: .warmup,
                        index: index,
                        weightKg: set.weightKg,
                        targetReps: set.reps
                    )
                }

            let workingSets = (0..<progression.workingSets).map { index in
                DraftSet(
                    id: stableUUID(
                        namespace: "set",
                        components: [
                            exerciseLogID.uuidString,
                            SetKind.working.rawValue,
                            String(index)
                        ]
                    ),
                    kind: .working,
                    index: index,
                    weightKg: progression.currentWeightKg,
                    targetReps: progression.workingReps
                )
            }

            exerciseLogs.append(DraftExerciseLog(
                id: exerciseLogID,
                exercise: exercise,
                exerciseNameSnapshot: exercise.name,
                targetWeightKgSnapshot: progression.currentWeightKg,
                targetSetsSnapshot: progression.workingSets,
                targetRepsSnapshot: progression.workingReps,
                stalledCount: progression.stalledCount,
                sets: warmups + workingSets
            ))
        }

        return DraftSessionPlan(
            id: stableUUID(
                namespace: "session",
                components: [
                    LocalDay.id(for: startedAt, in: timeZone),
                    timeZone.identifier,
                    programDay.name,
                    startedAt.formatted(.iso8601)
                ]
            ),
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

    private func stableUUID(namespace: String, components: [String]) -> UUID {
        let seed = ([namespace] + components).joined(separator: "|")
        let digest = Insecure.SHA1.hash(data: Data(seed.utf8))
        let bytes = Array(digest.prefix(16))
        let uuid = uuid_t(
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: uuid)
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

    init(session: WorkoutSession, stalledCounts: [String: Int] = [:]) {
        self.init(
            id: session.id,
            workoutDayID: session.workoutDayID,
            timeZoneIdentifier: session.timeZoneIdentifierAtStart,
            startedAt: session.startedAt,
            programDay: session.programDay ?? ProgramDay(name: "Workout", orderInRotation: 0),
            exerciseLogs: session.orderedExerciseLogs.map { log in
                DraftExerciseLog(
                    log: log,
                    stalledCount: log.exercise.flatMap { stalledCounts[$0.key] } ?? 0
                )
            }
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
    let stalledCount: Int
    let sets: [DraftSet]

    init(
        id: UUID,
        exercise: Exercise?,
        exerciseNameSnapshot: String,
        targetWeightKgSnapshot: Double,
        targetSetsSnapshot: Int,
        targetRepsSnapshot: Int,
        stalledCount: Int = 0,
        sets: [DraftSet]
    ) {
        self.id = id
        self.exercise = exercise
        self.exerciseNameSnapshot = exerciseNameSnapshot
        self.targetWeightKgSnapshot = targetWeightKgSnapshot
        self.targetSetsSnapshot = targetSetsSnapshot
        self.targetRepsSnapshot = targetRepsSnapshot
        self.stalledCount = stalledCount
        self.sets = sets
    }

    init(log: ExerciseLog, stalledCount: Int = 0) {
        self.init(
            id: log.id,
            exercise: log.exercise,
            exerciseNameSnapshot: log.exerciseNameSnapshot,
            targetWeightKgSnapshot: log.targetWeightKgSnapshot,
            targetSetsSnapshot: log.targetSetsSnapshot,
            targetRepsSnapshot: log.targetRepsSnapshot,
            stalledCount: stalledCount,
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
