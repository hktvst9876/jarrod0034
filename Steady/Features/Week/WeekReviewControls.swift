import SteadyCore
import SwiftUI

struct WeekExperimentEditor: View {
    @Environment(\.dismiss) private var dismiss
    let environment: AppEnvironment
    let prepare: (WeeklyExperimentKind, Date, Date) -> Void
    @State private var kind = WeeklyExperimentKind.smallPlan
    @State private var start: Date?
    @State private var end: Date?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Experiment", selection: $kind) {
                    ForEach(WeeklyExperimentKind.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Text(kind.simpleMeasure)
                DatePicker("Start", selection: Binding(get: { start ?? today }, set: { start = $0 }), displayedComponents: .date)
                DatePicker("End before", selection: Binding(get: { end ?? defaultEnd }, set: { end = $0 }), displayedComponents: .date)
                DisclosureGroup("Why these dates") {
                    Text("Choose a start within the next week and an end between two and fourteen local days later. The end date is exclusive. The next screen asks for explicit confirmation; this editor writes nothing.")
                }
                Text("This is an optional intention, not exercise progression or a reminder schedule.")
            }
            .navigationTitle("Choose one experiment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Review") { prepare(kind, start ?? today, end ?? defaultEnd) } }
            }
        }
    }

    private var today: Date { environment.calendar.startOfDay(for: environment.now) }
    private var defaultEnd: Date { environment.calendar.date(byAdding: .day, value: 7, to: start ?? today) ?? today }
}

struct WeekConfirmation<Content: View>: View {
    let title: String
    let confirmLabel: String
    let cancel: () -> Void
    let confirm: () -> Void
    let content: () -> Content

    init(title: String, confirmLabel: String, cancel: @escaping () -> Void, confirm: @escaping () -> Void,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title; self.confirmLabel = confirmLabel
        self.cancel = cancel; self.confirm = confirm; self.content = content
    }

    var body: some View {
        NavigationStack {
            Form { content() }
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: cancel) }
                    ToolbarItem(placement: .confirmationAction) { Button(confirmLabel, action: confirm) }
                }
        }
    }
}
