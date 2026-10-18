import Foundation

/// Low-data exports intentionally are metadata-only, not restorable backups.
public enum WeeklyExportPolicy {
    private static let lowDataKeys: Set<String> = [
        "id", "key", "profileID", "sampleData", "day", "weekStart", "at", "updatedAt",
        "createdAt", "confirmedAt", "processedAt", "consumedAt", "recordKind"
    ]

    public static func project<Value>(_ record: [String: Value], lowDataMode: Bool) -> [String: Value] {
        guard lowDataMode else { return record }
        return record.filter { lowDataKeys.contains($0.key) }
    }
}
