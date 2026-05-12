import SwiftUI

struct RestTimerOverlay: View {
    @Bindable var restTimer: RestTimerService

    @Environment(\.haptics) private var haptics
    @Environment(\.scenePhase) private var scenePhase
    @State private var completedSetID: UUID?

    var body: some View {
        Group {
            if let activeRest = restTimer.active {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    contentForActive(activeRest, now: context.date)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if completedSetID != nil {
                restedContent
                    .transition(.opacity)
            }
        }
        .animation(.snappy(duration: 0.25), value: restTimer.active?.setID)
        .animation(.snappy(duration: 0.25), value: completedSetID)
        .task(id: completionTaskID) {
            guard let activeRest = restTimer.active else { return }

            let remaining = restTimer.remaining() ?? 0
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }

            guard scenePhase == .active,
                  restTimer.active?.setID == activeRest.setID,
                  restTimer.hasFinished() else {
                return
            }

            completedSetID = activeRest.setID
            haptics.restCompleted()

            try? await Task.sleep(for: .seconds(3))
            guard restTimer.active?.setID == activeRest.setID else {
                completedSetID = nil
                return
            }
            await restTimer.clearIfFinished()
            completedSetID = nil
        }
    }

    @ViewBuilder
    private func contentForActive(_ activeRest: RestTimerService.ActiveRest, now: Date) -> some View {
        if restTimer.hasFinished(now: now) {
            restedContent
        } else {
            let remaining = max(restTimer.remaining(now: now) ?? 0, 0)
            let progress = Double(remaining) / Double(max(activeRest.durationSeconds, 1))

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activeRest.exerciseName.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(LiftTheme.textSecondary)
                            .accessibilityHidden(true)

                        Text(formatted(remaining))
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(LiftTheme.textPrimary)
                            .accessibilityLabel("Rest timer for \(activeRest.exerciseName)")
                            .accessibilityValue("\(remaining) seconds remaining")
                    }

                    Spacer(minLength: 12)

                    Button("Skip") {
                        Task { await restTimer.skip() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel("Skip rest")

                    Button("+30s") {
                        Task { await restTimer.extend(bySeconds: 30) }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityLabel("Extend rest by 30 seconds")
                }

                ProgressView(value: progress)
                    .tint(LiftTheme.accent)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private var restedContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(LiftTheme.success)
            Text("Rested!")
                .font(.headline.weight(.semibold))
                .foregroundStyle(LiftTheme.success)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var completionTaskID: String? {
        guard let activeRest = restTimer.active else { return nil }
        return "\(activeRest.setID.uuidString)-\(activeRest.durationSeconds)-\(scenePhase == .active)"
    }

    private func formatted(_ remainingSeconds: Int) -> String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return "\(minutes):\(seconds.formatted(.number.precision(.integerLength(2))))"
    }
}
