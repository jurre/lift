import SwiftUI

struct RestTimerOverlay: View {
    @Bindable var restTimer: RestTimerService
    let exerciseLogs: [DraftExerciseLog]

    @Environment(\.haptics) private var haptics
    @Environment(\.scenePhase) private var scenePhase
    @State private var completedSetID: UUID?

    var body: some View {
        Group {
            if let activeRest = restTimer.active {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    contentForActive(activeRest, now: context.date)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if completedSetID != nil {
                restedContent
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
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
                        Text(exerciseName(for: activeRest.setID).uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)

                        Text(formatted(remaining))
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .accessibilityLabel("Rest timer for \(exerciseName(for: activeRest.setID))")
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
                    .tint(.accentColor)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
    }

    private var restedContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Rested!")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.green)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    private func exerciseName(for setID: UUID) -> String {
        for log in exerciseLogs {
            if log.sets.contains(where: { $0.id == setID }) {
                return log.exerciseNameSnapshot
            }
        }
        return "Rest"
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
