import SteadyCore
import SwiftData
import SwiftUI

extension AlternativesView {
    var laterSheet: some View {
        NavigationStack {
            List {
                Text("Pick a suitable time to review. Nothing changes until you confirm.")
                Text("Times are shown in Singapore time.").font(.footnote)
                if store.record?.calendarEventDeleted == true {
                    Text("Your earlier Calendar event was removed. Steady will not recreate it.")
                } else if model.calendarAvailable {
                    ForEach(model.proposals, id: \.id) { proposal in
                        Button {
                            model.showLater = false
                            model.requestedConfirmation = RescheduleProposal(id: UUID().uuidString, planID: proposal.planID,
                                title: proposal.title, start: proposal.start, end: proposal.end)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(environment.planDateLabel(proposal.start, dayStyle: .medium))
                                Text("Until \(environment.planDateLabel(proposal.end))").font(.footnote)
                            }
                        }
                    }
                    if model.proposals.isEmpty { Text("No suitable free window is known. You can keep the plan unscheduled.") }
                } else {
                    Text("Calendar access is off. You can keep the plan for later without adding an event.")
                }
                Button("Keep for later without Calendar") {
                    Task {
                        if await store.act(.later, source: source, profile: profile, sample: sample,
                                           environment: environment, context: context) { model.showLater = false; dismiss() }
                    }
                }
            }
            .navigationTitle("Later")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.showLater = false } } }
        }.presentationDetents([.medium, .large])
    }

    func confirmationSheet(_ proposal: RescheduleProposal) -> some View {
        NavigationStack {
            Form {
                Section("Review Calendar change") {
                    Text(proposal.title)
                    Text(environment.planDateLabel(proposal.start, dayStyle: .full))
                    Text("Ends \(environment.planDateLabel(proposal.end))")
                    Text("Singapore time")
                    Text("Reason: keep the plan at a later suitable time.")
                    Text(sample ? "This changes only the sample calendar." : "Only the Steady calendar will change.")
                }
                if let failure = store.failure { Text(failure).foregroundStyle(.red) }
                Button(store.isWorking ? "Saving..." : "Confirm") {
                    Task {
                        if await store.confirm(proposal, source: source, profile: profile, sample: sample,
                                               environment: environment, context: context) { model.confirmation = nil; dismiss() }
                    }
                }.disabled(store.isWorking)
            }
            .navigationTitle("Confirm time")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.confirmation = nil }.disabled(store.isWorking) } }
            .interactiveDismissDisabled(store.isWorking)
        }
    }

}
