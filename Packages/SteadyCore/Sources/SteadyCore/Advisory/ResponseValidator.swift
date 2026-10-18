import Foundation

public enum ResponseValidator {
    /// A valid result is a complete permutation, not a selection/subset.
    /// Rebuilding canonical values means no model-generated claim can reach UI.
    public static func validate(_ result: AdvisorResult, for request: AdvisorRequest) throws {
        let candidates = request.packet.candidates
        let expectedIDs = candidates.map(\.id)
        guard request.packet.schemaVersion == 1,
              (2...3).contains(candidates.count),
              Set(expectedIDs).count == candidates.count,
              expectedIDs == Array(["choice_a", "choice_b", "choice_c"].prefix(candidates.count)),
              candidates.allSatisfy({ $0.minutes > 0 }),
              !request.packet.context.lowDataMode || request.packet.context.barrier == nil else {
            throw AdvisorValidationError.invalidPacket
        }
        guard (2...3).contains(result.rankedCandidateIDs.count) else {
            throw AdvisorValidationError.invalidOptionCount
        }
        guard Set(result.rankedCandidateIDs).count == result.rankedCandidateIDs.count else {
            throw AdvisorValidationError.duplicateCandidateID
        }
        guard result.rankedCandidateIDs.count == expectedIDs.count,
              Set(result.rankedCandidateIDs) == Set(expectedIDs) else {
            throw AdvisorValidationError.notAFullPermutation
        }
    }
}
