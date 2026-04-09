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
            // Skip during init to avoid circular dependency with BlockSettings.shared
            guard !isLoading, BlockSettings.shared.isEnabled else { return }
            applyShields()
        }
    }

    /// Whether shields are currently applied
    var isShielding: Bool = false

    /// Apps blocked due to Don't Do limit exceeded (separate from schedule)
    private var failureBlockedApps: Set<ApplicationToken> = []

    /// True during init — prevents applyShields() from being called before init completes
    /// (avoids circular dependency deadlock with BlockSettings.shared)
    private var isLoading = false

    // MARK: - Private

    private static let failureBlockedAppsKey = "failureBlockedApps"
    private let settingsStore = ManagedSettingsStore(named: .init("sown.blocking"))
    private let failureStore = ManagedSettingsStore(named: .init("sown.failure"))
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
        // Load saved selection (isLoading flag prevents applyShields deadlock)
        isLoading = true
        loadSelection()
        isLoading = false
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

    /// Apply schedule shields to the selected apps (only during active schedule windows).
    func applyShields() {
        let applications = activitySelection.applicationTokens
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

    /// Remove schedule shields — apps become accessible again.
    /// Does NOT touch failure shields (those persist until midnight).
    func removeShields() {
        settingsStore.shield.applications = nil
        settingsStore.shield.applicationCategories = nil
        isShielding = !hasActiveFailureShields

    }

    /// Apply failure shields for Don't-Do apps that exceeded their limit.
    /// These persist until midnight regardless of schedule.
    private func applyFailureShields() {
        guard !failureBlockedApps.isEmpty else { return }
        failureStore.shield.applications = failureBlockedApps
        isShielding = true

    }

    /// Remove failure shields (called at midnight).
    private func removeFailureShields() {
        failureStore.shield.applications = nil
        failureStore.shield.applicationCategories = nil
        isShielding = settingsStore.shield.applications != nil

    }

    /// Whether the failure store has active shields
    private var hasActiveFailureShields: Bool {
        failureStore.shield.applications != nil
    }

    /// Whether the failure store has active shields (used by intercept guard)
    var failureStoreHasShields: Bool {
        failureStore.shield.applications != nil
    }

    // MARK: - Failure Blocking (Don't Do habits)

    /// Block a specific app due to exceeding a Don't Do limit.
    /// Uses the failure store — persists until midnight regardless of schedule.
    func blockAppForFailure(_ appToken: ApplicationToken) {
        failureBlockedApps.insert(appToken)
        saveFailureBlockedApps()
        applyFailureShields()
    }

    /// Clear all failure-blocked apps (called at midnight)
    func clearFailureBlocks() {
        failureBlockedApps.removeAll()
        saveFailureBlockedApps()
        removeFailureShields()
        clearFailureBlockedHabitInfo()
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

    /// Clear failure-blocked habit info from shared defaults (called at midnight)
    private func clearFailureBlockedHabitInfo() {
        sharedDefaults.removeObject(forKey: "failureBlockedHabitInfo")
    }

    /// Whether a specific habit has an active failure block
    func hasActiveFailureBlock(habitId: String) -> Bool {
        let info = sharedDefaults.array(forKey: "failureBlockedHabitInfo") as? [[String: Any]] ?? []
        return info.contains { ($0["habitId"] as? String) == habitId }
    }

    /// Get all failure-blocked habit info (for debug overlay)
    func failureBlockedHabitInfo() -> [[String: Any]] {
        sharedDefaults.array(forKey: "failureBlockedHabitInfo") as? [[String: Any]] ?? []
    }

    /// Remove failure block for a specific habit (e.g., when habit is deleted)
    func clearFailureBlock(forHabitId habitId: String) {
        // Remove from habit info
        var info = sharedDefaults.array(forKey: "failureBlockedHabitInfo") as? [[String: Any]] ?? []
        info.removeAll { ($0["habitId"] as? String) == habitId }
        if info.isEmpty {
            sharedDefaults.removeObject(forKey: "failureBlockedHabitInfo")
        } else {
            sharedDefaults.set(info, forKey: "failureBlockedHabitInfo")
        }

        // If no failure blocks remain, clear the failure store
        if info.isEmpty {
            failureBlockedApps.removeAll()
            saveFailureBlockedApps()
            removeFailureShields()
        }
    }

    /// Clean up stale failure blocks for habits that no longer exist.
    /// Call on app launch with the set of existing habit IDs.
    func cleanupStaleFailureBlocks(existingHabitIds: Set<String>) {
        let info = sharedDefaults.array(forKey: "failureBlockedHabitInfo") as? [[String: Any]] ?? []
        let staleIds = info.compactMap { $0["habitId"] as? String }.filter { !existingHabitIds.contains($0) }
        for id in staleIds {
            clearFailureBlock(forHabitId: id)
        }
    }

    /// Sync failure-blocked apps from extension (call on app become active).
    /// Uses the failure store — independent of schedule.
    func syncFailureBlockedApps() {
        loadFailureBlockedApps()
        if !failureBlockedApps.isEmpty {
            applyFailureShields()
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

    /// Enable blocking: start schedule monitoring, then apply shields only if within schedule
    func enableBlocking() {

        startMonitoring()
        if BlockSettings.shared.isCurrentlyActive {
            applyShields()
        }
    }

    /// Disable blocking: remove all shields + stop monitoring
    func disableBlocking() {

        stopMonitoring()
        removeFailureShields()
        failureBlockedApps.removeAll()
        saveFailureBlockedApps()
        clearFailureBlockedHabitInfo()
    }

    /// Called when the schedule or selection changes while blocking is enabled
    func updateBlocking() {
        guard BlockSettings.shared.isEnabled else { return }

        startMonitoring()
        if BlockSettings.shared.isCurrentlyActive {
            applyShields()
        } else {
            removeShields()
        }
    }

    /// Reconcile shield state with current schedule (call on app foreground).
    func reconcileShields() {
        let bs = BlockSettings.shared

        guard bs.isEnabled else {
            removeShields()
            removeFailureShields()
            return
        }
        if bs.isCurrentlyActive {
            applyShields()
        } else {
            removeShields()
        }
        syncFailureBlockedApps()
    }

    // MARK: - Temporary Unlock

    /// When the current temporary unlock expires (nil = no active unlock)
    private(set) var temporaryUnlockExpiry: Date?

    /// Temporarily remove all shields for 5 minutes, then re-apply them.
    /// The Screen Time API uses opaque tokens — we cannot identify individual apps,
    /// so we remove ALL shields and restore them after the timeout.
    func grantTemporaryUnlock(minutes: Double = 5) {

        let expiry = Date().addingTimeInterval(minutes * 60)
        temporaryUnlockExpiry = expiry

        // Remove all shields immediately
        removeShields()

        // Re-apply after the timeout. The expiry check ensures stale timers
        // from previous unlocks don't re-block prematurely.
        DispatchQueue.main.asyncAfter(deadline: .now() + minutes * 60) { [weak self] in
            guard let self,
                  BlockSettings.shared.isEnabled,
                  BlockSettings.shared.isCurrentlyActive else {
                self?.temporaryUnlockExpiry = nil
                return
            }
            // Only re-block if this timer's expiry is still the current one
            guard let currentExpiry = self.temporaryUnlockExpiry, currentExpiry <= expiry else { return }
            self.temporaryUnlockExpiry = nil
            self.applyShields()
        }
    }

    /// Whether apps are temporarily unlocked right now
    var isTemporarilyUnlocked: Bool {
        guard let expiry = temporaryUnlockExpiry else { return false }
        return Date() < expiry
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
