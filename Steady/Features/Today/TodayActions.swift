import SteadyCore
import SwiftData
import SwiftUI

extension TodayView {
    func reload() async {
        let requestedMode = useSampleData
        let requestedProfileID = profile.id
        let requestedDay = environment.calendar.startOfDay(for: environment.now)
        let loaded = await model.load(profile: profile, environment: environment, useSampleData: requestedMode,
            requestIsCurrent: { requestedMode == useSampleData && requestedProfileID == profile.id })
        guard loaded, !Task.isCancelled, requestedMode == useSampleData, requestedProfileID == profile.id,
              requestedDay == environment.calendar.startOfDay(for: environment.now) else { return }
        await planStore.load(profile: profile, sample: requestedMode, snapshot: model.snapshot, proposedPlan: model.priority?.planA,
                             environment: environment, context: modelContext)
        guard !Task.isCancelled, requestedMode == useSampleData, requestedProfileID == profile.id,
              requestedDay == environment.calendar.startOfDay(for: environment.now) else { return }
        foundationStore.load(profile: profile, sample: requestedMode, environment: environment, context: modelContext)
        foundationStore.retainSafety(planStore.safetyFlags)
        await FoundationReminderCoordinator.refresh(store: foundationStore, profile: profile, sample: requestedMode,
            snapshot: model.snapshot, environment: environment, context: modelContext)
    }

    func saveCheckIn(_ checkIn: CheckIn) {
        guard !DataDeletionGate.shared.isBlocked, modelContext.autosaveEnabled else { return }
        profile.lastMorningCheckInAt = environment.now
        profile.lastMorningCheckInRawValue = checkIn.rawValue
        do {
            try modelContext.save()
            model.showMorningCheckIn = false
            model.updatePriority(profile: profile, now: environment.now, calendar: environment.calendar)
            planStore.suggestedPlan = model.priority?.planA
        } catch {
            modelContext.rollback()
            saveError = error.localizedDescription
        }
    }

    func saveSymptom(_ symptom: Symptom) {
        guard !DataDeletionGate.shared.isBlocked, modelContext.autosaveEnabled else { return }
        profile.reportedSafetySymptomAt = environment.now
        profile.reportedSafetySymptomRawValue = symptom.rawValue
        do {
            try modelContext.save()
        } catch {
            saveError = error.localizedDescription
        }
        model.report(symptom, profile: profile, now: environment.now, calendar: environment.calendar)
        planStore.suggestedPlan = model.priority?.planA
        if !planStore.safetyFlags.contains(.userReported(symptom)) { planStore.safetyFlags.append(.userReported(symptom)) }
        if !planStore.sessionSafetyFlags.contains(.userReported(symptom)) { planStore.sessionSafetyFlags.append(.userReported(symptom)) }
        foundationStore.retainSafety(planStore.safetyFlags)
        Task {
            await FoundationReminderCoordinator.refresh(store: foundationStore, profile: profile, sample: useSampleData,
                snapshot: model.snapshot, environment: environment, context: modelContext)
        }
    }

    var foundationsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Foundations").font(.headline)
            Text("Optional mobility, daylight, water, study-break, reset, and wind-down options. No daily target to fill.")
                .font(.subheadline).foregroundStyle(.secondary)
            if foundationStore.safetyMessage == nil, foundationStore.movementPreferencesConfirmed(profile: profile),
               let quiet = foundationStore.silentCards.first(where: {
                   foundationStore.item($0.kind)?.status != .done && foundationStore.item($0.kind)?.status != .disabled
               }) {
                Text("Quiet option for later: \(quiet.title)").font(.subheadline.bold())
                Text(quiet.body).font(.footnote).foregroundStyle(.secondary)
            }
            Button("Open Foundations", systemImage: "leaf") { showFoundations = true }
                .buttonStyle(.bordered)
            if let message = foundationStore.reminderMessage { Text(message).font(.footnote).foregroundStyle(.secondary) }
        }.steadyCard()
    }
}
