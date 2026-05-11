import Foundation
import SwiftData
import Testing
@testable import Lift

@Suite("TodayViewModel")
@MainActor
struct TodayViewModelTests {
    @Test("load defaults to workout A and builds a draft plan")
    func loadDefaultsToWorkoutAAndBuildsDraftPlan() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try LiftSeeder().seedIfNeeded(in: context)

        let viewModel = TodayViewModel(
            modelContext: context,
            now: fixtureDate(),
            timeZone: .utc
        )

        viewModel.load()

        #expect(viewModel.selectedProgramDay?.name == "Workout A")
        let draftPlan = try #require(viewModel.draftPlan)
        #expect(draftPlan.exerciseLogs.count == 3)
        let selectedDay = try #require(viewModel.selectedProgramDay)
        #expect(draftPlan.exerciseLogs.count == selectedDay.orderedSlots.count)
    }

    @Test("completed workout A advances selection to workout B")
    func completedWorkoutAAdvancesToWorkoutB() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try LiftSeeder().seedIfNeeded(in: context)

        let workoutA = try requireDay(named: "Workout A", from: context)
        let completedSession = WorkoutSession(
            workoutDayID: "2025-01-01",
            timeZoneIdentifierAtStart: TimeZone.utc.identifier,
            startedAt: fixtureDate(),
            programDay: workoutA,
            status: .completed
        )
        context.insert(completedSession)
        try context.save()

        let viewModel = TodayViewModel(
            modelContext: context,
            now: fixtureDate(),
            timeZone: .utc
        )

        viewModel.refresh()

        #expect(viewModel.selectedProgramDay?.name == "Workout B")
        let draftPlan = try #require(viewModel.draftPlan)
        let selectedDay = try #require(viewModel.selectedProgramDay)
        #expect(draftPlan.exerciseLogs.count == selectedDay.orderedSlots.count)
    }

    private func requireDay(named name: String, from context: ModelContext) throws -> ProgramDay {
        let days = try fetchAll(ProgramDay.self, from: context)
        guard let day = days.first(where: { $0.name == name }) else {
            Issue.record("Missing program day \(name)")
            fatalError("Missing program day")
        }
        return day
    }

    private func fixtureDate() -> Date {
        Date(timeIntervalSince1970: 1_735_689_600)
    }
}

private extension TimeZone {
    static let utc = TimeZone(secondsFromGMT: 0)!
}
