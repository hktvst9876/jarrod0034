import SteadyCore
import SwiftUI

extension TodayView {
    @ViewBuilder
    var priorityCard: some View {
        if let priority = model.priority {
            VStack(alignment: .leading, spacing: 12) {
                Text("TODAY'S PRIORITY").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(planStore.safetyMessage?.title ?? (planStore.plan == nil ? priority.title : "Follow your chosen plan")).font(.title2.bold())
                Text(planStore.safetyMessage?.guidance ?? planStore.plan?.outcome.summary ?? priority.explanation.summary).foregroundStyle(.secondary)
                Divider()
                let activePlan = planStore.effectivePlan(priority: priority) ?? priority.planA
                Label(activePlan.title, systemImage: "arrow.right.circle.fill").font(.headline)
                if planStore.plan != nil && planStore.safetyMessage == nil {
                    Text(activePlan.status.title).font(.subheadline).foregroundStyle(.secondary)
                }
                if let safety = planStore.safetyMessage {
                    Text(safety.guidance)
                    Text(safety.emergencyGuidance).font(.footnote)
                }
                if activePlan.minutes > 0 {
                    Button("About \(activePlan.minutes) minutes - Why") {
                        why = WhyItem(
                            title: "Why this amount",
                            explanation: "This is an approximate duration for this plan. Your saved choice stays in place when today's context refreshes."
                        )
                    }
                    .font(.subheadline)
                }
                if let slot = activePlan.slot {
                    Button("\(planStore.record?.eventIdentifier == nil ? "Proposed time" : "Saved time"): \(environment.planDateLabel(slot.start, dayStyle: .medium)) - Why") {
                        why = WhyItem(
                            title: "Proposed time",
                            explanation: planStore.record?.eventIdentifier == nil ? "This is a suggested time. It has not been added to Calendar." : "You explicitly confirmed this time in the Steady calendar."
                        )
                    }
                    .font(.subheadline)
                }
                Button("Why this priority") {
                    why = WhyItem(title: "Today's priority", explanation: planStore.plan == nil ? priority.explanation.summary : "This is the plan you chose. Refreshing context keeps your choice; a safety concern takes precedence.")
                }
                Button("Choose another priority") { showPriorityChoices = true }
                    .buttonStyle(.bordered)
                if activePlan.status != .completed && activePlan.status != .intentionallyRested {
                    Button("Find another option", systemImage: "arrow.triangle.branch") { showAlternatives = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(planStore.safetyMessage != nil)
                    Button("Rest on purpose", systemImage: "leaf") {
                        Task { _ = await planStore.act(.restOnPurpose, source: activePlan, profile: profile,
                            sample: useSampleData, environment: environment, context: modelContext) }
                    }.buttonStyle(.bordered)
                }
            }
            .steadyCard()
        }
    }
}
