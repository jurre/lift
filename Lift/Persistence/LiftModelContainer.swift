import SwiftData

enum LiftModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([])
        let configuration = ModelConfiguration("Lift", schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create Lift model container: \(error)")
        }
    }()
}

// TODO: Phase 1 registers the app's SwiftData @Model types in this schema.
