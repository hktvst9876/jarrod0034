import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @State private var model = OnboardingViewModel()
    @State private var saveError: String?

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(model.step + 1), total: Double(model.lastStep + 1))
                    .padding(.horizontal)
                    .accessibilityLabel("Onboarding progress")

                Group {
                    switch model.step {
                    case 0: OnboardingWelcomePage(name: $model.name)
                    case 1: OnboardingFocusPage(focus: $model.focus)
                    case 2:
                        OnboardingSleepPage(
                            sleepNeedHours: $model.sleepNeedHours,
                            weekdayWake: $model.weekdayWake,
                            weekendWake: $model.weekendWake
                        )
                    case 3:
                        OnboardingMovementPage(
                            sessions: $model.strengthSessionsPerWeek,
                            workoutTime: $model.workoutTime,
                            movementsToAvoid: $model.movementsToAvoid,
                            lowDataMode: $model.lowDataMode
                        )
                    default:
                        OnboardingPermissionsPage(model: model, environment: environment)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack {
                    if model.step > 0 {
                        Button("Back") { model.moveBack() }
                    }
                    Spacer()
                    if model.step < model.lastStep {
                        Button("Skip for now") { model.moveForward() }
                        Button("Continue") { model.moveForward() }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button("Start using Steady") {
                            finishOnboarding()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .navigationTitle("Set up Steady")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Could not save your profile", isPresented: saveErrorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "Your choices are still on this screen. Please try again.")
        }
    }

    private func finishOnboarding() {
        let profile = model.makeProfile(completedAt: environment.now)
        modelContext.insert(profile)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
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

