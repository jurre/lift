import Foundation
import SwiftData

enum DraftSessionError: Error, Equatable {
    case draftAlreadyExistsForToday(existing: WorkoutSession)
    case missingUserConfiguration

    static func == (lhs: DraftSessionError, rhs: DraftSessionError) -> Bool {
        switch (lhs, rhs) {
        case let (.draftAlreadyExistsForToday(left), .draftAlreadyExistsForToday(right)):
            return left.id == right.id
        case (.missingUserConfiguration, .missingUserConfiguration):
            return true
        default:
            return false
        }
    }
}

@MainActor
struct DraftSessionService {
    let modelContext: ModelContext
    let factory: DraftSessionFactory
    let weightLoading: WeightLoading

    init(
        modelContext: ModelContext,
        factory: DraftSessionFactory = DraftSessionFactory()
    ) throws {
        self.modelContext = modelContext
        self.factory = factory
        self.weightLoading = try Self.makeWeightLoading(from: modelContext)
    }

    func currentDraft(now: Date = .now, calendar: Calendar = .current) -> WorkoutSession? {
        let todayID = LocalDay.id(for: now, in: calendar.timeZone)
        return allDrafts().first(where: { $0.workoutDayID == todayID })
    }

    func allDrafts() -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor).filter { $0.status == .draft }
        } catch {
            assertionFailure("Failed to fetch draft sessions: \(error)")
            return []
        }
    }

    func createDraft(
        for programDay: ProgramDay,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> WorkoutSession {
        if let existing = currentDraft(now: now, calendar: calendar) {
            throw DraftSessionError.draftAlreadyExistsForToday(existing: existing)
        }

        let warmupCalculator = WarmupCalculator(weightLoading: weightLoading)
        let draftPlan = factory.makeDraft(
            programDay: programDay,
            startedAt: now,
            timeZone: calendar.timeZone,
            warmupCalculator: warmupCalculator
        )

        let session = WorkoutSession(
            id: draftPlan.id,
            workoutDayID: draftPlan.workoutDayID,
            timeZoneIdentifierAtStart: calendar.timeZone.identifier,
            startedAt: draftPlan.startedAt,
            programDay: programDay,
            exerciseLogs: [],
            status: .draft
        )

        modelContext.insert(session)

        for draftLog in draftPlan.exerciseLogs {
            guard let exercise = draftLog.exercise else { continue }

            let exerciseLog = ExerciseLog(
                id: draftLog.id,
                session: session,
                exercise: exercise,
                exerciseNameSnapshot: draftLog.exerciseNameSnapshot,
                targetWeightKgSnapshot: draftLog.targetWeightKgSnapshot,
                targetSetsSnapshot: draftLog.targetSetsSnapshot,
                targetRepsSnapshot: draftLog.targetRepsSnapshot,
                sets: []
            )

            modelContext.insert(exerciseLog)
            session.exerciseLogs.append(exerciseLog)

            for draftSet in draftLog.sets {
                let loggedSet = LoggedSet(
                    id: draftSet.id,
                    log: exerciseLog,
                    kind: draftSet.kind,
                    index: draftSet.index,
                    weightKg: draftSet.weightKg,
                    targetReps: draftSet.targetReps,
                    actualReps: nil
                )
                modelContext.insert(loggedSet)
                exerciseLog.sets.append(loggedSet)
            }
        }

        try modelContext.save()
        return session
    }

    func discard(_ session: WorkoutSession) {
        modelContext.delete(session)
        persistChanges(action: "discard draft")
    }

    func endWithoutProgression(_ session: WorkoutSession, now: Date = .now) {
        session.status = .endedNoProgression
        session.endedAt = now
        persistChanges(action: "end draft without progression")
    }

    func finalize(_ session: WorkoutSession, now: Date = .now) {
        session.status = .completed
        session.endedAt = now
        // TODO: Apply session progression in Phase 4c before saving.
        persistChanges(action: "finalize draft session")
    }

    private func persistChanges(action: String) {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to \(action): \(error)")
        }
    }

    private static func makeWeightLoading(from modelContext: ModelContext) throws -> WeightLoading {
        let user = try modelContext.fetch(FetchDescriptor<User>()).first
        guard let user else {
            throw DraftSessionError.missingUserConfiguration
        }

        return WeightLoading(barWeightKg: user.barWeightKg, inventory: user.orderedPlates)
    }
}
