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
    }

    func saveCheckIn(_ checkIn: CheckIn) {
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
    }
}
