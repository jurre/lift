import Foundation

/// State of a working set in the UI.
/// Distinct from `LoggedSet` which only stores `actualReps: Int?`.
/// Mapping to `actualReps`:
///   .pending → nil
///   .complete → targetReps
///   .partial(n) → n  (where 0 ≤ n < targetReps)
enum SetCellState: Equatable, Sendable {
    case pending
    case complete
    case partial(reps: Int)
}

enum SetTapTransition: Equatable, Sendable {
    case persist(newReps: Int?)
    case persistPending
    case noop
}

struct SetTapStateMachine {
    static func tap(current: SetCellState, targetReps: Int, kind: SetKind) -> (newState: SetCellState, transition: SetTapTransition) {
        guard targetReps > 0 else {
            return (.pending, .noop)
        }

        switch kind {
        case .warmup:
            switch current {
            case .pending:
                return (.complete, .persist(newReps: targetReps))
            case .complete, .partial:
                return (.pending, .persistPending)
            }

        case .working:
            switch current {
            case .pending:
                return (.complete, .persist(newReps: targetReps))
            case .complete:
                return (.partial(reps: targetReps - 1), .persist(newReps: targetReps - 1))
            case let .partial(reps):
                guard reps > 0 else {
                    return (.pending, .persistPending)
                }
                return (.partial(reps: reps - 1), .persist(newReps: reps - 1))
            }
        }
    }

    static func state(for actualReps: Int?, targetReps: Int) -> SetCellState {
        guard targetReps > 0 else {
            return .pending
        }

        guard let actualReps else {
            return .pending
        }

        guard actualReps >= 0 else {
            return .pending
        }

        if actualReps >= targetReps {
            return .complete
        }

        return .partial(reps: actualReps)
    }
}
