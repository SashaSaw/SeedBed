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

    // MARK: - Private

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

    /// Remove all shields — apps become accessible again
    func removeShields() {
        settingsStore.shield.applications = nil
        settingsStore.shield.applicationCategories = nil
        isShielding = false
    }

    // MARK: - Schedule Monitoring

    /// Start monitoring the block schedule — shields will be applied/removed automatically
    func startMonitoring() {
        let blockSettings = BlockSettings.shared

        let startHour = blockSettings.scheduleStartMinutes / 60
        let startMinute = blockSettings.scheduleStartMinutes % 60
        let endHour = blockSettings.scheduleEndMinutes / 60
        let endMinute = blockSettings.scheduleEndMinutes % 60

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: startHour, minute: startMinute),
            intervalEnd: DateComponents(hour: endHour, minute: endMinute),
            repeats: true
        )

        do {
            // Stop any existing monitoring first
            activityCenter.stopMonitoring([blockingActivity])
            // Start fresh
            try activityCenter.startMonitoring(blockingActivity, during: schedule)
        } catch {
            print("ScreenTimeManager: Failed to start monitoring: \(error)")
        }
    }

    /// Stop monitoring the schedule
    func stopMonitoring() {
        activityCenter.stopMonitoring([blockingActivity])
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
