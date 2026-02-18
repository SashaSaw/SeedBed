import Foundation
import SwiftData

// MARK: - Schema Versioning
//
// HOW THIS WORKS:
// ================
// Every time you make a BREAKING change to your models (rename property,
// change type, remove property), you need to:
//
// 1. Create a new schema version (copy the current models into a new enum)
// 2. Add a migration stage that explains how to convert old → new
// 3. Update the "current" typealias to point to your new version
//
// SAFE CHANGES (no migration needed):
// - Adding a new OPTIONAL property (String?, Int?, etc.)
// - Adding a new property WITH a default value
//
// BREAKING CHANGES (migration required):
// - Renaming a property
// - Changing a property's type
// - Removing a property
// - Making an optional property required
//

// MARK: - Version 1 (Initial Release)
// This is a snapshot of models as they exist NOW (after iCloud changes)

enum SownSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Habit.self, HabitGroup.self, DailyLog.self, DayRecord.self, EndOfDayNote.self]
    }
}

// MARK: - Migration Plan
// Add migration stages here when you create V2, V3, etc.

enum SownMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SownSchemaV1.self]
        // When you add V2: [SownSchemaV1.self, SownSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        // No migrations yet - this is our first version
        []

        // EXAMPLE: When you create V2, add a migration stage:
        // [migrateV1toV2]
    }

    // EXAMPLE MIGRATION (uncomment and modify when needed):
    //
    // static let migrateV1toV2 = MigrationStage.lightweight(
    //     fromVersion: SownSchemaV1.self,
    //     toVersion: SownSchemaV2.self
    // )
    //
    // For complex migrations where you need to transform data:
    //
    // static let migrateV1toV2 = MigrationStage.custom(
    //     fromVersion: SownSchemaV1.self,
    //     toVersion: SownSchemaV2.self,
    //     willMigrate: { context in
    //         // Code to run BEFORE migration
    //         // e.g., fetch old data and prepare it
    //     },
    //     didMigrate: { context in
    //         // Code to run AFTER migration
    //         // e.g., transform data, set default values for new fields
    //     }
    // )
}

// MARK: - How to Add a New Version
//
// STEP 1: Create the new schema enum (copy of current models at that point)
//
// enum SownSchemaV2: VersionedSchema {
//     static var versionIdentifier = Schema.Version(2, 0, 0)
//     static var models: [any PersistentModel.Type] {
//         [Habit.self, HabitGroup.self, DailyLog.self, DayRecord.self, EndOfDayNote.self]
//     }
// }
//
// STEP 2: Add V2 to the schemas array in SownMigrationPlan
//
// STEP 3: Add a migration stage (lightweight if just adding fields, custom if transforming data)
//
// STEP 4: Update CloudSyncService.makeModelContainer() to use the migration plan
