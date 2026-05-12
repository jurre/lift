import Foundation
import SwiftData
import Testing
@testable import Lift

@Suite("DraftSessionFactory")
@MainActor
struct DraftSessionFactoryTests {
    @Test("draft session mirrors the seeded workout B order and snapshots")
    func draftSessionMirrorsWorkoutB() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try LiftSeeder().seedIfNeeded(in: context)

        let workoutB = try requireDay(named: "Workout B", from: context)
        setWeight(40, forExerciseKey: "squat", in: workoutB)
        setWeight(25, forExerciseKey: "ohp", in: workoutB)
        setWeight(25, forExerciseKey: "deadlift", in: workoutB)

        let plan = DraftSessionFactory.makeDraft(
            programDay: workoutB,
            startedAt: fixtureDate(),
            timeZone: try #require(TimeZone(identifier: "America/Los_Angeles")),
            warmupCalculator: WarmupCalculator(weightLoading: WeightLoading(barWeightKg: 20, inventory: standardInventory()))
        )

        #expect(plan.exerciseLogs.count == 3)
        #expect(plan.exerciseLogs.map(\.exerciseNameSnapshot) == ["Squat", "OHP", "Deadlift"])
        #expect(plan.exerciseLogs.map(\.targetWeightKgSnapshot) == [40, 25, 25])
        #expect(plan.exerciseLogs.map(\.targetSetsSnapshot) == [3, 3, 1])
        #expect(plan.exerciseLogs.map(\.targetRepsSnapshot) == [5, 5, 5])

        let squatSets = try #require(plan.exerciseLogs.first?.sets)
        #expect(squatSets.filter { $0.kind == .warmup }.map { ($0.weightKg, $0.targetReps) }.elementsEqual(
            [(20.0, 5), (30.0, 2)],
            by: ==
        ))
        #expect(squatSets.filter { $0.kind == .working }.count == 3)

        let deadliftSets = try #require(plan.exerciseLogs.last?.sets)
        #expect(deadliftSets.filter { $0.kind == .warmup }.isEmpty)
        #expect(deadliftSets.filter { $0.kind == .working }.map(\.weightKg) == [25])
    }

    @Test("shared squat progression snapshots the same weight in workouts A and B")
    func sharedSquatProgressionUsesSameWeight() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try LiftSeeder().seedIfNeeded(in: context)

        let workoutA = try requireDay(named: "Workout A", from: context)
        let workoutB = try requireDay(named: "Workout B", from: context)
        setWeight(42.5, forExerciseKey: "squat", in: workoutA)

        let calculator = WarmupCalculator(weightLoading: WeightLoading(barWeightKg: 20, inventory: standardInventory()))
        let draftA = DraftSessionFactory.makeDraft(programDay: workoutA, startedAt: fixtureDate(), timeZone: .utc, warmupCalculator: calculator)
        let draftB = DraftSessionFactory.makeDraft(programDay: workoutB, startedAt: fixtureDate(), timeZone: .utc, warmupCalculator: calculator)

        #expect(draftA.exerciseLogs.first?.targetWeightKgSnapshot == 42.5)
        #expect(draftB.exerciseLogs.first?.targetWeightKgSnapshot == 42.5)
    }

    @Test("draft session assigns timezone-aware day ids and unique ids")
    func draftSessionAssignsIdentifiers() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try LiftSeeder().seedIfNeeded(in: context)

        let workoutA = try requireDay(named: "Workout A", from: context)
        let calculator = WarmupCalculator(weightLoading: WeightLoading(barWeightKg: 20, inventory: standardInventory()))
        let plan = DraftSessionFactory.makeDraft(
            programDay: workoutA,
            startedAt: fixtureDate(),
            timeZone: try #require(TimeZone(identifier: "America/Los_Angeles")),
            warmupCalculator: calculator
        )

        #expect(plan.workoutDayID == "2024-12-31")
        #expect(plan.timeZoneIdentifier == "America/Los_Angeles")
        #expect(plan.id != .zero)

        let logIDs = plan.exerciseLogs.map(\.id)
        #expect(Set(logIDs).count == logIDs.count)
        #expect(logIDs.allSatisfy { $0 != .zero })

        let setIDs = plan.exerciseLogs.flatMap(\.sets).map(\.id)
        #expect(Set(setIDs).count == setIDs.count)
        #expect(setIDs.allSatisfy { $0 != .zero })
    }

    private func requireDay(named name: String, from context: ModelContext) throws -> ProgramDay {
        let days = try fetchAll(ProgramDay.self, from: context)
        guard let day = days.first(where: { $0.name == name }) else {
            Issue.record("Missing program day \(name)")
            fatalError("Missing program day")
        }
        return day
    }

    private func setWeight(_ weight: Double, forExerciseKey key: String, in day: ProgramDay) {
        day.orderedSlots
            .first(where: { $0.exerciseProgression?.exercise?.key == key })?
            .exerciseProgression?
            .currentWeightKg = weight
    }

    private func standardInventory() -> [PlateInventoryItem] {
        [25, 20, 15, 10, 5, 2.5, 1.25].map { PlateInventoryItem(weightKg: $0, countTotal: 2) }
    }

    private func fixtureDate() -> Date {
        Date(timeIntervalSince1970: 1_735_689_600)
    }
}

private extension TimeZone {
    static let utc = TimeZone(secondsFromGMT: 0)!
}

private extension UUID {
    static let zero = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
}
