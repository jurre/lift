import Foundation
import SwiftData
import Testing
@testable import Lift

@Suite("WorkoutScheduler")
@MainActor
struct WorkoutSchedulerTests {
    @Test("no completed session returns workout A")
    func noCompletedSessionReturnsWorkoutA() throws {
        let (days, _) = try seededDays()

        #expect(WorkoutScheduler.nextProgramDay(from: days, mostRecentCompleted: nil)?.name == "Workout A")
    }

    @Test("completed workout A returns workout B")
    func completedWorkoutAReturnsWorkoutB() throws {
        let (days, workoutA) = try seededDays(named: "Workout A")
        let completed = WorkoutSession(
            workoutDayID: "2024-01-01",
            timeZoneIdentifierAtStart: TimeZone.utc.identifier,
            startedAt: .now,
            programDay: workoutA,
            status: .completed
        )

        #expect(WorkoutScheduler.nextProgramDay(from: days, mostRecentCompleted: completed)?.name == "Workout B")
    }

    @Test("completed workout B returns workout A")
    func completedWorkoutBReturnsWorkoutA() throws {
        let (days, workoutB) = try seededDays(named: "Workout B")
        let completed = WorkoutSession(
            workoutDayID: "2024-01-01",
            timeZoneIdentifierAtStart: TimeZone.utc.identifier,
            startedAt: .now,
            programDay: workoutB,
            status: .completed
        )

        #expect(WorkoutScheduler.nextProgramDay(from: days, mostRecentCompleted: completed)?.name == "Workout A")
    }

    @Test("abandoned sessions do not advance the schedule")
    func abandonedSessionsDoNotAdvance() throws {
        let (days, workoutA) = try seededDays(named: "Workout A")
        let abandoned = WorkoutSession(
            workoutDayID: "2024-01-01",
            timeZoneIdentifierAtStart: TimeZone.utc.identifier,
            startedAt: .now,
            programDay: workoutA,
            status: .abandoned
        )

        #expect(WorkoutScheduler.nextProgramDay(from: days, mostRecentCompleted: abandoned)?.name == "Workout A")
    }

    @Test("ended without progression sessions do not advance the schedule")
    func endedWithoutProgressionDoesNotAdvance() throws {
        let (days, workoutB) = try seededDays(named: "Workout B")
        let noProgression = WorkoutSession(
            workoutDayID: "2024-01-01",
            timeZoneIdentifierAtStart: TimeZone.utc.identifier,
            startedAt: .now,
            programDay: workoutB,
            status: .endedNoProgression
        )

        #expect(WorkoutScheduler.nextProgramDay(from: days, mostRecentCompleted: noProgression)?.name == "Workout A")
    }

    private func seededDays(named name: String? = nil) throws -> ([ProgramDay], ProgramDay) {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try LiftSeeder().seedIfNeeded(in: context)

        let days = try fetchAll(ProgramDay.self, from: context, sortBy: [SortDescriptor(\ProgramDay.orderInRotation)])
        guard let selected = days.first(where: { $0.name == (name ?? "Workout A") }) else {
            Issue.record("Program day not found")
            fatalError("Missing seeded program day")
        }

        return (days, selected)
    }
}

private extension TimeZone {
    static let utc = TimeZone(secondsFromGMT: 0)!
}
