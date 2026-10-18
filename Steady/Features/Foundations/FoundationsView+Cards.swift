import SteadyCore
import SwiftUI

extension FoundationsView {
    @ViewBuilder func foundationCard(_ kind: FoundationKind) -> some View {
        if let item = store.item(kind), let source = store.source(profile: profile) {
            VStack(alignment: .leading, spacing: 10) {
                Text(kind.title).font(.headline)
                Text(item.status.title).font(.footnote).foregroundStyle(.secondary)
                if item.status == .disabled {
                    Button("Enable this Foundation") { perform(.enable, kind: kind, source: source) }
                } else {
                    if let option = store.currentOption(for: kind, profile: profile) {
                        Text(option.title).font(.title3)
                        Button(option.minutes.map { "\($0) minutes - Why" } ?? "No fixed timer - Why") {
                            why = WhyItem(title: "Optional time", explanation: option.durationExplanation)
                        }.font(.subheadline)
                        Button("Why this option") { why = WhyItem(title: option.title, explanation: option.reason) }
                            .font(.footnote)
                        ForEach(Array(option.steps.enumerated()), id: \.offset) { _, step in Text("- \(step)").font(.subheadline) }
                        if item.status != .done {
                            if item.status == .snoozed, let until = item.snoozedUntil {
                                Button("Snoozed until \(FoundationTimeFormatting.time(until)) - Why") {
                                    why = WhyItem(title: "Snooze time", explanation: "This is the time you chose for this local day. A reminder is optional and must still fit the daily limit and quiet windows.")
                                }.font(.footnote)
                                Button("Show it now instead") { perform(.resume, kind: kind, source: source) }
                            }
                            HStack {
                                Button("Done") { perform(.done, kind: kind, source: source) }.buttonStyle(.borderedProminent)
                                Menu("Replace") {
                                    ForEach(store.options(for: kind, profile: profile).filter { $0.id != option.id }) { replacement in
                                        Button(replacement.title) { perform(.replace(optionID: replacement.id), kind: kind, source: source) }
                                    }
                                }.buttonStyle(.bordered)
                                Menu("Snooze") {
                                    ForEach([15, 30, 60], id: \.self) { minutes in
                                        Button("\(minutes) minutes") {
                                            perform(.snooze(until: environment.now.addingTimeInterval(Double(minutes) * 60)), kind: kind, source: source)
                                        }
                                    }
                                }.buttonStyle(.bordered)
                            }
                            Button("Why these snooze times") {
                                why = WhyItem(title: "Snooze", explanation: "These are optional short delays, not recommended doses. Snooze stays within today and never bypasses quiet times or the notification limit.")
                            }.font(.footnote)
                        }
                    } else if !store.movementPreferencesConfirmed(profile: profile) {
                        Text("Review your movement preferences above to see suitable options.").foregroundStyle(.secondary)
                    } else if store.safetyMessage == nil {
                        Text("No suitable option matches your explicit preferences. You can change them or skip this Foundation.").foregroundStyle(.secondary)
                    }
                    Button("Disable this Foundation") { perform(.disable, kind: kind, source: source) }.font(.footnote)
                }
                if (store.dismissals[kind] ?? 0) >= 2 {
                    Text((store.dismissals[kind] ?? 0) >= 4 ? "Reminders paused after repeated dismissals." : "Reminders are less frequent after dismissals.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Resume reminders for this Foundation") {
                        if store.resumeReminders(kind: kind, source: source, profile: profile, sample: sample,
                            environment: environment, context: context) { Task { await refreshReminders() } }
                    }.font(.footnote)
                }
            }.steadyCard()
        }
    }
}
