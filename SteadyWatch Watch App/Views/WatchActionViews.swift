import SteadyCore
import SwiftUI

struct WatchAlternativesView: View {
    @Bindable var model: WatchCompanionModel
    @State private var explanation: WatchExplanation?
    var body: some View {
        List {
            if let snapshot = model.snapshot {
                ForEach(snapshot.alternatives) { option in
                    Section(option.title) {
                        Button("\(option.minutes) min - Why") {
                            explanation = WatchExplanation(title: "Alternative duration", text: option.durationExplanation)
                        }.font(.footnote)
                        Text("Effort: \(option.effort.rawValue)").font(.footnote)
                        Text("Keeps: \(option.benefitKept)").font(.footnote)
                        Text("Tradeoff: \(option.tradeoff)").font(.footnote)
                        ForEach(option.steps, id: \.self) { Text($0).font(.footnote) }
                        Button("Choose - send to phone") { model.queue(.chooseAlternative(optionID: option.id), from: snapshot) }
                            .disabled(!model.canAct)
                    }
                }
            }
            Text("Choosing changes the app plan only after phone validation. It does not complete a workout or change Calendar.")
                .font(.footnote)
        }
        .navigationTitle("Alternatives")
        .sheet(item: $explanation) { WatchExplanationView(explanation: $0) }
    }
}

struct WatchMovementView: View {
    @Bindable var model: WatchCompanionModel
    @State private var explanation: WatchExplanation?
    var body: some View {
        List {
            Text("Record movement you already did. These choices are not targets, advice, sensor measurements, or HealthKit writes.")
                .font(.footnote)
            if let snapshot = model.snapshot {
                ForEach(snapshot.movementKinds, id: \.rawValue) { kind in
                    Section(title(kind)) {
                        ForEach(WatchMovementKind.allowedMinutes.sorted(), id: \.self) { minutes in
                            Button("Log \(minutes) min") { model.queue(.logMovement(kind: kind, minutes: minutes), from: snapshot) }
                                .disabled(!model.canAct)
                        }
                    }
                }
            }
            Button("Why these durations?") {
                explanation = WatchExplanation(title: "Your manual duration",
                    text: "The duration is what you explicitly select for movement already done, not a sensor result, prescribed target, calorie estimate, or Health sample. The phone may reject a stale action.")
            }.font(.footnote)
        }
        .navigationTitle("Movement log")
        .sheet(item: $explanation) { WatchExplanationView(explanation: $0) }
    }

    private func title(_ kind: WatchMovementKind) -> String {
        switch kind {
        case .walk: "Walk"
        case .mobility: "Comfortable mobility"
        case .wheelchairMovement: "Wheelchair movement"
        }
    }
}

struct WatchSavedMealsView: View {
    @Bindable var model: WatchCompanionModel
    var body: some View {
        List {
            if let snapshot = model.snapshot {
                ForEach(snapshot.savedMeals) { meal in
                    Section(meal.title) {
                        Text(meal.uncertainty).font(.footnote)
                        Button("Review on phone") { model.queue(.savedMealHandoff(savedCorrectionID: meal.id), from: snapshot) }
                            .disabled(!model.canAct)
                    }
                }
            }
            Text("This asks the phone to open an existing dated observation. It does not choose/eat a meal, confirm a correction, or establish allergy suitability.")
                .font(.footnote)
        }
        .navigationTitle("Saved dishes")
    }
}

struct WatchQueueView: View {
    @Bindable var model: WatchCompanionModel
    var body: some View {
        List {
            Section("Pending - not yet applied") {
                if model.pending.isEmpty { Text("No pending actions.").font(.footnote) }
                ForEach(model.pending) { action in Text(title(action.kind)).font(.footnote) }
            }
            Section("Phone receipts") {
                ForEach(model.receipts) { receipt in
                    VStack(alignment: .leading) {
                        Text(title(receipt.action.kind))
                        switch receipt.status {
                        case .accepted: Text("Applied by phone.").font(.footnote)
                        case .rejected: Text("Not applied. Open the phone for its current view.").font(.footnote)
                        }
                    }
                }
            }
            Text("Delivery may wait for both devices. Closing/reopening keeps the same action IDs. Queued does not mean applied.")
                .font(.footnote)
        }
        .navigationTitle("Companion queue")
    }

    private func title(_ kind: WatchActionKind) -> String {
        switch kind {
        case .chooseAlternative: "App plan alternative"
        case .logMovement: "Manual movement record"
        case .foundationDone: "Foundation Done"
        case .savedMealHandoff: "Saved-dish handoff"
        }
    }
}
