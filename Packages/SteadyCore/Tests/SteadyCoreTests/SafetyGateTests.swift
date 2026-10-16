import Foundation
import Testing
@testable import SteadyCore

@Suite("Safety gate")
struct SafetyGateTests {
    @Test("No explicit flag leaves ordinary guidance available")
    func clearWithoutFlag() {
        #expect(SafetyGate.evaluate([]) == .clear)
    }

    @Test("Every supported symptom pauses performance recommendations")
    func symptomsBlockAdvice() {
        for symptom in Symptom.allCases {
            let decision = SafetyGate.evaluate([.userReported(symptom)])
            #expect(decision.blocksPerformanceRecommendations)

            guard case .pauseRecommendations(let message) = decision else {
                Issue.record("Expected a safety message for \(symptom)")
                continue
            }
            #expect(message.guidance.contains("GP") || message.guidance.contains("health centre"))
            #expect(message.emergencyGuidance.contains("995"))
        }
    }

    @Test("An actual health alert pauses performance recommendations")
    func healthAlertBlocksAdvice() {
        let decision = SafetyGate.evaluate([
            .healthAlert(kind: "irregular rhythm", at: testDate())
        ])
        #expect(decision.blocksPerformanceRecommendations)
    }
}
