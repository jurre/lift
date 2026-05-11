import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class TodayViewModel {
    var selectedProgramDay: ProgramDay? {
        didSet {
            guard !matchesSelection(selectedProgramDay, oldValue) else { return }
            rebuildDraftPlan()
        }
    }

    private(set) var availableProgramDays: [ProgramDay] = []
    private(set) var draftPlan: DraftSessionPlan?
    private(set) var isLoading = false
    private(set) var isProgramDayLocked = false
    private(set) var programDayLockHint: String?

    private var modelContext: ModelContext?
    private var weightLoading: WeightLoading?
    private var reopenedDraftID: UUID?
    private var activeDraftSessionID: UUID?
    private let now: Date
    private let timeZone: TimeZone

    init(modelContext: ModelContext? = nil, now: Date = .now, timeZone: TimeZone = .current) {
        self.modelContext = modelContext
        self.now = now
        self.timeZone = timeZone
    }

    func setModelContext(_ modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func setReopenedDraftID(_ reopenedDraftID: UUID?) {
        self.reopenedDraftID = reopenedDraftID
    }

    func load() {
        refresh()
    }

    func refresh() {
        guard let modelContext else {
            availableProgramDays = []
            selectedProgramDay = nil
            draftPlan = nil
            isProgramDayLocked = false
            programDayLockHint = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let dayDescriptor = FetchDescriptor<ProgramDay>(sortBy: [SortDescriptor(\ProgramDay.orderInRotation)])
            let sessionDescriptor = FetchDescriptor<WorkoutSession>(
                sortBy: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)]
            )
            let userDescriptor = FetchDescriptor<User>()

            let days = try modelContext.fetch(dayDescriptor)
            let mostRecentCompleted = try modelContext.fetch(sessionDescriptor).first(where: { $0.status == .completed })
            let user = try modelContext.fetch(userDescriptor).first
            let draftService = try DraftSessionService(modelContext: modelContext)

            availableProgramDays = days
            weightLoading = makeWeightLoading(from: user)

            if let persistedDraft = activeDraftSession(using: draftService) {
                activeDraftSessionID = persistedDraft.id
                selectedProgramDay = matchProgramDay(persistedDraft.programDay, in: days)
                draftPlan = DraftSessionPlan(session: persistedDraft)
                isProgramDayLocked = true
                programDayLockHint = makeProgramDayLockHint(for: persistedDraft)
                return
            } else {
                activeDraftSessionID = nil
                isProgramDayLocked = false
                programDayLockHint = nil
            }

            if let currentSelection = selectedProgramDay,
               let refreshedSelection = days.first(where: { matchesSelection($0, currentSelection) }) {
                selectedProgramDay = refreshedSelection
            } else {
                selectedProgramDay = WorkoutScheduler.nextProgramDay(from: days, mostRecentCompleted: mostRecentCompleted)
            }

            if selectedProgramDay == nil {
                draftPlan = nil
            } else {
                rebuildDraftPlan()
            }
        } catch {
            assertionFailure("Failed to load Today screen: \(error)")
            availableProgramDays = []
            selectedProgramDay = nil
            draftPlan = nil
            isProgramDayLocked = false
            programDayLockHint = nil
        }
    }

    func select(day: ProgramDay) {
        guard !isProgramDayLocked else { return }
        guard let matchingDay = availableProgramDays.first(where: { matchesSelection($0, day) }) else {
            return
        }
        selectedProgramDay = matchingDay
    }

    func prepareDraftIfNeeded() throws -> WorkoutSession? {
        guard let modelContext, let selectedProgramDay else {
            return nil
        }

        let draftService = try DraftSessionService(modelContext: modelContext)
        if let activeDraft = activeDraftSession(using: draftService) {
            return activeDraft
        }

        let session = try draftService.createDraft(
            for: selectedProgramDay,
            now: now,
            calendar: currentCalendar
        )
        reopenedDraftID = session.id
        refresh()
        return session
    }

    func plateSuggestion(for exerciseLog: DraftExerciseLog) -> String {
        guard let weightLoading else { return "—" }

        switch weightLoading.plates(for: exerciseLog.targetWeightKgSnapshot) {
        case let .exact(perSidePlatesKg):
            if perSidePlatesKg.isEmpty {
                return "bar only"
            }
            return perSidePlatesKg
                .map(Self.formatWeight)
                .joined(separator: " + ")
        case let .closest(belowKg, aboveKg):
            let nearest = [belowKg, aboveKg]
                .compactMap { $0 }
                .min(by: { abs($0 - exerciseLog.targetWeightKgSnapshot) < abs($1 - exerciseLog.targetWeightKgSnapshot) })
            guard let nearest else { return "—" }
            return "closest: \(Self.formatWeight(nearest)) kg"
        }
    }

    private func rebuildDraftPlan() {
        guard let selectedProgramDay, let weightLoading else {
            draftPlan = nil
            return
        }

        let warmupCalculator = WarmupCalculator(weightLoading: weightLoading)
        draftPlan = DraftSessionFactory.makeDraft(
            programDay: selectedProgramDay,
            startedAt: now,
            timeZone: timeZone,
            warmupCalculator: warmupCalculator
        )
    }

    private func makeWeightLoading(from user: User?) -> WeightLoading? {
        guard let user else { return nil }
        return WeightLoading(barWeightKg: user.barWeightKg, inventory: user.orderedPlates)
    }

    private var currentCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private func activeDraftSession(using draftService: DraftSessionService) -> WorkoutSession? {
        if let reopenedDraftID {
            if let reopened = draftService.allDrafts().first(where: { $0.id == reopenedDraftID }) {
                return reopened
            }
            self.reopenedDraftID = nil
        }

        return draftService.currentDraft(now: now, calendar: currentCalendar)
    }

    private func matchProgramDay(_ programDay: ProgramDay?, in days: [ProgramDay]) -> ProgramDay? {
        guard let programDay else { return nil }
        return days.first(where: { matchesSelection($0, programDay) }) ?? programDay
    }

    private func makeProgramDayLockHint(for session: WorkoutSession) -> String {
        let dayName = session.programDay?.name ?? selectedProgramDay?.name ?? "Workout"
        let todayID = LocalDay.id(for: now, in: timeZone)
        if session.workoutDayID == todayID {
            return "\(dayName) — locked for today"
        }
        return "\(dayName) — locked to unfinished draft"
    }

    private func matchesSelection(_ lhs: ProgramDay?, _ rhs: ProgramDay?) -> Bool {
        switch (lhs?.persistentModelID, rhs?.persistentModelID) {
        case let (left?, right?):
            return left == right
        case (nil, nil):
            return true
        default:
            return false
        }
    }

    private static func formatWeight(_ weight: Double) -> String {
        weight.formatted(.number.precision(.fractionLength(weight.rounded(.down) == weight ? 0 : 1)))
    }
}
