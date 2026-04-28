import Foundation
import HealthKit

@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    @Published private(set) var summary: HealthSummary?
    @Published private(set) var hasAskedForAccess: Bool
    @Published private(set) var isHealthAvailable: Bool

    private let healthStore = HKHealthStore()
    private let askedKey = "hasAskedForHealthAccess"

    private init() {
        hasAskedForAccess = UserDefaults.standard.bool(forKey: askedKey)
        isHealthAvailable = HKHealthStore.isHealthDataAvailable()
    }

    func markSkipped() {
        hasAskedForAccess = true
        UserDefaults.standard.set(true, forKey: askedKey)
    }

    func requestPermissionsAndRefresh() async {
        hasAskedForAccess = true
        UserDefaults.standard.set(true, forKey: askedKey)

        #if targetEnvironment(simulator)
        summary = mockSummary()
        return
        #else
        guard HKHealthStore.isHealthDataAvailable(),
              let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount),
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            summary = nil
            return
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: [stepsType, sleepType])
            summary = try await fetchSummary(days: 14)
        } catch {
            summary = nil
        }
        #endif
    }

    func refreshIfPossible() async {
        #if targetEnvironment(simulator)
        if hasAskedForAccess {
            summary = mockSummary()
        }
        #else
        guard hasAskedForAccess, HKHealthStore.isHealthDataAvailable() else { return }
        summary = try? await fetchSummary(days: 14)
        #endif
    }

    private func fetchSummary(days: Int) async throws -> HealthSummary? {
        async let sleep = fetchSleepHours(days: days)
        async let steps = fetchDailySteps(days: days)

        let sleepValues = try await sleep
        let stepValues = try await steps

        guard sleepValues.isEmpty == false || stepValues.isEmpty == false else {
            return nil
        }

        let averageSleep = sleepValues.isEmpty ? 0 : sleepValues.reduce(0, +) / Double(sleepValues.count)
        let lastNightSleep = sleepValues.last ?? averageSleep
        let averageSteps = stepValues.isEmpty ? 0 : Int(Double(stepValues.reduce(0, +)) / Double(stepValues.count))
        let trend = stepTrend(from: stepValues)

        return HealthSummary(
            averageSleep: averageSleep,
            lastNightSleep: lastNightSleep,
            averageSteps: averageSteps,
            trend: trend
        )
    }

    private func fetchSleepHours(days: Int) async throws -> [Double] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }

        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -days, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples as? [HKCategorySample] ?? [])
            }
            healthStore.execute(query)
        }

        var totalsByDay: [Date: TimeInterval] = [:]
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]

        for sample in samples where asleepValues.contains(sample.value) {
            let day = calendar.startOfDay(for: sample.endDate)
            totalsByDay[day, default: 0] += sample.endDate.timeIntervalSince(sample.startDate)
        }

        return totalsByDay
            .sorted { $0.key < $1.key }
            .map { $0.value / 3600 }
            .filter { $0 > 0 }
    }

    private func fetchDailySteps(days: Int) async throws -> [Int] {
        guard let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return [] }

        let calendar = Calendar.current
        let end = Date()
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -days, to: end) ?? end)
        var results: [Int] = []

        for offset in 0..<days {
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: start),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                continue
            }

            let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
            let total: Double = try await withCheckedThrowingContinuation { continuation in
                let query = HKStatisticsQuery(
                    quantityType: stepsType,
                    quantitySamplePredicate: predicate,
                    options: .cumulativeSum
                ) { _, statistics, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    let count = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    continuation.resume(returning: count)
                }
                healthStore.execute(query)
            }

            if total > 0 {
                results.append(Int(total))
            }
        }

        return results
    }

    private func stepTrend(from steps: [Int]) -> HealthTrend {
        guard steps.count >= 6 else { return .stable }
        let split = steps.count / 2
        let first = steps.prefix(split)
        let second = steps.suffix(steps.count - split)
        let firstAverage = Double(first.reduce(0, +)) / Double(first.count)
        let secondAverage = Double(second.reduce(0, +)) / Double(second.count)
        let difference = secondAverage - firstAverage

        if difference > 750 { return .up }
        if difference < -750 { return .down }
        return .stable
    }

    private func mockSummary() -> HealthSummary {
        let sleep = [6.1, 7.3, 5.6, 6.8, 7.7, 5.9, 7.1]
        let steps = [3200, 4100, 8700, 6200, 9400, 5100, 7800]
        return HealthSummary(
            averageSleep: sleep.reduce(0, +) / Double(sleep.count),
            lastNightSleep: sleep.last ?? 6.5,
            averageSteps: steps.reduce(0, +) / steps.count,
            trend: stepTrend(from: steps)
        )
    }
}
