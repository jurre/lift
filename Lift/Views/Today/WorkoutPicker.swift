import SwiftUI

struct WorkoutPicker: View {
    let selectedDayName: String
    let availableProgramDays: [ProgramDay]
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
                    .font(.title2.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.thinMaterial, in: Capsule())
        }
        .accessibilityLabel("Workout picker")
        .accessibilityValue(selectedDayName)
    }
}

#Preview {
    WorkoutPicker(
        selectedDayName: "Workout B",
        availableProgramDays: PreviewSupport.programDays(),
        onSelect: { _ in }
    )
    .padding()
}
