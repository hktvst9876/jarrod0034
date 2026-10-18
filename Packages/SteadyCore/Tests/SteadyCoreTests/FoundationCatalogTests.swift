import Foundation
import Testing
@testable import SteadyCore

@Suite("Daily Foundation library")
struct FoundationCatalogTests {
    @Test("Every family has distinct choices for every explicit movement mode")
    func everyKindAndMode() {
        var allIDs: Set<String> = []
        for kind in FoundationKind.allCases {
            for mode in AlternativeMovementMode.allCases {
                let settings = FoundationSettings(movementMode: mode)
                let options = FoundationCatalog.options(for: kind, settings: settings)
                #expect(options.count >= 2)
                #expect(Set(options.map(\.id)).count == options.count)
                #expect(Set(options.map(\.title)).count == options.count)
                #expect(options.allSatisfy { $0.kind == kind && $0.supportedMovementModes.contains(mode) })
                #expect(options.allSatisfy { !$0.reason.isEmpty && !$0.durationExplanation.isEmpty && !$0.steps.isEmpty })
                #expect(options.allSatisfy { $0.minutes == nil || ($0.minutes ?? 0) > 0 })
                #expect(options == FoundationCatalog.options(for: kind, settings: settings))
                allIDs.formUnion(options.map(\.id))
            }
        }
        #expect(allIDs.count == 14)
    }

    @Test("Typed avoid selections filter every required movement without inference")
    func avoidedMovements() {
        for mode in AlternativeMovementMode.allCases {
            for movement in AlternativeMovement.allCases {
                let settings = FoundationSettings(movementMode: mode, movementsToAvoid: [movement])
                for kind in FoundationKind.allCases {
                    let options = FoundationCatalog.options(for: kind, settings: settings)
                    #expect(options.allSatisfy { !$0.requiredMovements.contains(movement) })
                }
            }
        }
    }

    @Test("Seated and wheelchair options never require standing or walking")
    func supportedVariants() {
        for mode in [AlternativeMovementMode.seated, .wheelchair] {
            for kind in FoundationKind.allCases {
                let options = FoundationCatalog.options(for: kind, settings: FoundationSettings(movementMode: mode))
                #expect(options.allSatisfy { $0.requiredMovements.isDisjoint(with: [.standing, .walking]) })
            }
        }
    }

    @Test("No movement choice is padded in when every movement is explicitly avoided")
    func noFillerWhenRestricted() {
        let settings = FoundationSettings(movementsToAvoid: Set(AlternativeMovement.allCases))
        #expect(FoundationCatalog.options(for: .mobility, settings: settings).isEmpty)
        #expect(FoundationCatalog.options(for: .movementBreak, settings: settings).isEmpty)
        for kind in [FoundationKind.daylight, .hydration, .reset, .windDown] {
            #expect(!FoundationCatalog.options(for: kind, settings: settings).isEmpty)
        }
    }

    @Test("Each safety symptom and device alert suppress every foundation suggestion")
    func safetyFirst() {
        let flags = Symptom.allCases.map { SafetyFlag.userReported($0) }
            + [.healthAlert(kind: "relevant alert", at: testDate())]
        for flag in flags {
            for kind in FoundationKind.allCases {
                #expect(FoundationCatalog.options(for: kind, safetyFlags: [flag]).isEmpty)
            }
        }
    }

    @Test("A disabled kind has no suggested options without disabling other kinds")
    func disabledKinds() {
        for kind in FoundationKind.allCases {
            let settings = FoundationSettings(disabledKinds: [kind])
            #expect(FoundationCatalog.options(for: kind, settings: settings).isEmpty)
            for other in FoundationKind.allCases where other != kind {
                #expect(!FoundationCatalog.options(for: other, settings: settings).isEmpty)
            }
        }
    }

    @Test("Hydration is thirst-led with neither volume nor timer target")
    func hydrationHasNoQuota() {
        for option in FoundationCatalog.options(for: .hydration) {
            #expect(option.minutes == nil)
            let copy = ([option.title, option.reason, option.durationExplanation] + option.steps).joined(separator: " ").lowercased()
            #expect(copy.contains("thirst"))
            #expect(!copy.contains("litre") && !copy.contains("ml") && !copy.contains("glasses"))
            #expect(copy.rangeOfCharacter(from: .decimalDigits) == nil)
            #expect(option.steps.contains { $0.contains("fluid") })
        }
    }

    @Test("Daylight explicitly avoids sun gazing and offers shade and weather opt-out")
    func daylightBoundaries() {
        for option in FoundationCatalog.options(for: .daylight) {
            let copy = option.steps.joined(separator: " ").lowercased()
            #expect(copy.contains("shade"))
            #expect(copy.contains("never") && copy.contains("sun"))
            #expect(copy.contains("unsafe") || copy.contains("unsuitable"))
            #expect(!copy.contains("vitamin") && !copy.contains("treat"))
        }
    }

    @Test("The smallest wind-down is first and has no elaborate ritual claim")
    func smallestWindDown() throws {
        let option = try #require(FoundationCatalog.options(for: .windDown).first)
        #expect(option.id == "winddown-smallest")
        #expect(option.minutes == 1)
        #expect(option.durationExplanation.contains("not required"))
        #expect(option.requiredMovements.isEmpty)
    }
}
