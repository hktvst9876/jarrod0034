import Foundation
@testable import SteadyCore

func advisorOutcome() -> Outcome {
    Outcome(id: "private-outcome-id", summary: "Private outcome summary", parts: [.gentleMovement])
}

func advisorAlternatives(count: Int = 3, barrier: AlternativeBarrier = .anotherOption) -> AlternativeSet {
    let options = [
        alternativeOption("original-a", effort: .minimal, minutes: 3),
        alternativeOption("original-b", effort: .light, minutes: 5),
        alternativeOption("original-c", effort: .moderate, minutes: 10)
    ]
    return AlternativeSet(planID: "private-plan-id", barrier: barrier,
                          options: Array(options.prefix(count)), source: .catalog)
}

func advisorRequest(count: Int = 3, context: AdvisorContext = AdvisorContext()) throws -> AdvisorRequest {
    try AdvisorPacketBuilder.makeRequest(alternatives: advisorAlternatives(count: count),
                                         outcome: advisorOutcome(), context: context)
}

enum AdvisorStubError: Error { case rejected }

actor AdvisorSpy: AdvisorProviding {
    private var callCount = 0
    private let result: AdvisorResult?
    private let error: Bool
    private let json: Data?
    private let cancelsTask: Bool

    init(result: AdvisorResult? = nil, error: Bool = false, json: Data? = nil, cancelsTask: Bool = false) {
        self.result = result
        self.error = error
        self.json = json
        self.cancelsTask = cancelsTask
    }

    func advise(_ request: AdvisorRequest) async throws -> AdvisorResult {
        callCount += 1
        if error { throw AdvisorStubError.rejected }
        if let json { return try AdvisorResult.decode(json) }
        if cancelsTask { withUnsafeCurrentTask { $0?.cancel() } }
        return result ?? AdvisorResult(rankedCandidateIDs: request.packet.candidates.reversed().map(\.id))
    }

    func calls() -> Int { callCount }
}
