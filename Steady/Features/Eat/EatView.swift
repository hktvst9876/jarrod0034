import SteadyCore
import SwiftData
import SwiftUI

struct EatView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("useSampleData") private var sample = false
    let profile: ProfileRecord
    @State private var model = EatViewModel()
    @State private var showLocationExplanation = false
    @State private var why: WhyItem?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Food help, when you ask").font(.headline)
                    Text("Place discovery is not a menu or an ingredient check. Only evidence-backed choices can be primary; uncertain places and saved observations stay separate.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if sample {
                        Text("Sample mode: no live search or location prompt. Manual observations are kept separate from real records.")
                            .font(.footnote)
                    }
                }
                requestSection
                preferenceSection
                actionSection
                results
                savedSection
                Section("Sources and limits") {
                    if let url = URL(string: "https://www.hpb.gov.sg/healthy-living/food-and-beverage/sgfoodid/") {
                        Link("About Singapore HPB SG FoodID", destination: url)
                    }
                    Text("No verified menu or nutrition records ship in this source release. A directory website or a general SG FoodID link is not a cited dish-and-serving match. Nutrition stays unavailable until defensible evidence is attached; legacy seed estimates are not used.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let message = model.message { Section { Text(message).font(.footnote) } }
                if let failure = model.failure { Section { Text(failure).foregroundStyle(.red) } }
            }
            .navigationTitle("Eat")
        }
        .task(id: sample) { resetAndLoad() }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                guard !Task.isCancelled, scenePhase == .active else { return }
                model.expireIfNeeded(profile: profile, sample: sample, environment: environment, context: context)
            }
        }
        .onChange(of: profileScope) { _, _ in resetAndLoad() }
        .onChange(of: model.inputs) { old, new in model.invalidate(clearLocation: old.area != new.area) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { model.invalidate(clearLocation: true) }
            else if phase == .active {
                // A location permission prompt may briefly make the scene inactive.
                model.expireIfNeeded(profile: profile, sample: sample, environment: environment, context: context)
                if !model.isWorking && model.editor == nil && model.confirmation == nil {
                    model.load(profile: profile, sample: sample, context: context)
                }
            }
        }
        .onDisappear { model.invalidate(clearLocation: true) }
        .sheet(item: $model.editor, onDismiss: { model.editorDismissed() }) { source in
            FoodCorrectionEditor(source: source) { draft, captured in
                model.prepareRemember(draft, source: captured, profile: profile, sample: sample, environment: environment)
            }
        }
        .sheet(isPresented: confirmationPresented, onDismiss: { model.cancelRemember() }) {
            if let proposal = model.confirmation { confirmationSheet(proposal) }
        }
        .sheet(item: $why) { WhySheet(title: $0.title, explanation: $0.explanation) }
        .alert("Use approximate location?", isPresented: $showLocationExplanation) {
            Button("Continue") { model.requestLocation(profile: profile, sample: sample, environment: environment) }
            Button("Use typed area", role: .cancel) {}
        } message: {
            Text("Steady requests location only for this action and uses a coarse area for Apple Maps place discovery. Your dietary rules, allergies, dislikes, and context are not sent to Maps. Location stays in memory for this screen and is not saved. You can deny access and type an area instead. Sample mode does not open a system prompt.")
        }
    }

    private var requestSection: some View {
        Section("This request") {
            Picker("Meal", selection: $model.inputs.mealType) {
                ForEach(FoodMealType.allCases, id: \.rawValue) { meal in Text(FoodDisplay.title(meal)).tag(meal) }
            }
            TextField("Area or campus (optional for saved dishes)", text: $model.inputs.area)
            if model.approximateCoordinate != nil {
                Text("Searching near your approximate location, not the typed area.").font(.footnote)
                if let at = model.approximateLocationCapturedAt {
                    Button("Area captured \(FoodDisplay.date(at)) - Why") {
                        why = WhyItem(title: "Captured approximate area", explanation: "This is a one-shot coarse area, not live tracking. It expires after ten minutes or when you leave/background this screen. You must explicitly request it again; Steady never refreshes location automatically.")
                    }.font(.caption)
                }
                Button("Use typed area instead") { model.invalidate(clearLocation: true) }
            }
            Button("Use approximate location", systemImage: "location") { showLocationExplanation = true }
                .disabled(model.isWorking)
            Picker("Kitchen access", selection: $model.inputs.kitchenAccess) {
                ForEach(FoodKitchenAccess.allCases, id: \.rawValue) { kitchen in Text(FoodDisplay.title(kitchen)).tag(kitchen) }
            }
            TextField("Dislikes, separated by commas", text: $model.inputs.dislikes, axis: .vertical)
            TextField("Context you want to state (optional)", text: $model.inputs.context, axis: .vertical)
            Text("Context stays request-only. No model interprets it, and no health or dietary need is inferred.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var preferenceSection: some View {
        Section("Dietary rules and allergies") {
            if !profile.dietaryRulesText.isEmpty { Text("Saved dietary note: \(profile.dietaryRulesText)") }
            if !profile.allergiesText.isEmpty { Text("Saved allergy note: \(profile.allergiesText)") }
            Text("All saved notes are kept as free text and handled conservatively. Selecting a typed rule here does not erase a saved note. Edit saved notes in Settings.")
                .font(.footnote).foregroundStyle(.secondary)
            DisclosureGroup("Typed dietary rules for this request") {
                ForEach(FoodDietaryRule.allCases, id: \.rawValue) { rule in
                    Toggle(FoodDisplay.title(rule), isOn: dietaryBinding(rule))
                }
            }
            DisclosureGroup("Typed allergies for this request") {
                ForEach(FoodAllergen.allCases, id: \.rawValue) { allergen in
                    Toggle(FoodDisplay.title(allergen), isOn: allergenBinding(allergen))
                }
            }
            if let maximum = profile.maxPricePerMealSGD {
                Button("Per-meal preference: \(FoodDisplay.price(maximum)) - Why") {
                    why = WhyItem(title: "Per-meal preference", explanation: "This is your optional maximum in Settings, not a spending target or total. Known over-limit items are excluded; an unknown price is still unknown and needs checking.")
                }
            } else {
                Text("No per-meal price limit selected. You can add one in Settings.").font(.footnote)
            }
        }
    }

    private var actionSection: some View {
        Section {
            Button("Find choices", systemImage: "magnifyingglass") {
                model.find(profile: profile, sample: sample, environment: environment, context: context)
            }.disabled(model.isWorking)
            if model.isWorking {
                ProgressView("Checking places and your saved observations")
                Button("Cancel search") { model.invalidate(clearLocation: true); model.message = "Cancelled. Nothing was saved." }
            }
            Button("Add a dish manually", systemImage: "square.and.pencil") {
                model.startEditor(candidate: nil, profile: profile, sample: sample, environment: environment)
            }
            Text("At most three distinct results, sometimes fewer or none. Nothing is remembered by searching or viewing.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var results: some View {
        if let selection = model.selection {
            Section("Primary choices") {
                if selection.primary.isEmpty {
                    Text("No primary choice has sufficiently complete evidence. We will not fill the space with an uncertain recommendation.")
                        .font(.footnote)
                }
                ForEach(selection.primary, id: \.candidate.id) { assessment in choice(assessment, requiresCheck: false) }
            }
            if !selection.requiresConfirmation.isEmpty {
                Section("Places or observations to check - not primary choices") {
                    ForEach(selection.requiresConfirmation, id: \.candidate.id) { assessment in choice(assessment, requiresCheck: true) }
                }
            }
            if !selection.excluded.isEmpty {
                Section("Not offered") {
                    Text("Some records were excluded by allergen, dietary, dislike, kitchen, meal, identity, or known-price rules. They are not recommendations.")
                        .font(.footnote).foregroundStyle(.secondary)
                    ForEach(Array(Set(selection.excluded.flatMap(\.reasons))).sorted(), id: \.self) { reason in
                        Text(reason).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func choice(_ assessment: FoodAssessment, requiresCheck: Bool) -> some View {
        FoodChoiceCard(assessment: assessment, lowDataMode: profile.lowDataMode, requiresCheck: requiresCheck) {
            model.startEditor(candidate: assessment.candidate, profile: profile, sample: sample, environment: environment)
        }
    }

    @ViewBuilder private var savedSection: some View {
        if !model.saved.isEmpty {
            Section("Your records - not recommendations") {
                let areas = Array(Set(model.saved.compactMap { $0.candidate.place?.area }.filter { !$0.isEmpty })).sorted()
                if !areas.isEmpty {
                    Menu("Use a saved area") {
                        ForEach(areas, id: \.self) { area in Button(area) { model.inputs.area = area } }
                    }
                }
                Menu("Review or correct a saved observation") {
                    ForEach(model.saved, id: \.id) { value in
                        Button(value.candidate.dishName) {
                            model.startEditor(candidate: value.candidate, profile: profile, sample: sample, environment: environment)
                        }
                    }
                }
                Text("Saved from prior visits, not evidence of today's menu or allergy suitability. A saved observation still requires checking directly.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var profileScope: EatProfileScope {
        EatProfileScope(id: profile.id, dietaryNotes: profile.dietaryRulesText,
            allergyNotes: profile.allergiesText, maxPrice: profile.maxPricePerMealSGD, lowDataMode: profile.lowDataMode)
    }

    private var confirmationPresented: Binding<Bool> {
        Binding(get: { model.confirmation != nil }, set: { if !$0 { model.cancelRemember() } })
    }

    private func confirmationSheet(_ proposal: FoodCorrectionProposal) -> some View {
        FoodRememberReview(proposal: proposal, onConfirm: {
            _ = model.confirmRemember(profile: profile, sample: sample, environment: environment, context: context)
        }, onCancel: { model.cancelRemember() })
    }

    private func resetAndLoad() {
        model.invalidate(clearLocation: true)
        model.load(profile: profile, sample: sample, context: context)
    }

    private func dietaryBinding(_ rule: FoodDietaryRule) -> Binding<Bool> {
        Binding(get: { model.inputs.dietaryRules.contains(rule) }, set: { selected in
            model.inputs.dietaryRules.removeAll { $0 == rule }
            if selected { model.inputs.dietaryRules.append(rule) }
        })
    }

    private func allergenBinding(_ allergen: FoodAllergen) -> Binding<Bool> {
        Binding(get: { model.inputs.allergens.contains(allergen) }, set: { selected in
            model.inputs.allergens.removeAll { $0 == allergen }
            if selected { model.inputs.allergens.append(allergen) }
        })
    }

}

