import Foundation
import Observation
import SwiftData

struct HistoryEditResult: Sendable, Equatable {
    let setID: UUID
    let exerciseLogID: UUID
    let flippedSuccessForExercise: Bool
    let didSucceedAfter: Bool
}

enum HistoryViewModelError: Error, Equatable {
    case missingModelContext
    case missingSet(UUID)
}

@MainActor
@Observable
final class HistoryViewModel {
    private(set) var sections: [HistorySection] = []
    private(set) var isLoading = false

    @ObservationIgnored
    private var modelContext: ModelContext?
    @ObservationIgnored
    private(set) var weightLoading: WeightLoading?

    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
    }

    func setModelContext(_ modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func load() {
        refresh()
    }

    func refresh() {
        guard let modelContext else {
            sections = []
            weightLoading = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let user = try modelContext.fetch(FetchDescriptor<User>()).first
            weightLoading = makeWeightLoading(from: user)

            let descriptor = FetchDescriptor<WorkoutSession>(
                sortBy: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)]
            )
            let all = try modelContext.fetch(descriptor)
            let visible = all.filter { $0.status != .draft }
            sections = HistorySectionBuilder.sections(from: visible)
        } catch {
            sections = []
        }
    }

    @discardableResult
    func editActualReps(setID: UUID, actualReps: Int?) throws -> HistoryEditResult {
        try mutate(setID: setID) { set in
            if let value = actualReps {
                let clamped = max(0, value)
                set.actualReps = clamped
                if set.completedAt == nil {
                    set.completedAt = Date()
                }
            } else {
                set.actualReps = nil
                set.completedAt = nil
            }
        }
    }

    @discardableResult
    func editWeight(setID: UUID, weightKg: Double) throws -> HistoryEditResult {
        try mutate(setID: setID) { set in
            let snapped = weightLoading?.nearestLoadable(weightKg) ?? weightKg
            set.weightKg = snapped
        }
    }

    private func mutate(
        setID: UUID,
        change: (LoggedSet) -> Void
    ) throws -> HistoryEditResult {
        guard let modelContext else { throw HistoryViewModelError.missingModelContext }

        let allSets = try modelContext.fetch(FetchDescriptor<LoggedSet>())
        guard let target = allSets.first(where: { $0.id == setID }), let log = target.log else {
            throw HistoryViewModelError.missingSet(setID)
        }

        let beforeSucceeded = exerciseSucceeded(log: log)
        change(target)
        try modelContext.save()
        let afterSucceeded = exerciseSucceeded(log: log)

        refresh()

        let flipped = (target.kind == .working) && (beforeSucceeded != afterSucceeded)
        return HistoryEditResult(
            setID: setID,
            exerciseLogID: log.id,
            flippedSuccessForExercise: flipped,
            didSucceedAfter: afterSucceeded
        )
    }

    private func exerciseSucceeded(log: ExerciseLog) -> Bool {
        let attempts = log.sets
            .filter { $0.kind == .working }
            .sorted { $0.index < $1.index }
            .map { WorkingSetAttempt(targetReps: $0.targetReps, actualReps: $0.actualReps) }
        return Progression.didExerciseSucceed(workingSets: attempts)
    }

    private func makeWeightLoading(from user: User?) -> WeightLoading? {
        guard let user else { return nil }
        return WeightLoading(barWeightKg: user.barWeightKg, inventory: user.orderedPlates)
    }
}
