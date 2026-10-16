import SwiftUI
import SteadyCore

struct OnboardingWelcomePage: View {
    @Binding var name: String

    var body: some View {
        Form {
            Section {
                Label("One realistic priority", systemImage: "scope")
                Label("A smaller option when plans change", systemImage: "arrow.triangle.branch")
                Label("Private and useful without every permission", systemImage: "lock")
            } header: {
                Text("A calmer plan for today")
            }
            Section("What should Steady call you? (optional)") {
                TextField("Name", text: $name)
                    .textContentType(.name)
            }
        }
    }
}

struct OnboardingFocusPage: View {
    @Binding var focus: WellnessFocus

    var body: some View {
        Form {
            Section("What would help most?") {
                Picker("Main focus", selection: $focus) {
                    ForEach(WellnessFocus.allCases, id: \.rawValue) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.inline)
            }
            Text("You can change this any time. Steady still considers sleep, movement, food and downtime together.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

struct OnboardingSleepPage: View {
    @Binding var sleepNeedHours: Double
    @Binding var weekdayWake: Date
    @Binding var weekendWake: Date

    var body: some View {
        Form {
            Section("Sleep preferences") {
                Stepper(value: $sleepNeedHours, in: 6...10, step: 0.5) {
                    LabeledContent("Sleep need", value: sleepNeedHours.formatted(.number.precision(.fractionLength(1))) + " hours")
                }
                DatePicker("Weekday wake", selection: $weekdayWake, displayedComponents: .hourAndMinute)
                DatePicker("Weekend wake", selection: $weekendWake, displayedComponents: .hourAndMinute)
            }
            Text("Why: these times let Steady protect a realistic sleep window; they are not a score or a rule.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

struct OnboardingMovementPage: View {
    @Binding var sessions: Int
    @Binding var workoutTime: DayPeriod
    @Binding var movementsToAvoid: String
    @Binding var lowDataMode: Bool

    var body: some View {
        Form {
            Section("Movement") {
                Stepper("Strength sessions: \(sessions) each week", value: $sessions, in: 0...5)
                Picker("Preferred time", selection: $workoutTime) {
                    ForEach(DayPeriod.allCases, id: \.rawValue) { option in
                        Text(option.title).tag(option)
                    }
                }
                TextField("Movements to avoid (optional)", text: $movementsToAvoid, axis: .vertical)
            }
            Section("Display") {
                Toggle("Use low-data mode", isOn: $lowDataMode)
                Text("Hides calorie, weight-trend and recovery-label details. Plain guidance stays available.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

