import SteadyCore
import SwiftUI

struct SleepView: View {
    @Environment(AppEnvironment.self) private var environment
    let profile: ProfileRecord
    @State private var model = SleepViewModel()
    @State private var why: WhyItem?
    @AppStorage("useSampleData") private var useSampleData = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if model.isLoading && model.sleep.lastNight == nil {
                        ProgressView("Reading sleep context…")
                            .padding(.top, 80)
                    } else {
                        lastNightCard
                        recentCard
                        bedtimeCard
                    }
                }
                .padding()
            }
            .navigationTitle("Sleep")
            .refreshable { await reload() }
        }
        .task(id: useSampleData) { await reload() }
        .sheet(item: $why) { item in
            WhySheet(title: item.title, explanation: item.explanation)
        }
    }

    private var lastNightCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Last night").font(.headline)
            if let night = model.sleep.lastNight {
                Text(duration(night.asleepMinutes)).font(.title.bold())
                Text("Woke at \(night.wakeTime.formatted(date: .omitted, time: .shortened))")
                    .foregroundStyle(.secondary)
                Button("Why these numbers") {
                    why = WhyItem(
                        title: "Last night",
                        explanation: "Steady merges overlapping sleep stages from Apple Health and counts a night on the date you woke up."
                    )
                }
            } else {
                Text("No readable sleep data for last night.")
                    .font(.title3.bold())
                Text("Steady can still plan from your preferences and check-in.")
                    .foregroundStyle(.secondary)
            }
        }
        .steadyCard()
    }

    private var recentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent pattern").font(.headline)
            if let shortfall = model.sleep.shortfall7dMinutes {
                LabeledContent("Combined shortfall", value: duration(shortfall))
                LabeledContent("Coverage", value: "\(model.sleep.nightsTracked) tracked nights")
                Button("Why this total") {
                    why = WhyItem(
                        title: "Recent sleep opportunity",
                        explanation: "For each readable night in the recent window, Steady compares sleep duration with your chosen sleep need. Missing nights do not count as zero."
                    )
                }
            } else {
                Text("Not enough readable nights for a recent total.")
                    .foregroundStyle(.secondary)
            }
            if let consistency = model.sleep.wakeConsistency {
                LabeledContent("Wake timing", value: consistency.label.title)
                Button("Why this pattern") {
                    why = WhyItem(
                        title: "Wake timing",
                        explanation: "This compares your readable wake times with their recent average. It is context, not a grade."
                    )
                }
            }
        }
        .steadyCard()
    }

    private var bedtimeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tonight").font(.headline)
            if let plan = model.sleep.bedtimePlan {
                BedtimeRow(
                    label: "Bedtime window",
                    value: "\(time(plan.bedtimeWindowStart))–\(time(plan.bedtimeWindowEnd))"
                ) {
                    why = WhyItem(title: "Bedtime window", explanation: plan.explanation)
                }
                BedtimeRow(label: "Wind down", value: time(plan.windDownTime)) {
                    why = WhyItem(
                        title: "Wind-down time",
                        explanation: "This starts before the planned bedtime so the smallest useful routine can happen without rushing."
                    )
                }
                BedtimeRow(label: "Caffeine cutoff", value: time(plan.caffeineCutoffTime)) {
                    why = WhyItem(
                        title: "Caffeine cutoff",
                        explanation: "This uses the lead time saved in your sleep preferences. It is guidance, not a restriction."
                    )
                }
                if plan.needsEarlyWakeHeadsUp {
                    Text("Tomorrow starts earlier than your usual wake time.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if plan.isWakeTimeClamped {
                    Text("A commitment may need a wake time earlier than Steady's planning floor. Check the event and travel time directly.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("A bedtime window is unavailable. Check your wake preferences in Settings.")
                    .foregroundStyle(.secondary)
            }
        }
        .steadyCard()
    }

    private func reload() async {
        await model.load(profile: profile, environment: environment, useSampleData: useSampleData)
    }

    private func duration(_ minutes: Int) -> String {
        Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    private func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

private struct BedtimeRow: View {
    let label: String
    let value: String
    let showWhy: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(label).font(.subheadline)
                Text(value).font(.title3.bold())
            }
            Spacer()
            Button("Why", systemImage: "info.circle", action: showWhy)
                .labelStyle(.iconOnly)
        }
    }
}

private extension WakeConsistencyLabel {
    var title: String {
        switch self {
        case .steady: "Steady"
        case .aBitIrregular: "A little varied"
        case .irregular: "Varied"
        }
    }
}
