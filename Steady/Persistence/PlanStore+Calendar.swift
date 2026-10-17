import Foundation
import SteadyCore
import SwiftData

extension PlanStore {
    func confirm(_ proposal: RescheduleProposal, source: PlanItem, profile: ProfileRecord,
                 sample: Bool, environment: AppEnvironment, context: ModelContext) async -> Bool {
        guard !isWorking, record?.calendarEventDeleted != true else { return false }
        guard plan?.status != .completed && plan?.status != .intentionallyRested else {
            failure = "This plan is already finished. Calendar has not been changed."
            return false
        }
        isWorking = true; defer { isWorking = false }
        guard validateForMutation(source, profile: profile, sample: sample, environment: environment) else { return false }
        guard proposal.planID == source.id, proposal.title == source.title,
              proposal.durationMinutes == source.minutes,
              proposal.end.timeIntervalSince(proposal.start) == Double(source.minutes) * 60 else {
            failure = "This time proposal no longer matches the plan. Close alternatives and refresh."
            return false
        }
        guard await refreshSafety(profile: profile, sample: sample, environment: environment) else { return false }
        guard validateForMutation(source, profile: profile, sample: sample, environment: environment) else { return false }
        var writeAttempted = false
        var remoteSaved = false
        let wasPending = record?.pendingCalendarData != nil
        do {
            guard await environment.calendar(useSampleData: sample).accessState() == .fullAccess else {
                throw CalendarServiceError.accessRequired
            }
            try validateSource(source, profile: profile, sample: sample, environment: environment)
            let write: CalendarWriteProposal
            if let data = record?.pendingCalendarData {
                write = try JSONDecoder().decode(CalendarWriteProposal.self, from: data)
                guard write.operationID == proposal.id, write.title == proposal.title,
                      write.start == proposal.start, write.end == proposal.end else { throw PlanStoreError.pendingCalendar }
            } else {
                write = CalendarWriteProposal(title: proposal.title, start: proposal.start, end: proposal.end,
                    notes: "Deferred by you in Steady.", existingEventIdentifier: record?.eventIdentifier, operationID: proposal.id)
            }
            let saved = try ensureRecord(source, profile: profile, sample: sample, environment: environment, context: context)
            saved.pendingCalendarData = try JSONEncoder().encode(write)
            try context.save()
            let confirmed = UserConfirmedCalendarWrite.afterUserTappedConfirm(write)
            writeAttempted = true
            let identifier = try await environment.calendar(useSampleData: sample).write(confirmed)
            remoteSaved = true
            try validateSource(source, profile: profile, sample: sample, environment: environment)
            let slot = FreeSlot(start: write.start, end: write.end, confidence: sample ? .manual : .calendarDerived)
            let deferred = copy(source, status: .deferred, slot: slot)
            saved.planData = try JSONEncoder().encode(deferred)
            saved.eventIdentifier = identifier
            saved.pendingCalendarData = nil
            saved.updatedAt = environment.now
            try insertChoice(action: "schedule", barrier: nil, optionID: selectedOption?.id, plan: source,
                             profile: profile, sample: sample, at: environment.now, context: context)
            try context.save()
            try refreshValues()
            message = sample ? "Sample event saved. Your real Calendar was not changed." : "Saved to your Steady calendar."
            return true
        } catch {
            context.rollback()
            let removedEvent: Bool
            if let serviceError = error as? CalendarServiceError {
                removedEvent = switch serviceError { case .eventMissing, .eventNotOwned: true; default: false }
            } else { removedEvent = false }
            if !remoteSaved && (removedEvent || (!wasPending && (!writeAttempted || knownNoCalendarChange(error)))) {
                record?.pendingCalendarData = nil
                if removedEvent {
                    record?.calendarEventDeleted = true
                    record?.eventIdentifier = nil
                    if let encoded = try? JSONEncoder().encode(copy(source, status: .deferred, slot: nil)) { record?.planData = encoded }
                }
                do { try context.save() } catch { context.rollback() }
            }
            return fail(error, context: context)
        }
    }

    func pendingProposal() -> RescheduleProposal? {
        guard let data = record?.pendingCalendarData,
              let pending = try? JSONDecoder().decode(CalendarWriteProposal.self, from: data),
              let plan else { return nil }
        return RescheduleProposal(id: pending.operationID, planID: plan.id, title: pending.title, start: pending.start, end: pending.end)
    }

    func abandonPending(source: PlanItem, profile: ProfileRecord, sample: Bool, environment: AppEnvironment, context: ModelContext) {
        guard !isWorking else { return }
        guard validateForMutation(source, profile: profile, sample: sample, environment: environment, allowSafetyRest: true) else { return }
        record?.pendingCalendarData = nil
        do {
            try context.save()
            failure = nil
            message = "Calendar retry cleared. Check Calendar for the previous event before making another time."
        } catch { _ = fail(error, context: context) }
    }

    func replacePriority(_ source: PlanItem, profile: ProfileRecord, sample: Bool,
                         environment: AppEnvironment, context: ModelContext) async {
        guard !isWorking else { return }
        isWorking = true; defer { isWorking = false }
        do { try validateContext(profile: profile, sample: sample, environment: environment) }
        catch { failure = error.localizedDescription; return }
        guard await refreshSafety(profile: profile, sample: sample, environment: environment) else { return }
        do {
            try validateContext(profile: profile, sample: sample, environment: environment)
            guard environment.calendar.isDate(source.day, inSameDayAs: environment.now) else { throw PlanStoreError.contextChanged }
            guard record?.pendingCalendarData == nil else { throw PlanStoreError.pendingCalendar }
            let saved = try ensureRecord(source, profile: profile, sample: sample, environment: environment, context: context)
            saved.originalPlanData = try JSONEncoder().encode(source)
            try persist(source, original: source, selected: nil, action: "priority", barrier: nil,
                        profile: profile, sample: sample, environment: environment, context: context)
            message = "Your selected priority is saved."
        } catch { _ = fail(error, context: context) }
    }

    func knownNoCalendarChange(_ error: Error) -> Bool {
        guard let serviceError = error as? CalendarServiceError else { return false }
        return switch serviceError {
        case .accessRequired, .calendarSourceUnavailable, .invalidProposal, .slotUnavailable, .eventMissing, .eventNotOwned: true
        case .saveFailed: false
        }
    }

}
