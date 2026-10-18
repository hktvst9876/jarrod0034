import Foundation
import Testing
@testable import SteadyCore

@Suite("Minimal read-only advisor packets")
struct AdvisorPacketTests {
    @Test("Canonical arbitrary text and stored identifiers never enter a packet")
    func noFreeTextOrStoredIDs() throws {
        let marker = "SECRET_HEALTH_CALENDAR_PROFILE_MARKER"
        let options = [AlternativeEffort.minimal, .light, .moderate].enumerated().map { index, effort in
            AlternativeOption(
                id: marker + "-id-\(index)", title: marker + "-title-\(index)", minutes: index + 2,
                effort: effort, benefitKept: marker + "-benefit", tradeoff: marker + "-tradeoff",
                preserves: [.gentleMovement], doesNotPreserve: [], steps: [marker + "-steps"], planType: .mobility
            )
        }
        let set = AlternativeSet(planID: marker, barrier: .sore, options: options, source: .catalog)
        let outcome = Outcome(id: marker, summary: marker, parts: [.gentleMovement])
        let request = try AdvisorPacketBuilder.makeRequest(alternatives: set, outcome: outcome, context: AdvisorContext())
        let encoded = String(decoding: try JSONEncoder().encode(request), as: UTF8.self)
        #expect(!encoded.contains(marker))
        #expect(request.packet.candidates.map(\.id) == ["choice_a", "choice_b", "choice_c"])
    }

    @Test("The serialized request has an explicit allowlist of keys")
    func exactPacketShape() throws {
        let data = try JSONEncoder().encode(advisorRequest(context: AdvisorContext(availableMinutes: 15)))
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(root.keys) == ["packet"])
        let packet = try #require(root["packet"] as? [String: Any])
        #expect(Set(packet.keys) == ["schemaVersion", "candidates", "context"])
        let context = try #require(packet["context"] as? [String: Any])
        #expect(Set(context.keys) == ["timeBudget", "barrier", "lowDataMode"])
        let candidates = try #require(packet["candidates"] as? [[String: Any]])
        #expect(candidates.allSatisfy {
            Set($0.keys) == ["id", "planType", "minutes", "effort", "preserves", "doesNotPreserve"]
        })
    }

    @Test("Low-data mode omits the explicit barrier and has no health fields")
    func lowDataRedaction() throws {
        let request = try AdvisorPacketBuilder.makeRequest(
            alternatives: advisorAlternatives(barrier: .sore), outcome: advisorOutcome(),
            context: AdvisorContext(availableMinutes: 8, lowDataMode: true)
        )
        #expect(request.packet.context.barrier == nil)
        let encoded = String(decoding: try JSONEncoder().encode(request), as: UTF8.self)
        for forbidden in ["barrier", "sore", "recovery", "readiness", "health", "symptom", "calorie", "weight"] {
            #expect(!encoded.lowercased().contains(forbidden))
        }
        #expect(request.packet.context.timeBudget == .fiveToTenMinutes)
    }

    @Test("A missing time budget remains unknown rather than becoming zero")
    func missingNotZero() throws {
        let unknown = try advisorRequest()
        let zero = try advisorRequest(context: AdvisorContext(availableMinutes: 0))
        #expect(unknown.packet.context.timeBudget == .unknown)
        #expect(zero.packet.context.timeBudget == .underFiveMinutes)
        #expect(unknown != zero)
    }

    @Test("Only a coarse time bucket is included, not precise available minutes")
    func coarseTimeBoundaries() throws {
        let examples: [(Int, AdvisorTimeBudget)] = [
            (-1, .underFiveMinutes), (0, .underFiveMinutes), (4, .underFiveMinutes),
            (5, .fiveToTenMinutes), (10, .fiveToTenMinutes),
            (11, .elevenToTwentyMinutes), (20, .elevenToTwentyMinutes),
            (21, .overTwentyMinutes), (Int.max, .overTwentyMinutes)
        ]
        for (minutes, expected) in examples {
            #expect(try advisorRequest(context: AdvisorContext(availableMinutes: minutes)).packet.context.timeBudget == expected)
        }
    }

    @Test("Packet encoding is stable with sorted outcome sets")
    func stableEncoding() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let request = try advisorRequest()
        #expect(try encoder.encode(request) == encoder.encode(advisorRequest()))
        #expect(request.packet.schemaVersion == 1)
    }

    @Test("Invalid canonical content never reaches the packet boundary")
    func badCanonicalInput() {
        let bad = AlternativeSet(planID: "plan", barrier: .anotherOption,
                                 options: [alternativeOption("a", effort: .minimal, benefit: "")], source: .catalog)
        #expect(throws: AdvisorValidationError.invalidCandidates) {
            try AdvisorPacketBuilder.makeRequest(alternatives: bad, outcome: advisorOutcome(), context: AdvisorContext())
        }
    }

    @Test("Typed packets provide no history, identity, timestamps, or action contract")
    func noActionOrPersonalContext() throws {
        let encoded = String(decoding: try JSONEncoder().encode(advisorRequest()), as: UTF8.self).lowercased()
        for forbidden in ["profile", "name", "planid", "original-", "timestamp", "calendar", "event", "notes", "tool", "action", "write"] {
            #expect(!encoded.contains(forbidden))
        }
    }
}
