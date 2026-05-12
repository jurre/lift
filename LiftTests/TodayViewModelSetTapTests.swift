import Foundation
import SwiftData
import Testing
@testable import Lift

@Suite("TodayViewModel set logging")
@MainActor
struct TodayViewModelSetTapTests {
    @Test("tapSet creates a draft, persists reps, and locks the day picker")
    func tapSetCreatesDraftAndLocksSelection() async throws {
        let fixture = try makeFixture()
        let workingSet = try #require(fixture.viewModel.draftPlan?.exerciseLogs.first?.sets.first(where: { $0.kind == .working }))

        try await fixture.viewModel.tapSet(workingSet.id)

        let service = try DraftSessionService(modelContext: fixture.context)
        let draft = try #require(service.currentDraft(now: fixture.now, calendar: fixture.calendar))
        let persistedSet = try #require(findLoggedSet(id: workingSet.id, in: draft))

        #expect(persistedSet.actualReps == persistedSet.targetReps)
        #expect(fixture.viewModel.isProgramDayLocked)
        #expect(fixture.viewModel.programDayLockHint == "Workout A — in progress. Tap to switch.")
    }

    @Test("working set taps decrement reps until cleared")
    func repeatedTapsDecrementWorkingSet() async throws {
        let fixture = try makeFixture()
        let workingSetID = try #require(
            fixture.viewModel.draftPlan?.exerciseLogs.first?.sets.first(where: { $0.kind == .working })
        ).id

        let expected: [Int?] = [5, 4, 3, 2, 1, 0, nil]
        for reps in expected {
            try await fixture.viewModel.tapSet(workingSetID)
            let persisted = try #require(try fetchLoggedSet(id: workingSetID, from: fixture.context))
            #expect(persisted.actualReps == reps)
        }
    }

    @Test("warmup set taps only toggle between pending and target reps")
    func warmupTapToggles() async throws {
        let fixture = try makeFixture()
        let warmupSetID = try #require(
            fixture.viewModel.draftPlan?.exerciseLogs.first?.sets.first(where: { $0.kind == .warmup })
        ).id

        try await fixture.viewModel.tapSet(warmupSetID)
        #expect(try #require(try fetchLoggedSet(id: warmupSetID, from: fixture.context)).actualReps == 5)

        try await fixture.viewModel.tapSet(warmupSetID)
        #expect(try #require(try fetchLoggedSet(id: warmupSetID, from: fixture.context)).actualReps == nil)
    }

    @Test("completing a working set starts rest using the exercise progression duration")
    func workingSetCompletionStartsRest() async throws {
        let restTimer = RecordingRestTimer()
        let fixture = try makeFixture(restTimer: restTimer)
        let workingSet = try #require(
            fixture.viewModel.draftPlan?.exerciseLogs.first?.sets.first(where: { $0.kind == .working })
        )
        let exerciseLog = try #require(fixture.viewModel.draftPlan?.exerciseLogs.first)

        try await fixture.viewModel.tapSet(workingSet.id)

        let request = try #require(restTimer.startedRests.first)
        #expect(request.exerciseLogID == exerciseLog.id)
        #expect(request.setID == workingSet.id)
        #expect(request.durationSeconds == 180)
    }

    @Test("rest timer starts from the current clock, not the time the view model was created")
    func restStartsFromCurrentClock() async throws {
        let restTimer = RecordingRestTimer()
        let testClock = TestClock(fixtureDate())
        let fixture = try makeFixture(restTimer: restTimer, clock: testClock.now)
        let workingSet = try #require(
            fixture.viewModel.draftPlan?.exerciseLogs.first?.sets.first(where: { $0.kind == .working })
        )

        // Simulate the user sitting on the Today screen for ten minutes
        // before tapping their first working set.
        let tapTime = fixtureDate().addingTimeInterval(600)
        testClock.current = tapTime

        try await fixture.viewModel.tapSet(workingSet.id)

        let request = try #require(restTimer.startedRests.first)
        #expect(
            request.now == tapTime,
            "rest timer should start at the moment of tap, not at view-model init"
        )

        let persisted = try #require(try fetchLoggedSet(id: workingSet.id, from: fixture.context))
        #expect(persisted.completedAt == tapTime)
    }

    @Test("intermediate warmup completions do not start a rest timer")
    func intermediateWarmupsDoNotStartRest() async throws {
        let restTimer = RecordingRestTimer()
        let fixture = try makeFixture(restTimer: restTimer)
        let exerciseLog = try #require(fixture.viewModel.draftPlan?.exerciseLogs.first)

        // Ensure there are at least two warmups so we can complete an intermediate one
        // without finishing the warmup phase.
        while (fixture.viewModel.draftPlan?.exerciseLogs.first?.sets.filter { $0.kind == .warmup }.count ?? 0) < 2 {
            try fixture.viewModel.addWarmupSet(toExerciseLogID: exerciseLog.id)
        }

        let warmupSets = try #require(
            fixture.viewModel.draftPlan?.exerciseLogs.first?.sets
                .filter { $0.kind == .warmup }
                .sorted { $0.index < $1.index }
        )
        try #require(warmupSets.count >= 2)

        try await fixture.viewModel.tapSet(warmupSets[0].id)

        #expect(restTimer.startedRests.isEmpty)
    }

    @Test("completing the final warmup starts a rest timer before the working sets")
    func lastWarmupCompletionStartsRest() async throws {
        let restTimer = RecordingRestTimer()
        let fixture = try makeFixture(restTimer: restTimer)
        let warmupSets = try #require(
            fixture.viewModel.draftPlan?.exerciseLogs.first?.sets
                .filter { $0.kind == .warmup }
                .sorted { $0.index < $1.index }
        )
        try #require(!warmupSets.isEmpty, "fixture should have warmups to complete")
        let exerciseLog = try #require(fixture.viewModel.draftPlan?.exerciseLogs.first)

        for warmup in warmupSets {
            try await fixture.viewModel.tapSet(warmup.id)
        }

        let request = try #require(restTimer.startedRests.last)
        #expect(request.exerciseLogID == exerciseLog.id)
        #expect(request.setID == warmupSets.last?.id)
        #expect(request.durationSeconds == 180)
        #expect(restTimer.startedRests.count == 1, "only the final warmup should kick off a rest")
    }

    @Test("editWeight updates pending sets, preserves completed sets, and refreshes pending warmups")
    func editWeightUpdatesPendingSetsAndWarmups() async throws {
        let fixture = try makeFixture(squatWeight: 65)
        let firstExerciseLog = try #require(fixture.viewModel.draftPlan?.exerciseLogs.first)
        let completedWorkingID = try #require(firstExerciseLog.sets.first(where: { $0.kind == .working })).id
        let completedWarmupID = try #require(firstExerciseLog.sets.first(where: { $0.kind == .warmup })).id

        try await fixture.viewModel.tapSet(completedWorkingID)
        try await fixture.viewModel.tapSet(completedWarmupID)
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

    @Test("addWarmupSet appends a bar warmup at 5 reps when no warmups exist")
    func addWarmupSetAddsBarWhenEmpty() throws {
        let fixture = try makeFixture(squatWeight: 60)
        let firstExerciseLog = try #require(fixture.viewModel.draftPlan?.exerciseLogs.first)
        let warmupSetIDs = firstExerciseLog.sets.filter { $0.kind == .warmup }.map(\.id)
        for warmupID in warmupSetIDs {
            try fixture.viewModel.deleteSet(warmupID)
        }

        try fixture.viewModel.addWarmupSet(toExerciseLogID: firstExerciseLog.id)

        let exerciseLog = try #require(try fetchExerciseLog(id: firstExerciseLog.id, from: fixture.context))
        let warmups = exerciseLog.sets.filter { $0.kind == .warmup }.sorted { $0.index < $1.index }
        try #require(warmups.count == 1)
        #expect(warmups[0].weightKg == 20)
        #expect(warmups[0].targetReps == 5)
        #expect(warmups[0].index == 0)
        #expect(warmups[0].actualReps == nil)
    }

    @Test("addWarmupSet appends the next loadable above the last warmup at 3 reps")
    func addWarmupSetAddsNextLoadable() throws {
        let fixture = try makeFixture(squatWeight: 60)
        let firstExerciseLog = try #require(fixture.viewModel.draftPlan?.exerciseLogs.first)
        let priorWarmupCount = firstExerciseLog.sets.filter { $0.kind == .warmup }.count
        let priorLastWarmup = try #require(firstExerciseLog.sets.filter { $0.kind == .warmup }.sorted { $0.index < $1.index }.last)
        let priorLastWeight = priorLastWarmup.weightKg

        try fixture.viewModel.addWarmupSet(toExerciseLogID: firstExerciseLog.id)

        let exerciseLog = try #require(try fetchExerciseLog(id: firstExerciseLog.id, from: fixture.context))
        let warmups = exerciseLog.sets.filter { $0.kind == .warmup }.sorted { $0.index < $1.index }
        #expect(warmups.count == priorWarmupCount + 1)

        let expectedWeight = fixture.weightLoading.nextHigherLoadable(priorLastWeight) ?? priorLastWeight
        let appended = try #require(warmups.last)
        #expect(appended.weightKg == expectedWeight)
        #expect(appended.weightKg < 60)
        #expect(appended.targetReps == 3)
        #expect(appended.index == warmups.count - 1)
    }

    @Test("addWarmupSet duplicates the last warmup when no loadable fits before working weight")
    func addWarmupSetDuplicatesLastWarmupWhenAtCeiling() throws {
        let fixture = try makeFixture(squatWeight: 22.5)
        let firstExerciseLog = try #require(fixture.viewModel.draftPlan?.exerciseLogs.first)
        let priorWarmups = firstExerciseLog.sets.filter { $0.kind == .warmup }.sorted { $0.index < $1.index }
        let priorLast = try #require(priorWarmups.last)
        let priorWeight = priorLast.weightKg

        try fixture.viewModel.addWarmupSet(toExerciseLogID: firstExerciseLog.id)

        let exerciseLog = try #require(try fetchExerciseLog(id: firstExerciseLog.id, from: fixture.context))
        let warmups = exerciseLog.sets.filter { $0.kind == .warmup }.sorted { $0.index < $1.index }
        #expect(warmups.count == priorWarmups.count + 1)
        let appended = try #require(warmups.last)
        #expect(appended.weightKg == priorWeight)
        #expect(appended.targetReps == 3)
    }

    @Test("addWarmupSet generates a unique stable identifier")
    func addWarmupSetGeneratesUniqueID() throws {
        let fixture = try makeFixture(squatWeight: 60)
        let firstExerciseLog = try #require(fixture.viewModel.draftPlan?.exerciseLogs.first)
        let priorIDs = Set(firstExerciseLog.sets.map(\.id))

        try fixture.viewModel.addWarmupSet(toExerciseLogID: firstExerciseLog.id)

        let exerciseLog = try #require(try fetchExerciseLog(id: firstExerciseLog.id, from: fixture.context))
        let newIDs = exerciseLog.sets.map(\.id).filter { !priorIDs.contains($0) }
        #expect(newIDs.count == 1)
    }

    @Test("editReps updates a set's targetReps and persists the change")
    func editRepsUpdatesTargetReps() throws {
        let fixture = try makeFixture(squatWeight: 60)
        let warmupSet = try #require(fixture.viewModel.draftPlan?.exerciseLogs.first?.sets.first(where: { $0.kind == .warmup }))

        try fixture.viewModel.editReps(forSet: warmupSet.id, targetReps: 8)

        let persisted = try #require(try fetchLoggedSet(id: warmupSet.id, from: fixture.context))
        #expect(persisted.targetReps == 8)
    }

    @Test("editReps clamps target reps to at least one")
    func editRepsClampsToOne() throws {
        let fixture = try makeFixture(squatWeight: 60)
        let setID = try #require(fixture.viewModel.draftPlan?.exerciseLogs.first?.sets.first).id

        try fixture.viewModel.editReps(forSet: setID, targetReps: 0)

        let persisted = try #require(try fetchLoggedSet(id: setID, from: fixture.context))
        #expect(persisted.targetReps == 1)
    }

    @Test("deleteSet removes a warmup and reindexes the remaining warmups")
    func deleteSetReindexesWarmups() throws {
        let fixture = try makeFixture(squatWeight: 60)
        let firstExerciseLog = try #require(fixture.viewModel.draftPlan?.exerciseLogs.first)
        let warmups = firstExerciseLog.sets.filter { $0.kind == .warmup }.sorted { $0.index < $1.index }
        try #require(warmups.count >= 2)
        let secondWarmupID = warmups[1].id

        try fixture.viewModel.deleteSet(secondWarmupID)

        let exerciseLog = try #require(try fetchExerciseLog(id: firstExerciseLog.id, from: fixture.context))
        let remaining = exerciseLog.sets.filter { $0.kind == .warmup }.sorted { $0.index < $1.index }
        #expect(remaining.count == warmups.count - 1)
        for (index, set) in remaining.enumerated() {
            #expect(set.index == index)
        }
    }

    private func makeFixture(
        squatWeight: Double = 20,
        restTimer: some RestTimerStarting = RecordingRestTimer(),
        clock: @escaping () -> Date = { Date(timeIntervalSince1970: 1_735_689_600) }
    ) throws -> TodayFixture {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try LiftSeeder().seedIfNeeded(in: context)
        try setProgressionWeight(forExerciseKey: "squat", to: squatWeight, in: context)

        let viewModel = TodayViewModel(
            modelContext: context,
            clock: clock,
            timeZone: .utc,
            restTimer: restTimer
        )
        viewModel.load()

        let users = try context.fetch(FetchDescriptor<User>())
        let user = try #require(users.first)
        return TodayFixture(
            context: context,
            viewModel: viewModel,
            now: clock(),
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

@MainActor
private final class RecordingRestTimer: RestTimerStarting {
    struct StartRequest: Equatable, Sendable {
        let exerciseLogID: UUID
        let exerciseName: String
        let setID: UUID
        let durationSeconds: Int
        let now: Date
    }

    private(set) var startedRests: [StartRequest] = []

    func start(exerciseLogID: UUID, exerciseName: String, setID: UUID, durationSeconds: Int, now: Date) async {
        startedRests.append(
            StartRequest(
                exerciseLogID: exerciseLogID,
                exerciseName: exerciseName,
                setID: setID,
                durationSeconds: durationSeconds,
                now: now
            )
        )
    }
}

@MainActor
private final class TestClock {
    var current: Date
    init(_ current: Date) { self.current = current }
    func now() -> Date { current }
}

private extension TimeZone {
    static let utc = TimeZone(secondsFromGMT: 0)!
}
