import SteadyCore
import SwiftUI

struct WeekSummarySections: View {
    let summary: WeeklySummary
    let lowData: Bool
    let sleepNote: String
    @Binding var why: WhyItem?

    var body: some View {
        Section("Available coverage") {
            Text("Week beginning \(WeekFormatting.date(summary.window.start))")
            Text(summary.window.isPartial ? "This week is still in progress." : "This week has ended.")
            explain("Why this window", "Singapore calendar weeks begin on Monday. Only elapsed days and observations available by this refresh are included; future days are not missing days.")
        }
        Section("Sleep context") {
            Text(sleepNote).foregroundStyle(.secondary)
            if lowData {
                Text("Sleep duration detail is hidden in low-data mode.")
            } else {
                if let total = summary.actualSleepMinutes, summary.sleepTrackedDays > 0 {
                    row("Mean recorded sleep", duration(total / Double(summary.sleepTrackedDays)))
                } else { Text("Recorded sleep duration is unavailable.") }
                if let total = summary.sleepOpportunityMinutes, summary.opportunityTrackedDays > 0 {
                    row("Mean recorded in-bed window", duration(total / Double(summary.opportunityTrackedDays)))
                } else { Text("Recorded sleep opportunity is unavailable; your sleep target is not an observed opportunity.") }
            }
            row("Readable sleep coverage", "\(summary.sleepTrackedDays) of \(summary.window.elapsedDays) elapsed days")
            row("In-bed proxy coverage", "\(summary.opportunityTrackedDays) of \(summary.window.elapsedDays) elapsed days")
            explain("Why these sleep numbers", "Overlapping asleep stages are merged by wake date. Means include only readable nights, never a zero for a missing night. Opportunity here is a recorded in-bed proxy only on nights that also have asleep data; it is not a target, actual sleep, or proof of an uninterrupted chance to sleep.")
        }
        Section("Movement and plans") {
            if let minutes = summary.movementMinutes {
                row("User-reported Watch movement", "\(minutes) min in \(summary.movementEntries) records")
            } else { Text("No retained user-reported movement record in this week. Other activity is unknown.") }
            if summary.plansRecorded > 0 {
                row("Saved plans", "\(summary.plansRecorded)")
                row("Explicitly completed plans", "\(summary.plansCompleted)")
                row("Adapted plans", "\(summary.plansChanged) across \(summary.changedPlanDays) days")
            } else { Text("No retained plan record in this week; this does not mean you did nothing.") }
            row("Alternatives chosen", "\(summary.alternativesChosen)")
            row("Chosen alternatives later completed", "\(summary.alternativesCompleted)")
            explain("Why these movement and plan counts", "Movement counts only explicit local Watch reports, not a Health total or inferred workout. Plan completion requires a saved completion. Changes, rest, and deferral are not completion; alternative completions link a saved choice to a later explicit completion. These are retained local records, not an activity score or catch-up target.")
        }
        Section("Foundations") {
            if summary.foundationsRecorded > 0 {
                row("Stored day/kind states", "\(summary.foundationsRecorded)")
                row("Marked Done", "\(summary.foundationsDone)")
                row("Day/kind dismissal records", "\(summary.foundationsDismissed)")
            } else { Text("No retained Foundation state or dismissal record for this week.") }
            explain("Why these Foundation counts", "Each Foundation kind is counted once per stored local day. Done is explicit; a dismissal is a saved callback, not a failure or a measure of whether every reminder was delivered. Stored states are not a completion target or an exposure denominator.")
        }
        Section("Remembered food observations") {
            row("Retained confirmed corrections", "\(summary.foodCorrections)")
            if !summary.commonSavedFoods.isEmpty {
                ForEach(summary.commonSavedFoods, id: \.dishID) { food in
                    row(food.name, "\(food.count) confirmed records")
                }
            }
            Text("These are saved observations, not meals eaten. Updated records may replace an older correction; no food-consumption history is inferred.").font(.footnote)
            explain("Why these food counts", "Only explicitly confirmed saved corrections dated within this week are counted. Common names mean repeated retained records, not a verified menu, current ingredients, or commonly eaten food. There is no weekly money total.")
        }
        Section("Local learning only") {
            if let shown = summary.metrics.suggestionsShown {
                row("New Week suggestions recorded as shown", "\(shown)")
                row("Explicit approvals linked to shown", "\(summary.metrics.suggestionsAccepted ?? 0)")
            } else { Text("Suggestion exposure tracking is unavailable for this week.") }
            if let seconds = summary.metrics.meanDecisionSeconds {
                row("Mean time from first shown to approval", "\(Int(seconds.rounded())) sec")
            } else { Text("Decision timing is unavailable without a tracked approval.") }
            Text("Earlier alternative exposure/timing and food correction rates are unavailable. Historical actions are not backfilled as shown or treated as zero.").font(.footnote)
            row("Explicit helpfulness answers", "\(summary.metrics.helpfulResponses + summary.metrics.mixedResponses + summary.metrics.notHelpfulResponses)")
            explain("Why these local metrics", "Only new Week suggestion cards, their explicit approvals, time since the first recorded display, and your optional helpfulness response are tracked here. A card is deduplicated within its review week. No remote analytics or Health measurements are recorded, and absent denominators remain unavailable.")
        }
    }

    private func row(_ label: String, _ value: String) -> some View { LabeledContent(label, value: value) }
    private func explain(_ title: String, _ explanation: String) -> some View {
        Button(title) { why = WhyItem(title: title, explanation: explanation) }
    }
    private func duration(_ minutes: Double) -> String {
        Duration.seconds(Int(minutes.rounded()) * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}
