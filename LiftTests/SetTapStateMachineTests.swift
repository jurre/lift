import Testing
@testable import Lift

@Suite("SetTapStateMachine")
struct SetTapStateMachineTests {
    @Test("working sets cycle through complete, partial reps, and back to pending")
    func workingSetsRoundTrip() {
        let expected: [(SetCellState, SetTapTransition)] = [
            (.complete, .persist(newReps: 5)),
            (.partial(reps: 4), .persist(newReps: 4)),
            (.partial(reps: 3), .persist(newReps: 3)),
            (.partial(reps: 2), .persist(newReps: 2)),
            (.partial(reps: 1), .persist(newReps: 1)),
            (.partial(reps: 0), .persist(newReps: 0)),
            (.pending, .persistPending),
            (.complete, .persist(newReps: 5))
        ]

        var current = SetCellState.pending

        for (state, transition) in expected {
            let result = SetTapStateMachine.tap(current: current, targetReps: 5, kind: .working)
            #expect(result.newState == state)
            #expect(result.transition == transition)
            current = result.newState
        }
    }

    @Test("warmup sets only toggle between pending and complete")
    func warmupSetsRoundTrip() {
        let first = SetTapStateMachine.tap(current: .pending, targetReps: 5, kind: .warmup)
        #expect(first.newState == .complete)
        #expect(first.transition == .persist(newReps: 5))

        let second = SetTapStateMachine.tap(current: first.newState, targetReps: 5, kind: .warmup)
        #expect(second.newState == .pending)
        #expect(second.transition == .persistPending)
    }

    @Test("one-rep working sets still pass through partial zero")
    func oneRepWorkingSetRoundTrip() {
        let first = SetTapStateMachine.tap(current: .pending, targetReps: 1, kind: .working)
        #expect(first.newState == .complete)
        #expect(first.transition == .persist(newReps: 1))

        let second = SetTapStateMachine.tap(current: first.newState, targetReps: 1, kind: .working)
        #expect(second.newState == .partial(reps: 0))
        #expect(second.transition == .persist(newReps: 0))

        let third = SetTapStateMachine.tap(current: second.newState, targetReps: 1, kind: .working)
        #expect(third.newState == .pending)
        #expect(third.transition == .persistPending)
    }

    @Test("state mapping reflects persisted reps")
    func stateMapping() {
        #expect(SetTapStateMachine.state(for: nil, targetReps: 5) == .pending)
        #expect(SetTapStateMachine.state(for: 5, targetReps: 5) == .complete)
        #expect(SetTapStateMachine.state(for: 6, targetReps: 5) == .complete)
        #expect(SetTapStateMachine.state(for: 3, targetReps: 5) == .partial(reps: 3))
        #expect(SetTapStateMachine.state(for: 0, targetReps: 5) == .partial(reps: 0))
        #expect(SetTapStateMachine.state(for: -2, targetReps: 5) == .pending)
    }

    @Test("invalid target reps are handled defensively")
    func zeroTargetRepsDoesNotCrash() {
        #expect(SetTapStateMachine.state(for: 0, targetReps: 0) == .pending)

        let result = SetTapStateMachine.tap(current: .pending, targetReps: 0, kind: .working)
        #expect(result.newState == .pending)
        #expect(result.transition == .noop)
    }
}
