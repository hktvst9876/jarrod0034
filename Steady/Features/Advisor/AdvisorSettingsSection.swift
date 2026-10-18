import SwiftUI

struct AdvisorSettingsSection: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.scenePhase) private var scenePhase
    let profile: ProfileRecord
    let sample: Bool
    @State private var availability: AdvisorAvailability = .unavailable
    @State private var cleared = false

    var body: some View {
        Section("On-device alternative ordering") {
            Toggle("Use on-device ordering", isOn: Binding(
                get: { environment.advisor.isEnabled(profileID: profile.id, sample: sample) },
                set: { environment.advisor.setEnabled($0, profileID: profile.id, sample: sample); cleared = false }
            ))
            Text("Optional and off by default. In Alternatives, ask to try a different order. The on-device model receives only a small typed packet, not your name, raw Health data, Calendar details, or saved notes.")
                .font(.footnote).foregroundStyle(.secondary)
            Text("The model can reorder the same approved cards only. It cannot change their words, make a plan choice, schedule anything, or change settings. No cloud advisor or account is used.")
                .font(.footnote).foregroundStyle(.secondary)
            Text("This switch applies immediately and is separate for sample mode. Turning it off restores template ordering.")
                .font(.footnote).foregroundStyle(.secondary)
            Text(availability.message).font(.footnote)
            Button("Clear advisor activity") { environment.advisor.clearActivity(); cleared = true }
            Text(cleared ? "Advisor activity cleared. Your wellness records are unchanged."
                 : "Only temporary outcome labels are kept in memory. Prompts, model responses, and conversations are not saved. Clearing also discards an in-progress ordering request.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .task { refresh() }
        .onChange(of: sample) { _, _ in refresh() }
        .onChange(of: profile.id) { _, _ in refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
    }

    private func refresh() {
        environment.advisor.activate(profileID: profile.id, sample: sample)
        availability = AdvisorProviderFactory.availability(sample: sample)
    }
}
