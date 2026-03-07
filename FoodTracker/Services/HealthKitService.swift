import HealthKit
import os

actor HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()
    private let logger = Logger(subsystem: "com.DNT.FoodTracker", category: "healthkit")
    private let metadataKey = "FoodTrackerEntryID"

    static var isEnabled: Bool {
        get { sharedDefaults.bool(forKey: "healthKitSyncEnabled") }
        set { sharedDefaults.set(newValue, forKey: "healthKitSyncEnabled") }
    }

    private let shareTypes: Set<HKSampleType> = [
        HKQuantityType(.dietaryEnergyConsumed),
        HKQuantityType(.dietaryProtein),
        HKQuantityType(.dietaryCarbohydrates),
        HKQuantityType(.dietaryFatTotal),
    ]

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: [])
            return true
        } catch {
            logger.error("HealthKit authorization failed: \(error.localizedDescription)")
            return false
        }
    }

    func syncEntry(_ entry: FoodEntry) async {
        guard Self.isEnabled, HKHealthStore.isHealthDataAvailable() else { return }
        let samples = makeSamples(for: entry)
        do {
            try await store.save(samples)
        } catch {
            logger.error("Failed to save HealthKit samples: \(error.localizedDescription)")
        }
    }

    func deleteEntry(id: UUID, date: Date) async {
        guard Self.isEnabled, HKHealthStore.isHealthDataAvailable() else { return }
        let predicate = HKQuery.predicateForObjects(withMetadataKey: metadataKey, allowedValues: [id.uuidString])
        for type in shareTypes {
            do {
                try await store.deleteObjects(of: type, predicate: predicate)
            } catch {
                logger.error("Failed to delete HealthKit samples: \(error.localizedDescription)")
            }
        }
    }

    func updateEntry(_ entry: FoodEntry) async {
        await deleteEntry(id: entry.id, date: entry.date)
        await syncEntry(entry)
    }

    func syncAllEntries(_ entries: [FoodEntry]) async {
        guard Self.isEnabled, HKHealthStore.isHealthDataAvailable() else { return }
        let samples = entries.flatMap { makeSamples(for: $0) }
        guard !samples.isEmpty else { return }
        do {
            try await store.save(samples)
            logger.info("Synced \(entries.count) entries (\(samples.count) samples) to HealthKit")
        } catch {
            logger.error("Failed to sync all entries to HealthKit: \(error.localizedDescription)")
        }
    }

    private func makeSamples(for entry: FoodEntry) -> [HKQuantitySample] {
        let date = entry.date
        let meta: [String: Any] = [metadataKey: entry.id.uuidString]
        return [
            HKQuantitySample(type: HKQuantityType(.dietaryEnergyConsumed), quantity: HKQuantity(unit: .kilocalorie(), doubleValue: Double(entry.totalCalories)), start: date, end: date, metadata: meta),
            HKQuantitySample(type: HKQuantityType(.dietaryProtein), quantity: HKQuantity(unit: .gram(), doubleValue: entry.totalProteinGrams), start: date, end: date, metadata: meta),
            HKQuantitySample(type: HKQuantityType(.dietaryCarbohydrates), quantity: HKQuantity(unit: .gram(), doubleValue: entry.totalCarbsGrams), start: date, end: date, metadata: meta),
            HKQuantitySample(type: HKQuantityType(.dietaryFatTotal), quantity: HKQuantity(unit: .gram(), doubleValue: entry.totalFatGrams), start: date, end: date, metadata: meta),
        ]
    }
}
