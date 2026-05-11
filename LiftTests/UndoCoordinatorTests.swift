import Foundation
import Testing
@testable import Lift

@Suite("UndoCoordinator")
@MainActor
struct UndoCoordinatorTests {
    @Test("recording a decrement enqueues snackbar state")
    func recordDecrementEnqueuesSnackbar() {
        let coordinator = UndoCoordinator(now: { Date(timeIntervalSince1970: 100) })
        let setID = UUID()

        coordinator.recordDecrement(setID: setID, fromReps: 5, toReps: 4)

        let snackbar = coordinator.currentSnackbar
        #expect(snackbar?.setID == setID)
        #expect(snackbar?.fromReps == 5)
        #expect(snackbar?.toReps == 4)
    }

    @Test("undo returns the prior state for the most recent decrement")
    func undoReturnsPriorState() {
        let coordinator = UndoCoordinator(now: { Date(timeIntervalSince1970: 100) })
        let setID = UUID()

        coordinator.recordDecrement(setID: setID, fromReps: 3, toReps: 2)

        let action = coordinator.undo()
        #expect(action?.setID == setID)
        #expect(action?.restoreReps == 3)
        #expect(coordinator.currentSnackbar == nil)
    }

    @Test("tick clears expired snackbars")
    func tickClearsExpiredSnackbar() {
        var now = Date(timeIntervalSince1970: 100)
        let coordinator = UndoCoordinator(now: { now })
        coordinator.recordDecrement(setID: UUID(), fromReps: 1, toReps: 0)

        now = Date(timeIntervalSince1970: 105)
        coordinator.tick()

        #expect(coordinator.currentSnackbar == nil)
    }
}
