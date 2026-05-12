import SwiftUI

struct WorkoutPicker: View {
    let selectedDayName: String
    let availableProgramDays: [ProgramDay]
    let isLocked: Bool
    let onSelect: (ProgramDay) -> Void

    var body: some View {
        Menu {
            ForEach(availableProgramDays, id: \.persistentModelID) { day in
                Button(day.name) {
                    onSelect(day)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(selectedDayName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(LiftTheme.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LiftTheme.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(LiftTheme.accentMuted, in: Capsule())
            .overlay(Capsule().strokeBorder(LiftTheme.accentBorder, lineWidth: 1))
        }
        .accessibilityLabel("Workout picker")
        .accessibilityValue(selectedDayName)
        .accessibilityHint(isLocked ? "Workout in progress. Switching will discard logged sets." : "Choose today's workout")
    }
}

#Preview {
    WorkoutPicker(
        selectedDayName: "Workout B",
        availableProgramDays: PreviewSupport.programDays(),
        isLocked: false,
        onSelect: { _ in }
    )
    .padding()
    .background(LiftTheme.canvas)
}

