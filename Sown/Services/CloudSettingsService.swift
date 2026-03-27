import Foundation

/// Service for syncing user settings to iCloud via NSUbiquitousKeyValueStore.
/// Syncs: userName, onboarding status, wake/bed times, sound effects, smart reminders
@Observable
final class CloudSettingsService {
    static let shared = CloudSettingsService()

    private let store = NSUbiquitousKeyValueStore.default
    private let localDefaults = UserDefaults.standard
    private var retryTimer: Timer?

    // MARK: - Keys

    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let iCloudSyncEnabled = "iCloudSyncEnabled"
        static let userName = "userName"
        static let soundEffectsEnabled = "soundEffectsEnabled"
        static let wakeTimeMinutes = "userWakeTimeMinutes"
        static let bedTimeMinutes = "userBedTimeMinutes"
        static let smartRemindersEnabled = "smartRemindersEnabled"
        static let blockingEnabledFlag = "blockingEnabled"
    }

    // MARK: - Initialization

    private init() {
        // Pull any cached iCloud data from disk before reading
        store.synchronize()

        // Start observing external changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleExternalChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )

        // Check iCloud for onboarding status immediately
        checkOnboardingFromCloud()

        // If onboarding wasn't restored immediately, poll iCloud for a few seconds
        // (on reinstall, iCloud KV data may not be available until after init)
        if !localDefaults.bool(forKey: Keys.hasCompletedOnboarding)
            && !localDefaults.bool(forKey: "dataWipedOnReinstall") {
            startOnboardingRetry()
        }
    }

    // MARK: - Onboarding Check

    /// Check iCloud for onboarding status and update local storage if needed.
    /// This ensures users don't have to re-onboard after reinstalling or on a new device.
    func checkOnboardingFromCloud() {
        // Only check if local says we haven't onboarded
        guard !localDefaults.bool(forKey: Keys.hasCompletedOnboarding) else { return }

        // Don't restore onboarding if a wipe just occurred
        guard !localDefaults.bool(forKey: "dataWipedOnReinstall") else { return }

        // Check if iCloud says we have onboarded
        if store.bool(forKey: Keys.hasCompletedOnboarding) {
            localDefaults.set(true, forKey: Keys.hasCompletedOnboarding)
            print("CloudSettingsService: Restored onboarding status from iCloud")
        }
    }

    /// Poll iCloud every 0.5s for up to 3s to catch delayed KV sync on reinstall.
    private func startOnboardingRetry() {
        var attempts = 0
        retryTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            attempts += 1
            self.store.synchronize()
            self.checkOnboardingFromCloud()
            self.restoreCloudSyncSettingIfNeeded()

            if self.localDefaults.bool(forKey: Keys.hasCompletedOnboarding) || attempts >= 6 {
                timer.invalidate()
                self.retryTimer = nil
            }
        }
    }

    /// Returns true if onboarding has been completed (checks both local and cloud)
    var hasCompletedOnboarding: Bool {
        localDefaults.bool(forKey: Keys.hasCompletedOnboarding) || store.bool(forKey: Keys.hasCompletedOnboarding)
    }

    // MARK: - iCloud Sync Setting

    /// Check iCloud for sync enabled status and restore it if needed.
    /// IMPORTANT: This must be called BEFORE creating the ModelContainer.
    /// Returns true if iCloud sync should be enabled.
    @discardableResult
    func restoreCloudSyncSettingIfNeeded() -> Bool {
        // If local already has it enabled, we're good
        if localDefaults.bool(forKey: Keys.iCloudSyncEnabled) {
            return true
        }

        // Only restore if iCloud explicitly has sync enabled (user toggled it on before)
        if store.bool(forKey: Keys.iCloudSyncEnabled) {
            localDefaults.set(true, forKey: Keys.iCloudSyncEnabled)
            print("CloudSettingsService: Restored iCloud sync setting from cloud")
            return true
        }

        return false
    }

    /// Sync the iCloud enabled setting to cloud
    func syncCloudSyncSetting(_ enabled: Bool) {
        store.set(enabled, forKey: Keys.iCloudSyncEnabled)
    }

    // MARK: - Blocking Flag (Dead Man's Switch)

    /// Write the blocking-enabled flag to iCloud KV store.
    /// Called when blocking is toggled on/off.
    func setBlockingFlag(_ enabled: Bool) {
        store.set(enabled, forKey: Keys.blockingEnabledFlag)
    }

    /// Detect a reinstall while blocking was active.
    /// Returns true if data should be wiped (blocking was on when app was deleted).
    /// Must be called BEFORE creating the ModelContainer.
    func checkAndHandleBlockingWipe() -> Bool {
        // Was blocking enabled when the app was last running?
        guard store.bool(forKey: Keys.blockingEnabledFlag) else { return false }

        // Is this a reinstall? Local onboarding is false, but iCloud says we onboarded before
        let localOnboarded = localDefaults.bool(forKey: Keys.hasCompletedOnboarding)
        let cloudOnboarded = store.bool(forKey: Keys.hasCompletedOnboarding)

        guard !localOnboarded && cloudOnboarded else { return false }

        // This is a reinstall with blocking active — force local-only mode and flag for wipe
        localDefaults.set(false, forKey: Keys.iCloudSyncEnabled)
        localDefaults.set(true, forKey: "dataWipedOnReinstall")

        print("CloudSettingsService: Reinstall detected with blocking active — wiping data")
        return true
    }

    // MARK: - Sync to Cloud

    /// Push all local settings to iCloud (called on first sync enable)
    func pushAllSettingsToCloud() {
        guard CloudSyncService.shared.isEnabled else { return }

        // iCloud sync enabled (so it's restored on reinstall)
        store.set(true, forKey: Keys.iCloudSyncEnabled)

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

        // Reminder overrides
        for i in 1...5 {
            let key = "reminder\(i)Override"
            if localDefaults.object(forKey: key) != nil {
                store.set(localDefaults.integer(forKey: key), forKey: key)
            }
        }

        // System will sync automatically
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

    }

    // MARK: - External Change Handling

    @objc private func handleExternalChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonKey = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }

        // Always process bootstrap keys (onboarding + sync setting), even if sync
        // isn't formally enabled yet. These are what restore the user's state on reinstall.
        if !localDefaults.bool(forKey: "dataWipedOnReinstall") {
            if store.bool(forKey: Keys.hasCompletedOnboarding) {
                localDefaults.set(true, forKey: Keys.hasCompletedOnboarding)
            }
            if store.bool(forKey: Keys.iCloudSyncEnabled) {
                localDefaults.set(true, forKey: Keys.iCloudSyncEnabled)
            }
        }

        guard CloudSyncService.shared.isEnabled else { return }

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
        let changedKeys = Array(store.dictionaryRepresentation.keys)

        for key in changedKeys {
            switch key {
            case Keys.hasCompletedOnboarding:
                if store.bool(forKey: key) {
                    localDefaults.set(true, forKey: key)
                }

            case Keys.iCloudSyncEnabled:
                // Note: This is mainly handled at app startup via restoreCloudSyncSettingIfNeeded()
                // but we also update here for completeness
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

            case _ where key.hasPrefix("reminder") && key.hasSuffix("Override"):
                let value = Int(store.longLong(forKey: key))
                if value >= 0 {
                    localDefaults.set(value, forKey: key)
                } else {
                    localDefaults.removeObject(forKey: key)
                }
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
    static let smartRemindersChanged = Notification.Name("smartRemindersChanged")
}
