import Foundation
import SwiftData

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var workoutDayID: String
    var timeZoneIdentifierAtStart: String
    var startedAt: Date
    var endedAt: Date?
    var programDay: ProgramDay?
    var status: SessionStatus

    @Relationship(deleteRule: .cascade, inverse: \ExerciseLog.session)
    var exerciseLogs: [ExerciseLog]

    init(
        id: UUID = UUID(),
        workoutDayID: String,
        timeZoneIdentifierAtStart: String,
        startedAt: Date,
        endedAt: Date? = nil,
        programDay: ProgramDay,
        exerciseLogs: [ExerciseLog] = [],
        status: SessionStatus = .draft
    ) {
        self.id = id
        self.workoutDayID = workoutDayID
        self.timeZoneIdentifierAtStart = timeZoneIdentifierAtStart
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.programDay = programDay
        self.exerciseLogs = exerciseLogs
        self.status = status
    }
}

@Model
final class ExerciseLog {
    @Attribute(.unique) var id: UUID
    var session: WorkoutSession?
    var exercise: Exercise?
    var exerciseNameSnapshot: String
    var targetWeightKgSnapshot: Double
    var targetSetsSnapshot: Int
    var targetRepsSnapshot: Int

    @Relationship(deleteRule: .cascade, inverse: \LoggedSet.log)
    var sets: [LoggedSet]

    init(
        id: UUID = UUID(),
        session: WorkoutSession,
        exercise: Exercise,
        exerciseNameSnapshot: String,
        targetWeightKgSnapshot: Double,
        targetSetsSnapshot: Int,
        targetRepsSnapshot: Int,
        sets: [LoggedSet] = []
    ) {
        self.id = id
        self.session = session
        self.exercise = exercise
        self.exerciseNameSnapshot = exerciseNameSnapshot
        self.targetWeightKgSnapshot = targetWeightKgSnapshot
        self.targetSetsSnapshot = targetSetsSnapshot
        self.targetRepsSnapshot = targetRepsSnapshot
        self.sets = sets
    }
}

@Model
final class LoggedSet {
    @Attribute(.unique) var id: UUID
    var log: ExerciseLog?
    var kind: SetKind
    var index: Int
    var weightKg: Double
    var targetReps: Int
    var actualReps: Int?
    var completedAt: Date?
    var notes: String?

    init(
        id: UUID = UUID(),
        log: ExerciseLog,
        kind: SetKind,
        index: Int,
        weightKg: Double,
        targetReps: Int,
        actualReps: Int? = nil,
        completedAt: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.log = log
        self.kind = kind
        self.index = index
        self.weightKg = weightKg
        self.targetReps = targetReps
        self.actualReps = actualReps
        self.completedAt = completedAt
        self.notes = notes
    }
}

@Model
final class ProgressionEvent {
    @Attribute(.unique) var id: UUID
    var exerciseProgression: ExerciseProgression?
    var session: WorkoutSession?
    var oldWeightKg: Double
    var newWeightKg: Double
    var reason: ProgressionReason
    var createdAt: Date

    init(
        id: UUID = UUID(),
        exerciseProgression: ExerciseProgression,
        session: WorkoutSession? = nil,
        oldWeightKg: Double,
        newWeightKg: Double,
        reason: ProgressionReason,
        createdAt: Date = .now
    ) {
        self.id = id
        self.exerciseProgression = exerciseProgression
        self.session = session
        self.oldWeightKg = oldWeightKg
        self.newWeightKg = newWeightKg
        self.reason = reason
        self.createdAt = createdAt
    }
}
