# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Reference Documents

- **[VISION.md](VISION.md)** — App purpose, philosophy, blocking philosophy, design principles. Consult before making design decisions.
- **[USER_STORIES.md](USER_STORIES.md)** — Living checklist of features with acceptance criteria. Check before implementing. Update after changing behavior.

## Build & Run

This is an Xcode project (no SPM Package.swift). Build and run via Xcode or:

```bash
xcodebuild -scheme Sown -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build
```

- **Clean Build:** Cmd+Shift+K in Xcode
- **Build & Run:** Cmd+R
- No test targets exist yet

## Xcode Instructions

When providing Xcode instructions:
- **Assume beginner level** — keep steps atomic, explain concepts before implementation
- **Use exact menu paths** (e.g., "Click File > New > File") and keyboard shortcuts as fallback
- **Verify for Xcode 16+** — UI has changed significantly from earlier versions

| Action | Shortcut |
|--------|----------|
| Open Library | Cmd+Shift+L |
| Show/hide left sidebar | Cmd+0 |
| Show/hide right sidebar | Cmd+Option+0 |
| Attributes Inspector | Cmd+Option+4 |
| Size Inspector | Cmd+Option+5 |
| Clean Build | Cmd+Shift+K |
| Build & Run | Cmd+R |

## App Overview

**Sown** is an iOS habit tracker with a journal/paper aesthetic. SwiftUI + SwiftData + CloudKit sync. Custom "PatrickHand" handwritten font throughout.

### Targets (5 total)

| Target | Purpose |
|--------|---------|
| **Sown** | Main app |
| **HabitMonitor** | DeviceActivityMonitor extension — enforces Screen Time blocks on schedule |
| **HabitShieldConfig** | Customizes the shield UI shown when blocked app is opened |
| **HabitShieldAction** | Handles button taps on shield ("Open Sown" / "Close") |
| **SownWidgetExtension** | Home screen widget showing today's progress |

All 5 targets share data via App Group `group.com.incept5.SeedBed` using UserDefaults (extensions cannot access SwiftData directly).

## Architecture

### State Management

- `@Observable` pattern (Swift 5.9+), not `@StateObject`
- `HabitStore` is the central state manager — takes `ModelContext`, exposes filtered views of habits
- `completionChangeCounter: Int` is incremented on any change; views observe this single value for efficient re-render
- `prefetchDailyLogs()` pre-loads today's logs to prevent lazy-loading faults blocking the main thread

### Navigation

Tab-based with 5 tabs: **Today** (TodayView) → **Month** (MonthGridView) → **Block** (BlockTabView) → **Journal** (JournalView) → **Stats** (StatsView). Onboarding gate via `hasCompletedOnboarding` flag.

Deep links: `sown://intercept` (from blocked app), `sown://today`.

### Data Models (all `@Model` for SwiftData)

- **Habit** — Core entity for both recurring habits and one-off tasks (`isTask` = `frequencyType == .once`). Has tier (mustDo/niceToDo), type (positive/negative), frequency, HealthKit linking, schedule times, optional photo/notes support.
- **DailyLog** — One entry per habit per date. Tracks completion, value, notes, photos, auto-completion flags.
- **HabitGroup** — Bundles habits with "complete X of Y" logic. References habits by UUID array.
- **DayRecord** — Locks "good day" status at midnight. Prevents gaming by adding easy habits after the fact.
- **EndOfDayNote** — Evening reflection with fulfillment score (1-10). Editable for 48 hours, then auto-locked.
- **BlockSettings** — **Not a @Model**. Stored in UserDefaults (shared via App Group). Manages app blocking config.

### Services (observable singletons with `.shared`)

- **CloudSyncService** — Creates ModelContainer with/without CloudKit. Handles sync opt-in.
- **CloudSettingsService** — Persists non-model settings (wake/bed times, blocking flags) to CloudKit.
- **HealthKitManager** — Auto-completes habits when HealthKit targets are met.
- **ScreenTimeManager** — FamilyControls authorization + app shielding via ManagedSettings.
- **UnifiedNotificationService** — Schedules reminders within iOS's 64-notification budget (44 habits + 20 task deadlines). Uses 5 time slots mapped to wall-clock times via UserSchedule.
- **UserSchedule** — Wake/bed times. Drives notification slot → actual time mapping.
- **PhotoStorageService / CloudPhotoService** — Local + iCloud photo storage for hobby logs.
- **SoundEffectService** — Completion/unlock sounds. Pre-warms audio at launch.
- **WidgetDataService** — Pushes habit data to App Group defaults for widget reads.

### Key Files

- `HabitStore.swift` — Central state management
- `JournalTheme.swift` — Colors, fonts, dimensions, Feedback enum
- `SownApp.swift` — App entry, ModelContainer setup, deep link handling
- `ContentView.swift` — Tab bar layout
- `SownSchemaVersions.swift` — SwiftData migration setup

## UI Rules

### Text Contrast

- **Light backgrounds** (paper, paperLight, white): use dark text (`inkBlack`, `navy`, `completedGray` for secondary). Never use system default text color.
- **Dark backgrounds** (navy, inkBlue, teal): use white or light text.
- **Placeholder text**: always set explicitly via `prompt:` parameter with `completedGray`.
- **DatePickers**: always add `.environment(\.colorScheme, .light)`. For `.compact`, also `.fixedSize()`. For `.wheel`, also `.frame(maxWidth: .infinity)` and `.clipped()`.
- **Every new feature**: verify all text/controls have sufficient contrast. System defaults assume pure white background.

## SwiftData + CloudKit Patterns

### Enum Properties

SwiftData macros lose type info on enum defaults. Store raw String value, expose enum via computed property:

```swift
// ❌ BAD
var tier: HabitTier = .mustDo

// ✅ GOOD
private var tierRawValue: String = HabitTier.mustDo.rawValue
var tier: HabitTier {
    get { HabitTier(rawValue: tierRawValue) ?? .mustDo }
    set { tierRawValue = newValue.rawValue }
}
```

### Relationships Must Be Optional

CloudKit requires optional relationships (data may arrive out-of-order during sync):

```swift
// ❌ BAD
@Relationship(deleteRule: .cascade, inverse: \DailyLog.habit)
var dailyLogs: [DailyLog] = []

// ✅ GOOD
@Relationship(deleteRule: .cascade, inverse: \DailyLog.habit)
var dailyLogs: [DailyLog]?
```

Access with: `(habit.dailyLogs ?? []).filter { }`, `habit.dailyLogs?.first { }`

### ModelContainer Crash After Schema Changes

If you see `SwiftDataError._Error.loadIssueModelContainer` after changing model properties:
- **Dev fix:** Delete app from simulator (long-press → Delete App) and reinstall
- **Production:** Add a `VersionedSchema` + `SchemaMigrationPlan` in `SownSchemaVersions.swift`

### Schema Migrations

Safe (no migration needed): adding optional properties, adding properties with defaults.

Breaking (migration required): renaming, type changes, removing properties, making optional → required.

To add a version: create `SownSchemaV{N}` enum, add to migration plan's `schemas` array, add a `MigrationStage` (.lightweight or .custom), update `CloudSyncService.makeModelContainer()`.

### CloudKit Background Mode

CloudKit push notifications require `remote-notification` in UIBackgroundModes (Info.plist or Signing & Capabilities → Background Modes → Remote notifications).

## Non-Obvious Behaviors

- **Good day lock**: `DayRecord.lockedAt` freezes good-day status at midnight. Adding new habits won't retroactively change it.
- **Block-wipe on reinstall**: If app blocking was active when uninstalled, the cloud flag triggers a data wipe on reinstall to prevent bypass.
- **Notification budget**: iOS allows max 64 scheduled notifications. The app budgets 44 for habit reminders + 20 for task deadlines. Don't schedule naively.
- **Time slots**: Habits use 5 abstract slots (After Wake, Morning, During Day, Evening, Before Bed) mapped to real times via UserSchedule wake/bed times, not arbitrary clock times.

## Future Features

### Auto-Generated Habit Prompts

**Status:** Planned. Use an LLM to auto-generate motivational micro-habit prompts (e.g., "Put on your trainers and step outside" for a Run habit). Currently users must write these manually. Potential approaches: on-device models, API-based generation, or pre-generated templates.
