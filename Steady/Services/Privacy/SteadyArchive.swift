import CoreTransferable
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// The share item holds a revocable lease, not a second retained copy of the JSON.
struct SteadyArchive: Transferable, Sendable {
    let lease: ArchiveLease

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { (archive: SteadyArchive) in
            try await archive.lease.read()
        }
        .suggestedFileName("Steady-local-data.json")
    }
}

@MainActor
final class ArchiveLease {
    private static var active: [ArchiveLease] = []
    private var data: Data?
    private let revision: Int
    private let container: ModelContainer
    private let modes: [UUID: Bool]

    init(data: Data, container: ModelContainer, profiles: [ProfileRecord]) {
        self.data = data
        self.container = container
        self.revision = DataDeletionGate.shared.revision
        self.modes = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0.lowDataMode) })
        Self.active.append(self)
    }

    func read() throws -> Data {
        guard !DataDeletionGate.shared.isBlocked, revision == DataDeletionGate.shared.revision,
              let data else { throw PrivacyDataError.staleRequest }
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let current = try context.fetch(FetchDescriptor<ProfileRecord>())
        guard Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0.lowDataMode) }) == modes else {
            invalidate()
            throw PrivacyDataError.staleRequest
        }
        return data
    }

    func invalidate() { data = nil; Self.active.removeAll { $0 === self } }

    static func invalidateAll() {
        for lease in active { lease.data = nil }
        active = []
    }
}

struct ArchivePreparation {
    let item: SteadyArchive
    let metadataOnly: Bool
    let counts: [String: Int]
}
