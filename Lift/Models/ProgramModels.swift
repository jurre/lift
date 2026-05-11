import Foundation
import SwiftData

@Model
final class Exercise {
    @Attribute(.unique) var key: String
    var name: String

    init(key: String, name: String) {
        self.key = key
        self.name = name
    }
}

@Model
final class ExerciseProgression {
    var exercise: Exercise?
    var currentWeightKg: Double
    var incrementKg: Double
    var restSeconds: Int
    var workingSets: Int
    var workingReps: Int
    var lastProgressionAt: Date?
    var stalledCount: Int

    init(
        exercise: Exercise,
        currentWeightKg: Double,
        incrementKg: Double,
        restSeconds: Int,
        workingSets: Int,
        workingReps: Int,
        lastProgressionAt: Date? = nil,
        stalledCount: Int = 0
    ) {
        self.exercise = exercise
        self.currentWeightKg = currentWeightKg
        self.incrementKg = incrementKg
        self.restSeconds = restSeconds
        self.workingSets = workingSets
        self.workingReps = workingReps
        self.lastProgressionAt = lastProgressionAt
        self.stalledCount = stalledCount
    }
}

@Model
final class ProgramDay {
    var name: String
    var orderInRotation: Int

    @Relationship(deleteRule: .cascade, inverse: \ProgramExerciseSlot.programDay)
    var slots: [ProgramExerciseSlot]

    init(name: String, orderInRotation: Int, slots: [ProgramExerciseSlot] = []) {
        self.name = name
        self.orderInRotation = orderInRotation
        self.slots = slots
    }

    var orderedSlots: [ProgramExerciseSlot] {
        slots.sorted { $0.order < $1.order }
    }

    @discardableResult
    func addSlot(exerciseProgression: ExerciseProgression, order: Int) throws -> ProgramExerciseSlot {
        let exerciseKey = exerciseProgression.exercise?.key ?? "unknown"
        if slots.contains(where: { $0.exerciseProgression?.exercise?.key == exerciseKey }) {
            throw ProgramModelError.duplicateExerciseInDay(programDayName: name, exerciseKey: exerciseKey)
        }

        let slot = ProgramExerciseSlot(programDay: self, exerciseProgression: exerciseProgression, order: order)
        slots.append(slot)
        slots.sort { $0.order < $1.order }
        return slot
    }
}

@Model
final class ProgramExerciseSlot {
    var programDay: ProgramDay?
    var exerciseProgression: ExerciseProgression?
    var order: Int

    init(programDay: ProgramDay, exerciseProgression: ExerciseProgression, order: Int) {
        self.programDay = programDay
        self.exerciseProgression = exerciseProgression
        self.order = order
    }
}
