import Foundation
import SteadyCore
import SwiftData

extension WatchPhoneCoordinator {
    /// Already-committed results need no new wellness mutation or current snapshot.
    /// Replay these before opening current controls, including after a UI reload failure or daily cap.
    func replayCommittedReceipts(environment: AppEnvironment, context: ModelContext) throws {
        for data in try CompanionDiskInbox.shared.read().actions {
            guard let action = try? WatchWireCodec.decodeAction(data) else { continue }
            let id = action.id
            guard let row = try context.fetch(FetchDescriptor<WatchActionReceiptRecord>(predicate: #Predicate { $0.id == id })).first else { continue }
            let saved = try WatchWireCodec.decodeReceipt(row.receiptData)
            let response = saved.action == action ? saved : WatchActionReceipt(action: action,
                status: .rejected(.conflictingReplay), processedAt: environment.now)
            try acknowledge(response, raw: data, environment: environment)
        }
    }

    func processInbox(issued: WatchIssuedSnapshotRecord?, state: inout WatchPhoneState,
                      profile: ProfileRecord, sample: Bool, today: TodayViewModel, plans: PlanStore,
                      foundations: FoundationStore, flags: [SafetyFlag], environment: AppEnvironment,
                      context: ModelContext, transaction: ModelContext) throws {
        let queued = try CompanionDiskInbox.shared.read().actions
        let receiptDay = environment.calendar.startOfDay(for: environment.now)
        guard let nextReceiptDay = environment.calendar.date(byAdding: .day, value: 1, to: receiptDay) else {
            throw WatchPhoneError.unavailable
        }
        for data in queued {
            let action: WatchAction
            do { action = try WatchWireCodec.decodeAction(data) }
            catch {
                // Invalid bytes have no action authority and cannot yield a trustworthy action ID.
                try CompanionDiskInbox.shared.removeAction(data)
                message = "An unsupported Watch message was ignored. Open both apps to refresh."
                continue
            }
            let id = action.id
            let prior = try transaction.fetch(FetchDescriptor<WatchActionReceiptRecord>(predicate: #Predicate { $0.id == id })).first
            if let prior {
                let saved = try WatchWireCodec.decodeReceipt(prior.receiptData)
                let response = saved.action == action ? saved : WatchActionReceipt(action: action,
                    status: .rejected(.conflictingReplay), processedAt: environment.now)
                try acknowledge(response, raw: data, environment: environment)
                continue
            }
            let dailyCount = try transaction.fetchCount(FetchDescriptor<WatchActionReceiptRecord>(
                predicate: #Predicate { $0.processedAt >= receiptDay && $0.processedAt < nextReceiptDay }))
            guard dailyCount < 256 else {
                message = "Today's Watch action inbox is at its local limit. Existing actions stay queued; phone actions still work."
                throw WatchPhoneError.dailyLimit
            }
            let snapshot = try issued.map { try WatchWireCodec.decodeSnapshot($0.snapshotData) }
            let status: WatchReceiptStatus
            if let issued, let snapshot {
                let decision = WatchActionValidator.evaluate(action, snapshot: snapshot,
                    current: state.current(snapshot: snapshot, profile: profile, sample: sample, environment: environment),
                    receipts: [], clock: FixedClock(now: environment.now), calendar: environment.calendar)
                switch decision {
                case .apply:
                    status = issued.bindingDigest == state.bindingDigest ? .accepted : .rejected(.contextChanged)
                case .reject(let reason): status = .rejected(reason)
                case .replay(let receipt): status = receipt.status
                }
            } else { status = .rejected(.unavailable) }
            guard !context.hasChanges else { throw WatchPhoneError.busy }
            let receipt = WatchActionReceipt(action: action, status: status, processedAt: environment.now)
            do {
                if status == .accepted {
                    try apply(action, state: state, profile: profile, sample: sample,
                        environment: environment, context: transaction)
                }
                transaction.insert(try WatchActionReceiptRecord(receipt: receipt))
                // Receipt and permitted mutation share this one save. No success can escape before it.
                try transaction.save()
            } catch {
                transaction.rollback()
                throw error
            }
            if status == .accepted {
                try reloadCommittedState(action: action, profile: profile, sample: sample,
                    today: today, plans: plans, foundations: foundations, environment: environment,
                    context: context, transaction: transaction)
                state = try WatchPhoneState.read(profile: profile, sample: sample, today: today, planStore: plans,
                    flags: flags, environment: environment, context: transaction)
                message = "A Watch action was saved on this phone. No Calendar or Health record was written."
            }
            try acknowledge(receipt, raw: data, environment: environment)
        }
    }

    private func acknowledge(_ receipt: WatchActionReceipt, raw: Data, environment: AppEnvironment) throws {
        try environment.companion(useSampleData: false).sendReceipt(WatchWireCodec.encode(receipt))
        // A failed acknowledgement leaves the raw inbox entry, so the durable receipt is replayed next time.
        try CompanionDiskInbox.shared.removeAction(raw)
    }

    private func apply(_ action: WatchAction, state: WatchPhoneState, profile: ProfileRecord,
                       sample: Bool, environment: AppEnvironment, context: ModelContext) throws {
        switch action.kind {
        case .chooseAlternative(let id):
            guard let source = state.plan, let options = state.alternatives,
                  let selected = options.options.first(where: { $0.id == id }),
                  state.planRecord?.pendingCalendarData == nil else { throw WatchPhoneError.changed }
            let result = try AlternativeChoiceReducer.apply(AlternativeChoiceEvent(id: action.id,
                at: environment.now, action: .choose(optionID: id)), to: AlternativeChoiceState(plan: source),
                options: options, safetyFlags: state.safetyFlags)
            let key = "\(profile.id.uuidString)-\(Int(action.day.timeIntervalSinceReferenceDate))-\(sample)"
            let row = try state.planRecord ?? PlanRecord(key: key, profileID: profile.id,
                day: action.day, sampleData: sample, plan: source, at: environment.now)
            if row.modelContext == nil { context.insert(row) }
            row.planData = try JSONEncoder().encode(result.plan)
            row.selectedOptionData = try JSONEncoder().encode(selected)
            row.movementNoteAtChoice = profile.movementsToAvoid
            row.startedAt = nil
            row.updatedAt = environment.now
            let choice = SavedChoice(id: action.id, planID: source.id, at: environment.now,
                action: "choose", barrier: .anotherOption, optionID: id)
            context.insert(try ChoiceRecord(choice: choice, profileID: profile.id, sampleData: sample))
        case .logMovement(let kind, let minutes):
            context.insert(WatchMovementRecord(action: action, kind: kind, minutes: minutes, receivedAt: environment.now))
        case .foundationDone(let kind, let optionID):
            guard state.foundation?.kind == kind, state.foundation?.id == optionID else { throw WatchPhoneError.changed }
            let event = FoundationEvent(id: action.id, day: action.day, kind: kind, action: .done)
            let value = try FoundationReducer.apply(event, to: state.foundationState, now: environment.now,
                calendar: environment.calendar, safetyFlags: state.safetyFlags)
            let preferenceKey = "\(profile.id.uuidString)-\(sample)"
            let preference = try state.preferences ?? FoundationPreferenceRecord(key: preferenceKey,
                profileID: profile.id, sampleData: sample, at: environment.now)
            let key = "\(preferenceKey)-\(Int(action.day.timeIntervalSinceReferenceDate))"
            let day = try state.foundationRecord ?? FoundationDayRecord(key: key, profileID: profile.id,
                sampleData: sample, state: value, at: environment.now)
            if preference.modelContext == nil { context.insert(preference) }
            if day.modelContext == nil { context.insert(day) }
            var counts = try JSONDecoder().decode([FoundationKind: Int].self, from: preference.dismissalCountsData)
            counts[kind] = 0
            preference.dismissalCountsData = try JSONEncoder().encode(counts)
            preference.settingsData = try JSONEncoder().encode(value.settings)
            preference.updatedAt = environment.now
            day.stateData = try JSONEncoder().encode(value); day.updatedAt = environment.now
            context.insert(FoundationResponseRecord(id: action.id, profileID: profile.id, sampleData: sample,
                day: action.day, kind: kind, action: "done", at: environment.now))
        case .savedMealHandoff(let correctionID):
            guard state.saved.contains(where: { $0.id.uuidString == correctionID }) else { throw WatchPhoneError.changed }
            context.insert(WatchMealHandoffRecord(action: action, correctionID: correctionID))
        }
    }
}
