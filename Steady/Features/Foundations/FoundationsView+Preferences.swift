import SteadyCore
import SwiftUI

extension FoundationsView {
    var preferences: some View {
        DisclosureGroup("Movement preferences and quiet times") {
            VStack(alignment: .leading, spacing: 12) {
                if !profile.movementsToAvoid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Your saved movement note: \(profile.movementsToAvoid)")
                    Text("Steady does not interpret this as an injury. Choose your preferences explicitly, then save.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Picker("Movement preference", selection: $mode) {
                    Text("Standing").tag(AlternativeMovementMode.standing)
                    Text("Seated").tag(AlternativeMovementMode.seated)
                    Text("Wheelchair").tag(AlternativeMovementMode.wheelchair)
                }
                ForEach(AlternativeMovement.allCases, id: \.rawValue) { movement in
                    Toggle("Avoid \(movement.rawValue)", isOn: Binding(
                        get: { avoids.contains(movement) },
                        set: { if $0 { avoids.insert(movement) } else { avoids.remove(movement) } }))
                }
                Divider()
                Text("Quiet periods").font(.headline)
                Text("A period may cross midnight. Equal start and end means quiet all day. Planned sleep is also protected.")
                    .font(.footnote).foregroundStyle(.secondary)
                ForEach(Array(quiet.enumerated()), id: \.offset) { index, period in
                    HStack {
                        Text(quietDescription(period)).font(.subheadline)
                        Spacer()
                        Button("Remove", systemImage: "minus.circle") { quiet.remove(at: index) }.labelStyle(.iconOnly)
                    }
                }
                DatePicker("Quiet start", selection: minutesBinding($quietStart), displayedComponents: .hourAndMinute)
                DatePicker("Quiet end", selection: minutesBinding($quietEnd), displayedComponents: .hourAndMinute)
                Button("Add quiet period") {
                    if !quiet.contains(where: { $0.startMinute == quietStart && $0.endMinute == quietEnd }) {
                        quiet.append(NudgeQuietPeriod(startMinute: quietStart, endMinute: quietEnd))
                    }
                }
                Button("Why these times") {
                    why = WhyItem(title: "Quiet periods", explanation: "These are your selected Singapore-time windows. Reminders are moved or dropped inside them; in-app Foundations stay available when you open the app.")
                }.font(.footnote)
                Button("Save these preferences") {
                    guard let source = store.source(profile: profile) else { return }
                    if store.savePreferences(mode: mode, avoids: avoids, quiet: quiet, source: source, profile: profile,
                        sample: sample, environment: environment, context: context) { Task { await refreshReminders() } }
                }.buttonStyle(.borderedProminent)
                Text("Edits above apply only after Save. Your daily Done choices are preserved.")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding(.top, 10)
        }.steadyCard()
    }

    var reminders: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Optional reminders").font(.headline)
            Text(permissionStatus).font(.footnote).foregroundStyle(.secondary)
            Text(store.nudgesEnabled ? "Reminders are enabled in Steady." : "Reminders are off in Steady. Quiet in-app cards are still available.")
                .font(.subheadline)
            if store.nudgesEnabled {
                Button("Turn off reminders") {
                    guard let source = store.source(profile: profile) else { return }
                    if store.setNudgesEnabled(false, source: source, profile: profile, sample: sample,
                        environment: environment, context: context) { Task { await refreshReminders() } }
                }
            } else {
                Button(sample ? "Try simulated reminders" : "Review and enable reminders") { showPermissionExplanation = true }
            }
            Button("Why the daily reminder limit") {
                why = WhyItem(title: "At most three proactive reminders", explanation: "This is a ceiling, not a target. A reminder you snooze also uses the day's allowance. Quiet, sleep, busy, workout, dismissal, and safety rules can reduce delivery further. An open-app card is preferred when the action can wait.")
            }.font(.footnote)
            Text("No sensitive Health measurements are included in notification text. Notification permission does not grant Health or Calendar access.")
                .font(.footnote).foregroundStyle(.secondary)
        }.steadyCard()
    }

    func minutesBinding(_ source: Binding<Int>) -> Binding<Date> {
        Binding(get: { ProfileTimeFormatting.date(for: source.wrappedValue, calendar: environment.calendar) },
                set: { source.wrappedValue = ProfileTimeFormatting.minutes(from: $0, calendar: environment.calendar) })
    }

    func quietDescription(_ period: NudgeQuietPeriod) -> String {
        if period.startMinute == period.endMinute { return "All-day quiet" }
        let start = FoundationTimeFormatting.time(ProfileTimeFormatting.date(for: period.startMinute, calendar: environment.calendar))
        let end = FoundationTimeFormatting.time(ProfileTimeFormatting.date(for: period.endMinute, calendar: environment.calendar))
        return "\(start) to \(end)\(period.startMinute > period.endMinute ? " (overnight)" : "")"
    }
}
