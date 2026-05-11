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

    private var modelContext: ModelContext?
    private var weightLoading: WeightLoading?
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

    func load() {
        refresh()
    }

    func refresh() {
        guard let modelContext else {
            availableProgramDays = []
            selectedProgramDay = nil
            draftPlan = nil
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

            availableProgramDays = days
            weightLoading = makeWeightLoading(from: user)

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
        }
    }

    func select(day: ProgramDay) {
        guard let matchingDay = availableProgramDays.first(where: { matchesSelection($0, day) }) else {
            return
        }
        selectedProgramDay = matchingDay
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
