# Claude Code Guidelines for Sown

## Xcode Instructions

When providing Xcode instructions:

- **Keep steps atomic and simple** - one action per step
- **Explain core concepts first** - before diving into implementation, explain what we're doing and why
- **Describe the overall flow** - how changes affect the app's behavior
- **Assume beginner level** - this is the user's first time using Xcode
- **Use exact menu paths** - e.g., "Click File > New > File" not "create a new file"
- **Reference UI elements clearly** - describe where things are located on screen
- **Verify UI for Xcode 16+** - UI has changed significantly; always use keyboard shortcuts as fallback

### Common Xcode Operations (Xcode 16+)

| Action | How to do it |
|--------|--------------|
| Open Library (UI elements) | Press **Cmd+Shift+L** |
| Add constraints | Select view, then **Editor > Resolve Auto Layout Issues** or click constraints icon at bottom of canvas |
| Show/hide sidebars | **Cmd+0** (left), **Cmd+Option+0** (right) |
| Show Attributes Inspector | **Cmd+Option+4** |
| Show Size Inspector | **Cmd+Option+5** |
| Clean Build | **Cmd+Shift+K** |
| Build & Run | **Cmd+R** |

## App Architecture

- **SwiftUI** app using **SwiftData** for persistence
- **@Observable** pattern for state management via `HabitStore`
- Custom **PatrickHand** handwritten font throughout
- Journal/paper aesthetic with lined backgrounds

## Key Files

- `HabitStore.swift` - Central state management
- `JournalTheme.swift` - Colors, fonts, dimensions, Feedback enum
- `SoundEffectService.swift` - Audio playback
- Models in `/Models` - Habit, DailyLog, HabitGroup, etc.

---

## Common Issues & Solutions

### SwiftData: Enum Default Values Don't Work

**Error message:**
```
Type 'Any?' has no member 'mustDo'
```

**What's happening:**
SwiftData uses the `@Model` macro to auto-generate persistence code. When you give a custom enum property a default value like `var tier: HabitTier = .mustDo`, the macro loses track of the type. It sees `.mustDo` but thinks the type is `Any?` instead of `HabitTier`, so it can't find the enum case.

**Why it matters:**
CloudKit (iCloud sync) requires all non-optional properties to have default values. But SwiftData macros can't handle enum defaults. This creates a conflict.

**The fix:**
Store the enum's raw String value instead, then use a computed property for convenient enum access:

```swift
// ❌ BAD - SwiftData macro can't handle this
var tier: HabitTier = .mustDo

// ✅ GOOD - Store raw value, expose enum via computed property
private var tierRawValue: String = HabitTier.mustDo.rawValue

var tier: HabitTier {
    get { HabitTier(rawValue: tierRawValue) ?? .mustDo }
    set { tierRawValue = newValue.rawValue }
}
```

**Files affected:** `Habit.swift`, `HabitGroup.swift` (any model with enum properties)

---

### SwiftData: "Could not create ModelContainer" after changing models

**Error message:**
```
Fatal error: Could not create ModelContainer: SwiftDataError(_error: SwiftData.SwiftDataError._Error.loadIssueModelContainer)
```

**What's happening:**
You changed the structure of a `@Model` class (added/removed/renamed properties), but the app already has data saved with the OLD structure. SwiftData can't automatically convert from the old format to the new one.

**Example:** Changing `var tier: HabitTier` to `var tierRawValue: String` creates a new column and removes the old one. The existing data is orphaned.

**Quick fix (development only):**
Delete the app from simulator/device and reinstall. This clears the old database.

- **Simulator:** Long-press app → Delete App
- **Device:** Settings → General → iPhone Storage → Sown → Delete App

**For production apps:**
You would need to set up a `VersionedSchema` and `SchemaMigrationPlan` to tell SwiftData exactly how to convert old data to new format. This is only needed if you've already shipped to users.

---

## Schema Migrations (For Released Apps)

### Overview

When you release your app, users save data in a specific format. If you later change your models, you need **migrations** to convert their old data to the new format.

**File:** `SownSchemaVersions.swift` contains the migration setup.

### Safe Changes (No Migration Needed)

These changes are automatically handled by SwiftData:
- Adding a new **optional** property (`var newField: String?`)
- Adding a new property **with a default value** (`var newField: String = ""`)

### Breaking Changes (Migration Required)

These need a migration:
- **Renaming** a property (`name` → `title`)
- **Changing** a property's type (`String` → `Int`)
- **Removing** a property
- Making an optional property **required**

### How to Add a New Schema Version

**Step 1:** In `SownSchemaVersions.swift`, create a new version enum:

```swift
enum SownSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Habit.self, HabitGroup.self, DailyLog.self, DayRecord.self, EndOfDayNote.self]
    }
}
```

**Step 2:** Add V2 to the migration plan's schemas array:

```swift
static var schemas: [any VersionedSchema.Type] {
    [SownSchemaV1.self, SownSchemaV2.self]
}
```

**Step 3:** Add a migration stage:

```swift
// For simple changes (adding optional fields):
static let migrateV1toV2 = MigrationStage.lightweight(
    fromVersion: SownSchemaV1.self,
    toVersion: SownSchemaV2.self
)

// For complex changes (renaming, type changes):
static let migrateV1toV2 = MigrationStage.custom(
    fromVersion: SownSchemaV1.self,
    toVersion: SownSchemaV2.self,
    willMigrate: nil,
    didMigrate: { context in
        // Transform data here
    }
)
```

**Step 4:** Add the stage to the stages array:

```swift
static var stages: [MigrationStage] {
    [migrateV1toV2]
}
```

**Step 5:** Update `CloudSyncService.makeModelContainer()` to use the new schema version.

---

### CloudKit: Relationships Must Be Optional

**Error message:**
```
CloudKit integration requires that all relationships be optional, the following are not:
Habit: dailyLogs
```

**What's happening:**
CloudKit (iCloud sync) requires that all relationships between models be **optional**. This is because when data syncs from the cloud, related objects might not arrive at the same time. CloudKit needs to handle the case where a `Habit` exists but its `DailyLog` records haven't synced yet.

**The fix:**
Change relationship arrays from non-optional to optional:

```swift
// ❌ BAD - CloudKit can't handle this
@Relationship(deleteRule: .cascade, inverse: \DailyLog.habit)
var dailyLogs: [DailyLog] = []

// ✅ GOOD - Optional relationship
@Relationship(deleteRule: .cascade, inverse: \DailyLog.habit)
var dailyLogs: [DailyLog]?
```

**Important:** After making this change, update all code that accesses the relationship:
- `habit.dailyLogs.filter { }` → `(habit.dailyLogs ?? []).filter { }`
- `habit.dailyLogs.first { }` → `habit.dailyLogs?.first { }`
- `habit.dailyLogs.append(log)` → Initialize if nil, then append

---

### CloudKit: Remote Notification Background Mode Required

**Error message:**
```
CloudKit push notifications require the 'remote-notification' background mode in your info plist.
```

**What's happening:**
CloudKit uses push notifications to tell your app when data changes on other devices. For this to work, iOS needs to know your app can receive notifications in the background.

**The fix:**
Add to `Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

Or in Xcode: Target → Signing & Capabilities → + Background Modes → Check "Remote notifications"
