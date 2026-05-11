import Foundation
import Testing
@testable import Lift

@Suite("RestTimerService")
@MainActor
struct RestTimerServiceTests {
    @Test("remaining is nil before a rest starts")
    func remainingIsNilWithoutActiveRest() {
        let service = RestTimerService(
            scheduler: RecordingRestNotificationScheduler(),
            notificationBodyProvider: { _ in "Rest finished" }
        )

        #expect(service.remaining() == nil)
    }

    @Test("remaining counts down from the start time and clamps at zero")
    func remainingUsesAbsoluteTime() async {
        let scheduler = RecordingRestNotificationScheduler()
        let service = RestTimerService(
            scheduler: scheduler,
            notificationBodyProvider: { _ in "Rest finished" }
        )
        let t0 = Date(timeIntervalSince1970: 1_735_689_600)

        await service.start(
            exerciseLogID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            setID: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            durationSeconds: 90,
            now: t0
        )

        #expect(service.remaining(now: t0) == 90)
        #expect(service.remaining(now: t0.addingTimeInterval(30)) == 60)
        #expect(service.remaining(now: t0.addingTimeInterval(120)) == 0)
    }

    @Test("hasFinished flips once now reaches the rest deadline")
    func hasFinishedUsesDeadline() async {
        let service = RestTimerService(
            scheduler: RecordingRestNotificationScheduler(),
            notificationBodyProvider: { _ in "Rest finished" }
        )
        let t0 = Date(timeIntervalSince1970: 1_735_689_600)

        await service.start(
            exerciseLogID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            setID: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            durationSeconds: 45,
            now: t0
        )

        #expect(service.hasFinished(now: t0.addingTimeInterval(44)) == false)
        #expect(service.hasFinished(now: t0.addingTimeInterval(45)))
        #expect(service.hasFinished(now: t0.addingTimeInterval(90)))
    }

    @Test("starting a second rest replaces the prior active rest and cancels its notification")
    func startReplacesExistingRest() async {
        let scheduler = RecordingRestNotificationScheduler()
        let service = RestTimerService(
            scheduler: scheduler,
            notificationBodyProvider: { id in
                id == UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")! ? "Rest finished — Squat 60kg" : "Rest finished — Bench 42.5kg"
            }
        )
        let t0 = Date(timeIntervalSince1970: 1_735_689_600)
        let firstSetID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let secondSetID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!

        await service.start(
            exerciseLogID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            setID: firstSetID,
            durationSeconds: 90,
            now: t0
        )

        await service.start(
            exerciseLogID: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
            setID: secondSetID,
            durationSeconds: 120,
            now: t0.addingTimeInterval(5)
        )

        #expect(service.active?.setID == secondSetID)
        #expect(await scheduler.cancelledIDs == ["rest-\(firstSetID.uuidString)"])
    }

    @Test("skip clears the active rest and cancels its notification")
    func skipClearsRest() async {
        let scheduler = RecordingRestNotificationScheduler()
        let service = RestTimerService(
            scheduler: scheduler,
            notificationBodyProvider: { _ in "Rest finished — Squat 60kg" }
        )
        let setID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

        await service.start(
            exerciseLogID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            setID: setID,
            durationSeconds: 90,
            now: Date(timeIntervalSince1970: 1_735_689_600)
        )

        await service.skip()

        #expect(service.active == nil)
        #expect(await scheduler.cancelledIDs == ["rest-\(setID.uuidString)"])
    }

    @Test("extend adds seconds without changing the start time and reschedules the notification")
    func extendAddsSeconds() async {
        let scheduler = RecordingRestNotificationScheduler()
        let service = RestTimerService(
            scheduler: scheduler,
            notificationBodyProvider: { _ in "Rest finished — Squat 60kg" }
        )
        let t0 = Date(timeIntervalSince1970: 1_735_689_600)
        let setID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

        await service.start(
            exerciseLogID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            setID: setID,
            durationSeconds: 90,
            now: t0
        )
        await service.extend(bySeconds: 30)

        #expect(service.active?.durationSeconds == 120)
        #expect(service.remaining(now: t0.addingTimeInterval(30)) == 90)
        #expect(await scheduler.cancelledIDs == ["rest-\(setID.uuidString)"])
        let scheduled = await scheduler.scheduledRequests
        #expect(scheduled.count == 2)
        #expect(scheduled.last?.fireAt == t0.addingTimeInterval(120))
    }

    @Test("clearIfFinished only clears a rest that has reached zero")
    func clearIfFinishedGuardsOnCompletion() async {
        let scheduler = RecordingRestNotificationScheduler()
        let service = RestTimerService(
            scheduler: scheduler,
            notificationBodyProvider: { _ in "Rest finished — Squat 60kg" }
        )
        let t0 = Date(timeIntervalSince1970: 1_735_689_600)
        let setID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

        await service.start(
            exerciseLogID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            setID: setID,
            durationSeconds: 90,
            now: t0
        )

        await service.clearIfFinished(now: t0.addingTimeInterval(30))
        #expect(service.active?.setID == setID)

        await service.clearIfFinished(now: t0.addingTimeInterval(90))
        #expect(service.active == nil)
        #expect(await scheduler.cancelledIDs == ["rest-\(setID.uuidString)"])
    }

    @Test("start schedules the notification with the expected fire date and body")
    func startSchedulesNotification() async throws {
        let scheduler = RecordingRestNotificationScheduler()
        let service = RestTimerService(
            scheduler: scheduler,
            notificationBodyProvider: { _ in "Rest finished — Squat 60kg" }
        )
        let t0 = Date(timeIntervalSince1970: 1_735_689_600)
        let setID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

        await service.start(
            exerciseLogID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            setID: setID,
            durationSeconds: 90,
            now: t0
        )

        let firstRequest = await scheduler.scheduledRequests.first
        let request = try #require(firstRequest)
        #expect(request.id == "rest-\(setID.uuidString)")
        #expect(request.fireAt == t0.addingTimeInterval(90))
        #expect(request.body == "Rest finished — Squat 60kg")
    }
}

private actor RecordingRestNotificationScheduler: RestNotificationScheduler {
    struct ScheduledRequest: Equatable, Sendable {
        let id: String
        let fireAt: Date
        let body: String
    }

    private(set) var scheduledRequests: [ScheduledRequest] = []
    private(set) var cancelledIDs: [String] = []

    func schedule(id: String, fireAt: Date, body: String) async {
        scheduledRequests.append(ScheduledRequest(id: id, fireAt: fireAt, body: body))
    }

    func cancel(id: String) async {
        cancelledIDs.append(id)
    }
}
