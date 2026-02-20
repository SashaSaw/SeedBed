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
            // IMPORTANT: Restore iCloud sync setting from cloud BEFORE creating container
            // This ensures returning users get their habits synced
            CloudSettingsService.shared.restoreCloudSyncSettingIfNeeded()

            // Use CloudSyncService to create container with appropriate iCloud settings
            return try CloudSyncService.shared.makeModelContainer()
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
        if response.notification.request.content.categoryIdentifier == "OPEN_SOWN" {
            // Write the flag so ContentView shows InterceptView
            let defaults = UserDefaults(suiteName: "group.com.incept5.SeedBed")
            defaults?.set(Date().timeIntervalSince1970, forKey: "interceptRequested")
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
