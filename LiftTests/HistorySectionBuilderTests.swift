import Foundation
import SwiftData
import Testing
@testable import Lift

@Suite("HistorySectionBuilder")
@MainActor
struct HistorySectionBuilderTests {
    @Test("groups completed sessions by month derived from workoutDayID prefix")
    func groupsByMonthPrefix() throws {
        let fixture = try makeFixture()
        let mayA = try fixture.makeCompletedSession(programDayName: "Workout A", workoutDayID: "2026-05-12", startedAt: fixture.date(2026, 5, 12, 9))
        let mayB = try fixture.makeCompletedSession(programDayName: "Workout B", workoutDayID: "2026-05-14", startedAt: fixture.date(2026, 5, 14, 9))
        let april = try fixture.makeCompletedSession(programDayName: "Workout A", workoutDayID: "2026-04-30", startedAt: fixture.date(2026, 4, 30, 9))

        let sections = HistorySectionBuilder.sections(from: [mayA, mayB, april])

        #expect(sections.count == 2)
        #expect(sections[0].monthKey == "2026-05")
        #expect(sections[1].monthKey == "2026-04")
    }

    @Test("sections are sorted newest month first")
    func sectionsSortedNewestFirst() throws {
        let fixture = try makeFixture()
        let oldest = try fixture.makeCompletedSession(programDayName: "Workout A", workoutDayID: "2025-12-31", startedAt: fixture.date(2025, 12, 31, 9))
        let middle = try fixture.makeCompletedSession(programDayName: "Workout B", workoutDayID: "2026-01-02", startedAt: fixture.date(2026, 1, 2, 9))
        let newest = try fixture.makeCompletedSession(programDayName: "Workout A", workoutDayID: "2026-03-15", startedAt: fixture.date(2026, 3, 15, 9))

        let sections = HistorySectionBuilder.sections(from: [middle, oldest, newest])

        #expect(sections.map(\.monthKey) == ["2026-03", "2026-01", "2025-12"])
    }

    @Test("sessions within a section are sorted by startedAt descending")
    func sessionsWithinSectionSortedNewestFirst() throws {
        let fixture = try makeFixture()
        let earlier = try fixture.makeCompletedSession(programDayName: "Workout A", workoutDayID: "2026-05-12", startedAt: fixture.date(2026, 5, 12, 7))
        let later = try fixture.makeCompletedSession(programDayName: "Workout B", workoutDayID: "2026-05-12", startedAt: fixture.date(2026, 5, 12, 18))

        let sections = HistorySectionBuilder.sections(from: [earlier, later])

        #expect(sections.count == 1)
        #expect(sections[0].sessions.map(\.id) == [later.id, earlier.id])
    }

    @Test("section title is a localized month + year string")
    func sectionTitleHumanReadable() throws {
        let fixture = try makeFixture()
        let session = try fixture.makeCompletedSession(programDayName: "Workout A", workoutDayID: "2026-05-12", startedAt: fixture.date(2026, 5, 12, 9))

        let sections = HistorySectionBuilder.sections(from: [session])

        #expect(sections.count == 1)
        #expect(sections[0].title.contains("2026"))
        #expect(sections[0].title.lowercased().contains("may"))
    }
}

@Suite("Progression.didExerciseSucceed")
struct ProgressionDidExerciseSucceedTests {
    @Test("returns false when no working sets exist")
    func emptyIsFailure() {
        #expect(Progression.didExerciseSucceed(workingSets: []) == false)
    }

    @Test("returns false when any working set is unlogged")
    func unloggedIsFailure() {
        let attempts: [WorkingSetAttempt] = [
            .init(targetReps: 5, actualReps: 5),
            .init(targetReps: 5, actualReps: nil),
            .init(targetReps: 5, actualReps: 5)
        ]
        #expect(Progression.didExerciseSucceed(workingSets: attempts) == false)
    }

    @Test("returns false when any logged working set is short")
    func shortIsFailure() {
        let attempts: [WorkingSetAttempt] = [
            .init(targetReps: 5, actualReps: 5),
            .init(targetReps: 5, actualReps: 4),
            .init(targetReps: 5, actualReps: 5)
        ]
        #expect(Progression.didExerciseSucceed(workingSets: attempts) == false)
    }

    @Test("returns true when every working set hits or exceeds target")
    func allHitIsSuccess() {
        let attempts: [WorkingSetAttempt] = [
            .init(targetReps: 5, actualReps: 5),
            .init(targetReps: 5, actualReps: 5),
            .init(targetReps: 5, actualReps: 6)
        ]
        #expect(Progression.didExerciseSucceed(workingSets: attempts) == true)
    }
}

@Suite("ExerciseLogSummary")
@MainActor
struct ExerciseLogSummaryTests {
    @Test("formats a successful exercise with shared weight as 'Squat 60kg 3x5 ✓'")
    func successSummary() throws {
        let fixture = try makeFixture()
        let session = try fixture.makeCompletedSession(programDayName: "Workout A", workoutDayID: "2026-05-12", startedAt: fixture.date(2026, 5, 12, 9))
        let squat = try #require(session.exerciseLogs.first(where: { $0.exerciseNameSnapshot == "Squat" }))
        try fixture.fillWorkingSets(in: squat, weights: [60, 60, 60], actualReps: [5, 5, 5])

        let summary = ExerciseLogSummary.make(from: squat)

        #expect(summary.name == "Squat")
        #expect(summary.weightDisplay == "60 kg")
        #expect(summary.didSucceed == true)
        #expect(summary.summary == "Squat · 60 kg · 3×5 ✓")
    }

    @Test("formats a partial exercise as 'Squat · 60 kg · 2/3 sets · last 3/5'")
    func partialSummary() throws {
        let fixture = try makeFixture()
        let session = try fixture.makeCompletedSession(programDayName: "Workout A", workoutDayID: "2026-05-12", startedAt: fixture.date(2026, 5, 12, 9))
        let squat = try #require(session.exerciseLogs.first(where: { $0.exerciseNameSnapshot == "Squat" }))
        try fixture.fillWorkingSets(in: squat, weights: [60, 60, 60], actualReps: [5, 5, 3])

        let summary = ExerciseLogSummary.make(from: squat)

        #expect(summary.didSucceed == false)
        #expect(summary.summary == "Squat · 60 kg · 2/3 sets · last 3/5")
    }

    @Test("formats unlogged exercise as 'Squat · 60 kg · 0/3 logged'")
    func unloggedSummary() throws {
        let fixture = try makeFixture()
        let session = try fixture.makeCompletedSession(programDayName: "Workout A", workoutDayID: "2026-05-12", startedAt: fixture.date(2026, 5, 12, 9))
        let squat = try #require(session.exerciseLogs.first(where: { $0.exerciseNameSnapshot == "Squat" }))
        try fixture.fillWorkingSets(in: squat, weights: [60, 60, 60], actualReps: [nil, nil, nil])

        let summary = ExerciseLogSummary.make(from: squat)

        #expect(summary.didSucceed == false)
        #expect(summary.summary == "Squat · 60 kg · 0/3 logged")
    }

    @Test("formats mixed weights as 'Squat · mixed · 3/3 sets ✓'")
    func mixedWeightsSummary() throws {
        let fixture = try makeFixture()
        let session = try fixture.makeCompletedSession(programDayName: "Workout A", workoutDayID: "2026-05-12", startedAt: fixture.date(2026, 5, 12, 9))
        let squat = try #require(session.exerciseLogs.first(where: { $0.exerciseNameSnapshot == "Squat" }))
        try fixture.fillWorkingSets(in: squat, weights: [60, 60, 62.5], actualReps: [5, 5, 5])

        let summary = ExerciseLogSummary.make(from: squat)

        #expect(summary.weightDisplay == "mixed")
        #expect(summary.didSucceed == true)
        #expect(summary.summary == "Squat · mixed · 3×5 ✓")
    }

    @Test("formats decimal weights without trailing zeros (e.g. 62.5 kg)")
    func decimalWeightFormat() throws {
        let fixture = try makeFixture()
        let session = try fixture.makeCompletedSession(programDayName: "Workout A", workoutDayID: "2026-05-12", startedAt: fixture.date(2026, 5, 12, 9))
        let squat = try #require(session.exerciseLogs.first(where: { $0.exerciseNameSnapshot == "Squat" }))
        try fixture.fillWorkingSets(in: squat, weights: [62.5, 62.5, 62.5], actualReps: [5, 5, 5])

        let summary = ExerciseLogSummary.make(from: squat)

        #expect(summary.weightDisplay == "62.5 kg")
    }
}

// MARK: - Fixture

@MainActor
private func makeFixture() throws -> HistoryFixture {
    let container = try makeInMemoryContainer()
    let context = ModelContext(container)
    try LiftSeeder().seedIfNeeded(in: context)
    let days = try fetchAll(ProgramDay.self, from: context, sortBy: [SortDescriptor(\.orderInRotation)])
    return HistoryFixture(context: context, days: days)
}

@MainActor
private struct HistoryFixture {
    let context: ModelContext
    let days: [ProgramDay]

    func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    func makeCompletedSession(programDayName: String, workoutDayID: String, startedAt: Date) throws -> WorkoutSession {
        guard let day = days.first(where: { $0.name == programDayName }) else {
            Issue.record("Missing program day \(programDayName)")
            fatalError("Missing program day")
        }
        let session = WorkoutSession(
            workoutDayID: workoutDayID,
            timeZoneIdentifierAtStart: TimeZone(secondsFromGMT: 0)?.identifier ?? "UTC",
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(45 * 60),
            programDay: day,
            status: .completed
        )
        context.insert(session)

        for slot in day.orderedSlots {
            guard let progression = slot.exerciseProgression, let exercise = progression.exercise else { continue }
            let log = ExerciseLog(
                session: session,
                exercise: exercise,
                exerciseNameSnapshot: exercise.name,
                targetWeightKgSnapshot: progression.currentWeightKg,
                targetSetsSnapshot: progression.workingSets,
                targetRepsSnapshot: progression.workingReps,
                sets: []
            )
            context.insert(log)
            session.exerciseLogs.append(log)

            for index in 0..<progression.workingSets {
                let set = LoggedSet(
                    log: log,
                    kind: .working,
                    index: index,
                    weightKg: progression.currentWeightKg,
                    targetReps: progression.workingReps,
                    actualReps: progression.workingReps,
                    completedAt: startedAt.addingTimeInterval(TimeInterval(index * 60))
                )
                context.insert(set)
                log.sets.append(set)
            }
        }
        try context.save()
        return session
    }

    func fillWorkingSets(in log: ExerciseLog, weights: [Double], actualReps: [Int?]) throws {
        let working = log.sets.filter { $0.kind == .working }.sorted { $0.index < $1.index }
        for (index, set) in working.enumerated() {
            if index < weights.count { set.weightKg = weights[index] }
            if index < actualReps.count {
                set.actualReps = actualReps[index]
                set.completedAt = actualReps[index] == nil ? nil : log.session?.startedAt
            }
        }
        try context.save()
    }
}
