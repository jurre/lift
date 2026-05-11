import Foundation
import SwiftData
import Testing
@testable import Lift

@Suite("DraftSessionService finalize")
@MainActor
struct DraftSessionFinalizeTests {
    @Test("all working sets hit target applies progression and writes a success event")
    func finalizeAdvancesSuccessfulExercises() throws {
        let fixture = try makeFixture()
        let workoutA = try fixture.requireDay(named: "Workout A")
        fixture.setWeight(60, increment: 1.25, stalledCount: 0, forExerciseKey: "squat")

        let service = try fixture.makeService()
        let session = try service.createDraft(for: workoutA, now: fixture.start, calendar: fixture.calendar)
        fixture.fillWorkingSets(in: session, repsByExercise: ["Squat": [5, 5, 5], "Bench": [5, 5, 5], "Row": [5, 5, 5]])

        let result = try service.finalize(session, now: fixture.end)

        let squatProgression = try fixture.requireProgression(forExerciseKey: "squat")
        #expect(squatProgression.currentWeightKg == 62.5)
        #expect(squatProgression.stalledCount == 0)
        #expect(squatProgression.lastProgressionAt == fixture.end)
        #expect(session.status == .completed)
        #expect(session.endedAt == fixture.end)

        let events = try fixture.fetchProgressionEvents()
        let squatEvent = try #require(events.first(where: { $0.exerciseProgression?.exercise?.key == "squat" }))
        #expect(squatEvent.reason == .success)
        #expect(squatEvent.oldWeightKg == 60)
        #expect(squatEvent.newWeightKg == 62.5)
        #expect(squatEvent.session?.id == session.id)
        #expect(result.perExercise.first(where: { $0.exerciseName == "Squat" })?.didProgress == true)
        #expect(result.nextProgramDayName == "Workout B")
    }

    @Test("one short working set stalls without writing a progression event")
    func finalizeWithOneMissedSetStalls() throws {
        let fixture = try makeFixture()
        let workoutA = try fixture.requireDay(named: "Workout A")
        fixture.setWeight(60, increment: 1.25, stalledCount: 1, forExerciseKey: "squat")

        let service = try fixture.makeService()
        let session = try service.createDraft(for: workoutA, now: fixture.start, calendar: fixture.calendar)
        fixture.fillWorkingSets(in: session, repsByExercise: ["Squat": [5, 5, 4], "Bench": [5, 5, 5], "Row": [5, 5, 5]])

        let result = try service.finalize(session, now: fixture.end)

        let squatProgression = try fixture.requireProgression(forExerciseKey: "squat")
        #expect(squatProgression.currentWeightKg == 60)
        #expect(squatProgression.stalledCount == 2)
        #expect(session.status == .completed)
        #expect(try fixture.fetchProgressionEvents().contains(where: { $0.exerciseProgression?.exercise?.key == "squat" }) == false)
        let perExercise = try #require(result.perExercise.first(where: { $0.exerciseName == "Squat" }))
        #expect(perExercise.didProgress == false)
        #expect(perExercise.newWeightKg == 60)
        #expect(perExercise.stalledCount == 2)
    }

    @Test("all short working sets stall and still complete the session")
    func finalizeWithAllMissedSetsStalls() throws {
        let fixture = try makeFixture()
        let workoutA = try fixture.requireDay(named: "Workout A")
        fixture.setWeight(60, increment: 1.25, stalledCount: 0, forExerciseKey: "squat")

        let service = try fixture.makeService()
        let session = try service.createDraft(for: workoutA, now: fixture.start, calendar: fixture.calendar)
        fixture.fillWorkingSets(in: session, repsByExercise: ["Squat": [4, 4, 4], "Bench": [5, 5, 5], "Row": [5, 5, 5]])

        _ = try service.finalize(session, now: fixture.end)

        let squatProgression = try fixture.requireProgression(forExerciseKey: "squat")
        #expect(squatProgression.currentWeightKg == 60)
        #expect(squatProgression.stalledCount == 1)
        #expect(session.status == .completed)
        #expect(try fixture.fetchProgressionEvents().contains(where: { $0.exerciseProgression?.exercise?.key == "squat" }) == false)
    }

    @Test("pending working sets prevent finalize and leave the session unchanged")
    func finalizeRejectsPendingWorkingSets() throws {
        let fixture = try makeFixture()
        let workoutA = try fixture.requireDay(named: "Workout A")
        let service = try fixture.makeService()
        let session = try service.createDraft(for: workoutA, now: fixture.start, calendar: fixture.calendar)
        fixture.fillWorkingSets(in: session, repsByExercise: ["Squat": [5, 5, nil], "Bench": [5, 5, 5], "Row": [5, 5, 5]])

        do {
            _ = try service.finalize(session, now: fixture.end)
            Issue.record("Expected finalize to throw for pending working sets")
        } catch let error as DraftSessionError {
            #expect(error == .cannotFinalizeWithPendingSets(count: 1))
        }

        #expect(session.status == .draft)
        #expect(session.endedAt == nil)
        #expect(try fixture.fetchProgressionEvents().isEmpty)
    }

    @Test("shared exercises progress exactly once even if they appear twice in a session")
    func finalizeDeduplicatesExerciseProgressionByExerciseReference() throws {
        let fixture = try makeFixture()
        let workoutA = try fixture.requireDay(named: "Workout A")
        fixture.setWeight(60, increment: 1.25, stalledCount: 0, forExerciseKey: "squat")

        let service = try fixture.makeService()
        let session = try service.createDraft(for: workoutA, now: fixture.start, calendar: fixture.calendar)
        fixture.fillWorkingSets(in: session, repsByExercise: ["Squat": [5, 5, 5], "Bench": [5, 5, 5], "Row": [5, 5, 5]])
        try fixture.appendDuplicateExerciseLog(named: "Squat", to: session, reps: [5, 5, 5])

        let result = try service.finalize(session, now: fixture.end)

        let squatProgression = try fixture.requireProgression(forExerciseKey: "squat")
        #expect(squatProgression.currentWeightKg == 62.5)
        let squatEvents = try fixture.fetchProgressionEvents().filter { $0.exerciseProgression?.exercise?.key == "squat" }
        #expect(squatEvents.count == 1)
        #expect(result.perExercise.filter { $0.exerciseName == "Squat" }.count == 1)
    }

    @Test("success snaps unloadable increments up to the next loadable weight")
    func finalizeRoundsUnloadableSuccessUpToNextLoadable() throws {
        let fixture = try makeFixture(plateWeights: [25, 20, 15, 10, 5])
        let workoutA = try fixture.requireDay(named: "Workout A")
        fixture.setWeight(60, increment: 1.25, stalledCount: 0, forExerciseKey: "squat")

        let service = try fixture.makeService()
        let session = try service.createDraft(for: workoutA, now: fixture.start, calendar: fixture.calendar)
        fixture.fillWorkingSets(in: session, repsByExercise: ["Squat": [5, 5, 5], "Bench": [5, 5, 5], "Row": [5, 5, 5]])

        let result = try service.finalize(session, now: fixture.end)

        // Inventory has no plates below 5kg; pair-loaded steps are 10kg, so next loadable above 60 is 70.
        let squatProgression = try fixture.requireProgression(forExerciseKey: "squat")
        #expect(squatProgression.currentWeightKg == 70)
        #expect(squatProgression.lastProgressionAt == fixture.end)
        let squatEvent = try #require(
            try fixture.fetchProgressionEvents()
                .first(where: { $0.exerciseProgression?.exercise?.key == "squat" })
        )
        #expect(squatEvent.oldWeightKg == 60)
        #expect(squatEvent.newWeightKg == 70)
        let squat = try #require(result.perExercise.first(where: { $0.exerciseName == "Squat" }))
        #expect(squat.oldWeightKg == 60)
        #expect(squat.newWeightKg == 70)
        #expect(squat.didProgress == true)
        #expect(squat.stalledCount == 0)
    }

    @Test("regression: real-world default seed advances Squat from the bar even with the partner's small increment")
    func finalizeAdvancesFromBarWithSmallIncrementOnDefaultPlateInventory() throws {
        let fixture = try makeFixture()
        let workoutA = try fixture.requireDay(named: "Workout A")
        fixture.setWeight(20, increment: 1.25, stalledCount: 0, forExerciseKey: "squat")

        let service = try fixture.makeService()
        let session = try service.createDraft(for: workoutA, now: fixture.start, calendar: fixture.calendar)
        fixture.fillWorkingSets(in: session, repsByExercise: ["Squat": [5, 5, 5], "Bench": [5, 5, 5], "Row": [5, 5, 5]])

        let result = try service.finalize(session, now: fixture.end)

        let squatProgression = try fixture.requireProgression(forExerciseKey: "squat")
        #expect(squatProgression.currentWeightKg == 22.5)
        let squatEvent = try #require(
            try fixture.fetchProgressionEvents()
                .first(where: { $0.exerciseProgression?.exercise?.key == "squat" })
        )
        #expect(squatEvent.oldWeightKg == 20)
        #expect(squatEvent.newWeightKg == 22.5)
        let squat = try #require(result.perExercise.first(where: { $0.exerciseName == "Squat" }))
        #expect(squat.didProgress == true)
        #expect(squat.newWeightKg == 22.5)
    }

    @Test("endWithoutProgression leaves progressions and events untouched")
    func endWithoutProgressionDoesNotTouchProgressionsOrEvents() throws {
        let fixture = try makeFixture()
        let workoutA = try fixture.requireDay(named: "Workout A")
        fixture.setWeight(60, increment: 1.25, stalledCount: 2, forExerciseKey: "squat")

        let service = try fixture.makeService()
        let session = try service.createDraft(for: workoutA, now: fixture.start, calendar: fixture.calendar)
        fixture.fillWorkingSets(in: session, repsByExercise: ["Squat": [5, nil, nil], "Bench": [nil, nil, nil], "Row": [nil, nil, nil]])

        service.endWithoutProgression(session, now: fixture.end)

        let squatProgression = try fixture.requireProgression(forExerciseKey: "squat")
        #expect(session.status == .endedNoProgression)
        #expect(session.endedAt == fixture.end)
        #expect(squatProgression.currentWeightKg == 60)
        #expect(squatProgression.stalledCount == 2)
        #expect(squatProgression.lastProgressionAt == nil)
        #expect(try fixture.fetchProgressionEvents().isEmpty)
    }

    @Test("completed sessions advance the schedule and endedNoProgression sessions do not")
    func finalizeAndEndWithoutProgressionAffectScheduleDifferently() throws {
        let fixture = try makeFixture()
        let workoutA = try fixture.requireDay(named: "Workout A")
        let workoutB = try fixture.requireDay(named: "Workout B")
        let service = try fixture.makeService()

        let sessionA = try service.createDraft(for: workoutA, now: fixture.start, calendar: fixture.calendar)
        fixture.fillWorkingSets(in: sessionA, repsByExercise: ["Squat": [5, 5, 5], "Bench": [5, 5, 5], "Row": [5, 5, 5]])
        _ = try service.finalize(sessionA, now: fixture.end)
        #expect(WorkoutScheduler.nextProgramDay(from: fixture.days, mostRecentCompleted: sessionA)?.name == "Workout B")

        let sessionB = try service.createDraft(for: workoutB, now: fixture.start.addingTimeInterval(86_400), calendar: fixture.calendar)
        fixture.fillWorkingSets(in: sessionB, repsByExercise: ["Squat": [5, 5, 5], "OHP": [5, 5, 5], "Deadlift": [5]])
        _ = try service.finalize(sessionB, now: fixture.end.addingTimeInterval(86_400))
        #expect(WorkoutScheduler.nextProgramDay(from: fixture.days, mostRecentCompleted: sessionB)?.name == "Workout A")

        let repeatedA = try service.createDraft(for: workoutA, now: fixture.start.addingTimeInterval(86_400 * 2), calendar: fixture.calendar)
        fixture.fillWorkingSets(in: repeatedA, repsByExercise: ["Squat": [5, nil, nil], "Bench": [nil, nil, nil], "Row": [nil, nil, nil]])
        service.endWithoutProgression(repeatedA, now: fixture.end.addingTimeInterval(86_400 * 2))
        #expect(WorkoutScheduler.nextProgramDay(from: fixture.days, mostRecentCompleted: repeatedA)?.name == "Workout A")
    }

    @Test("FinalizeResult mirrors exercise-log order and per-exercise outcomes")
    func finalizeResultPerExerciseMatchesSessionOrder() throws {
        let fixture = try makeFixture()
        let workoutA = try fixture.requireDay(named: "Workout A")
        fixture.setWeight(60, increment: 1.25, stalledCount: 0, forExerciseKey: "squat")
        fixture.setWeight(42.5, increment: 1.25, stalledCount: 1, forExerciseKey: "bench")
        fixture.setWeight(45, increment: 2.5, stalledCount: 2, forExerciseKey: "row")

        let service = try fixture.makeService()
        let session = try service.createDraft(for: workoutA, now: fixture.start, calendar: fixture.calendar)
        fixture.fillWorkingSets(in: session, repsByExercise: ["Squat": [5, 5, 5], "Bench": [5, 5, 4], "Row": [4, 4, 4]])

        let result = try service.finalize(session, now: fixture.end)

        let expectedByExercise: [String: (old: Double, new: Double, progressed: Bool, stalled: Int)] = [
            "Squat": (60, 62.5, true, 0),
            "Bench": (42.5, 42.5, false, 2),
            "Row": (45, 45, false, 3)
        ]

        #expect(result.perExercise.map(\.exerciseName) == session.exerciseLogs.map(\.exerciseNameSnapshot))
        for exercise in result.perExercise {
            let expected = try #require(expectedByExercise[exercise.exerciseName])
            #expect(exercise.oldWeightKg == expected.old)
            #expect(exercise.newWeightKg == expected.new)
            #expect(exercise.didProgress == expected.progressed)
            #expect(exercise.stalledCount == expected.stalled)
        }
    }

    @Test("FinalizeResult reports the next program day after completion")
    func finalizeResultReportsNextProgramDayName() throws {
        let fixture = try makeFixture()
        let workoutA = try fixture.requireDay(named: "Workout A")
        let service = try fixture.makeService()
        let session = try service.createDraft(for: workoutA, now: fixture.start, calendar: fixture.calendar)
        fixture.fillWorkingSets(in: session, repsByExercise: ["Squat": [5, 5, 5], "Bench": [5, 5, 5], "Row": [5, 5, 5]])

        let result = try service.finalize(session, now: fixture.end)

        #expect(result.nextProgramDayName == "Workout B")
    }

    private func makeFixture(plateWeights: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]) throws -> Fixture {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try LiftSeeder().seedIfNeeded(in: context)

        let user = try #require(try context.fetch(FetchDescriptor<User>()).first)
        user.plates.removeAll()
        for weight in plateWeights {
            user.plates.append(PlateInventoryItem(weightKg: weight, countTotal: 2, user: user))
        }
        try context.save()

        let days = try fetchAll(ProgramDay.self, from: context, sortBy: [SortDescriptor(\.orderInRotation)])
        return Fixture(
            context: context,
            days: days,
            start: Date(timeIntervalSince1970: 1_735_689_600),
            end: Date(timeIntervalSince1970: 1_735_689_960)
        )
    }
}

@MainActor
private struct Fixture {
    let context: ModelContext
    let days: [ProgramDay]
    let start: Date
    let end: Date

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .utc
        return calendar
    }

    func makeService() throws -> DraftSessionService {
        try DraftSessionService(modelContext: context)
    }

    func requireDay(named name: String) throws -> ProgramDay {
        guard let day = days.first(where: { $0.name == name }) else {
            Issue.record("Missing program day \(name)")
            fatalError("Missing program day")
        }
        return day
    }

    func requireProgression(forExerciseKey key: String) throws -> ExerciseProgression {
        let progressions = try fetchAll(ExerciseProgression.self, from: context)
        guard let progression = progressions.first(where: { $0.exercise?.key == key }) else {
            Issue.record("Missing progression \(key)")
            fatalError("Missing progression")
        }
        return progression
    }

    func fetchProgressionEvents() throws -> [ProgressionEvent] {
        try fetchAll(ProgressionEvent.self, from: context)
    }

    func setWeight(_ weight: Double, increment: Double, stalledCount: Int, forExerciseKey key: String) {
        guard let progression = try? requireProgression(forExerciseKey: key) else { return }
        progression.currentWeightKg = weight
        progression.incrementKg = increment
        progression.stalledCount = stalledCount
        progression.lastProgressionAt = nil
    }

    func fillWorkingSets(in session: WorkoutSession, repsByExercise: [String: [Int?]]) {
        for exerciseLog in session.exerciseLogs {
            guard let reps = repsByExercise[exerciseLog.exerciseNameSnapshot] else { continue }
            let workingSets = exerciseLog.sets
                .filter { $0.kind == .working }
                .sorted { $0.index < $1.index }
            for (set, reps) in zip(workingSets, reps) {
                set.actualReps = reps
                set.completedAt = reps == nil ? nil : end
            }
        }
    }

    func appendDuplicateExerciseLog(named exerciseName: String, to session: WorkoutSession, reps: [Int]) throws {
        guard let original = session.exerciseLogs.first(where: { $0.exerciseNameSnapshot == exerciseName }),
              let exercise = original.exercise else {
            Issue.record("Missing original exercise log \(exerciseName)")
            return
        }

        let duplicate = ExerciseLog(
            session: session,
            exercise: exercise,
            exerciseNameSnapshot: original.exerciseNameSnapshot,
            targetWeightKgSnapshot: original.targetWeightKgSnapshot,
            targetSetsSnapshot: original.targetSetsSnapshot,
            targetRepsSnapshot: original.targetRepsSnapshot,
            sets: []
        )
        context.insert(duplicate)
        session.exerciseLogs.append(duplicate)

        for (index, actualReps) in reps.enumerated() {
            let set = LoggedSet(
                log: duplicate,
                kind: .working,
                index: index,
                weightKg: original.targetWeightKgSnapshot,
                targetReps: original.targetRepsSnapshot,
                actualReps: actualReps,
                completedAt: end
            )
            context.insert(set)
            duplicate.sets.append(set)
        }
        try context.save()
    }
}

private extension TimeZone {
    static let utc = TimeZone(secondsFromGMT: 0)!
}
