import Foundation
import Observation
import SteadyCore
import SwiftData

@MainActor
@Observable
final class DataLifecycle {
    private(set) var revision = DataDeletionGate.shared.revision
    private(set) var isBlocked = DataDeletionGate.shared.isBlocked
    private(set) var isDeleting = false
    private(set) var errorMessage: String?
    var hasConfirmedDeletion: Bool { DataDeletionGate.shared.hasPendingDeletion }

    func recheckJournal() {
        DataDeletionGate.shared.reload()
        synchronize()
        if isBlocked && !hasConfirmedDeletion { errorMessage = PrivacyDataError.invalidJournal.localizedDescription }
        else { errorMessage = nil }
    }

    func synchronize() {
        revision = DataDeletionGate.shared.revision
        isBlocked = DataDeletionGate.shared.isBlocked
    }

    func deleteAll(container: ModelContainer, sharedContext: ModelContext,
                   environment: AppEnvironment, expectedRevision: Int?) async {
        guard !isDeleting else { return }
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false; synchronize() }
        let priorAutosave = sharedContext.autosaveEnabled
        let priorRevision = DataDeletionGate.shared.revision
        // An abandoned shared context must never autosave records after the fresh deletion transaction.
        sharedContext.autosaveEnabled = false
        do {
            let authority = LocalResetAuthorization.evaluate(expectedRevision: expectedRevision,
                currentRevision: priorRevision, isBlocked: DataDeletionGate.shared.isBlocked,
                hasPendingDeletion: DataDeletionGate.shared.hasPendingDeletion)
            guard authority != .refuse else { throw PrivacyDataError.staleRequest }
            if authority == .begin {
                let context = ModelContext(container)
                context.autosaveEnabled = false
                let issued = try context.fetch(FetchDescriptor<WatchIssuedSnapshotRecord>()).map(\.revision).max() ?? 0
                let millis = environment.now.timeIntervalSince1970 * 1_000
                guard millis.isFinite, millis >= 0, millis < Double(Int.max - 2),
                      issued < Int.max - 2, priorRevision < Int.max - 2 else { throw PrivacyDataError.staleRequest }
                let cutoff = max(Int(millis), max(issued, priorRevision) + 1)
                try DataDeletionGate.shared.begin(CompanionEraseControl(revision: cutoff, createdAt: environment.now))
            }
            synchronize() // Unmount all data-entry views before any suspension point.
            ArchiveLease.invalidateAll()
            environment.advisor.resetForDeletion()
            environment.companion(useSampleData: false).start()
            await environment.clearLocalServicesForDeletion()
            // Each retry is safe after partial cleanup. Only this isolated context is changed.
            try LocalRecordDeletion.erase(in: container)
            try CompanionDiskInbox.shared.eraseAllPersonalData()
            for key in UserDefaults.standard.dictionaryRepresentation().keys
                where key == "useSampleData" || key.hasPrefix("steady.") {
                UserDefaults.standard.removeObject(forKey: key)
            }
            guard let control = DataDeletionGate.shared.currentErase else { throw PrivacyDataError.invalidJournal }
            // Persisted tombstone is retried by the transport on activation; offline Watch is not instant-erased.
            try? environment.companion(useSampleData: false).requestErase(control)
            try DataDeletionGate.shared.finish()
        } catch {
            errorMessage = error.localizedDescription
            // A failure before begin is not a deletion: let this context keep its previous policy.
            if !DataDeletionGate.shared.isBlocked, DataDeletionGate.shared.revision == priorRevision {
                sharedContext.autosaveEnabled = priorAutosave
            }
        }
    }
}

@MainActor
private enum LocalRecordDeletion {
    static func erase(in container: ModelContainer) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        try remove(ProfileRecord.self, context)
        try remove(PlanRecord.self, context)
        try remove(ChoiceRecord.self, context)
        try remove(FoundationPreferenceRecord.self, context)
        try remove(FoundationDayRecord.self, context)
        try remove(FoundationResponseRecord.self, context)
        try remove(FoodCorrectionRecord.self, context)
        try remove(WatchIssuedSnapshotRecord.self, context)
        try remove(WatchActionReceiptRecord.self, context)
        try remove(WatchMovementRecord.self, context)
        try remove(WatchMealHandoffRecord.self, context)
        try remove(WeeklyReviewRecord.self, context)
        try remove(WeeklyExperimentRecord.self, context)
        try remove(WeeklyMetricRecord.self, context)
        try context.save()
    }

    private static func remove<T: PersistentModel>(_ type: T.Type, _ context: ModelContext) throws {
        for record in try context.fetch(FetchDescriptor<T>()) { context.delete(record) }
    }
}
