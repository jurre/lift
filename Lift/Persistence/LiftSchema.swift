import SwiftData

enum LiftSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        .init(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [
            User.self,
            PlateInventoryItem.self,
            Exercise.self,
            ExerciseProgression.self,
            ProgramDay.self,
            ProgramExerciseSlot.self,
            WorkoutSession.self,
            ExerciseLog.self,
            LoggedSet.self,
            ProgressionEvent.self
        ]
    }
}

enum LiftMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [LiftSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
