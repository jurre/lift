import Foundation
import SwiftData
import Testing
@testable import Lift

@Suite("Seeding")
@MainActor
struct SeedingTests {
    @Test("seed creates the default exercise catalog and progressions")
    func seedCreatesDefaultExercisesAndProgressions() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        try LiftSeeder().seedIfNeeded(in: context)

        let exercises = try fetchAll(Exercise.self, from: context, sortBy: [SortDescriptor(\Exercise.key)])
        let progressions = try fetchAll(ExerciseProgression.self, from: context)

        #expect(exercises.map(\.key) == ["bench", "deadlift", "ohp", "row", "squat"])
        #expect(progressions.count == 5)
        #expect(Set(progressions.compactMap { $0.exercise?.key }) == Set(exercises.map(\.key)))
    }

    @Test("seed shares squat progression across workouts and preserves slot order")
    func seedCreatesSharedSquatAndWorkoutOrder() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        try LiftSeeder().seedIfNeeded(in: context)

        let days = try fetchAll(ProgramDay.self, from: context, sortBy: [SortDescriptor(\ProgramDay.orderInRotation)])
        guard let workoutA = days.first(where: { $0.name == "Workout A" }) else {
            Issue.record("Workout A not found")
            return
        }
        guard let workoutB = days.first(where: { $0.name == "Workout B" }) else {
            Issue.record("Workout B not found")
            return
        }

        #expect(workoutA.orderedSlots.map { $0.exerciseProgression?.exercise?.key } == ["squat", "bench", "row"])
        #expect(workoutB.orderedSlots.map { $0.exerciseProgression?.exercise?.key } == ["squat", "ohp", "deadlift"])

        guard let squatA = workoutA.orderedSlots.first?.exerciseProgression else {
            Issue.record("Workout A squat progression missing")
            return
        }
        guard let squatB = workoutB.orderedSlots.first?.exerciseProgression else {
            Issue.record("Workout B squat progression missing")
            return
        }
        #expect(squatA.persistentModelID == squatB.persistentModelID)

        squatA.currentWeightKg += squatA.incrementKg
        #expect(squatB.currentWeightKg == squatA.currentWeightKg)
    }

    @Test("seed applies default rest times and plate inventory")
    func seedAppliesDefaultRestAndPlates() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        try LiftSeeder().seedIfNeeded(in: context)

        let progressions = try fetchAll(ExerciseProgression.self, from: context)
        let restPairs: [(String, Int)] = progressions.compactMap {
            guard let key = $0.exercise?.key else { return nil }
            return (key, $0.restSeconds)
        }
        let restByExercise = Dictionary(uniqueKeysWithValues: restPairs)
        let users = try fetchAll(User.self, from: context)
        guard let user = users.only else {
            Issue.record("Expected exactly one user")
            return
        }

        #expect(restByExercise["squat"] == 180)
        #expect(restByExercise["deadlift"] == 180)
        #expect(restByExercise["bench"] == 120)
        #expect(restByExercise["ohp"] == 120)
        #expect(restByExercise["row"] == 120)
        #expect(user.orderedPlates.map(\.weightKg) == [25, 20, 15, 10, 5, 2.5, 1.25])
        #expect(user.orderedPlates.allSatisfy { $0.countTotal == 2 })
    }

    @Test("seed is idempotent")
    func seedIsIdempotent() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let seeder = LiftSeeder()

        try seeder.seedIfNeeded(in: context)
        let firstCounts = try counts(in: context)

        try seeder.seedIfNeeded(in: context)
        let secondCounts = try counts(in: context)

        #expect(firstCounts == secondCounts)
        #expect(secondCounts == ["users": 1, "exercises": 5, "progressions": 5, "days": 2, "slots": 6, "plates": 7])
    }

    private func counts(in context: ModelContext) throws -> [String: Int] {
        [
            "users": try context.fetchCount(FetchDescriptor<User>()),
            "exercises": try context.fetchCount(FetchDescriptor<Exercise>()),
            "progressions": try context.fetchCount(FetchDescriptor<ExerciseProgression>()),
            "days": try context.fetchCount(FetchDescriptor<ProgramDay>()),
            "slots": try context.fetchCount(FetchDescriptor<ProgramExerciseSlot>()),
            "plates": try context.fetchCount(FetchDescriptor<PlateInventoryItem>())
        ]
    }
}

private extension Array {
    var only: Element? {
        count == 1 ? first : nil
    }
}
