import SwiftData
import SwiftUI

/// A new context and view identity prevent registered pre-reset models from reappearing.
struct PrivacyLaunchView: View {
    @Environment(AppEnvironment.self) private var environment
    let container: ModelContainer

    var body: some View {
        Group {
            if environment.dataLifecycle.isBlocked {
                DeletionRecoveryView(container: container)
            } else {
                FreshDataRoot(container: container)
                    .id(environment.dataLifecycle.revision)
            }
        }
    }
}

private struct FreshDataRoot: View {
    @State private var context: ModelContext

    init(container: ModelContainer) {
        let fresh = ModelContext(container)
        fresh.autosaveEnabled = true
        _context = State(initialValue: fresh)
    }

    var body: some View { AppLaunchView().modelContext(context) }
}

private struct DeletionRecoveryView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var context
    let container: ModelContainer

    var body: some View {
        NavigationStack {
            Form {
                if environment.dataLifecycle.hasConfirmedDeletion {
                  Section("Finish local deletion") {
                    Text("A confirmed privacy reset did not finish. Steady keeps data entry blocked so old records cannot be restored by a delayed update.")
                    Text("Retry clears Steady's app-local records only. Apple Health and Apple Calendar remain unchanged. A disconnected Watch may need to reconnect or open Steady to receive the clear request.")
                    Button("Retry confirmed deletion", role: .destructive) {
                        Task {
                            await environment.dataLifecycle.deleteAll(container: container,
                                sharedContext: context, environment: environment, expectedRevision: nil)
                        }
                    }
                    .disabled(environment.dataLifecycle.isDeleting)
                    if environment.dataLifecycle.isDeleting { ProgressView("Clearing local data…") }
                    if let error = environment.dataLifecycle.errorMessage { Text(error).foregroundStyle(.red) }
                  }
                } else {
                    Section("Privacy journal unavailable") {
                        Text("Steady cannot read its non-personal reset fence. It cannot safely determine whether deletion was confirmed or reject every old message, so it has blocked data entry. No destructive reset is guessed from unreadable bytes.")
                        Text("Close Steady, check device storage, then try again. Apple Health and Apple Calendar remain unchanged.")
                        Button("Recheck privacy journal") { environment.dataLifecycle.recheckJournal() }
                        if let error = environment.dataLifecycle.errorMessage { Text(error).foregroundStyle(.red) }
                    }
                }
            }
            .navigationTitle("Privacy reset")
        }
    }
}
