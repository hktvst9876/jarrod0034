import SteadyCore
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: ProfileRecord
    @State private var model = SettingsViewModel()
    @AppStorage("useSampleData") private var useSampleData = false
    @State private var saveError: String?

    var body: some View {
        Form {
            profileSection
            sleepSection
            movementSection
            foodSection
            privacySection
            permissionSection
            debugSection
            aboutSection
        }
        .navigationTitle("Settings")
        .task { await model.refresh(using: environment) }
        .disabled(model.isRequesting)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
        .alert("Could not save settings", isPresented: saveErrorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "Please try again.")
        }
    }

    private var profileSection: some View {
        Section("Profile") {
            TextField("Name (optional)", text: $profile.name)
            Picker("Main focus", selection: $profile.primaryFocusRawValue) {
                ForEach(WellnessFocus.allCases, id: \.rawValue) { focus in
                    Text(focus.title).tag(focus.rawValue)
                }
            }
        }
    }

    private var sleepSection: some View {
        Section("Sleep") {
            Stepper(value: $profile.sleepNeedMinutes, in: 360...600, step: 30) {
                LabeledContent("Sleep need", value: duration(profile.sleepNeedMinutes))
            }
            DatePicker("Weekday wake", selection: minutesBinding($profile.weekdayWakeMinutes), displayedComponents: .hourAndMinute)
            DatePicker("Weekend wake", selection: minutesBinding($profile.weekendWakeMinutes), displayedComponents: .hourAndMinute)
            Stepper("Morning routine: \(profile.morningRoutineMinutes) min", value: $profile.morningRoutineMinutes, in: 0...120, step: 5)
            Stepper("Usual travel: \(profile.travelMinutes) min", value: $profile.travelMinutes, in: 0...120, step: 5)
        }
    }

    private var movementSection: some View {
        Section("Movement") {
            Stepper("Strength sessions: \(profile.strengthSessionsPerWeek) a week", value: $profile.strengthSessionsPerWeek, in: 0...5)
            Picker("Preferred time", selection: $profile.preferredWorkoutTimeRawValue) {
                ForEach(DayPeriod.allCases, id: \.rawValue) { period in
                    Text(period.title).tag(period.rawValue)
                }
            }
            TextField("Movements to avoid", text: $profile.movementsToAvoid, axis: .vertical)
        }
    }

    private var foodSection: some View {
        Section("Food preferences") {
            TextField("Dietary rules, separated by commas", text: $profile.dietaryRulesText, axis: .vertical)
            TextField("Allergies, separated by commas", text: $profile.allergiesText, axis: .vertical)
            Toggle("Use a per-meal price preference", isOn: pricePreferenceEnabled)
            if profile.maxPricePerMealSGD != nil {
                TextField("Maximum per meal", value: pricePreferenceValue, format: .currency(code: "SGD"))
                    .keyboardType(.decimalPad)
            }
            Text("Allergies will be hard filters. Unknown ingredients are never assumed safe.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var privacySection: some View {
        Section("Privacy and display") {
            Toggle("Low-data mode", isOn: $profile.lowDataMode)
            Toggle("Exam mode", isOn: $profile.examMode)
            Text("Low-data mode hides calorie, weight-trend and recovery-label details everywhere.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var permissionSection: some View {
        Section("Permissions") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Apple Health").font(.headline)
                Text(model.healthStatus).font(.footnote).foregroundStyle(.secondary)
                Button("Review Health access") { Task { await model.requestHealth(using: environment) } }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Calendar").font(.headline)
                Text(model.calendarStatus).font(.footnote).foregroundStyle(.secondary)
                Button("Review Calendar access") { Task { await model.requestCalendar(using: environment) } }
            }
        }
    }

    @ViewBuilder
    private var debugSection: some View {
        #if DEBUG
        Section("Debug") {
            Toggle("Use sample data", isOn: $useSampleData)
            Text("Uses a plausible 30-day sample while keeping your saved profile.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        #endif
    }

    private var aboutSection: some View {
        Section("About") {
            Text("Steady offers general wellness guidance. It does not diagnose or treat medical conditions.")
        }
    }

    private func duration(_ minutes: Int) -> String {
        Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    private func minutesBinding(_ source: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { ProfileTimeFormatting.date(for: source.wrappedValue) },
            set: { source.wrappedValue = ProfileTimeFormatting.minutes(from: $0) }
        )
    }

    private var pricePreferenceEnabled: Binding<Bool> {
        Binding(
            get: { profile.maxPricePerMealSGD != nil },
            set: { profile.maxPricePerMealSGD = $0 ? (profile.maxPricePerMealSGD ?? 6) : nil }
        )
    }

    private var pricePreferenceValue: Binding<Double> {
        Binding(
            get: { profile.maxPricePerMealSGD ?? 6 },
            set: { profile.maxPricePerMealSGD = max(0, $0) }
        )
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private var saveErrorIsPresented: Binding<Bool> {
        Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )
    }
}
