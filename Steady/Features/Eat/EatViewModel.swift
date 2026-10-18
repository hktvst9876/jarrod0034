import Foundation
import Observation
import SteadyCore
import SwiftData

@MainActor
@Observable
final class EatViewModel {
    var inputs = EatRequestInputs()
    var approximateCoordinate: FoodCoordinate?
    private(set) var approximateLocationCapturedAt: Date?
    var selection: FoodSelection?
    var saved: [FoodSavedCorrection] = []
    var editor: FoodEditorSource?
    var confirmation: FoodCorrectionProposal?
    var isWorking = false
    var message: String?
    var failure: String?
    private(set) var revision = UUID()
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var confirmationSource: EatActionSource?
    @ObservationIgnored private var pendingConfirmation: FoodCorrectionProposal?
    @ObservationIgnored private var savedVersion: [FoodStoredVersion] = []
    @ObservationIgnored private var savedStorageAvailable = false
    @ObservationIgnored private var selectionSource: EatActionSource?
    @ObservationIgnored private var selectionCheckedAt: Date?
    @ObservationIgnored private var activeSource: EatActionSource?

    func source(profile: ProfileRecord, sample: Bool, environment: AppEnvironment) -> EatActionSource {
        EatActionSource(dataRevision: DataDeletionGate.shared.revision, profileID: profile.id, sample: sample,
            day: environment.calendar.startOfDay(for: environment.now),
            dietaryNotes: profile.dietaryRulesText, allergyNotes: profile.allergiesText,
            maxPrice: profile.maxPricePerMealSGD, lowDataMode: profile.lowDataMode,
            request: inputs, revision: revision, savedVersion: savedVersion)
    }

    func invalidate(clearLocation: Bool = false) {
        task?.cancel(); task = nil
        revision = UUID(); isWorking = false
        selection = nil; editor = nil; confirmation = nil; confirmationSource = nil; pendingConfirmation = nil
        selectionSource = nil; selectionCheckedAt = nil
        activeSource = nil
        if clearLocation { approximateCoordinate = nil; approximateLocationCapturedAt = nil }
    }

    func load(profile: ProfileRecord, sample: Bool, context: ModelContext) {
        guard !DataDeletionGate.shared.isBlocked else { invalidate(clearLocation: true); return }
        do {
            let result = try readSaved(profileID: profile.id, sample: sample, context: context)
            saved = result.corrections; savedVersion = result.version; savedStorageAvailable = true
            failure = nil
        } catch {
            saved = []; savedVersion = []; savedStorageAvailable = false
            failure = "Could not open saved food observations. Your records have not been erased. Try again before remembering a change."
        }
    }

    func find(profile: ProfileRecord, sample: Bool, environment: AppEnvironment, context: ModelContext) {
        expireIfNeeded(profile: profile, sample: sample, environment: environment, context: context)
        invalidate()
        load(profile: profile, sample: sample, context: context)
        let captured = source(profile: profile, sample: sample, environment: environment)
        let near = approximateCoordinate
        let request = inputs.request(profile: profile, usingApproximateLocation: near != nil)
        let savedCandidates = saved.map(\.candidate)
        let checkedAt = environment.now
        message = nil; isWorking = true
        activeSource = captured
        task = Task { [weak self] in
            guard let self else { return }
            var discovered: [FoodCandidate] = []
            var status: String?
            if near != nil || !request.area.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                do {
                    let places = try await environment.foodDiscovery(useSampleData: sample)
                        .discover(area: request.area, near: near, checkedAt: checkedAt)
                    discovered = places.map(FoodCandidate.discoveredPlace)
                    if sample { status = "Sample mode makes no live place search. Add a manual saved observation to try the confirmation flow." }
                    else if places.isEmpty { status = "No places returned. Your saved observations are still available; try another typed area." }
                } catch {
                    status = "Place search was unavailable. Showing only your saved observations; typed areas and manual saving still work."
                }
            } else {
                status = "Using saved observations only. Type an area or explicitly use approximate location for a place search."
            }
            guard !Task.isCancelled, self.isCurrent(captured, profile: profile, sample: sample, environment: environment) else { return }
            guard let latest = try? self.readSaved(profileID: profile.id, sample: sample, context: context),
                  latest.version == captured.savedVersion else {
                self.isWorking = false; self.task = nil; self.activeSource = nil
                self.load(profile: profile, sample: sample, context: context)
                self.message = "Saved observations changed while searching. Tap Find choices to use the current records."
                return
            }
            self.selection = FoodSelector.select(candidates: savedCandidates + discovered, request: request, now: environment.now)
            self.selectionSource = captured; self.selectionCheckedAt = environment.now
            self.message = status; self.isWorking = false
            self.task = nil; self.activeSource = nil
        }
    }

    func requestLocation(profile: ProfileRecord, sample: Bool, environment: AppEnvironment) {
        invalidate(clearLocation: true)
        let captured = source(profile: profile, sample: sample, environment: environment)
        isWorking = true; message = nil
        activeSource = captured
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let coordinate = try await environment.foodLocation(useSampleData: sample).approximateLocation()
                guard !Task.isCancelled, self.isCurrent(captured, profile: profile, sample: sample, environment: environment) else { return }
                self.approximateCoordinate = coordinate
                self.approximateLocationCapturedAt = environment.now
                self.message = "Approximate area is ready for this screen only. Tap Find choices to search."
            } catch {
                guard !Task.isCancelled, self.isCurrent(captured, profile: profile, sample: sample, environment: environment) else { return }
                self.message = "Approximate location is unavailable or not shared. Type an area, use a saved area, or use saved observations."
            }
            self.isWorking = false; self.task = nil; self.activeSource = nil
        }
    }

    func startEditor(candidate: FoodCandidate?, profile: ProfileRecord, sample: Bool, environment: AppEnvironment) {
        guard savedStorageAvailable else {
            failure = "Saved food records are unavailable. Try Find choices again before remembering a change."
            return
        }
        task?.cancel(); task = nil; isWorking = false; activeSource = nil
        editor = FoodEditorSource(candidate: candidate,
            actionSource: source(profile: profile, sample: sample, environment: environment),
            observedAt: candidate?.ingredients?.checkedAt ?? candidate?.price?.checkedAt ?? environment.now)
    }

    func prepareRemember(_ draft: FoodCorrectionDraft, source: EatActionSource,
                         profile: ProfileRecord, sample: Bool, environment: AppEnvironment) -> Bool {
        guard !DataDeletionGate.shared.isBlocked,
              source == self.source(profile: profile, sample: sample, environment: environment),
              let proposal = FoodCorrectionReducer.propose(draft: draft, remember: true,
                profileID: profile.id, isSample: sample, now: environment.now, operationID: UUID()) else {
            failure = "This observation changed or belongs to an earlier day. Reopen it before remembering anything."
            return false
        }
        editor = nil
        confirmationSource = source
        pendingConfirmation = proposal
        return true
    }

    func editorDismissed() {
        if let pendingConfirmation {
            self.pendingConfirmation = nil
            confirmation = pendingConfirmation
        }
    }

    func confirmRemember(profile: ProfileRecord, sample: Bool, environment: AppEnvironment, context: ModelContext) -> Bool {
        guard !DataDeletionGate.shared.isBlocked, let proposal = confirmation, let captured = confirmationSource,
              captured == source(profile: profile, sample: sample, environment: environment),
              let latest = try? readSaved(profileID: profile.id, sample: sample, context: context),
              latest.version == captured.savedVersion,
              let correction = FoodCorrectionReducer.confirm(proposal: proposal, profileID: profile.id,
                isSample: sample, now: environment.now, existing: latest.corrections) else {
            failure = "This confirmation expired or its food preferences changed. Nothing was remembered; review the observation again."
            confirmation = nil; confirmationSource = nil
            return false
        }
        let key = "\(profile.id.uuidString)-\(sample)-\(correction.candidate.id)"
        // A food-only transaction must never roll back unsaved profile or plan edits.
        let foodContext = ModelContext(context.container)
        foodContext.autosaveEnabled = false
        do {
            let row = try foodContext.fetch(FetchDescriptor<FoodCorrectionRecord>(predicate: #Predicate { $0.key == key })).first
            let encoded = try JSONEncoder().encode(correction)
            if let row { row.correctionData = encoded; row.updatedAt = environment.now }
            else { foodContext.insert(try FoodCorrectionRecord(key: key, profileID: profile.id, sampleData: sample,
                        correction: correction, at: environment.now)) }
            try foodContext.save()
            confirmation = nil; confirmationSource = nil
            load(profile: profile, sample: sample, context: context)
            revision = UUID(); selection = nil; selectionSource = nil; selectionCheckedAt = nil
            message = "Remembered on this device as a prior-visit observation, not a current ingredient or allergy guarantee. Tap Find choices to use it."
            return true
        } catch {
            foodContext.rollback()
            failure = "Could not remember this observation. It has not changed ranking. Your earlier saved records remain available."
            return false
        }
    }

    func cancelRemember() { confirmation = nil; confirmationSource = nil; pendingConfirmation = nil }

    /// Foreground-only expiry; never searches, requests permission, or remembers anything.
    func expireIfNeeded(profile: ProfileRecord, sample: Bool, environment: AppEnvironment, context: ModelContext) {
        let now = environment.now
        let captured = source(profile: profile, sample: sample, environment: environment)
        let oldSource = activeSource ?? selectionSource ?? confirmationSource ?? editor?.actionSource
        let locationExpired = approximateLocationCapturedAt.map {
            let age = now.timeIntervalSince($0)
            return !age.isFinite || age < 0 || age >= 600
        } ?? false
        let selectionExpired = selectionCheckedAt.map {
            let age = now.timeIntervalSince($0)
            return !age.isFinite || age < 0 || age >= 600
        } ?? false
        let confirmationExpired = confirmation.map {
            let age = now.timeIntervalSince($0.createdAt)
            return !age.isFinite || age < 0 || age >= 900
        } ?? false
        let storedChanged: Bool
        if selectionSource != nil || confirmationSource != nil || editor != nil {
            storedChanged = (try? readSaved(profileID: profile.id, sample: sample, context: context).version) != savedVersion
        } else { storedChanged = false }
        guard locationExpired || selectionExpired || confirmationExpired || storedChanged || (oldSource != nil && oldSource != captured) else { return }
        invalidate(clearLocation: true)
        load(profile: profile, sample: sample, context: context)
        message = "This request, observation review, or captured area needs refreshing. Nothing was remembered. Tap Find choices again, type an area, or explicitly request approximate location again."
    }

    private func readSaved(profileID: UUID, sample: Bool, context: ModelContext) throws
        -> (corrections: [FoodSavedCorrection], version: [FoodStoredVersion]) {
        let foodContext = ModelContext(context.container)
        foodContext.autosaveEnabled = false
        let rows = try foodContext.fetch(FetchDescriptor<FoodCorrectionRecord>(
            predicate: #Predicate { $0.profileID == profileID && $0.sampleData == sample })).sorted { $0.key < $1.key }
        let corrections = try rows.map { row in
            let correction = try JSONDecoder().decode(FoodSavedCorrection.self, from: row.correctionData)
            let candidate = correction.candidate
            guard row.key == "\(profileID.uuidString)-\(sample)-\(candidate.id)",
                  candidate.ingredients?.source.kind == .userSaved,
                  candidate.ingredients?.source.recordID == correction.id.uuidString,
                  candidate.ingredients?.source.placeID == candidate.place?.id,
                  candidate.price == nil || (candidate.price?.source.kind == .userSaved
                    && candidate.price?.source.recordID == correction.id.uuidString
                    && candidate.price?.source.placeID == candidate.place?.id),
                  candidate.place?.coordinate == nil, candidate.place?.websiteURL == nil,
                  candidate.nutrition == nil, candidate.officialMenu == nil else {
                throw FoodSavedReadError.invalidRecord
            }
            return correction
        }
        let version = rows.map { FoodStoredVersion(key: $0.key, data: $0.correctionData, updatedAt: $0.updatedAt) }
        return (corrections, version)
    }

    private func isCurrent(_ captured: EatActionSource, profile: ProfileRecord, sample: Bool, environment: AppEnvironment) -> Bool {
        guard !DataDeletionGate.shared.isBlocked,
              captured == source(profile: profile, sample: sample, environment: environment) else {
            // A stale callback may clear only its own operation, never a newer search.
            if captured.revision == revision, activeSource == captured {
                task = nil; activeSource = nil; isWorking = false
                message = "The day or food preferences changed during this request. Tap Find choices again. Nothing was saved."
            }
            return false
        }
        return true
    }
}

private enum FoodSavedReadError: Error { case invalidRecord }
