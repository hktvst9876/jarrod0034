import SwiftUI

extension AlternativesView {
    @ViewBuilder var advisorControls: some View {
        if model.canonicalOptions != nil {
            VStack(alignment: .leading, spacing: 10) {
                Text(model.rankingMessage).font(.footnote).foregroundStyle(.secondary)
                if environment.advisor.isEnabled(profileID: profile.id, sample: sample) {
                    Text(AdvisorProviderFactory.availability(sample: sample).message).font(.footnote)
                    if AdvisorProviderFactory.availability(sample: sample) == .ready && !model.orderingFrozen {
                        Button(model.isRanking ? "Trying on-device order..." : "Try on-device order") {
                            model.tryOnDeviceOrder(source: source, profile: profile, snapshot: snapshot,
                                store: store, environment: environment, sample: sample)
                        }.buttonStyle(.bordered).disabled(model.isRanking)
                    }
                    Button("Use template order") { model.stopOrdering(); model.orderingFrozen = false }
                        .font(.footnote)
                } else {
                    Text("Optional on-device ordering is off. You can enable it in Settings.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }.steadyCard()
        }
    }
}
