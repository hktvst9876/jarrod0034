import Foundation
import SwiftData
import SwiftUI

struct DataControlsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("useSampleData") private var sample = false
    let profile: ProfileRecord
    @State private var archive: ArchivePreparation?
    @State private var deletion: DeletionReview?
    @State private var typedConfirmation = ""
    @State private var message: String?
    @State private var showCountWhy = false

    var body: some View {
        Form {
            Section("Export on this device") {
                Text("Prepare JSON from every saved Steady profile, real and sample records, local preferences and pending phone companion inbox. Nothing is uploaded by Steady.")
                Text("If any saved profile uses low-data mode, only identifiers and dates are included. That redacted file is not a complete backup. Raw HealthKit samples, full Calendar events and temporary searches are never included.")
                Button("Prepare local JSON") { prepare() }
                if let archive {
                    Text(archive.metadataOnly ? "Metadata-only archive ready" : "Full app-record archive ready")
                    Button("Why these record counts? (\(archive.counts.values.reduce(0, +)))") { showCountWhy = true }
                    Text("A full archive may include sensitive app-entered preferences and saved choices. Choose a destination you trust. Exported copies are outside Steady's control.")
                        .font(.footnote)
                    ShareLink("Share JSON…", item: archive.item, preview: SharePreview("Steady local data"))
                }
            }
            Section("Advisor diagnostics") {
                Text("Diagnostic activity is temporary and separate from your wellness records and opt-in setting.")
                Button("Clear advisor diagnostic activity") {
                    environment.advisor.clearActivity()
                    message = "Advisor diagnostic activity cleared. Wellness records and advisor opt-in were not changed."
                }
            }
            Section("Delete Steady's local data") {
                deletionExplanation
                Button("Review deletion…", role: .destructive) { reviewDeletion() }
            }
            if let message { Section { Text(message) } }
            if let error = environment.dataLifecycle.errorMessage { Section { Text(error).foregroundStyle(.red) } }
        }
        .navigationTitle("Your local data")
        .disabled(environment.dataLifecycle.isDeleting || environment.dataLifecycle.isBlocked)
        .sheet(item: $deletion) { review in deletionSheet(review) }
        .alert("Record counts", isPresented: $showCountWhy) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Each count is a persisted app-record count, not a wellness score or complete activity history.\n"
                 + (archive?.counts.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: "\n") ?? ""))
        }
        .onChange(of: profile.lowDataMode) { _, _ in invalidate() }
        .onChange(of: sample) { _, _ in invalidate() }
        .onChange(of: environment.dataLifecycle.revision) { _, _ in invalidate() }
        .onChange(of: scenePhase) { _, phase in if phase == .background { invalidate() } }
        .onDisappear { invalidate() }
    }

    private var deletionExplanation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Deletes all Steady profiles and real/sample plans, choices, Foundations, food observations, weekly reviews, experiments and local metrics. Also clears opt-ins, Steady reminders, diagnostics and phone companion queues.")
            Text("Apple Health data and Apple Calendar events are NOT deleted. Previously exported files, system backups and system permission choices are not erased. This removes app-accessible records, not a forensic secure erase of device storage.")
            Text("A clear request is retained for Watch delivery. A disconnected Watch cannot be erased immediately; reconnect and open Steady on it. A minimal non-personal reset fence remains to reject old messages and prevent extra reminders on the reset day.")
        }
        .font(.footnote)
    }

    private func deletionSheet(_ review: DeletionReview) -> some View {
        NavigationStack {
            Form {
                Section("This cannot be undone in Steady") { deletionExplanation }
                Section("Explicit confirmation") {
                    Text("Type DELETE to erase every local Steady profile. Cancel makes no changes.")
                    TextField("DELETE", text: $typedConfirmation)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    Button("Delete all Steady app data", role: .destructive) { confirmDeletion(review) }
                        .disabled(typedConfirmation != "DELETE" || environment.dataLifecycle.isDeleting)
                }
            }
            .navigationTitle("Confirm local deletion")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { deletion = nil; typedConfirmation = "" } } }
            .interactiveDismissDisabled(environment.dataLifecycle.isDeleting)
        }
    }

    private func prepare() {
        invalidate()
        do { archive = try SteadyArchiveBuilder.prepare(context: context, now: environment.now); message = nil }
        catch { message = error.localizedDescription + " Save any open Settings edits before trying again." }
    }

    private func reviewDeletion() {
        guard !context.hasChanges, !environment.dataLifecycle.isBlocked else {
            message = "Save your open Settings edits, then review deletion again. No data was erased."
            return
        }
        invalidate()
        typedConfirmation = ""
        deletion = DeletionReview(profileID: profile.id, sample: sample, lowData: profile.lowDataMode,
            revision: environment.dataLifecycle.revision, day: environment.calendar.startOfDay(for: environment.now),
            at: environment.now)
    }

    private func confirmDeletion(_ review: DeletionReview) {
        let age = environment.now.timeIntervalSince(review.at)
        guard typedConfirmation == "DELETE", !context.hasChanges, !environment.dataLifecycle.isBlocked,
              review.profileID == profile.id, review.sample == sample, review.lowData == profile.lowDataMode,
              review.revision == environment.dataLifecycle.revision, age.isFinite, (0..<900).contains(age),
              review.day == environment.calendar.startOfDay(for: environment.now) else {
            deletion = nil
            message = "This confirmation expired or its privacy scope changed. Review deletion again; nothing was erased."
            return
        }
        deletion = nil
        Task {
            await environment.dataLifecycle.deleteAll(container: context.container, sharedContext: context,
                environment: environment, expectedRevision: review.revision)
        }
    }

    private func invalidate() {
        archive?.item.lease.invalidate()
        archive = nil
        deletion = nil
        typedConfirmation = ""
    }
}

private struct DeletionReview: Identifiable {
    let id = UUID()
    let profileID: UUID
    let sample: Bool
    let lowData: Bool
    let revision: Int
    let day: Date
    let at: Date
}
