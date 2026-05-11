import Foundation
import SwiftData
@testable import Lift

@MainActor
func makeInMemoryContainer() throws -> ModelContainer {
    let schema = Schema(versionedSchema: LiftSchemaV1.self)
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, migrationPlan: LiftMigrationPlan.self, configurations: [configuration])
}

@MainActor
func fetchAll<T: PersistentModel>(_: T.Type, from context: ModelContext, sortBy: [SortDescriptor<T>] = []) throws -> [T] {
    try context.fetch(FetchDescriptor<T>(sortBy: sortBy))
}
