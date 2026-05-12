import Foundation
import SwiftData

@MainActor
struct PreviewSupport {
    static let container: ModelContainer = {
        do {
            let schema = Schema(versionedSchema: LiftSchemaV1.self)
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: LiftMigrationPlan.self,
                configurations: [configuration]
            )
            let context = ModelContext(container)
            try LiftSeeder().seedIfNeeded(in: context)
            try seedInterestingWeights(in: context)
            return container
        } catch {
            fatalError("Failed to build preview container: \(error)")
        }
    }()

    static func todayViewModel(selectedDayName: String = "Workout B") -> TodayViewModel {
        let context = ModelContext(container)
        let viewModel = TodayViewModel(
            modelContext: context,
            clock: { Date(timeIntervalSince1970: 1_736_121_600) },
            timeZone: TimeZone(identifier: "America/Los_Angeles") ?? .current
        )
        viewModel.load()
        if let day = viewModel.availableProgramDays.first(where: { $0.name == selectedDayName }) {
            viewModel.select(day: day)
        }
        return viewModel
    }

    static func draftPlan(dayName: String = "Workout B") -> DraftSessionPlan {
        let viewModel = todayViewModel(selectedDayName: dayName)
        guard let draftPlan = viewModel.draftPlan else {
            fatalError("Missing preview draft plan")
        }
        return draftPlan
    }

    static func programDays() -> [ProgramDay] {
        todayViewModel().availableProgramDays
    }

    private static func seedInterestingWeights(in context: ModelContext) throws {
        let descriptor = FetchDescriptor<ProgramDay>()
        let days = try context.fetch(descriptor)

        if let workoutB = days.first(where: { $0.name == "Workout B" }) {
            workoutB.orderedSlots.first?.exerciseProgression?.currentWeightKg = 60
            workoutB.orderedSlots.dropFirst().first?.exerciseProgression?.currentWeightKg = 35
            workoutB.orderedSlots.last?.exerciseProgression?.currentWeightKg = 80
        }

        if let workoutA = days.first(where: { $0.name == "Workout A" }) {
            workoutA.orderedSlots.first?.exerciseProgression?.currentWeightKg = 60
            workoutA.orderedSlots.dropFirst().first?.exerciseProgression?.currentWeightKg = 42.5
            workoutA.orderedSlots.last?.exerciseProgression?.currentWeightKg = 45
        }

        try context.save()
    }
}
