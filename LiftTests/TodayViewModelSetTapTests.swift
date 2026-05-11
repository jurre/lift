import Foundation
import SwiftData
import Testing
@testable import Lift

@Suite("TodayViewModel set logging")
@MainActor
struct TodayViewModelSetTapTests {
    @Test("tapSet creates a draft, persists reps, and locks the day picker")
    func tapSetCreatesDraftAndLocksSelection() throws {
        let fixture = try makeFixture()
        let workingSet = try #require(fixture.viewModel.draftPlan?.exerciseLogs.first?.sets.first(where: { $0.kind == .working }))

        try fixture.viewModel.tapSet(workingSet.id)

        let service = try DraftSessionService(modelContext: fixture.context)
        let draft = try #require(service.currentDraft(now: fixture.now, calendar: fixture.calendar))
        let persistedSet = try #require(findLoggedSet(id: workingSet.id, in: draft))

        #expect(persistedSet.actualReps == persistedSet.targetReps)
        #expect(fixture.viewModel.isProgramDayLocked)
        #expect(fixture.viewModel.programDayLockHint == "Workout A — locked for today")
    }

    @Test("working set taps decrement reps until cleared")
    func repeatedTapsDecrementWorkingSet() throws {
        let fixture = try makeFixture()
        let workingSetID = try #require(
            fixture.viewModel.draftPlan?.exerciseLogs.first?.sets.first(where: { $0.kind == .working })
        ).id

        let expected: [Int?] = [5, 4, 3, 2, 1, 0, nil]
        for reps in expected {
            try fixture.viewModel.tapSet(workingSetID)
            let persisted = try #require(try fetchLoggedSet(id: workingSetID, from: fixture.context))
            #expect(persisted.actualReps == reps)
        }
    }

    @Test("warmup set taps only toggle between pending and target reps")
    func warmupTapToggles() throws {
        let fixture = try makeFixture()
        let warmupSetID = try #require(
            fixture.viewModel.draftPlan?.exerciseLogs.first?.sets.first(where: { $0.kind == .warmup })
        ).id

        try fixture.viewModel.tapSet(warmupSetID)
        #expect(try #require(try fetchLoggedSet(id: warmupSetID, from: fixture.context)).actualReps == 5)

        try fixture.viewModel.tapSet(warmupSetID)
        #expect(try #require(try fetchLoggedSet(id: warmupSetID, from: fixture.context)).actualReps == nil)
    }

    @Test("editWeight updates pending sets, preserves completed sets, and refreshes pending warmups")
    func editWeightUpdatesPendingSetsAndWarmups() throws {
        let fixture = try makeFixture(squatWeight: 65)
        let firstExerciseLog = try #require(fixture.viewModel.draftPlan?.exerciseLogs.first)
        let completedWorkingID = try #require(firstExerciseLog.sets.first(where: { $0.kind == .working })).id
        let completedWarmupID = try #require(firstExerciseLog.sets.first(where: { $0.kind == .warmup })).id

        try fixture.viewModel.tapSet(completedWorkingID)
        try fixture.viewModel.tapSet(completedWarmupID)
        try fixture.viewModel.editWeight(forExerciseLog: firstExerciseLog.id, newWeightKg: 67.3)

        let exerciseLog = try #require(try fetchExerciseLog(id: firstExerciseLog.id, from: fixture.context))
        #expect(exerciseLog.targetWeightKgSnapshot == 67.5)

        let completedWorking = try #require(try fetchLoggedSet(id: completedWorkingID, from: fixture.context))
        #expect(completedWorking.weightKg == 65)

        let pendingWorkingWeights = exerciseLog.sets
            .filter { $0.kind == .working && $0.id != completedWorkingID }
            .map(\.weightKg)
        #expect(pendingWorkingWeights == [67.5, 67.5])

        let completedWarmup = try #require(try fetchLoggedSet(id: completedWarmupID, from: fixture.context))
        #expect(completedWarmup.weightKg == 20)

        let expectedWarmups = WarmupCalculator(weightLoading: fixture.weightLoading).warmupSets(forWorkingWeightKg: 67.5)
            .map(\.weightKg)
        let pendingWarmupWeights = exerciseLog.sets
            .filter { $0.kind == .warmup && $0.id != completedWarmupID && $0.actualReps == nil }
            .sorted { $0.index < $1.index }
            .map(\.weightKg)
        #expect(pendingWarmupWeights == Array(expectedWarmups.dropFirst()))
    }

    @Test("deleteSet removes the logged set and persists the change")
    func deleteSetRemovesLoggedSet() throws {
        let fixture = try makeFixture()
        let setID = try #require(fixture.viewModel.draftPlan?.exerciseLogs.first?.sets.last).id

        try fixture.viewModel.deleteSet(setID)

        #expect(try fetchLoggedSet(id: setID, from: fixture.context) == nil)
    }

    private func makeFixture(squatWeight: Double = 20) throws -> TodayFixture {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try LiftSeeder().seedIfNeeded(in: context)
        try setProgressionWeight(forExerciseKey: "squat", to: squatWeight, in: context)

        let viewModel = TodayViewModel(
            modelContext: context,
            now: fixtureDate(),
            timeZone: .utc
        )
        viewModel.load()

        let users = try context.fetch(FetchDescriptor<User>())
        let user = try #require(users.first)
        return TodayFixture(
            context: context,
            viewModel: viewModel,
            now: fixtureDate(),
            calendar: utcCalendar(),
            weightLoading: WeightLoading(barWeightKg: user.barWeightKg, inventory: user.orderedPlates)
        )
    }

    private func setProgressionWeight(forExerciseKey exerciseKey: String, to weight: Double, in context: ModelContext) throws {
        let progressions = try context.fetch(FetchDescriptor<ExerciseProgression>())
        let progression = try #require(progressions.first(where: { $0.exercise?.key == exerciseKey }))
        progression.currentWeightKg = weight
        try context.save()
    }

    private func findLoggedSet(id: UUID, in session: WorkoutSession) -> LoggedSet? {
        session.exerciseLogs
            .flatMap(\.sets)
            .first(where: { $0.id == id })
    }

    private func fetchLoggedSet(id: UUID, from context: ModelContext) throws -> LoggedSet? {
        try context.fetch(FetchDescriptor<LoggedSet>()).first(where: { $0.id == id })
    }

    private func fetchExerciseLog(id: UUID, from context: ModelContext) throws -> ExerciseLog? {
        try context.fetch(FetchDescriptor<ExerciseLog>()).first(where: { $0.id == id })
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

private struct TodayFixture {
    let context: ModelContext
    let viewModel: TodayViewModel
    let now: Date
    let calendar: Calendar
    let weightLoading: WeightLoading
}

private extension TimeZone {
    static let utc = TimeZone(secondsFromGMT: 0)!
}
