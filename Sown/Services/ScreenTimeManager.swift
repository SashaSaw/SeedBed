import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import SwiftUI

/// Manages Screen Time integration: authorization, app shielding, and schedule monitoring
@Observable
final class ScreenTimeManager {
    static let shared = ScreenTimeManager()

    // MARK: - State

    /// Whether the user has granted FamilyControls authorization
    var isAuthorized: Bool = false

    /// The user's selected apps/categories to block
    var activitySelection = FamilyActivitySelection() {
        didSet {
            saveSelection()
            // When selection changes while blocking is active, update shields
            if BlockSettings.shared.isEnabled {
                applyShields()
            }
        }
    }

    /// Whether shields are currently applied
    var isShielding: Bool = false

    /// Apps blocked due to Don't Do limit exceeded (separate from schedule)
    private var failureBlockedApps: Set<ApplicationToken> = []

    // MARK: - Private

    private static let failureBlockedAppsKey = "failureBlockedApps"
    private let settingsStore = ManagedSettingsStore()
    private let activityCenter = DeviceActivityCenter()
    private static let selectionKey = "screenTimeSelection"
    private static let authorizationKey = "screenTimeAuthorizationGranted"

    /// App Group identifier for sharing data between main app and extensions
    static let appGroupID = "group.com.incept5.SeedBed"

    /// Shared UserDefaults for app ↔ extension communication
    private var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: Self.appGroupID) ?? .standard
    }

    // The activity name for our blocking schedule
    private let blockingActivity = DeviceActivityName("sown.blocking")

    private init() {
        // Check existing authorization status
        checkAuthorization()
        // Load saved selection
        loadSelection()
        // Load failure-blocked apps from shared defaults
        loadFailureBlockedApps()
    }

    // MARK: - Authorization

    /// Request FamilyControls authorization from the user
    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            await MainActor.run {
                isAuthorized = true
                // Persist authorization state
                UserDefaults.standard.set(true, forKey: Self.authorizationKey)
                sharedDefaults.set(true, forKey: Self.authorizationKey)
            }
        } catch {
            print("ScreenTimeManager: Authorization failed: \(error)")
            await MainActor.run {
                isAuthorized = false
            }
        }
    }

    /// Check current authorization status
    private func checkAuthorization() {
        // Check live status first
        if AuthorizationCenter.shared.authorizationStatus == .approved {
            isAuthorized = true
            return
        }

        // Fall back to persisted state (API may not be ready immediately after app launch)
        let persistedAuth = sharedDefaults.bool(forKey: Self.authorizationKey)
            || UserDefaults.standard.bool(forKey: Self.authorizationKey)
        isAuthorized = persistedAuth
    }

    // MARK: - Shielding

    /// Apply shields to the selected apps — they'll show a system shield when opened
    func applyShields() {
        // Combine schedule-blocked apps with failure-blocked apps
        var applications = activitySelection.applicationTokens
        applications.formUnion(failureBlockedApps)
        let categories = activitySelection.categoryTokens

        if applications.isEmpty && categories.isEmpty {
            removeShields()
            return
        }

        settingsStore.shield.applications = applications.isEmpty ? nil : applications
        settingsStore.shield.applicationCategories = categories.isEmpty
            ? nil
            : ShieldSettings.ActivityCategoryPolicy<Application>.specific(categories)

        isShielding = true
    }

    /// Remove all shields — apps become accessible again
    func removeShields() {
        settingsStore.shield.applications = nil
        settingsStore.shield.applicationCategories = nil
        isShielding = false
    }

    // MARK: - Failure Blocking (Don't Do habits)

    /// Block a specific app due to exceeding a Don't Do limit
    func blockAppForFailure(_ appToken: ApplicationToken) {
        failureBlockedApps.insert(appToken)
        saveFailureBlockedApps()
        applyShields()
    }

    /// Clear all failure-blocked apps (called at midnight)
    func clearFailureBlocks() {
        failureBlockedApps.removeAll()
        saveFailureBlockedApps()
        // Re-apply shields to remove the failure blocks but keep schedule blocks
        if BlockSettings.shared.isEnabled {
            applyShields()
        } else {
            removeShields()
        }
    }

    /// Load failure-blocked apps from shared defaults
    private func loadFailureBlockedApps() {
        let blockedAppsData = sharedDefaults.array(forKey: Self.failureBlockedAppsKey) as? [Data] ?? []
        failureBlockedApps = Set(blockedAppsData.compactMap { data in
            try? PropertyListDecoder().decode(ApplicationToken.self, from: data)
        })
    }

    /// Save failure-blocked apps to shared defaults
    private func saveFailureBlockedApps() {
        let blockedAppsData = failureBlockedApps.compactMap { token in
            try? PropertyListEncoder().encode(token)
        }
        sharedDefaults.set(blockedAppsData, forKey: Self.failureBlockedAppsKey)
    }

    /// Sync failure-blocked apps from extension (call on app become active)
    func syncFailureBlockedApps() {
        loadFailureBlockedApps()
        if !failureBlockedApps.isEmpty && BlockSettings.shared.isEnabled {
            applyShields()
        }
    }

    // MARK: - Schedule Monitoring

    /// Start monitoring the block schedule — registers one activity per schedule entry
    func startMonitoring() {
        let blockSettings = BlockSettings.shared

        // Stop all existing monitoring first
        var activitiesToStop = [blockingActivity]
        // Also stop any per-day activities
        for day in 1...7 {
            activitiesToStop.append(DeviceActivityName("sown.block.\(day)"))
        }
        activityCenter.stopMonitoring(activitiesToStop)

        // Register one activity per schedule entry
        for entry in blockSettings.scheduleEntries {
            let startHour = entry.startMinutes / 60
            let startMinute = entry.startMinutes % 60
            let endHour = entry.endMinutes / 60
            let endMinute = entry.endMinutes % 60

            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: startHour, minute: startMinute),
                intervalEnd: DateComponents(hour: endHour, minute: endMinute),
                repeats: true
            )

            let activityName = DeviceActivityName("sown.block.\(entry.dayOfWeek)")

            do {
                try activityCenter.startMonitoring(activityName, during: schedule)
            } catch {
                print("ScreenTimeManager: Failed to start monitoring for day \(entry.dayOfWeek): \(error)")
            }
        }

        // Save day-of-week mapping to shared defaults so the extension can check
        let dayMapping = blockSettings.scheduleEntries.map { $0.dayOfWeek }
        sharedDefaults.set(dayMapping, forKey: "blockScheduleDays")
    }

    /// Stop monitoring the schedule
    func stopMonitoring() {
        var activitiesToStop = [blockingActivity]
        for day in 1...7 {
            activitiesToStop.append(DeviceActivityName("sown.block.\(day)"))
        }
        activityCenter.stopMonitoring(activitiesToStop)
        removeShields()
    }

    // MARK: - Enable / Disable (called from BlockSetupView)

    /// Enable blocking: apply shields + start schedule monitoring
    func enableBlocking() {
        applyShields()
        startMonitoring()
    }

    /// Disable blocking: remove shields + stop monitoring
    func disableBlocking() {
        stopMonitoring()
    }

    /// Called when the schedule or selection changes while blocking is enabled
    func updateBlocking() {
        guard BlockSettings.shared.isEnabled else { return }
        applyShields()
        startMonitoring()
    }

    // MARK: - Temporary Unlock

    /// Temporarily remove all shields for 5 minutes, then re-apply them.
    /// The Screen Time API uses opaque tokens — we cannot identify individual apps,
    /// so we remove ALL shields and restore them after the timeout.
    func grantTemporaryUnlock(minutes: Double = 5) {
        // Remove all shields immediately
        removeShields()

        // Re-apply after the timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + minutes * 60) { [weak self] in
            guard let self, BlockSettings.shared.isEnabled else { return }
            self.applyShields()
        }
    }

    // MARK: - Persistence

    private func saveSelection() {
        let encoder = PropertyListEncoder()
        if let data = try? encoder.encode(activitySelection) {
            // Save to both standard and shared defaults
            UserDefaults.standard.set(data, forKey: Self.selectionKey)
            sharedDefaults.set(data, forKey: Self.selectionKey)
        }
    }

    private func loadSelection() {
        // Try shared defaults first, fall back to standard
        let data = sharedDefaults.data(forKey: Self.selectionKey)
            ?? UserDefaults.standard.data(forKey: Self.selectionKey)
        guard let data else { return }
        let decoder = PropertyListDecoder()
        if let selection = try? decoder.decode(FamilyActivitySelection.self, from: data) {
            activitySelection = selection
        }
    }
}
