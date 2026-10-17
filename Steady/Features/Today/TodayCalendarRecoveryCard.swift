import SteadyCore
import SwiftUI

extension TodayView {
    @ViewBuilder var pendingCalendarRecovery: some View {
        if let proposal = planStore.pendingProposal() {
            VStack(alignment: .leading, spacing: 10) {
                Text("Unfinished Calendar save").font(.headline)
                Text("An earlier save may have added an event, even if the plan is now finished or resting.")
                Text(environment.planDateLabel(proposal.start, dayStyle: .medium))
                Button("Clear Calendar retry") {
                    pendingRetryOperationID = proposal.id
                    showClearCalendarRetry = true
                }
            }
            .steadyCard()
            .disabled(planStore.isWorking)
            .confirmationDialog("Clear this Calendar retry?", isPresented: $showClearCalendarRetry) {
                Button("Clear retry") {
                    guard planStore.pendingProposal()?.id == pendingRetryOperationID,
                          let source = planStore.plan else {
                        planStore.failure = "The pending Calendar change has changed. Refresh and review it again."
                        return
                    }
                    planStore.abandonPending(source: source, profile: profile, sample: useSampleData,
                        environment: environment, context: modelContext)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("An earlier Calendar save may have succeeded. Check Calendar before scheduling again. Clearing this retry does not delete any Calendar event.")
            }
        }
    }
}
