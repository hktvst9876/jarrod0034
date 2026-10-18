import Foundation
import Testing
@testable import SteadyCore

struct WeeklyApprovalTests {
    @Test func proposalNeedsRepeatedObservedDaysAndDoesNotChangeBase() {
        let proposal = weeklyProposal()
        #expect(proposal.baseExamMode == false)
        #expect(proposal.proposedExamMode == true)
        #expect(proposal.evidenceChangedDays == 3)
        #expect(proposal.evidencePlanIDs == ["plan-a", "plan-b", "plan-c"])
        #expect(WeeklyDefaultEngine.proposal(id: "p", summary: weeklyEvidenceSummary(), currentExamMode: true, now: weeklyNow) == nil)
    }

    @Test func approvalIsExplicitAndNarrowlyNonIntensifying() throws {
        let result = try WeeklyApprovalReducer.confirm(weeklyProposal(), currentScope: weeklyScope(),
                                                       currentExamMode: false, appliedProposalIDs: [], now: weeklyNow)
        #expect(result == .applyExamMode(true))
    }

    @Test func approvalRejectsChangedProfileSampleWeekAndRevision() {
        let scopes = [
            WeeklyScope(profileID: UUID(), isSample: false, weekStart: weeklyScope().weekStart, revision: "revision-a"),
            weeklyScope(sample: true), weeklyScope(weekStart: testDate(2026, 10, 5)), weeklyScope(revision: "revision-b")
        ]
        for scope in scopes {
            #expect(throws: WeeklyLearningError.staleScope) {
                try WeeklyApprovalReducer.confirm(weeklyProposal(), currentScope: scope,
                                                   currentExamMode: false, appliedProposalIDs: [], now: weeklyNow)
            }
        }
    }

    @Test func approvalRejectsChangedBaseValue() {
        #expect(throws: WeeklyLearningError.changedBaseValue) {
            try WeeklyApprovalReducer.confirm(weeklyProposal(), currentScope: weeklyScope(),
                                               currentExamMode: true, appliedProposalIDs: [], now: weeklyNow)
        }
    }

    @Test func exactAppliedProposalIDIsIdempotent() throws {
        let result = try WeeklyApprovalReducer.confirm(weeklyProposal(), currentScope: weeklyScope(),
                                                       currentExamMode: true, appliedProposalIDs: ["proposal-a"], now: weeklyNow)
        #expect(result == .alreadyApplied)
    }

    @Test func replayCannotCrossProfileOrRevision() {
        #expect(throws: WeeklyLearningError.staleScope) {
            try WeeklyApprovalReducer.confirm(weeklyProposal(), currentScope: weeklyScope(revision: "new"),
                                               currentExamMode: true, appliedProposalIDs: ["proposal-a"], now: weeklyNow)
        }
    }

    @Test func expiredAndFutureIssuedProposalsAreRejected() {
        #expect(throws: WeeklyLearningError.expired) {
            try WeeklyApprovalReducer.confirm(weeklyProposal(), currentScope: weeklyScope(),
                                               currentExamMode: false, appliedProposalIDs: [], now: weeklyNow.addingTimeInterval(1_801))
        }
        #expect(throws: WeeklyLearningError.expired) {
            try WeeklyApprovalReducer.confirm(weeklyProposal(), currentScope: weeklyScope(),
                                               currentExamMode: false, appliedProposalIDs: [], now: weeklyNow.addingTimeInterval(-1))
        }
    }

    @Test func sameWeekMidnightAndMondayRolloverInvalidateApproval() {
        for day in [15, 18] {
            let issued = testDate(2026, 10, day, 23, 55)
            let proposal = WeeklyDefaultEngine.proposal(id: "late", summary: weeklyEvidenceSummary(now: issued), currentExamMode: false, now: issued)!
            #expect(throws: (any Error).self) {
                try WeeklyApprovalReducer.confirm(proposal, currentScope: weeklyScope(), currentExamMode: false,
                                                   appliedProposalIDs: [], now: issued.addingTimeInterval(600))
            }
        }
    }

    @Test func futureObservedEvidenceCannotProduceAProposalAfterClockRollback() {
        #expect(WeeklyDefaultEngine.proposal(id: "future", summary: weeklyEvidenceSummary(),
                                             currentExamMode: false, now: weeklyNow.addingTimeInterval(-1)) == nil)
    }

    @Test func malformedProposalCannotRequestIntensificationOrUnsupportedChange() {
        let original = weeklyProposal()
        let invalid = WeeklyDefaultProposal(id: original.id, scope: original.scope, baseExamMode: true,
                                            proposedExamMode: false, issuedAt: original.issuedAt, expiresAt: original.expiresAt,
                                            evidencePlanIDs: original.evidencePlanIDs, evidenceChangedDays: 3, reason: "invalid")
        #expect(throws: WeeklyLearningError.invalidProposal) {
            try WeeklyApprovalReducer.confirm(invalid, currentScope: weeklyScope(), currentExamMode: true,
                                               appliedProposalIDs: [], now: weeklyNow)
        }
    }

    @Test func proposalAndReviewRoundTripWithoutPersistedHealthSummary() throws {
        let review = WeeklyReview(id: "review", scope: weeklyScope(), reviewedAt: weeklyNow, helpfulness: .mixed)
        let data = try JSONEncoder().encode(review)
        #expect(try JSONDecoder().decode(WeeklyReview.self, from: data) == review)
        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.contains("actualSleepMinutes"))
        #expect(!text.contains("sleepOpportunityMinutes"))
        #expect(try JSONDecoder().decode(WeeklyDefaultProposal.self, from: JSONEncoder().encode(weeklyProposal())) == weeklyProposal())
    }
}
