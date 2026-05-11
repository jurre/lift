import Foundation

@MainActor
enum WorkoutScheduler {
    static func nextProgramDay(
        from days: [ProgramDay],
        mostRecentCompleted: WorkoutSession?
    ) -> ProgramDay? {
        let orderedDays = days.sorted { $0.orderInRotation < $1.orderInRotation }
        guard !orderedDays.isEmpty else { return nil }

        guard
            let mostRecentCompleted,
            mostRecentCompleted.status == .completed,
            let currentDay = mostRecentCompleted.programDay,
            let currentIndex = orderedDays.firstIndex(where: { $0.orderInRotation == currentDay.orderInRotation })
        else {
            return orderedDays.first(where: { $0.orderInRotation == 0 }) ?? orderedDays.first
        }

        let nextIndex = (currentIndex + 1) % orderedDays.count
        return orderedDays[nextIndex]
    }
}
