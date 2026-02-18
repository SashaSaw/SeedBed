import Foundation

/// Service for syncing user settings to iCloud via NSUbiquitousKeyValueStore.
/// Syncs: userName, onboarding status, wake/bed times, sound effects, smart reminders
@Observable
final class CloudSettingsService {
    static let shared = CloudSettingsService()

    private let store = NSUbiquitousKeyValueStore.default
    private let localDefaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let userName = "userName"
        static let soundEffectsEnabled = "soundEffectsEnabled"
        static let wakeTimeMinutes = "userWakeTimeMinutes"
        static let bedTimeMinutes = "userBedTimeMinutes"
        static let smartRemindersEnabled = "smartRemindersEnabled"
    }

    // MARK: - Initialization

    private init() {
        // Start observing external changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleExternalChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )

        // Synchronize on launch
        store.synchronize()
    }

    // MARK: - Sync to Cloud

    /// Push all local settings to iCloud (called on first sync enable)
    func pushAllSettingsToCloud() {
        guard CloudSyncService.shared.isEnabled else { return }

        // Onboarding status
        if localDefaults.bool(forKey: Keys.hasCompletedOnboarding) {
            store.set(true, forKey: Keys.hasCompletedOnboarding)
        }

        // User name
        if let name = localDefaults.string(forKey: Keys.userName) {
            store.set(name, forKey: Keys.userName)
        }

        // Sound effects
        store.set(localDefaults.bool(forKey: Keys.soundEffectsEnabled), forKey: Keys.soundEffectsEnabled)

        // Schedule times
        let wakeTime = localDefaults.integer(forKey: Keys.wakeTimeMinutes)
        if wakeTime > 0 {
            store.set(wakeTime, forKey: Keys.wakeTimeMinutes)
        }

        let bedTime = localDefaults.integer(forKey: Keys.bedTimeMinutes)
        if bedTime > 0 {
            store.set(bedTime, forKey: Keys.bedTimeMinutes)
        }

        // Smart reminders
        store.set(localDefaults.bool(forKey: Keys.smartRemindersEnabled), forKey: Keys.smartRemindersEnabled)

        // Force sync
        store.synchronize()
    }

    /// Update a specific setting in cloud (called when setting changes)
    func updateSetting(_ key: String, value: Any) {
        guard CloudSyncService.shared.isEnabled else { return }

        switch value {
        case let boolValue as Bool:
            store.set(boolValue, forKey: key)
        case let intValue as Int:
            store.set(intValue, forKey: key)
        case let stringValue as String:
            store.set(stringValue, forKey: key)
        default:
            break
        }

        store.synchronize()
    }

    // MARK: - External Change Handling

    @objc private func handleExternalChange(_ notification: Notification) {
        guard CloudSyncService.shared.isEnabled else { return }

        guard let userInfo = notification.userInfo,
              let reasonKey = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }

        // Handle different change reasons
        switch reasonKey {
        case NSUbiquitousKeyValueStoreServerChange,
             NSUbiquitousKeyValueStoreInitialSyncChange:
            pullSettingsFromCloud()
        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            print("iCloud key-value storage quota exceeded")
        case NSUbiquitousKeyValueStoreAccountChange:
            // Account changed, pull new data
            pullSettingsFromCloud()
        default:
            break
        }
    }

    /// Pull settings from cloud to local storage
    private func pullSettingsFromCloud() {
        guard let changedKeys = store.dictionaryRepresentation.keys as? [String] else { return }

        for key in changedKeys {
            switch key {
            case Keys.hasCompletedOnboarding:
                if store.bool(forKey: key) {
                    localDefaults.set(true, forKey: key)
                }

            case Keys.userName:
                if let name = store.string(forKey: key), !name.isEmpty {
                    localDefaults.set(name, forKey: key)
                }

            case Keys.soundEffectsEnabled:
                localDefaults.set(store.bool(forKey: key), forKey: key)

            case Keys.wakeTimeMinutes, Keys.bedTimeMinutes:
                let value = Int(store.longLong(forKey: key))
                if value > 0 {
                    localDefaults.set(value, forKey: key)
                    // Notify UserSchedule to reload
                    NotificationCenter.default.post(name: .scheduleSettingsChanged, object: nil)
                }

            case Keys.smartRemindersEnabled:
                localDefaults.set(store.bool(forKey: key), forKey: key)
                NotificationCenter.default.post(name: .scheduleSettingsChanged, object: nil)

            default:
                break
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let scheduleSettingsChanged = Notification.Name("scheduleSettingsChanged")
}
