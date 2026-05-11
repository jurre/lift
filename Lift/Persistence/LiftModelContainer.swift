import SwiftData

enum LiftModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema(versionedSchema: LiftSchemaV1.self)
        let configuration = ModelConfiguration("Lift", schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: LiftMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            fatalError("Failed to create Lift model container: \(error)")
        }
    }()
}
