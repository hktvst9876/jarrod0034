import SwiftUI

struct OnboardingPermissionsPage: View {
    @Bindable var model: OnboardingViewModel
    let environment: AppEnvironment

    var body: some View {
        Form {
            Section {
                PermissionRow(
                    title: "Apple Health",
                    explanation: "Read sleep and activity to add context. Apple does not tell apps which read choices you allowed.",
                    status: model.healthMessage,
                    buttonTitle: "Choose Health access"
                ) {
                    Task { await model.requestHealth(using: environment) }
                }
                PermissionRow(
                    title: "Calendar",
                    explanation: "Read event times to find free windows. Event titles and notes are not stored.",
                    status: model.calendarMessage,
                    buttonTitle: "Choose Calendar access"
                ) {
                    Task { await model.requestCalendar(using: environment) }
                }
            } header: {
                Text("Optional permissions")
            } footer: {
                Text("Skip either request and Steady will use a check-in or ask how much time you have.")
            }

            Section("Privacy") {
                Label("Your profile and derived history stay on this device.", systemImage: "iphone.and.arrow.forward")
                Label("No account, analytics, cloud advisor or advertising.", systemImage: "hand.raised")
            }
        }
        .disabled(model.isRequestingPermission)
    }
}

private struct PermissionRow: View {
    let title: String
    let explanation: String
    let status: String?
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(explanation).font(.subheadline).foregroundStyle(.secondary)
            Button(buttonTitle, action: action).buttonStyle(.bordered)
            if let status {
                Text(status).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
