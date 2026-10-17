import Foundation
import Testing
@testable import SteadyCore

@Suite("Alternatives user actions")
struct AlternativesChoiceTests {
    @Test("Choose preserves plan identity, applies only the kept outcome, and does not schedule")
    func choose() throws {
        let plan = alternativePlan(.strength, parts: [.strengthStimulus])
        guard case .options(let set) = AlternativeEngine().alternatives(
            for: plan, barrier: .sore, context: AlternativeContext()
        ) else { Issue.record("No options"); return }
        let option = try #require(set.options.first)
        let event = AlternativeChoiceEvent(id: "choice", at: testDate(), action: .choose(optionID: option.id))
        let state = try AlternativeChoiceReducer.apply(event, to: AlternativeChoiceState(plan: plan), options: set)
        #expect(state.plan.id == plan.id)
        #expect(state.plan.title == option.title)
        #expect(state.plan.minutes == option.minutes)
        #expect(state.plan.outcome.parts == option.preserves)
        #expect(state.plan.outcome.parts.isEmpty)
        #expect(state.plan.status == .proposed && state.plan.slot == nil)
        #expect(state.selectedOption == option)
        #expect(try AlternativeChoiceReducer.apply(event, to: state) == state)
    }

    @Test("Later and intentional rest remain separate transitions even when no options fit")
    func laterAndRest() throws {
        let original = AlternativeChoiceState(plan: alternativePlan())
        let later = AlternativeChoiceEvent(id: "later", at: testDate(), action: .later)
        let deferred = try AlternativeChoiceReducer.apply(later, to: original)
        #expect(deferred.plan.status == .deferred && deferred.plan.slot == nil)
        #expect(deferred.selectedOption == nil)
        #expect(try AlternativeChoiceReducer.apply(later, to: deferred) == deferred)
        let rest = AlternativeChoiceEvent(id: "rest", at: testDate(), action: .restOnPurpose)
        let rested = try AlternativeChoiceReducer.apply(rest, to: original, safetyFlags: [.userReported(.pain)])
        #expect(rested.plan.status == .intentionallyRested && rested.plan.slot == nil)
        #expect(rested.selectedOption == nil)
        #expect(try AlternativeChoiceReducer.apply(rest, to: rested) == rested)
    }

    @Test("A stale or unallowlisted option cannot be chosen")
    func staleOrUnknownOption() throws {
        let plan = alternativePlan()
        guard case .options(let set) = AlternativeEngine().alternatives(
            for: plan, barrier: .anotherOption, context: AlternativeContext()
        ) else { Issue.record("No options"); return }
        let event = AlternativeChoiceEvent(id: "unknown", at: testDate(), action: .choose(optionID: "invented"))
        #expect(throws: AlternativeChoiceError.unknownOrStaleOption) {
            try AlternativeChoiceReducer.apply(event, to: AlternativeChoiceState(plan: plan), options: set)
        }
        let stale = AlternativeSet(planID: "different-plan", barrier: set.barrier, options: set.options, source: set.source)
        #expect(throws: AlternativeChoiceError.unknownOrStaleOption) {
            try AlternativeChoiceReducer.apply(event, to: AlternativeChoiceState(plan: plan), options: stale)
        }
    }

    @Test("A safety change between display and Choose blocks the action")
    func safetyRecheckedAtChoice() throws {
        let plan = alternativePlan()
        guard case .options(let set) = AlternativeEngine().alternatives(
            for: plan, barrier: .anotherOption, context: AlternativeContext()
        ) else { Issue.record("No options"); return }
        let first = try #require(set.options.first)
        let event = AlternativeChoiceEvent(id: "choose", at: testDate(), action: .choose(optionID: first.id))
        #expect(throws: AlternativeChoiceError.safetyBlocked) {
            try AlternativeChoiceReducer.apply(
                event, to: AlternativeChoiceState(plan: plan), options: set,
                safetyFlags: [.userReported(.chestSymptoms)]
            )
        }
    }

    @Test("Completion is idempotent and finished plans reject new actions")
    func completion() throws {
        let event = AlternativeChoiceEvent(id: "complete", at: testDate(), action: .complete)
        let completed = try AlternativeChoiceReducer.apply(event, to: AlternativeChoiceState(plan: alternativePlan()))
        #expect(completed.plan.status == .completed)
        #expect(try AlternativeChoiceReducer.apply(event, to: completed) == completed)
        #expect(throws: AlternativeChoiceError.planFinished) {
            try AlternativeChoiceReducer.apply(
                AlternativeChoiceEvent(id: "different", at: testDate(), action: .restOnPurpose), to: completed
            )
        }
    }

    @Test("An inert deferred plan cannot be completed as if it happened")
    func deferredNotComplete() throws {
        let deferred = try AlternativeChoiceReducer.apply(
            AlternativeChoiceEvent(id: "later", at: testDate(), action: .later),
            to: AlternativeChoiceState(plan: alternativePlan())
        )
        #expect(throws: AlternativeChoiceError.cannotCompleteDeferredPlan) {
            try AlternativeChoiceReducer.apply(
                AlternativeChoiceEvent(id: "complete", at: testDate(), action: .complete), to: deferred
            )
        }
    }

    @Test("Choice history and state round-trip with injected time")
    func codableRoundTrip() throws {
        let event = AlternativeChoiceEvent(id: "rest", at: testDate(), action: .restOnPurpose)
        let state = try AlternativeChoiceReducer.apply(event, to: AlternativeChoiceState(plan: alternativePlan()))
        #expect(try JSONDecoder().decode(AlternativeChoiceState.self, from: JSONEncoder().encode(state)) == state)
        #expect(try JSONDecoder().decode(AlternativeChoiceEvent.self, from: JSONEncoder().encode(event)) == event)
    }
}
