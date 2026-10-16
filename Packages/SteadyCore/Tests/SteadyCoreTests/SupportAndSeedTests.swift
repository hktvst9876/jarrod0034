import Foundation
import Testing
@testable import SteadyCore

@Suite("Support and seed loading")
struct SupportAndSeedTests {
    @Test("Singapore calendar is stable")
    func singaporeCalendar() {
        let calendar = SteadyCalendar.singapore()
        #expect(calendar.timeZone.identifier == "Asia/Singapore")
        #expect(calendar.firstWeekday == 2)
    }

    @Test("Fixed clock returns the injected instant")
    func fixedClock() {
        let expected = testDate(2026, 10, 16, 9, 45)
        #expect(FixedClock(now: expected).now == expected)
    }

    @Test("Legacy alternative fixture decodes")
    func alternativesDecode() throws {
        let url = try #require(Bundle.module.url(forResource: "alternatives", withExtension: "json"))
        let seed = try SeedLoader.decode(LegacyAlternativeSeed.self, from: url)

        #expect(seed.version == 1)
        #expect(seed.plans.count == 8)
        #expect(!seed.barriers.isEmpty)
        #expect(seed.plans.allSatisfy { !$0.options.isEmpty })
    }

    @Test("Legacy food fixture decodes")
    func foodsDecode() throws {
        let url = try #require(Bundle.module.url(forResource: "foods", withExtension: "json"))
        let seed = try SeedLoader.decode(LegacyFoodSeed.self, from: url)

        #expect(seed.version == 1)
        #expect(seed.dishes.count == 38)
        #expect(seed.groceries.count == 14)
    }
}
