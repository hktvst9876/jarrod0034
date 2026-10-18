import Foundation
import SteadyCore

/// A non-personal tombstone survives deletion. No profile, action, or Health values live here.
/// Delegate callbacks consult the same lock before admitting an old companion packet.
final class DataDeletionGate: @unchecked Sendable {
    static let shared = DataDeletionGate()

    private struct Journal: Codable {
        var control: CompanionEraseControl
        var pending: Bool
    }

    private let lock = NSLock()
    private var journal: Journal?
    private var unreadable = false

    private init() {
        reload()
    }

    /// Re-read a temporarily inaccessible journal without guessing an unknown historical cutoff.
    func reload() {
        lock.withLock {
            do {
                let url = try Self.fileURL()
                if FileManager.default.fileExists(atPath: url.path) {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    guard let size = attributes[.size] as? NSNumber, size.intValue <= 4_096 else {
                        throw PrivacyDataError.invalidJournal
                    }
                    let data = try Data(contentsOf: url)
                    guard data.count <= 4_096 else { throw PrivacyDataError.invalidJournal }
                    let saved = try JSONDecoder().decode(Journal.self, from: data)
                    try saved.control.validate()
                    guard saved.control.revision >= (journal?.control.revision ?? 0) else {
                        throw PrivacyDataError.invalidJournal
                    }
                    journal = saved
                    unreadable = false
                } else if journal != nil {
                    throw PrivacyDataError.invalidJournal
                }
            } catch { unreadable = true }
        }
    }

    var revision: Int { lock.withLock { journal?.control.revision ?? 0 } }
    var isBlocked: Bool { lock.withLock { unreadable || journal?.pending == true } }
    var hasPendingDeletion: Bool { lock.withLock { !unreadable && journal?.pending == true } }
    var currentErase: CompanionEraseControl? { lock.withLock { journal?.control } }

    func begin(_ control: CompanionEraseControl) throws {
        try control.validate()
        try lock.withLock {
            // An unreadable historical cutoff cannot safely be replaced by a lower guessed generation.
            guard !unreadable else { throw PrivacyDataError.invalidJournal }
            guard control.revision > (journal?.control.revision ?? 0) else {
                throw PrivacyDataError.staleRequest
            }
            try persist(Journal(control: control, pending: true))
        }
    }

    func finish() throws {
        try lock.withLock {
            guard let journal else { throw PrivacyDataError.invalidJournal }
            try persist(Journal(control: journal.control, pending: false))
        }
    }

    /// Watch-only admission of a phone's explicit erase command. Late commands never lower the fence.
    func receiveErase(_ control: CompanionEraseControl) throws {
        try control.validate()
        try lock.withLock {
            guard control.revision >= (journal?.control.revision ?? 0) else { return }
            guard control.revision > (journal?.control.revision ?? 0) || unreadable else { return }
            try persist(Journal(control: control, pending: false))
        }
    }

    private func persist(_ value: Journal) throws {
        let url = try Self.fileURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        journal = value
        unreadable = false
    }

    private static func fileURL() throws -> URL {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw PrivacyDataError.invalidJournal
        }
        return base.appendingPathComponent("SteadyPrivacy", isDirectory: true)
            .appendingPathComponent("reset-v1.json")
    }
}

enum PrivacyDataError: LocalizedError {
    case invalidJournal, staleRequest, corruptExport, tooLarge, deletionRequired

    var errorDescription: String? {
        switch self {
        case .invalidJournal: "The privacy reset journal could not be read safely. Check device storage and recheck it before continuing."
        case .staleRequest: "Your data or privacy settings changed. Review this action again."
        case .corruptExport: "A local record could not be exported. No partial archive was shared."
        case .tooLarge: "This archive is too large to prepare safely on this device. No partial archive was shared."
        case .deletionRequired: "A confirmed deletion is unfinished. Retry it before continuing."
        }
    }
}

enum MainActorDataAccessGate {
    static var isBlocked: Bool { DataDeletionGate.shared.isBlocked }
}
