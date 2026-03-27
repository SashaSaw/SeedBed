//
//  SownApp.swift
//  Sown
//
//  Created by Alexander Saw on 02/02/2026.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct SownApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        do {
            // Check if this is a reinstall while blocking was active — if so, wipe data
            let shouldWipe = CloudSettingsService.shared.checkAndHandleBlockingWipe()

            if !shouldWipe {
                // IMPORTANT: Restore iCloud sync setting from cloud BEFORE creating container
                // This ensures returning users get their habits synced
                CloudSettingsService.shared.restoreCloudSyncSettingIfNeeded()
            }

            // Use CloudSyncService to create container with appropriate iCloud settings
            // (if shouldWipe, iCloudSyncEnabled is already forced off so this creates local-only)
            let container = try CloudSyncService.shared.makeModelContainer()

            if shouldWipe {
                // Delete cloud data in background so it can't sync back
                Task {
                    await CloudSyncService.shared.deleteCloudData()
                }
            }

            return container
        } catch {
            // Fallback to local-only container if cloud initialization fails
            print("CloudKit container creation failed, falling back to local: \(error)")
            let schema = Schema(versionedSchema: SownSchemaV1.self)
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            do {
                return try ModelContainer(
                    for: schema,
                    migrationPlan: SownMigrationPlan.self,
                    configurations: [modelConfiguration]
                )
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    init() {
        // Sound effects enabled by default on first launch
        UserDefaults.standard.register(defaults: ["soundEffectsEnabled": true])

        // Pre-load sound effects in background so first tap doesn't hang
        SoundEffectService.warmUp()

        // Prepare haptic generators so first tap doesn't block on XPC connection
        Feedback.warmUp()

        // Request notification permission on app launch
        Task {
            _ = await NotificationService.shared.requestPermission()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - App Delegate for Notification Handling

/// Handles notification delegate so tapping "Open Sown" notification opens the app
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Called when a notification is tapped — the app is already opening, so just make sure
    /// the intercept flag is set so ContentView picks it up
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let category = response.notification.request.content.categoryIdentifier

        if category == "OPEN_SOWN" {
            // Write the flag so ContentView shows InterceptView
            let defaults = UserDefaults(suiteName: "group.com.incept5.SeedBed")
            defaults?.set(Date().timeIntervalSince1970, forKey: "interceptRequested")
        } else if category == "HABIT_REMINDER" || category == "TASK_REMINDER" {
            // Deep link to habit/task
            if let habitId = userInfo["habitId"] as? String,
               let type = userInfo["type"] as? String {
                let defaults = UserDefaults.standard
                defaults.set(habitId, forKey: "pendingNavigationHabitId")
                defaults.set(type, forKey: "pendingNavigationType")
                defaults.set(Date().timeIntervalSince1970, forKey: "pendingNavigationTime")
            }
        }
        completionHandler()
    }

    /// Show notifications even when the app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // If it's our "open Sown" notification and the app is already open, suppress it
        // and just show the intercept view directly
        if notification.request.content.categoryIdentifier == "OPEN_SOWN" {
            completionHandler([]) // suppress — the app is already open
        } else {
            completionHandler([.banner, .sound])
        }
    }
}
