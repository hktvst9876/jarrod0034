import Foundation
import Testing
@testable import SteadyCore

@Suite("Fail-closed advisor response validation")
struct AdvisorValidationTests {
    @Test("A full two-option or three-option permutation is accepted")
    func permutations() throws {
        for count in [2, 3] {
            let request = try advisorRequest(count: count)
            let result = AdvisorResult(rankedCandidateIDs: request.packet.candidates.reversed().map(\.id))
            try ResponseValidator.validate(result, for: request)
        }
    }

    @Test("Every permutation of three options preserves the allowlist")
    func allPermutations() throws {
        let request = try advisorRequest()
        let permutations = [
            ["choice_a", "choice_b", "choice_c"], ["choice_a", "choice_c", "choice_b"],
            ["choice_b", "choice_a", "choice_c"], ["choice_b", "choice_c", "choice_a"],
            ["choice_c", "choice_a", "choice_b"], ["choice_c", "choice_b", "choice_a"]
        ]
        for ids in permutations { try ResponseValidator.validate(AdvisorResult(rankedCandidateIDs: ids), for: request) }
    }

    @Test("Empty, single-option, and more-than-three results are rejected")
    func countLimit() throws {
        let request = try advisorRequest()
        for ids in [[], ["choice_a"], ["choice_a", "choice_b", "choice_c", "choice_d"]] {
            #expect(throws: AdvisorValidationError.invalidOptionCount) {
                try ResponseValidator.validate(AdvisorResult(rankedCandidateIDs: ids), for: request)
            }
        }
    }

    @Test("A duplicate cannot stand in for a missing option")
    func duplicateIDs() throws {
        let request = try advisorRequest()
        #expect(throws: AdvisorValidationError.duplicateCandidateID) {
            try ResponseValidator.validate(AdvisorResult(rankedCandidateIDs: ["choice_a", "choice_a", "choice_b"]), for: request)
        }
    }

    @Test("Unknown IDs, original IDs, blank IDs, and altered aliases are rejected")
    func outsideAllowlist() throws {
        let request = try advisorRequest()
        for outsider in ["unknown", "original-c", "", " choice_c", "CHOICE_C"] {
            #expect(throws: AdvisorValidationError.notAFullPermutation) {
                try ResponseValidator.validate(AdvisorResult(rankedCandidateIDs: ["choice_a", "choice_b", outsider]), for: request)
            }
        }
    }

    @Test("A subset or extra option from another request is not a complete permutation")
    func noOptionDropOrAddition() throws {
        let three = try advisorRequest()
        let two = try advisorRequest(count: 2)
        #expect(throws: AdvisorValidationError.notAFullPermutation) {
            try ResponseValidator.validate(AdvisorResult(rankedCandidateIDs: ["choice_a", "choice_b"]), for: three)
        }
        #expect(throws: AdvisorValidationError.notAFullPermutation) {
            try ResponseValidator.validate(AdvisorResult(rankedCandidateIDs: ["choice_a", "choice_b", "choice_c"]), for: two)
        }
    }

    @Test("Canonical fact or wording mutation fields are rejected rather than ignored")
    func factMutation() {
        for field in ["title", "minutes", "effort", "benefitKept", "tradeoff", "steps", "outcomes", "price", "nutrition"] {
            let json = "{\"rankedCandidateIDs\":[\"choice_a\",\"choice_b\",\"choice_c\"],\"\(field)\":\"invented\"}"
            #expect(throws: AdvisorValidationError.unexpectedResponseFields) { try AdvisorResult.decode(Data(json.utf8)) }
        }
    }

    @Test("Citations or live factual claims cannot be supplied in ranking-only output")
    func noCitationAuthority() {
        for field in ["citations", "sources", "liveClaim", "openingHours", "ingredients"] {
            let json = "{\"rankedCandidateIDs\":[\"choice_a\",\"choice_b\"],\"\(field)\":[]}"
            #expect(throws: AdvisorValidationError.unexpectedResponseFields) { try AdvisorResult.decode(Data(json.utf8)) }
        }
    }

    @Test("No inferred allergy, injury, diagnosis, or emotion field is accepted")
    func noInference() {
        for field in ["allergy", "injury", "diagnosis", "emotion", "explanation", "reason"] {
            let json = "{\"rankedCandidateIDs\":[\"choice_a\",\"choice_b\"],\"\(field)\":\"inferred\"}"
            #expect(throws: AdvisorValidationError.unexpectedResponseFields) { try AdvisorResult.decode(Data(json.utf8)) }
        }
    }

    @Test("No Calendar, notification, preference, or tool action can cross the output boundary")
    func noActionAuthority() {
        for field in ["action", "tool", "calendarWrite", "notification", "preference", "remember"] {
            let json = "{\"rankedCandidateIDs\":[\"choice_a\",\"choice_b\"],\"\(field)\":\"execute\"}"
            #expect(throws: AdvisorValidationError.unexpectedResponseFields) { try AdvisorResult.decode(Data(json.utf8)) }
        }
    }

    @Test("Malformed JSON, wrong field types, missing IDs, and top-level prose fail decoding")
    func malformedOutput() {
        for json in ["not JSON", "{}", "[]", "null", "{\"rankedCandidateIDs\":\"choice_a\"}",
                     "{\"rankedCandidateIDs\":[1,2]}", "{\"rankedCandidateIDs\":[\"choice_a\"]"] {
            #expect(throws: (any Error).self) { try AdvisorResult.decode(Data(json.utf8)) }
        }
    }

    @Test("The exact ID-only response round-trips without extra fields")
    func responseRoundTrip() throws {
        let original = AdvisorResult(rankedCandidateIDs: ["choice_b", "choice_a"])
        let data = try JSONEncoder().encode(original)
        #expect(try AdvisorResult.decode(data) == original)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["rankedCandidateIDs"])
    }
}
