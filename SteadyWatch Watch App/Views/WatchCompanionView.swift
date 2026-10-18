import SteadyCore
import SwiftUI

struct WatchCompanionView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var model: WatchCompanionModel
    @State private var explanation: WatchExplanation?

    var body: some View {
        NavigationStack {
            List {
                if let snapshot = model.snapshot {
                    glance(snapshot)
                    if snapshot.useSampleData {
                        Text("Phone sample mode: real Watch actions are paused. Open Steady on iPhone to resume.")
                            .font(.footnote)
                    } else {
                        if !snapshot.alternatives.isEmpty {
                            NavigationLink("Quick alternatives") { WatchAlternativesView(model: model) }
                        }
                        if !snapshot.movementKinds.isEmpty {
                            NavigationLink("Log movement") { WatchMovementView(model: model) }
                        }
                        if let foundation = snapshot.foundation { foundationAction(foundation, from: snapshot) }
                        if !snapshot.savedMeals.isEmpty {
                            NavigationLink("Saved dishes on phone") { WatchSavedMealsView(model: model) }
                        }
                    }
                    Button("Captured view - Why") {
                        explanation = WatchExplanation(title: "Last phone view",
                            text: "Captured \(WatchExplanation.timestamp(snapshot.createdAt)). Usable until \(WatchExplanation.timestamp(snapshot.expiresAt)) (Singapore time). It is not live Health or Calendar context. The phone checks current safety and state again before applying an action.")
                    }.font(.footnote)
                } else {
                    Section("Steady") {
                        Text("Open Steady on iPhone for a current plan. Cached actions are hidden when their view expires.")
                            .font(.footnote)
                    }
                }
                if let message = model.message { Text(message).font(.footnote) }
                if let failure = model.failure { Text(failure).font(.footnote).foregroundStyle(.orange) }
                NavigationLink("Pending actions and receipts") { WatchQueueView(model: model) }
                Button("Read updates / retry queued") { model.refresh() }.disabled(!model.storageReady)
            }
            .navigationTitle("Steady")
        }
        .sheet(item: $explanation) { WatchExplanationView(explanation: $0) }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            model.refresh()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                guard scenePhase == .active else { return }
                model.refresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionInboxChanged)) { _ in
            model.refresh(retry: scenePhase == .active)
        }
    }

    @ViewBuilder private func glance(_ snapshot: WatchSnapshot) -> some View {
        if let priority = snapshot.priority {
            Section("Today") {
                Text(priority.title).font(.headline)
                Text(priority.reason).font(.footnote)
            }
        }
        if let plan = snapshot.plan {
            Section(plan.status == .proposed ? "Next action" : "App plan status") {
                Text(plan.title)
                Text(statusText(plan.status)).font(.footnote)
                Button("Plan: \(plan.minutes) min - Why") {
                    explanation = WatchExplanation(title: "Plan duration", text: plan.durationExplanation)
                }.font(.footnote)
            }
        }
    }

    private func statusText(_ status: PlanStatus) -> String {
        switch status {
        case .proposed: "Proposed, not completed. Choose what fits."
        case .scheduled: "Scheduled. Check the confirmed time on iPhone before starting."
        case .completed: "Completed on the phone; this is not another action to do."
        case .deferred: "For later. Review its time and start controls on iPhone."
        case .intentionallyRested: "Rest on purpose is saved. There is no activity to make up."
        }
    }

    private func foundationAction(_ foundation: WatchFoundationCard, from snapshot: WatchSnapshot) -> some View {
        Section("Small Foundation") {
            Text(foundation.title)
            Text(foundation.reason).font(.footnote)
            ForEach(foundation.steps, id: \.self) { Text($0).font(.footnote) }
            if let minutes = foundation.minutes {
                Button("\(minutes) min - Why") {
                    explanation = WatchExplanation(title: "Optional duration", text: foundation.durationExplanation)
                }.font(.footnote)
            }
            Button("Done - send to phone") {
                model.queue(.foundationDone(kind: foundation.kind, optionID: foundation.optionID), from: snapshot)
            }.disabled(!model.canAct)
        }
    }
}

struct WatchExplanation: Identifiable {
    let id = UUID()
    let title: String
    let text: String

    static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = SteadyCalendar.singapore()
        formatter.timeZone = formatter.calendar.timeZone
        formatter.locale = Locale(identifier: "en_SG")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct WatchExplanationView: View {
    @Environment(\.dismiss) private var dismiss
    let explanation: WatchExplanation
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(explanation.title).font(.headline)
                Text(explanation.text).font(.footnote)
                Button("Close") { dismiss() }
            }.padding()
        }
    }
}
