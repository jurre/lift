import SwiftData
import Testing
@testable import Lift

@Suite("Model invariants")
@MainActor
struct InvariantTests {
    @Test("program days reject duplicate exercises")
    func programDaysRejectDuplicateExercises() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        try LiftSeeder().seedIfNeeded(in: context)

        let days = try fetchAll(ProgramDay.self, from: context)
        guard let workoutA = days.first(where: { $0.name == "Workout A" }) else {
            Issue.record("Workout A not found")
            return
        }
        guard let squat = workoutA.orderedSlots.first(where: { $0.exerciseProgression?.exercise?.key == "squat" })?.exerciseProgression else {
            Issue.record("Workout A squat progression missing")
            return
        }

        do {
            _ = try workoutA.addSlot(exerciseProgression: squat, order: 99)
            Issue.record("Expected duplicate exercise invariant to reject duplicate squat")
        } catch let error as ProgramModelError {
            #expect(error == .duplicateExerciseInDay(programDayName: "Workout A", exerciseKey: "squat"))
        }
    }
}
