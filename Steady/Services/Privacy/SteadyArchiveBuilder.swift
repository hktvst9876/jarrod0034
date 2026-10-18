import CryptoKit
import Foundation
import SteadyCore
import SwiftData

/// An explicit schema, not a database/file-system dump. It never queries HealthKit or EventKit.
@MainActor
struct SteadyArchiveBuilder {
    let context: ModelContext
    let now: Date
    let metadataOnly: Bool
    private let redactionSalt = UUID().uuidString
    private let payloadBudget = ArchivePayloadBudget()

    static func prepare(context shared: ModelContext, now: Date) throws -> ArchivePreparation {
        guard !shared.hasChanges, !DataDeletionGate.shared.isBlocked else { throw PrivacyDataError.staleRequest }
        let context = ModelContext(shared.container)
        context.autosaveEnabled = false
        let sizes = try [
            context.fetchCount(FetchDescriptor<ProfileRecord>()), context.fetchCount(FetchDescriptor<PlanRecord>()),
            context.fetchCount(FetchDescriptor<ChoiceRecord>()), context.fetchCount(FetchDescriptor<FoundationPreferenceRecord>()),
            context.fetchCount(FetchDescriptor<FoundationDayRecord>()), context.fetchCount(FetchDescriptor<FoundationResponseRecord>()),
            context.fetchCount(FetchDescriptor<FoodCorrectionRecord>()), context.fetchCount(FetchDescriptor<WatchIssuedSnapshotRecord>()),
            context.fetchCount(FetchDescriptor<WatchActionReceiptRecord>()), context.fetchCount(FetchDescriptor<WatchMovementRecord>()),
            context.fetchCount(FetchDescriptor<WatchMealHandoffRecord>()), context.fetchCount(FetchDescriptor<WeeklyReviewRecord>()),
            context.fetchCount(FetchDescriptor<WeeklyExperimentRecord>()), context.fetchCount(FetchDescriptor<WeeklyMetricRecord>())
        ]
        guard sizes.reduce(0, +) <= 20_000 else { throw PrivacyDataError.tooLarge }
        let profiles = try context.fetch(FetchDescriptor<ProfileRecord>())
        // A stricter profile protects the whole multi-profile archive, including legacy payloads.
        let builder = SteadyArchiveBuilder(context: context, now: now, metadataOnly: profiles.contains { $0.lowDataMode })
        let tables = try builder.tables(profiles: profiles)
        let counts = tables.mapValues(\.count)
        guard counts.values.reduce(0, +) <= 20_000 else { throw PrivacyDataError.tooLarge }
        let root: [String: Any] = [
            "schemaVersion": 1, "exportedAt": builder.date(now), "timeZone": "Asia/Singapore",
            "metadataOnly": builder.metadataOnly, "records": tables,
            "localPreferences": try builder.preferences(),
            "companionInbox": try builder.companionInbox(),
            "limitations": [
                "App-local records only; no raw HealthKit samples or complete EventKit events.",
                "Dates in decoded app payloads follow Foundation JSONEncoder's seconds since 2001-01-01 convention; envelope dates are ISO 8601.",
                "No import/restore is implemented. Metadata-only exports omit all content, measurements, settings and opaque payloads.",
                "Advisor diagnostics and transient Health, location and place-search caches are not exported.",
                "Non-personal privacy reset fences are retained separately and are not wellness history."
            ]
        ]
        guard JSONSerialization.isValidJSONObject(root) else { throw PrivacyDataError.corruptExport }
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        guard data.count <= 10_000_000 else { throw PrivacyDataError.tooLarge }
        return ArchivePreparation(item: SteadyArchive(lease: ArchiveLease(data: data, container: shared.container, profiles: profiles)),
                                  metadataOnly: builder.metadataOnly, counts: counts)
    }

    func date(_ value: Date) -> String { value.ISO8601Format() }
    func optionalDate(_ value: Date?) -> Any { value.map(date) as Any? ?? NSNull() }
    func optional<T>(_ value: T?) -> Any { value as Any? ?? NSNull() }

    func json(_ data: Data) throws -> Any {
        guard data.count <= 1_000_000 else { throw PrivacyDataError.tooLarge }
        try payloadBudget.include(data.count)
        do { return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) }
        catch { throw PrivacyDataError.corruptExport }
    }

    func optionalJSON(_ data: Data?) throws -> Any { try data.map(json) ?? NSNull() }

    func row(_ metadata: [String: Any], details: () throws -> [String: Any]) rethrows -> [String: Any] {
        if metadataOnly {
            var safe = WeeklyExportPolicy.project(metadata, lowDataMode: true)
            // Keys/IDs may contain old free-text identifiers. Salted opaque IDs close that escape hatch.
            for key in ["key", "id"] {
                if let value = safe[key] as? String {
                    safe[key] = SHA256.hash(data: Data((redactionSalt + value).utf8)).map { String(format: "%02x", $0) }.joined()
                }
            }
            return safe
        }
        return metadata.merging(try details()) { _, new in new }
    }

    private func preferences() throws -> [String: Any] {
        guard !metadataOnly else { return ["omitted": true] }
        var result: [String: Any] = [:]
        for (key, value) in UserDefaults.standard.dictionaryRepresentation()
            where key == "useSampleData" || key.hasPrefix("steady.") {
            result[key] = try normalizedPreference(value)
        }
        return result
    }

    private func normalizedPreference(_ value: Any) throws -> Any {
        if let data = value as? Data { return try json(data) }
        if let date = value as? Date { return self.date(date) }
        if let array = value as? [Any] { return try array.map(normalizedPreference) }
        if let object = value as? [String: Any] { return try object.mapValues(normalizedPreference) }
        if value is String || value is NSNumber { return value }
        throw PrivacyDataError.corruptExport
    }

    private func companionInbox() throws -> [String: Any] {
        guard !metadataOnly else { return ["omitted": true] }
        let inbox = try CompanionDiskInbox.shared.read()
        return ["snapshot": try optionalJSON(inbox.snapshot), "actions": try inbox.actions.map(json),
                "receipts": try inbox.receipts.map(json)]
    }
}

@MainActor
private final class ArchivePayloadBudget {
    private var bytes = 0
    func include(_ count: Int) throws {
        guard count <= 10_000_000 - bytes else { throw PrivacyDataError.tooLarge }
        bytes += count
    }
}
