import Foundation
import Testing
@testable import SteadyCore

@Suite("Alternatives deterministic engine")
struct AlternativesEngineTests {
    @Test("Every supported plan and user-selected barrier has a valid deterministic fallback")
    func fallbackMatrix() throws {
        let outcome = Set(OutcomePart.allCases)
        for type in PlanType.allCases {
            for barrier in AlternativeBarrier.allCases {
                let plan = alternativePlan(type, parts: outcome)
                let engine = AlternativeEngine()
                let result = engine.alternatives(for: plan, barrier: barrier, context: AlternativeContext())
                guard case .options(let set) = result else {
                    Issue.record("Missing fallback for \(type) / \(barrier)")
                    continue
                }
                try AlternativeValidator.validate(set.options, for: plan.outcome)
                #expect(set.source == .fallback)
                #expect(set.options.allSatisfy { !$0.preserves.contains(.nourishment) })
                #expect(set.options.allSatisfy { $0.planType != .rest })
                #expect(result == engine.alternatives(for: plan, barrier: barrier, context: AlternativeContext()))
            }
        }
    }

    @Test("Production catalog has all plan types and uses 2-3 truthful distinct-effort options")
    func productionCatalog() throws {
        let catalog = try alternativeCatalog()
        #expect(Set(catalog.templates.map(\.planType)) == Set(PlanType.allCases))
        let engine = AlternativeEngine(catalog: catalog)
        for template in catalog.templates {
            let first = try #require(template.options.first)
            let plan = alternativePlan(template.planType, parts: first.preserves.union(first.doesNotPreserve))
            guard case .options(let set) = engine.alternatives(for: plan, barrier: .anotherOption, context: AlternativeContext()) else {
                Issue.record("No production options for \(template.planType)")
                continue
            }
            #expect(set.source == .catalog)
            try AlternativeValidator.validate(set.options, for: plan.outcome)
        }
    }

    @Test("Safety blocks even with invalid catalog and no time")
    func safetyComesFirst() throws {
        let malformed = AlternativeCatalog(version: 99, templates: [])
        for symptom in Symptom.allCases {
            let result = AlternativeEngine(catalog: malformed).alternatives(
                for: alternativePlan(.strength), barrier: .anotherOption,
                context: AlternativeContext(availableMinutes: 0, safetyFlags: [.userReported(symptom)])
            )
            guard case .blocked(let message) = result else {
                Issue.record("Safety failed for \(symptom)")
                continue
            }
            #expect(!message.guidance.isEmpty)
        }
        let alert = AlternativeEngine().alternatives(
            for: alternativePlan(), barrier: .noTime,
            context: AlternativeContext(safetyFlags: [.healthAlert(kind: "alert", at: testDate())])
        )
        guard case .blocked = alert else { Issue.record("Health alert was not blocked"); return }
    }

    @Test("Unavailable time does not manufacture rest/defer primary options")
    func insufficientTime() {
        for minutes in [0, 1] {
            let result = AlternativeEngine().alternatives(
                for: alternativePlan(), barrier: .noTime,
                context: AlternativeContext(availableMinutes: minutes)
            )
            guard case .unavailable = result else { Issue.record("Expected unavailable at \(minutes) minutes"); continue }
        }
    }

    @Test("Very short windows and timed Plan A cap every option")
    func shortWindow() throws {
        let plan = alternativePlan(minutes: 3)
        guard case .options(let set) = AlternativeEngine().alternatives(
            for: plan, barrier: .noTime, context: AlternativeContext(availableMinutes: 2)
        ) else { Issue.record("Expected two short options"); return }
        #expect(set.options.count == 2)
        #expect(set.options.allSatisfy { $0.minutes <= 2 })
        #expect(Set(set.options.map(\.effort)).count == 2)
    }

    @Test("Go-easier recovery and soreness remove moderate effort and strength")
    func easierDay() throws {
        let engine = AlternativeEngine(catalog: try alternativeCatalog())
        let plan = alternativePlan(.strength, parts: [.strengthStimulus])
        for barrier in [AlternativeBarrier.lowEnergy, .sore] {
            guard case .options(let set) = engine.alternatives(
                for: plan, barrier: barrier, context: AlternativeContext(recoveryStatus: .goEasier)
            ) else { Issue.record("Expected easy fallback"); continue }
            #expect(set.options.count == 2)
            #expect(set.options.allSatisfy { $0.effort != .moderate && $0.planType != .strength })
        }
    }

    @Test("Recovered label never increases effort or duration")
    func favorableRecoveryDoesNotIntensify() {
        let engine = AlternativeEngine()
        let ordinary = engine.alternatives(for: alternativePlan(), barrier: .anotherOption, context: AlternativeContext())
        let recovered = engine.alternatives(
            for: alternativePlan(), barrier: .anotherOption, context: AlternativeContext(recoveryStatus: .recovered)
        )
        #expect(ordinary == recovered)
    }

    @Test("Seated and wheelchair contexts do not require standing, walking or transfers")
    func movementModes() throws {
        let engine = AlternativeEngine(catalog: try alternativeCatalog())
        for mode in [AlternativeMovementMode.seated, .wheelchair] {
            guard case .options(let set) = engine.alternatives(
                for: alternativePlan(.cardio, parts: [.aerobicMovement]), barrier: .badWeather,
                context: AlternativeContext(movementMode: mode)
            ) else { Issue.record("Expected accessible alternatives"); continue }
            #expect(set.options.allSatisfy { $0.requiredMovements.isDisjoint(with: [.standing, .walking, .lowerBody]) })
            #expect(set.options.allSatisfy { $0.supportedMovementModes.contains(mode) })
            #expect(set.options.allSatisfy { !$0.preserves.contains(.aerobicMovement) })
        }
    }

    @Test("Explicit movement exclusions stay excluded including when all movements are excluded")
    func movementAvoidance() throws {
        let excluded = Set(AlternativeMovement.allCases)
        guard case .options(let set) = AlternativeEngine(catalog: try alternativeCatalog()).alternatives(
            for: alternativePlan(.strength, parts: [.strengthStimulus]), barrier: .anotherOption,
            context: AlternativeContext(movementsToAvoid: excluded)
        ) else { Issue.record("Expected non-movement fallback"); return }
        #expect(set.source == .fallback)
        #expect(set.options.allSatisfy { $0.requiredMovements.isEmpty && $0.preserves.isEmpty })
    }

    @Test("A mismatched outcome or missing catalog entry falls back without carrying unsupported claims")
    func missingOrMismatchedTemplate() throws {
        let plan = alternativePlan(.walk, parts: [.dailyRoutine, .nourishment])
        for catalog in [AlternativeCatalog.empty, try alternativeCatalog(), AlternativeCatalog(version: 99, templates: [])] {
            guard case .options(let set) = AlternativeEngine(catalog: catalog).alternatives(
                for: plan, barrier: .lateHunger, context: AlternativeContext()
            ) else { Issue.record("Expected generic fallback"); continue }
            #expect(set.source == .fallback)
            #expect(set.options.allSatisfy { $0.doesNotPreserve.contains(.nourishment) })
            try AlternativeValidator.validate(set.options, for: plan.outcome)
        }
    }
}
