import Foundation
import SwiftData
import Testing
@testable import Lift

@Suite("HistoryViewModel")
@MainActor
struct HistoryViewModelTests {
    @Test("load groups completed sessions by month, newest first, drafts excluded")
    func loadGroupsAndExcludesDrafts() throws {
        let fixture = try makeFixture()
        _ = try fixture.makeSession(programDayName: "Workout A", workoutDayID: "2026-05-12", startedAt: fixture.date(2026, 5, 12, 9), status: .completed)
        _ = try fixture.makeSession(programDayName: "Workout B", workoutDayID: "2026-05-14", startedAt: fixture.date(2026, 5, 14, 9), status: .completed)
        _ = try fixture.makeSession(programDayName: "Workout A", workoutDayID: "2026-04-30", startedAt: fixture.date(2026, 4, 30, 9), status: .endedNoProgression)
        let draft = try fixture.makeSession(programDayName: "Workout B", workoutDayID: "2026-05-15", startedAt: fixture.date(2026, 5, 15, 9), status: .draft)

        let viewModel = HistoryViewModel(modelContext: fixture.context)
        viewModel.load()

        #expect(viewModel.sections.count == 2)
        #expect(viewModel.sections[0].monthKey == "2026-05")
        #expect(viewModel.sections[0].sessions.count == 2)
        #expect(viewModel.sections[1].monthKey == "2026-04")
        let allIDs = viewModel.sections.flatMap { $0.sessions }.map { $0.id }
        #expect(allIDs.contains(draft.id) == false)
    }

    @Test("includes abandoned and endedNoProgression sessions")
    func includesNonProgressionSessions() throws {
        let fixture = try makeFixture()
        let abandoned = try fixture.makeSession(programDayName: "Workout A", workoutDayID: "2026-05-10", startedAt: fixture.date(2026, 5, 10, 9), status: .abandoned)
        let endedNoProgression = try fixture.makeSession(programDayName: "Workout B", workoutDayID: "2026-05-11", startedAt: fixture.date(2026, 5, 11, 9), status: .endedNoProgression)

        let viewModel = HistoryViewModel(modelContext: fixture.context)
        viewModel.load()

        let allSessions = viewModel.sections.flatMap { $0.sessions }
        let actualIDs = allSessions.map { $0.id }
        let expectedIDs: Set<UUID> = [abandoned.id, endedNoProgression.id]
        #expect(Set(actualIDs) == expectedIDs)
    }

    @Test("editActualReps that flips success to failure reports flipped=true")
    func editActualRepsReportsFlipToFailure() throws {
        let fixture = try makeFixture()
        let session = try fixture.makeSession(programDayName: "Workout A", workoutDayID: "2026-05-12", startedAt: fixture.date(2026, 5, 12, 9), status: .completed)
        let squat = try #require(session.exerciseLogs.first(where: { $0.exerciseNameSnapshot == "Squat" }))
        try fixture.fillWorking(in: squat, weights: [60, 60, 60], actualReps: [5, 5, 5])

        let viewModel = HistoryViewModel(modelContext: fixture.context)
        viewModel.load()
        let lastSet = try #require(squat.sets.filter { $0.kind == .working }.sorted { $0.index < $1.index }.last)

        let result = try viewModel.editActualReps(setID: lastSet.id, actualReps: 3)

        #expect(result.flippedSuccessForExercise == true)
        let refreshed = try #require(try fetchLoggedSet(id: lastSet.id, from: fixture.context))
        #expect(refreshed.actualReps == 3)
    }

    @Test("editActualReps that keeps success state reports flipped=false")
    func editActualRepsNoFlip() throws {
        let fixture = try makeFixture()
        let session = try fixture.makeSession(programDayName: "Workout A", workoutDayID: "2026-05-12", startedAt: fixture.date(2026, 5, 12, 9), status: .completed)
        let squat = try #require(session.exerciseLogs.first(where: { $0.exerciseNameSnapshot == "Squat" }))
        try fixture.fillWorking(in: squat, weights: [60, 60, 60], actualReps: [5, 5, 4])

        let viewModel = HistoryViewModel(modelContext: fixture.context)
        viewModel.load()
        let lastSet = try #require(squat.sets.filter { $0.kind == .working }.sorted { $0.index < $1.index }.last)

        let result = try viewModel.editActualReps(setID: lastSet.id, actualReps: 3)

        #expect(result.flippedSuccessForExercise == false)
    }

    @Test("editActualReps clamps to zero or above and persists nil when explicitly cleared")
    func editActualRepsClampingAndClear() throws {
        let fixture = try makeFixture()
        let session = try fixture.makeSession(programDayName: "Workout A", workoutDayID: "2026-05-12", startedAt: fixture.date(2026, 5, 12, 9), status: .completed)
        let squat = try #require(session.exerciseLogs.first(where: { $0.exerciseNameSnapshot == "Squat" }))
        try fixture.fillWorking(in: squat, weights: [60, 60, 60], actualReps: [5, 5, 5])

        let viewModel = HistoryViewModel(modelContext: fixture.context)
        viewModel.load()
        let lastSet = try #require(squat.sets.filter { $0.kind == .working }.sorted { $0.index < $1.index }.last)

        let clamped = try viewModel.editActualReps(setID: lastSet.id, actualReps: -3)
        #expect(clamped.flippedSuccessForExercise == true)
        #expect(try #require(try fetchLoggedSet(id: lastSet.id, from: fixture.context)).actualReps == 0)

        let cleared = try viewModel.editActualReps(setID: lastSet.id, actualReps: nil)
        #expect(cleared.flippedSuccessForExercise == false)
        #expect(try #require(try fetchLoggedSet(id: lastSet.id, from: fixture.context)).actualReps == nil)
    }

    @Test("editWeight snaps to nearest loadable and persists")
    func editWeightSnapsToLoadable() throws {
        let fixture = try makeFixture()
        let session = try fixture.makeSession(programDayName: "Workout A", workoutDayID: "2026-05-12", startedAt: fixture.date(2026, 5, 12, 9), status: .completed)
        let squat = try #require(session.exerciseLogs.first(where: { $0.exerciseNameSnapshot == "Squat" }))
        try fixture.fillWorking(in: squat, weights: [60, 60, 60], actualReps: [5, 5, 5])

        let viewModel = HistoryViewModel(modelContext: fixture.context)
        viewModel.load()
        let firstSet = try #require(squat.sets.filter { $0.kind == .working }.sorted { $0.index < $1.index }.first)

        _ = try viewModel.editWeight(setID: firstSet.id, weightKg: 62)

        let refreshed = try #require(try fetchLoggedSet(id: firstSet.id, from: fixture.context))
        #expect(refreshed.weightKg == 62.5)
    }

    @Test("editWeight on a warmup never reports a flip")
    func editWarmupWeightNeverFlips() throws {
        let fixture = try makeFixture()
        let session = try fixture.makeSession(programDayName: "Workout A", workoutDayID: "2026-05-12", startedAt: fixture.date(2026, 5, 12, 9), status: .completed)
        let squat = try #require(session.exerciseLogs.first(where: { $0.exerciseNameSnapshot == "Squat" }))
        try fixture.addWarmup(to: squat, weightKg: 20, targetReps: 5, actualReps: 5)
        try fixture.fillWorking(in: squat, weights: [60, 60, 60], actualReps: [5, 5, 4])

        let viewModel = HistoryViewModel(modelContext: fixture.context)
        viewModel.load()
        let warmup = try #require(squat.sets.first(where: { $0.kind == .warmup }))

        let result = try viewModel.editWeight(setID: warmup.id, weightKg: 17)

        #expect(result.flippedSuccessForExercise == false)
    }

    @Test("edit refreshes the sections so the UI sees the updated set")
    func editRefreshesSections() throws {
        let fixture = try makeFixture()
        let session = try fixture.makeSession(programDayName: "Workout A", workoutDayID: "2026-05-12", startedAt: fixture.date(2026, 5, 12, 9), status: .completed)
        let squat = try #require(session.exerciseLogs.first(where: { $0.exerciseNameSnapshot == "Squat" }))
        try fixture.fillWorking(in: squat, weights: [60, 60, 60], actualReps: [5, 5, 5])

        let viewModel = HistoryViewModel(modelContext: fixture.context)
        viewModel.load()
        let lastSet = try #require(squat.sets.filter { $0.kind == .working }.sorted { $0.index < $1.index }.last)

        _ = try viewModel.editActualReps(setID: lastSet.id, actualReps: 3)

        let firstSession = try #require(viewModel.sections.first?.sessions.first)
        let refreshedSquat = try #require(firstSession.exerciseLogs.first(where: { $0.exerciseNameSnapshot == "Squat" }))
        let refreshedLast = try #require(refreshedSquat.sets.filter { $0.kind == .working }.sorted { $0.index < $1.index }.last)
        #expect(refreshedLast.actualReps == 3)
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
private func fetchLoggedSet(id: UUID, from context: ModelContext) throws -> LoggedSet? {
    try context.fetch(FetchDescriptor<LoggedSet>()).first(where: { $0.id == id })
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

    func makeSession(programDayName: String, workoutDayID: String, startedAt: Date, status: SessionStatus) throws -> WorkoutSession {
        guard let day = days.first(where: { $0.name == programDayName }) else {
            Issue.record("Missing program day \(programDayName)")
            fatalError("Missing program day")
        }
        let session = WorkoutSession(
            workoutDayID: workoutDayID,
            timeZoneIdentifierAtStart: TimeZone(secondsFromGMT: 0)?.identifier ?? "UTC",
            startedAt: startedAt,
            endedAt: status == .draft ? nil : startedAt.addingTimeInterval(45 * 60),
            programDay: day,
            status: status
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
                    actualReps: nil,
                    completedAt: nil
                )
                context.insert(set)
                log.sets.append(set)
            }
        }
        try context.save()
        return session
    }

    func fillWorking(in log: ExerciseLog, weights: [Double], actualReps: [Int?]) throws {
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

    func addWarmup(to log: ExerciseLog, weightKg: Double, targetReps: Int, actualReps: Int?) throws {
        let nextIndex = (log.sets.filter { $0.kind == .warmup }.map(\.index).max() ?? -1) + 1
        let set = LoggedSet(
            log: log,
            kind: .warmup,
            index: nextIndex,
            weightKg: weightKg,
            targetReps: targetReps,
            actualReps: actualReps,
            completedAt: actualReps == nil ? nil : log.session?.startedAt
        )
        context.insert(set)
        log.sets.append(set)
        try context.save()
    }
}
