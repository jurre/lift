import Foundation
import Observation
import SwiftData
import UserNotifications

protocol RestNotificationScheduler: Sendable {
    func schedule(id: String, fireAt: Date, body: String) async
    func cancel(id: String) async
}

struct UserNotificationRestScheduler: RestNotificationScheduler {
    func schedule(id: String, fireAt: Date, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Lift"
        content.body = body
        content.sound = .default
        content.userInfo["kind"] = "rest"

        let interval = max(1, fireAt.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        try? await UNUserNotificationCenter.current().add(request)
    }

    func cancel(id: String) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
    }
}

@MainActor
@Observable
final class RestTimerService: RestTimerStarting {
    struct ActiveRest: Equatable, Sendable {
        let exerciseLogID: UUID
        let setID: UUID
        let startedAt: Date
        let durationSeconds: Int
        let scheduledNotificationID: String?
    }

    // Rest state stays in memory on purpose. If the app is killed mid-rest, the notification can
    // still fire, but the in-app countdown is gone on relaunch until the user starts a new rest.
    private(set) var active: ActiveRest?

    @ObservationIgnored
    private var modelContext: ModelContext?
    @ObservationIgnored
    private let scheduler: any RestNotificationScheduler
    @ObservationIgnored
    private let notificationBodyProvider: (@MainActor @Sendable (UUID) -> String?)?

    init(
        modelContext: ModelContext? = nil,
        scheduler: any RestNotificationScheduler = UserNotificationRestScheduler(),
        notificationBodyProvider: (@MainActor @Sendable (UUID) -> String?)? = nil
    ) {
        self.modelContext = modelContext
        self.scheduler = scheduler
        self.notificationBodyProvider = notificationBodyProvider
    }

    func setModelContext(_ modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func remaining(now: Date = .now) -> Int? {
        guard let active else { return nil }
        let deadline = active.startedAt.addingTimeInterval(TimeInterval(active.durationSeconds))
        return max(0, Int(ceil(deadline.timeIntervalSince(now))))
    }

    func hasFinished(now: Date = .now) -> Bool {
        guard active != nil else { return false }
        return remaining(now: now) == 0
    }

    func start(
        exerciseLogID: UUID,
        setID: UUID,
        durationSeconds: Int,
        now: Date = .now
    ) async {
        await cancelActiveNotificationIfNeeded()

        let notificationID = Self.notificationID(for: setID)
        active = ActiveRest(
            exerciseLogID: exerciseLogID,
            setID: setID,
            startedAt: now,
            durationSeconds: durationSeconds,
            scheduledNotificationID: notificationID
        )

        let fireAt = now.addingTimeInterval(TimeInterval(durationSeconds))
        await scheduler.schedule(
            id: notificationID,
            fireAt: fireAt,
            body: notificationBody(for: exerciseLogID)
        )
    }

    func skip() async {
        await clearActiveRest()
    }

    func extend(bySeconds: Int) async {
        guard let active else { return }

        let updated = ActiveRest(
            exerciseLogID: active.exerciseLogID,
            setID: active.setID,
            startedAt: active.startedAt,
            durationSeconds: max(0, active.durationSeconds + bySeconds),
            scheduledNotificationID: active.scheduledNotificationID
        )
        self.active = updated

        guard let notificationID = updated.scheduledNotificationID else { return }
        await scheduler.cancel(id: notificationID)
        await scheduler.schedule(
            id: notificationID,
            fireAt: updated.startedAt.addingTimeInterval(TimeInterval(updated.durationSeconds)),
            body: notificationBody(for: updated.exerciseLogID)
        )
    }

    func clearIfFinished(now: Date = .now) async {
        guard hasFinished(now: now) else { return }
        await clearActiveRest()
    }

    private func clearActiveRest() async {
        guard let active else { return }
        self.active = nil

        if let notificationID = active.scheduledNotificationID {
            await scheduler.cancel(id: notificationID)
        }
    }

    private func cancelActiveNotificationIfNeeded() async {
        guard let notificationID = active?.scheduledNotificationID else { return }
        await scheduler.cancel(id: notificationID)
    }

    private func notificationBody(for exerciseLogID: UUID) -> String {
        if let notificationBodyProvider, let customBody = notificationBodyProvider(exerciseLogID) {
            return customBody
        }
        if let defaultBody = defaultNotificationBody(for: exerciseLogID) {
            return defaultBody
        }
        return "Rest finished"
    }

    private func defaultNotificationBody(for exerciseLogID: UUID) -> String? {
        guard let modelContext,
              let exerciseLog = try? modelContext.fetch(FetchDescriptor<ExerciseLog>()).first(where: { $0.id == exerciseLogID }) else {
            return nil
        }
        return "Rest finished — \(exerciseLog.exerciseNameSnapshot) \(Self.formatWeight(exerciseLog.targetWeightKgSnapshot))kg"
    }

    private static func notificationID(for setID: UUID) -> String {
        "rest-\(setID.uuidString)"
    }

    private static func formatWeight(_ weight: Double) -> String {
        weight.formatted(
            .number.precision(
                .fractionLength(weight.rounded(.down) == weight ? 0 : 1)
            )
        )
    }
}
