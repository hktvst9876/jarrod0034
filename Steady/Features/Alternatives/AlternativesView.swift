import SteadyCore
import SwiftData
import SwiftUI

struct AlternativesView: View {
    @Environment(AppEnvironment.self) var environment
    @Environment(PlanStore.self) var store
    @Environment(\.modelContext) var context
    @Environment(\.dismiss) var dismiss
    let profile: ProfileRecord
    let source: PlanItem
    let snapshot: PhaseOneContextSnapshot?
    @AppStorage("useSampleData") var sample = false
    @State var model = AlternativesViewModel()
    @State var why: WhyItem?
    @State var showAbandonConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Keep what matters").font(.title2.bold())
                    Text(source.outcome.summary).foregroundStyle(.secondary)
                    Text("Choose a barrier if it helps. No explanation is required.").font(.subheadline)
                    barrierPicker
                    Picker("Movement preference", selection: $model.movementMode) {
                        Text("Standing").tag(AlternativeMovementMode.standing)
                        Text("Seated").tag(AlternativeMovementMode.seated)
                        Text("Wheelchair").tag(AlternativeMovementMode.wheelchair)
                    }
                    Text("This preference applies to these options.").font(.footnote).foregroundStyle(.secondary)
                    pendingRecovery
                    restrictions
                    options
                    laterAndRest
                    if let message = model.catalogMessage { Text(message).font(.footnote).foregroundStyle(.secondary) }
                    if let failure = store.failure { Text(failure).foregroundStyle(.red).accessibilityIdentifier("alternativeSaveError") }
                }.padding()
            }
            .navigationTitle("Alternatives")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
        .task { refresh() }
        .onChange(of: model.barrier) { _, _ in refresh() }
        .onChange(of: model.movementMode) { _, _ in refresh() }
        .onChange(of: sample) { _, _ in dismiss() }
        .sheet(isPresented: $model.showLater, onDismiss: {
            if let requested = model.requestedConfirmation {
                model.requestedConfirmation = nil
                model.confirmation = requested
            }
        }) { laterSheet }
        .sheet(item: $model.confirmation) { proposal in confirmationSheet(proposal) }
        .sheet(item: $why) { WhySheet(title: $0.title, explanation: $0.explanation) }
        .confirmationDialog("Clear this Calendar retry?", isPresented: $showAbandonConfirmation) {
            Button("Clear retry") { store.abandonPending(source: source, profile: profile, sample: sample, environment: environment, context: context) }
            Button("Cancel", role: .cancel) {}
        } message: { Text("An earlier Calendar save may have succeeded. Check Calendar before scheduling again. This does not delete any Calendar event.") }
        .disabled(store.isWorking)
    }

    @ViewBuilder var pendingRecovery: some View {
        if let proposal = store.pendingProposal() {
            VStack(alignment: .leading, spacing: 10) {
                Text("Review an unfinished Calendar save").font(.headline)
                Text("The previous event may have been saved. Retrying checks the same change and does not add a second event.")
                Button("Review previous time") { model.confirmation = proposal }
                Button("Clear Calendar retry") { showAbandonConfirmation = true }
            }.steadyCard()
        }
    }

    var barrierPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(AlternativeBarrier.allCases, id: \.rawValue) { barrier in
                    Button(barrier.title) { model.barrier = barrier }
                        .buttonStyle(.bordered)
                        .tint(model.barrier == barrier ? .teal : .secondary)
                }
            }
        }
    }

    @ViewBuilder var restrictions: some View {
        if !profile.movementsToAvoid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !model.confirmedRestrictions {
            VStack(alignment: .leading, spacing: 12) {
                Text("Check your movement preferences").font(.headline)
                Text("Your saved note: \(profile.movementsToAvoid)")
                Text("Select the movements you want to leave out. Steady does not interpret this note as an injury.")
                ForEach([AlternativeMovement.walking, .standing, .upperBody, .lowerBody], id: \.rawValue) { movement in
                    Toggle("Avoid \(movement.rawValue)", isOn: Binding(
                        get: { model.avoids.contains(movement) },
                        set: { if $0 { model.avoids.insert(movement) } else { model.avoids.remove(movement) } }
                    ))
                }
                Button("Use these preferences") { model.confirmedRestrictions = true; refresh() }
                    .buttonStyle(.borderedProminent)
            }.steadyCard()
        }
    }

    @ViewBuilder var options: some View {
        if let result = model.result {
            switch result {
            case .options(let set):
                ForEach(set.options) { option in optionCard(option, set: set) }
            case .blocked(let message):
                VStack(alignment: .leading, spacing: 8) {
                    Text(message.title).font(.headline)
                    Text(message.guidance)
                    Text(message.emergencyGuidance).font(.footnote)
                }.steadyCard()
            case .unavailable(let message): Text(message).steadyCard()
            }
        }
    }

    func optionCard(_ option: AlternativeOption, set: AlternativeSet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(option.title).font(.headline)
            Button("\(option.minutes) minutes - \(option.effort.rawValue) effort - Why") {
                why = WhyItem(title: "Time and effort", explanation: "This is an approximate template duration and a relative effort level. Stop or shorten whenever you need.")
            }.font(.subheadline)
            Text("Keeps: \(option.benefitKept)")
            Text("Tradeoff: \(option.tradeoff)").foregroundStyle(.secondary)
            Text("Preserves: \(parts(option.preserves))").font(.footnote)
            Text("Leaves out: \(parts(option.doesNotPreserve))").font(.footnote)
            ForEach(Array(option.steps.enumerated()), id: \.offset) { _, step in Text("- \(step)").font(.subheadline) }
            Button("Choose this") {
                Task {
                    if await store.choose(option, from: set, source: source, profile: profile, sample: sample,
                                          environment: environment, context: context) { dismiss() }
                    else { refresh() }
                }
            }.buttonStyle(.borderedProminent)
        }.steadyCard()
    }

    var laterAndRest: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Later", systemImage: "clock") {
                Task {
                    guard await store.refreshSafety(profile: profile, sample: sample, environment: environment) else { refresh(); return }
                    if let previous = store.pendingProposal() { model.confirmation = previous; return }
                    await model.prepareLater(source: source, profile: profile, snapshot: snapshot, store: store, environment: environment, sample: sample)
                }
            }.buttonStyle(.bordered)
            Button("Rest on purpose", systemImage: "leaf") {
                Task {
                    if await store.act(.restOnPurpose, source: source, profile: profile, sample: sample,
                                       environment: environment, context: context) { dismiss() }
                }
            }.buttonStyle(.bordered)
            if store.record?.eventIdentifier != nil {
                Text("Choosing or resting changes your app plan. An existing Calendar event changes only after a separate confirmation.").font(.footnote).foregroundStyle(.secondary)
            }
        }.steadyCard()
    }

    func parts(_ parts: Set<OutcomePart>) -> String {
        parts.isEmpty ? "None of the original parts" : parts.map(\.title).sorted().joined(separator: ", ")
    }
    func refresh() { model.refresh(source: source, profile: profile, snapshot: snapshot, store: store) }
}
