import Foundation
import HealthKit
import SwiftData

// M8 T54 · Apple Health. Reading is per journey and only for the types the
// user ticked; what comes in becomes ordinary measurement records in that
// journey. Writing back copies the measurements recorded in a connected
// journey into Health (Settings holds the master switch, on by default).
// T61: all of it only on the device of the person the journey records —
// a husband logging his wife's blood pressure never writes it as his own.
// Nothing here talks to any server.

/// The four readings Carelogue exchanges with Health.
enum HealthMetric: String, CaseIterable, Codable, Identifiable {
    case weight
    case bloodPressure
    case heartRate
    case temperature

    var id: String { rawValue }

    /// The measurement type it maps to (LogTypePreset.measurement).
    var logType: String {
        switch self {
        case .weight: return "体重"
        case .bloodPressure: return LogTypePreset.bloodPressure
        case .heartRate: return "心率"
        case .temperature: return "体温"
        }
    }

    var unitLabel: String {
        switch self {
        case .weight: return "kg"
        case .bloodPressure: return "mmHg"
        case .heartRate: return "bpm"
        case .temperature: return "°C"
        }
    }

    var displayName: String { LogTypePreset.displayName(logType) }

    init?(logType: String) {
        guard let metric = Self.allCases.first(where: { $0.logType == logType }) else { return nil }
        self = metric
    }

    fileprivate var hkUnit: HKUnit {
        switch self {
        case .weight: return .gramUnit(with: .kilo)
        case .bloodPressure: return .millimeterOfMercury()
        case .heartRate: return .count().unitDivided(by: .minute())
        case .temperature: return .degreeCelsius()
        }
    }

    /// Heart rate is read as the daily *resting* rate: an Apple Watch logs
    /// thousands of raw heart-rate samples a day, which would flood a
    /// timeline. A reading taken in Carelogue is written as a plain one.
    fileprivate var readTypes: Set<HKObjectType> {
        switch self {
        case .weight: return [HKQuantityType(.bodyMass)]
        case .bloodPressure: return [HKQuantityType(.bloodPressureSystolic), HKQuantityType(.bloodPressureDiastolic)]
        case .heartRate: return [HKQuantityType(.restingHeartRate)]
        case .temperature: return [HKQuantityType(.bodyTemperature)]
        }
    }

    fileprivate var shareTypes: Set<HKSampleType> {
        switch self {
        case .weight: return [HKQuantityType(.bodyMass)]
        case .bloodPressure: return [HKQuantityType(.bloodPressureSystolic), HKQuantityType(.bloodPressureDiastolic)]
        case .heartRate: return [HKQuantityType(.heartRate)]
        case .temperature: return [HKQuantityType(.bodyTemperature)]
        }
    }
}

/// A journey's link to Health: which types it reads. Kept on this device —
/// HealthKit itself is per device.
struct HealthLink: Codable, Equatable {
    var metrics: [HealthMetric]
}

@MainActor
enum HealthSync {
    static let writeBackKey = "health.writeBack"
    private static let store = HKHealthStore()

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Settings › Apple 健康 › 写入 Apple 健康 — the master switch, on unless
    /// switched off. Writing also needs the journey connected here (T61).
    static var writeBackEnabled: Bool {
        UserDefaults.standard.object(forKey: writeBackKey) as? Bool ?? true
    }

    // MARK: Links

    private static func linkKey(_ journey: Journey) -> String { "health.link.\(journey.id.uuidString)" }

    static func link(for journey: Journey) -> HealthLink? {
        guard let data = UserDefaults.standard.data(forKey: linkKey(journey)) else { return nil }
        return try? JSONDecoder().decode(HealthLink.self, from: data)
    }

    /// Asks for exactly the ticked types (plus write access for all four when
    /// writing back is on), saves the link and imports. Returns how many
    /// readings came in.
    static func connect(_ journey: Journey, metrics: [HealthMetric], context: ModelContext) async throws -> Int {
        guard isAvailable, !metrics.isEmpty, journey.healthBelongsHere else { return 0 }
        let read = metrics.reduce(into: Set<HKObjectType>()) { $0.formUnion($1.readTypes) }
        let share = writeBackEnabled
            ? HealthMetric.allCases.reduce(into: Set<HKSampleType>()) { $0.formUnion($1.shareTypes) }
            : []
        try await store.requestAuthorization(toShare: share, read: read)
        if let data = try? JSONEncoder().encode(HealthLink(metrics: metrics)) {
            UserDefaults.standard.set(data, forKey: linkKey(journey))
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uitest-seed-health"), !seeded {
            seeded = true
            await seedForTests(since: start(of: journey))
        }
        #endif
        return await importNew(into: journey, context: context)
    }

    /// Stops reading for this journey. Records already imported stay.
    static func disconnect(_ journey: Journey) {
        UserDefaults.standard.removeObject(forKey: linkKey(journey))
    }

    /// Where reading starts: the journey's progress start (T56) if set,
    /// else the day it was created.
    private static func start(of journey: Journey) -> Date {
        Calendar.current.startOfDay(for: journey.progressStartDate ?? journey.createdAt)
    }

    // MARK: Import

    private struct Reading {
        let id: UUID
        let date: Date
        let value: Double
        var diastolic: Double?
    }

    /// Adds the readings Health has that the store doesn't (matched by
    /// sample id, across every journey, so nothing comes in twice and
    /// Carelogue's own write-backs never come back as imports).
    @discardableResult
    static func importNew(into journey: Journey, context: ModelContext) async -> Int {
        guard isAvailable, let link = link(for: journey) else { return 0 }
        // The journey now records someone else (changed here or by another
        // member): this device stops reading for it.
        guard journey.healthBelongsHere else {
            disconnect(journey)
            return 0
        }
        await reconcileWriteBacks(in: journey, context: context)
        let since = start(of: journey)
        let known = Set(((try? context.fetch(FetchDescriptor<Log>(
            predicate: #Predicate { $0.healthSampleID != nil }
        ))) ?? []).compactMap { $0.healthSampleID.flatMap(sampleUUID) })

        var added = 0
        for metric in link.metrics {
            for reading in await readings(metric, since: since) where !known.contains(reading.id) {
                let log = Log(kind: .measurement, type: metric.logType, occurredAt: reading.date,
                              value: reading.value, unit: metric.unitLabel, diastolic: reading.diastolic)
                log.healthSampleID = "in:\(reading.id.uuidString)"
                context.insert(log)
                journey.add(log)
                added += 1
            }
        }
        if added > 0 {
            try? context.save()
        }
        return added
    }

    private static func readings(_ metric: HealthMetric, since: Date) async -> [Reading] {
        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil)
        switch metric {
        case .bloodPressure:
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.correlation(type: HKCorrelationType(.bloodPressure), predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.startDate)])
            let correlations = (try? await descriptor.result(for: store)) ?? []
            return correlations.compactMap { correlation in
                let systolic = correlation.objects(for: HKQuantityType(.bloodPressureSystolic)).first as? HKQuantitySample
                let diastolic = correlation.objects(for: HKQuantityType(.bloodPressureDiastolic)).first as? HKQuantitySample
                guard let systolic else { return nil }
                return Reading(id: correlation.uuid, date: correlation.startDate,
                               value: systolic.quantity.doubleValue(for: metric.hkUnit),
                               diastolic: diastolic?.quantity.doubleValue(for: metric.hkUnit))
            }
        default:
            guard let type = metric.readTypes.first as? HKQuantityType else { return [] }
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: type, predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.startDate)])
            let samples = (try? await descriptor.result(for: store)) ?? []
            return samples.map {
                Reading(id: $0.uuid, date: $0.startDate,
                        value: (($0.quantity.doubleValue(for: metric.hkUnit)) * 10).rounded() / 10)
            }
        }
    }

    private static func sampleUUID(_ tagged: String) -> UUID? {
        tagged.split(separator: ":", maxSplits: 1).last.flatMap { UUID(uuidString: String($0)) }
    }

    // MARK: Write-back

    /// After a measurement is saved: mirrors it into Health (replacing the
    /// copy Carelogue wrote before, if any). Readings that came from Health
    /// are never written back; nothing is asked for here — without write
    /// access it simply does nothing.
    static func didSave(_ log: Log, context: ModelContext) async {
        guard let journey = log.journey, link(for: journey) != nil, journey.healthBelongsHere else { return }
        guard isAvailable, writeBackEnabled, log.kind == .measurement,
              let metric = HealthMetric(logType: log.type), let value = log.value,
              !(log.healthSampleID?.hasPrefix("in:") ?? false) else { return }
        guard metric.shareTypes.allSatisfy({ store.authorizationStatus(for: $0) == .sharingAuthorized }) else { return }

        if let old = log.healthSampleID.flatMap(sampleUUID) {
            await deleteSample(old, metric: metric)
        }
        guard let sample = makeSample(metric, value: value, diastolic: log.diastolic, date: log.occurredAt) else {
            log.healthSampleID = nil
            try? context.save()
            return
        }
        do {
            try await store.save(sample)
            log.healthSampleID = "out:\(sample.uuid.uuidString)"
        } catch {
            log.healthSampleID = nil
        }
        try? context.save()
    }

    /// A shared journey's other member may have changed a reading this
    /// device wrote to Health; the change arrives through the share, not the
    /// editor. On opening the journey, Health's copy catches up.
    private static func reconcileWriteBacks(in journey: Journey, context: ModelContext) async {
        for log in journey.allLogs where log.healthSampleID?.hasPrefix("out:") ?? false {
            guard let id = log.healthSampleID.flatMap(sampleUUID),
                  let metric = HealthMetric(logType: log.type) else { continue }
            let stored = await storedReading(id, metric: metric)
            let current = (log.value, log.diastolic, log.occurredAt)
            if stored == nil || stored!.value != current.0 || stored!.diastolic != current.1
                || abs(stored!.date.timeIntervalSince(current.2)) > 1 {
                await didSave(log, context: context)
            }
        }
    }

    private static func storedReading(_ id: UUID, metric: HealthMetric) async -> Reading? {
        let predicate = HKQuery.predicateForObject(with: id)
        if metric == .bloodPressure {
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.correlation(type: HKCorrelationType(.bloodPressure), predicate: predicate)],
                sortDescriptors: [])
            guard let correlation = (try? await descriptor.result(for: store))?.first else { return nil }
            let systolic = correlation.objects(for: HKQuantityType(.bloodPressureSystolic)).first as? HKQuantitySample
            let diastolic = correlation.objects(for: HKQuantityType(.bloodPressureDiastolic)).first as? HKQuantitySample
            return Reading(id: id, date: correlation.startDate,
                           value: systolic?.quantity.doubleValue(for: metric.hkUnit) ?? 0,
                           diastolic: diastolic?.quantity.doubleValue(for: metric.hkUnit))
        }
        guard let type = metric.shareTypes.first as? HKQuantityType else { return nil }
        let descriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: type, predicate: predicate)],
                                                 sortDescriptors: [])
        guard let sample = (try? await descriptor.result(for: store))?.first else { return nil }
        return Reading(id: id, date: sample.startDate, value: sample.quantity.doubleValue(for: metric.hkUnit))
    }

    /// Before a measurement is deleted: removes the copy Carelogue wrote.
    static func willDelete(_ log: Log) {
        guard isAvailable, let tagged = log.healthSampleID, tagged.hasPrefix("out:"),
              let id = sampleUUID(tagged), let metric = HealthMetric(logType: log.type) else { return }
        Task { await deleteSample(id, metric: metric) }
    }

    private static func makeSample(_ metric: HealthMetric, value: Double, diastolic: Double?, date: Date) -> HKSample? {
        let metadata: [String: Any] = [HKMetadataKeyWasUserEntered: true]
        switch metric {
        case .bloodPressure:
            // Health stores blood pressure only as a pair.
            guard let diastolic else { return nil }
            let systolicSample = HKQuantitySample(type: HKQuantityType(.bloodPressureSystolic),
                                                  quantity: HKQuantity(unit: metric.hkUnit, doubleValue: value),
                                                  start: date, end: date, metadata: metadata)
            let diastolicSample = HKQuantitySample(type: HKQuantityType(.bloodPressureDiastolic),
                                                   quantity: HKQuantity(unit: metric.hkUnit, doubleValue: diastolic),
                                                   start: date, end: date, metadata: metadata)
            return HKCorrelation(type: HKCorrelationType(.bloodPressure), start: date, end: date,
                                 objects: [systolicSample, diastolicSample], metadata: metadata)
        default:
            guard let type = metric.shareTypes.first as? HKQuantityType else { return nil }
            return HKQuantitySample(type: type, quantity: HKQuantity(unit: metric.hkUnit, doubleValue: value),
                                    start: date, end: date, metadata: metadata)
        }
    }

    private static func deleteSample(_ id: UUID, metric: HealthMetric) async {
        let types: [HKSampleType] = metric == .bloodPressure
            ? [HKCorrelationType(.bloodPressure)] + Array(metric.shareTypes)
            : Array(metric.shareTypes)
        for type in types {
            try? await store.deleteObjects(of: type, predicate: HKQuery.predicateForObject(with: id))
        }
    }

    // MARK: Debug

    #if DEBUG
    private static var seeded = false

    /// How many of the store's write-backs are in Health right now (UI tests).
    static func exportedCount(context: ModelContext) async -> Int {
        let logs = ((try? context.fetch(FetchDescriptor<Log>())) ?? [])
            .filter { $0.healthSampleID?.hasPrefix("out:") ?? false }
        var count = 0
        for log in logs {
            guard let id = log.healthSampleID.flatMap(sampleUUID), let metric = HealthMetric(logType: log.type) else { continue }
            let type: HKSampleType = metric == .bloodPressure ? HKCorrelationType(.bloodPressure) : metric.shareTypes.first!
            let descriptor = HKSampleQueryDescriptor(predicates: [.sample(type: type, predicate: HKQuery.predicateForObject(with: id))],
                                                     sortDescriptors: [])
            if let found = try? await descriptor.result(for: store), !found.isEmpty { count += 1 }
        }
        return count
    }

    /// -uitest-seed-health: three weights and one blood pressure in Health,
    /// as if another app had logged them, for the import to find.
    private static func seedForTests(since: Date) async {
        // Health outlives the app's store: clear what earlier runs wrote, so
        // every run imports the same four readings.
        let mine = HKQuery.predicateForObjects(from: .default())
        for type in [HKCorrelationType(.bloodPressure)] + HealthMetric.allCases.flatMap({ Array($0.shareTypes) }) {
            _ = try? await store.deleteObjects(of: type, predicate: mine)
        }
        // Earlier today, after the journey's start (tests create it today).
        let hoursAgo: (Double) -> Date = { max(Date.now.addingTimeInterval(-$0 * 60), since) }
        var samples: [HKSample] = [61.2, 61.6, 62.0].enumerated().compactMap { index, kg in
            makeSample(.weight, value: kg, diastolic: nil, date: hoursAgo(Double(30 - index * 10)))
        }
        if let pressure = makeSample(.bloodPressure, value: 117, diastolic: 76, date: hoursAgo(5)) {
            samples.append(pressure)
        }
        try? await store.save(samples)
    }
    #endif
}
