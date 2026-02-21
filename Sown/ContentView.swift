//
//  ContentView.swift
//  Sown
//
//  Created by Alexander Saw on 02/02/2026.
//

import SwiftUI
import SwiftData
import UIKit

/// Main app view with tab navigation
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab = 0
    @State private var habitStore: HabitStore?
    @State private var showingInterceptView = false
    @State private var pendingNavigationHabit: Habit? = nil
    @State private var showingHabitDetail = false

    init() {
        // Custom font for tab bar and navigation
        let patrickHand = UIFont(name: "PatrickHand-Regular", size: 10) ?? UIFont.systemFont(ofSize: 10)
        let navTitleFont = UIFont(name: "PatrickHand-Regular", size: 17) ?? UIFont.systemFont(ofSize: 17)
        let largeTitleFont = UIFont(name: "PatrickHand-Regular", size: 34) ?? UIFont.systemFont(ofSize: 34)

        // Make tab bar fully transparent with custom font
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundColor = UIColor.clear
        tabBarAppearance.shadowColor = UIColor.clear

        // Set tab bar item font
        let normalAttrs: [NSAttributedString.Key: Any] = [.font: patrickHand]
        let selectedAttrs: [NSAttributedString.Key: Any] = [.font: patrickHand]
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttrs
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttrs
        tabBarAppearance.inlineLayoutAppearance.normal.titleTextAttributes = normalAttrs
        tabBarAppearance.inlineLayoutAppearance.selected.titleTextAttributes = selectedAttrs
        tabBarAppearance.compactInlineLayoutAppearance.normal.titleTextAttributes = normalAttrs
        tabBarAppearance.compactInlineLayoutAppearance.selected.titleTextAttributes = selectedAttrs

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        // Make navigation bar fully transparent with custom font
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithTransparentBackground()
        navBarAppearance.backgroundColor = UIColor.clear
        navBarAppearance.shadowColor = UIColor.clear
        navBarAppearance.titleTextAttributes = [.font: navTitleFont]
        navBarAppearance.largeTitleTextAttributes = [.font: largeTitleFont]

        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
    }

    var body: some View {
        Group {
            if let store = habitStore {
                if hasCompletedOnboarding || CloudSettingsService.shared.hasCompletedOnboarding {
                    TabView(selection: $selectedTab) {
                        TodayView(store: store)
                            .tabItem {
                                Label("Today", systemImage: "checkmark.circle")
                            }
                            .tag(0)

                        MonthGridView(store: store)
                            .tabItem {
                                Label("Month", systemImage: "calendar")
                            }
                            .tag(1)

                        JournalView(store: store)
                            .tabItem {
                                Label("Journal", systemImage: "book")
                            }
                            .tag(2)

                        StatsView(store: store)
                            .tabItem {
                                Label("Stats", systemImage: "chart.bar")
                            }
                            .tag(3)

                        SettingsView(store: store)
                            .tabItem {
                                Label("Settings", systemImage: "gearshape")
                            }
                            .tag(4)
                    }
                    .tint(JournalTheme.Colors.inkBlue)
                    .onChange(of: selectedTab) { _, _ in
                        Feedback.tabSwitch()
                    }
                    .onAppear {
                        // Refresh smart reminders on app launch with current habit state
                        store.refreshSmartReminders()
                        // Check if launched from shield
                        checkAndShowIntercept()
                        // Check for pending notification navigation
                        checkPendingNavigation(store: store)
                    }
                    .onChange(of: scenePhase) { _, newPhase in
                        if newPhase == .active {
                            // Check if returning from a shield tap
                            checkAndShowIntercept()
                            // Check for pending notification navigation
                            checkPendingNavigation(store: store)
                        }
                    }
                    .onOpenURL { url in
                        // Handle sown://intercept deep link
                        if url.scheme == "sown" && url.host == "intercept" {
                            showingInterceptView = true
                        }
                    }
                    .fullScreenCover(isPresented: $showingInterceptView) {
                        InterceptView(
                            store: store,
                            blockedAppName: "App",
                            blockedAppEmoji: "📱",
                            blockedAppColor: .gray
                        )
                    }
                    .sheet(isPresented: $showingHabitDetail) {
                        if let habit = pendingNavigationHabit {
                            NavigationStack {
                                HabitDetailView(store: store, habit: habit)
                                    .toolbar {
                                        ToolbarItem(placement: .cancellationAction) {
                                            Button("Done") {
                                                showingHabitDetail = false
                                            }
                                            .foregroundStyle(JournalTheme.Colors.inkBlue)
                                        }
                                    }
                            }
                        }
                    }
                } else {
                    OnboardingView(store: store, onComplete: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            hasCompletedOnboarding = true
                            // Sync onboarding completion to iCloud
                            CloudSettingsService.shared.updateSetting("hasCompletedOnboarding", value: true)
                        }
                    })
                }
            } else {
                ProgressView()
                    .onAppear {
                        let store = HabitStore(modelContext: modelContext)
                        store.prefetchDailyLogs()
                        habitStore = store
                    }
            }
        }
    }

    /// Check if the shield action sent us an intercept request via App Group
    private func checkAndShowIntercept() {
        guard !showingInterceptView else { return }

        let defaults = UserDefaults(suiteName: "group.com.incept5.SeedBed")
        if let requestTime = defaults?.double(forKey: "interceptRequested"), requestTime > 0 {
            // Only honour requests from the last 30 seconds (avoid stale flags)
            let age = Date().timeIntervalSince1970 - requestTime
            if age < 30 {
                // Clear the flag so it doesn't re-trigger
                defaults?.removeObject(forKey: "interceptRequested")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showingInterceptView = true
                }
                return
            } else {
                // Stale flag — clean it up
                defaults?.removeObject(forKey: "interceptRequested")
            }
        }
    }

    /// Check for pending navigation from notification tap
    private func checkPendingNavigation(store: HabitStore) {
        let defaults = UserDefaults.standard

        guard let requestTime = defaults.double(forKey: "pendingNavigationTime") as Double?,
              requestTime > 0,
              let habitId = defaults.string(forKey: "pendingNavigationHabitId"),
              let type = defaults.string(forKey: "pendingNavigationType") else {
            return
        }

        // Only honour requests from the last 30 seconds
        let age = Date().timeIntervalSince1970 - requestTime
        guard age < 30 else {
            // Stale — clean up
            defaults.removeObject(forKey: "pendingNavigationHabitId")
            defaults.removeObject(forKey: "pendingNavigationType")
            defaults.removeObject(forKey: "pendingNavigationTime")
            return
        }

        // Clear the flags
        defaults.removeObject(forKey: "pendingNavigationHabitId")
        defaults.removeObject(forKey: "pendingNavigationType")
        defaults.removeObject(forKey: "pendingNavigationTime")

        // Find the habit
        if type == "task" {
            // Navigate to Today tab for tasks
            selectedTab = 0
        } else if type == "habit" {
            // Navigate to habit detail
            if let uuid = UUID(uuidString: habitId),
               let habit = store.habits.first(where: { $0.id == uuid }) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    pendingNavigationHabit = habit
                    showingHabitDetail = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Habit.self, HabitGroup.self, DailyLog.self, DayRecord.self, EndOfDayNote.self], inMemory: true)
}
