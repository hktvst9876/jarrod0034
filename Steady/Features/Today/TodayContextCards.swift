import SteadyCore
import SwiftUI

struct TodaySleepCard: View {
    let sleep: SleepContext
    let lowDataMode: Bool
    @Binding var why: WhyItem?
    let ignoreSleep: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Last night", systemImage: "moon.zzz")
                .font(.headline)
            if lowDataMode {
                Text(sleep.lastNight == nil ? "No readable sleep data for last night."
                    : "Readable sleep context is available. Duration and wake time are hidden in low-data mode.")
                    .foregroundStyle(.secondary)
                Button("Why these details are hidden") {
                    why = WhyItem(title: "Low-data sleep context", explanation: "Measured sleep duration and wake time are hidden by your chosen privacy mode. Missing observations remain unknown; available context may still support planning without showing a score.")
                }.font(.footnote)
                if sleep.lastNight != nil {
                    Button("That doesn't look right") { ignoreSleep() }.font(.footnote)
                }
            } else if let night = sleep.lastNight {
                Text(duration(night.asleepMinutes)).font(.title3.bold())
                Text("Wake time \(night.wakeTime.formatted(date: .omitted, time: .shortened))")
                    .foregroundStyle(.secondary)
                Button("Why these numbers") {
                    why = WhyItem(
                        title: "Last night's sleep",
                        explanation: "Sleep stages from Apple Health are merged when sources overlap. The night belongs to the day you woke up."
                    )
                }
                .font(.footnote)
                Button("That doesn't look right") { ignoreSleep() }
                    .font(.footnote)
            } else {
                Text("No sleep data, so the plan goes by your check-in and chosen focus.")
                    .foregroundStyle(.secondary)
            }
        }
        .steadyCard()
    }

    private func duration(_ minutes: Int) -> String {
        Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}

struct TodayActivityCard: View {
    let activity: ActivityContext
    @Binding var why: WhyItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Activity", systemImage: "figure.walk")
                .font(.headline)
            if let steps = activity.stepsToday {
                Text("\(steps.formatted()) steps today").font(.title3.bold())
                Button("Why this number") {
                    why = WhyItem(
                        title: "Steps today",
                        explanation: "This is the step total Apple Health makes readable to Steady for today. It is context, not a target."
                    )
                }
                .font(.footnote)
            } else {
                Text("No readable activity data. Manual planning still works.")
                    .foregroundStyle(.secondary)
            }
        }
        .steadyCard()
    }
}

struct TodayRecoveryCard: View {
    let recovery: RecoveryContext
    @Binding var why: WhyItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("How recovered you are", systemImage: "waveform.path.ecg")
                .font(.headline)
            Text(recovery.status.title).font(.title3.bold())
            if let reason = recovery.reasons.first {
                Text(reason.message).foregroundStyle(.secondary)
            }
            Button("Why this context") {
                why = WhyItem(
                    title: "Recovery context",
                    explanation: recoveryExplanation
                )
            }
            .font(.footnote)
        }
        .steadyCard()
    }

    private var recoveryExplanation: String {
        if recovery.status == .learning {
            return "Steady waits for enough days in each readable Health measure before comparing it with your usual range."
        }
        if recovery.reasons.isEmpty {
            return "Readable overnight measures did not give Steady a reason to reduce today's plan. It never makes a plan harder from these readings."
        }
        return recovery.reasons.map(\.message).joined(separator: " ")
    }
}

