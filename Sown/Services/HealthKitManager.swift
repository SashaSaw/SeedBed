import Foundation
import HealthKit
import Combine
import UserNotifications

/// Service for managing HealthKit integration
@Observable
final class HealthKitManager {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()
    private var observerQueries: [HKObserverQuery] = []

    /// Whether HealthKit is available on this device
    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Whether the user has authorized HealthKit access
    var isAuthorized: Bool = false

    /// Current values for each metric type (updated throughout the day)
    var currentValues: [HealthKitMetricType: Double] = [:]

    /// Publisher for value updates (metric type that was updated)
    let valueUpdatesPublisher = PassthroughSubject<HealthKitMetricType, Never>()

    private init() {
        // Check if we were previously authorized
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    /// Request authorization for all HealthKit data types we need
    @MainActor
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }

        let typesToRead = healthKitTypesToRead()
        guard !typesToRead.isEmpty else { return false }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            // For read-only access, HealthKit doesn't tell us if user granted permission
            // (this is a privacy feature). If the request didn't throw, we assume success.
            // The actual data fetch will return empty if user denied.
            UserDefaults.standard.set(true, forKey: "healthKitAuthorizationRequested")
            isAuthorized = true
            return true
        } catch {
            print("HealthKit authorization error: \(error)")
            return false
        }
    }

    /// Check current authorization status
    private func checkAuthorizationStatus() {
        guard isAvailable else {
            isAuthorized = false
            return
        }

        // For read-only access, we can only check if we previously requested authorization
        isAuthorized = UserDefaults.standard.bool(forKey: "healthKitAuthorizationRequested")
    }

    // MARK: - Data Fetching

    /// Fetch today's value for a specific metric
    func fetchTodayValue(for metric: HealthKitMetricType) async -> Double? {
        guard isAvailable else { return nil }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let now = Date()

        switch metric {
        case .steps:
            return await fetchCumulativeSum(
                typeIdentifier: .stepCount,
                unit: HKUnit.count(),
                start: startOfDay,
                end: now
            )
        case .distanceWalkingRunning:
            return await fetchCumulativeSum(
                typeIdentifier: .distanceWalkingRunning,
                unit: HKUnit.meterUnit(with: .kilo),
                start: startOfDay,
                end: now
            )
        case .distanceCycling:
            return await fetchCumulativeSum(
                typeIdentifier: .distanceCycling,
                unit: HKUnit.meterUnit(with: .kilo),
                start: startOfDay,
                end: now
            )
        case .activeEnergyBurned:
            return await fetchCumulativeSum(
                typeIdentifier: .activeEnergyBurned,
                unit: HKUnit.kilocalorie(),
                start: startOfDay,
                end: now
            )
        case .appleExerciseTime:
            return await fetchCumulativeSum(
                typeIdentifier: .appleExerciseTime,
                unit: HKUnit.minute(),
                start: startOfDay,
                end: now
            )
        case .flightsClimbed:
            return await fetchCumulativeSum(
                typeIdentifier: .flightsClimbed,
                unit: HKUnit.count(),
                start: startOfDay,
                end: now
            )
        case .mindfulMinutes:
            return await fetchMindfulMinutes(start: startOfDay, end: now)
        case .sleepHours:
            return await fetchSleepHours(start: startOfDay, end: now)
        case .waterIntake:
            return await fetchCumulativeSum(
                typeIdentifier: .dietaryWater,
                unit: HKUnit.liter(),
                start: startOfDay,
                end: now
            )
        }
    }

    private func fetchCumulativeSum(
        typeIdentifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async -> Double? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: typeIdentifier) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    print("HealthKit query error for \(typeIdentifier): \(error)")
                    continuation.resume(returning: nil)
                    return
                }

                let value = result?.sumQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }

            healthStore.execute(query)
        }
    }

    private func fetchMindfulMinutes(start: Date, end: Date) async -> Double? {
        guard let categoryType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: categoryType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    print("HealthKit mindful minutes query error: \(error)")
                    continuation.resume(returning: nil)
                    return
                }

                let totalMinutes = samples?.reduce(0.0) { total, sample in
                    let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60.0
                    return total + duration
                } ?? 0

                continuation.resume(returning: totalMinutes)
            }

            healthStore.execute(query)
        }
    }

    private func fetchSleepHours(start: Date, end: Date) async -> Double? {
        guard let categoryType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: categoryType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    print("HealthKit sleep query error: \(error)")
                    continuation.resume(returning: nil)
                    return
                }

                // Filter for asleep states (not in bed)
                let asleepSamples = samples?.compactMap { $0 as? HKCategorySample }.filter { sample in
                    if #available(iOS 16.0, *) {
                        return sample.value != HKCategoryValueSleepAnalysis.inBed.rawValue
                    } else {
                        return sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue
                    }
                }

                let totalHours = asleepSamples?.reduce(0.0) { total, sample in
                    let duration = sample.endDate.timeIntervalSince(sample.startDate) / 3600.0
                    return total + duration
                } ?? 0

                continuation.resume(returning: totalHours)
            }

            healthStore.execute(query)
        }
    }

    /// Refresh all currently tracked metric values
    func refreshAllValues() async {
        for metric in HealthKitMetricType.allCases {
            if let value = await fetchTodayValue(for: metric) {
                await MainActor.run {
                    currentValues[metric] = value
                }
            }
        }
    }

    /// Refresh values for specific metrics only
    func refreshValues(for metrics: [HealthKitMetricType]) async {
        for metric in metrics {
            if let value = await fetchTodayValue(for: metric) {
                await MainActor.run {
                    let oldValue = currentValues[metric]
                    currentValues[metric] = value
                    // Only publish if value changed
                    if oldValue != value {
                        valueUpdatesPublisher.send(metric)
                    }
                }
            }
        }
    }

    // MARK: - Background Delivery

    /// Enable background delivery for specific metrics
    func enableBackgroundDelivery(for metrics: [HealthKitMetricType]) {
        guard isAvailable else { return }

        // Stop existing observers first
        stopAllObservers()

        for metric in metrics {
            guard let sampleType = sampleType(for: metric) else { continue }

            // Set up background delivery
            healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate) { success, error in
                if let error = error {
                    print("Failed to enable background delivery for \(metric): \(error)")
                }
            }

            // Set up observer query
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completionHandler, error in
                if let error = error {
                    print("Observer query error for \(metric): \(error)")
                    completionHandler()
                    return
                }

                // Fetch updated value
                Task { [weak self] in
                    if let value = await self?.fetchTodayValue(for: metric) {
                        await MainActor.run { [weak self] in
                            self?.currentValues[metric] = value
                            self?.valueUpdatesPublisher.send(metric)
                        }
                    }
                    completionHandler()
                }
            }

            healthStore.execute(query)
            observerQueries.append(query)
        }
    }

    /// Stop all observer queries
    func stopAllObservers() {
        for query in observerQueries {
            healthStore.stop(query)
        }
        observerQueries.removeAll()
    }

    // MARK: - Notifications

    /// Send a local notification when a HealthKit goal is achieved
    func sendAchievementNotification(habitName: String, metricType: HealthKitMetricType, value: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Goal Achieved!"
        content.body = "\(habitName) completed - you reached \(formatValue(value, for: metricType)) \(metricType.unit)!"
        content.sound = .default
        content.categoryIdentifier = "HEALTHKIT_ACHIEVEMENT"

        let request = UNNotificationRequest(
            identifier: "healthkit_\(UUID().uuidString)",
            content: content,
            trigger: nil // Immediate
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send HealthKit notification: \(error)")
            }
        }
    }

    // MARK: - Historical Data Fetching

    /// Fetch value for a specific date range (for persisting past day values)
    func fetchValueForDateRange(for metric: HealthKitMetricType, start: Date, end: Date) async -> Double? {
        guard isAvailable else { return nil }

        switch metric {
        case .steps:
            return await fetchCumulativeSum(
                typeIdentifier: .stepCount,
                unit: HKUnit.count(),
                start: start,
                end: end
            )
        case .distanceWalkingRunning:
            return await fetchCumulativeSum(
                typeIdentifier: .distanceWalkingRunning,
                unit: HKUnit.meterUnit(with: .kilo),
                start: start,
                end: end
            )
        case .distanceCycling:
            return await fetchCumulativeSum(
                typeIdentifier: .distanceCycling,
                unit: HKUnit.meterUnit(with: .kilo),
                start: start,
                end: end
            )
        case .activeEnergyBurned:
            return await fetchCumulativeSum(
                typeIdentifier: .activeEnergyBurned,
                unit: HKUnit.kilocalorie(),
                start: start,
                end: end
            )
        case .appleExerciseTime:
            return await fetchCumulativeSum(
                typeIdentifier: .appleExerciseTime,
                unit: HKUnit.minute(),
                start: start,
                end: end
            )
        case .flightsClimbed:
            return await fetchCumulativeSum(
                typeIdentifier: .flightsClimbed,
                unit: HKUnit.count(),
                start: start,
                end: end
            )
        case .mindfulMinutes:
            return await fetchMindfulMinutes(start: start, end: end)
        case .sleepHours:
            return await fetchSleepHours(start: start, end: end)
        case .waterIntake:
            return await fetchCumulativeSum(
                typeIdentifier: .dietaryWater,
                unit: HKUnit.liter(),
                start: start,
                end: end
            )
        }
    }

    // MARK: - Helpers

    private func healthKitTypesToRead() -> Set<HKObjectType> {
        var types = Set<HKObjectType>()

        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepType)
        }
        if let distanceWalkingRunning = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distanceWalkingRunning)
        }
        if let distanceCycling = HKQuantityType.quantityType(forIdentifier: .distanceCycling) {
            types.insert(distanceCycling)
        }
        if let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        if let exerciseTime = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            types.insert(exerciseTime)
        }
        if let flights = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) {
            types.insert(flights)
        }
        if let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) {
            types.insert(mindful)
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        if let water = HKQuantityType.quantityType(forIdentifier: .dietaryWater) {
            types.insert(water)
        }

        return types
    }

    private func sampleType(for metric: HealthKitMetricType) -> HKSampleType? {
        switch metric {
        case .steps:
            return HKQuantityType.quantityType(forIdentifier: .stepCount)
        case .distanceWalkingRunning:
            return HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)
        case .distanceCycling:
            return HKQuantityType.quantityType(forIdentifier: .distanceCycling)
        case .activeEnergyBurned:
            return HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        case .appleExerciseTime:
            return HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)
        case .flightsClimbed:
            return HKQuantityType.quantityType(forIdentifier: .flightsClimbed)
        case .mindfulMinutes:
            return HKObjectType.categoryType(forIdentifier: .mindfulSession)
        case .sleepHours:
            return HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        case .waterIntake:
            return HKQuantityType.quantityType(forIdentifier: .dietaryWater)
        }
    }

    /// Format a value for display
    func formatValue(_ value: Double, for metric: HealthKitMetricType) -> String {
        switch metric {
        case .steps, .flightsClimbed:
            return String(format: "%.0f", value)
        case .distanceWalkingRunning, .distanceCycling, .waterIntake:
            return String(format: "%.1f", value)
        case .activeEnergyBurned, .appleExerciseTime, .mindfulMinutes:
            return String(format: "%.0f", value)
        case .sleepHours:
            return String(format: "%.1f", value)
        }
    }
}
