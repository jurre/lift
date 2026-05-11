import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class UndoCoordinator {
    private(set) var currentSnackbar: UndoSnackbarState?

    private let timeout: TimeInterval
    private let now: () -> Date

    init(timeout: TimeInterval = 4, now: @escaping () -> Date = { .now }) {
        self.timeout = timeout
        self.now = now
    }

    func recordDecrement(
        setID: UUID,
        description: String = "Set",
        fromReps: Int?,
        toReps: Int?
    ) {
        let expiresAt = now().addingTimeInterval(timeout)
        currentSnackbar = UndoSnackbarState(
            id: UUID(),
            setID: setID,
            description: description,
            fromReps: fromReps,
            toReps: toReps,
            expiresAt: expiresAt
        )
    }

    func undo() -> UndoRestoreAction? {
        guard let currentSnackbar else { return nil }
        self.currentSnackbar = nil
        return UndoRestoreAction(setID: currentSnackbar.setID, restoreReps: currentSnackbar.fromReps)
    }

    func tick() {
        guard let currentSnackbar, currentSnackbar.expiresAt <= now() else { return }
        self.currentSnackbar = nil
    }
}

struct UndoSnackbarState: Equatable, Identifiable {
    let id: UUID
    let setID: UUID
    let description: String
    let fromReps: Int?
    let toReps: Int?
    let expiresAt: Date

    var message: String {
        "\(description): \(formatted(fromReps)) → \(formatted(toReps)) reps."
    }

    private func formatted(_ reps: Int?) -> String {
        guard let reps else { return "pending" }
        return "\(reps)"
    }
}

struct UndoRestoreAction: Equatable {
    let setID: UUID
    let restoreReps: Int?
}

struct SnackbarView: View {
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 8)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.88), in: Capsule())
        .shadow(radius: 8, y: 4)
    }
}
