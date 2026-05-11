import Foundation
import SwiftData
import Testing
@testable import Lift

@Suite("DraftReopenCoordinator")
@MainActor
struct DraftReopenCoordinatorTests {
    @Test("load shows the most recent stale draft and ignores today's draft")
    func loadShowsMostRecentStaleDraft() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try LiftSeeder().seedIfNeeded(in: context)

        let workoutA = try requireDay(named: "Workout A", from: context)
        let workoutB = try requireDay(named: "Workout B", from: context)
        let service = try DraftSessionService(modelContext: context)

        _ = try service.createDraft(
            for: workoutA,
            now: fixtureDate().addingTimeInterval(-86_400 * 3),
            calendar: utcCalendar()
        )
        let expected = try service.createDraft(
            for: workoutB,
            now: fixtureDate().addingTimeInterval(-86_400),
            calendar: utcCalendar()
        )
        _ = try service.createDraft(
            for: workoutA,
            now: fixtureDate(),
            calendar: utcCalendar()
        )

        let coordinator = DraftReopenCoordinator(modelContext: context)
        coordinator.load(now: fixtureDate(), calendar: utcCalendar())

        #expect(coordinator.pendingDraft?.id == expected.id)
    }

    @Test("resume keeps the stale session selected for today")
    func resumeKeepsStaleSessionSelected() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try LiftSeeder().seedIfNeeded(in: context)

        let workoutA = try requireDay(named: "Workout A", from: context)
        let service = try DraftSessionService(modelContext: context)
        let stale = try service.createDraft(
            for: workoutA,
            now: fixtureDate().addingTimeInterval(-86_400),
            calendar: utcCalendar()
        )

        let coordinator = DraftReopenCoordinator(modelContext: context)
        coordinator.load(now: fixtureDate(), calendar: utcCalendar())
        coordinator.resumePendingDraft()

        #expect(coordinator.pendingDraft == nil)
        #expect(coordinator.resumedDraftID == stale.id)
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

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .utc
        return calendar
    }
}

private extension TimeZone {
    static let utc = TimeZone(secondsFromGMT: 0)!
}
