import Foundation
import Testing
@testable import SteadyCore

@Suite("Calendar availability")
struct FreeSlotFinderTests {
    @Test("An empty calendar returns the whole usable window")
    func emptyCalendar() throws {
        let slots = FreeSlotFinder.find(
            within: window(8, 18),
            busyIntervals: [],
            minimumDurationMinutes: 30,
            paddingMinutes: 15
        )
        let slot = try #require(slots.first)
        #expect(slots.count == 1)
        #expect(slot.start == testDate(2026, 10, 16, 8))
        #expect(slot.end == testDate(2026, 10, 16, 18))
    }

    @Test("Padding and overlap merge before gaps are calculated")
    func padsAndMergesBusyTime() {
        let busy = [
            BusyInterval(start: testDate(2026, 10, 16, 10), end: testDate(2026, 10, 16, 11)),
            BusyInterval(start: testDate(2026, 10, 16, 11, 10), end: testDate(2026, 10, 16, 12))
        ]
        let slots = FreeSlotFinder.find(
            within: window(8, 14),
            busyIntervals: busy,
            minimumDurationMinutes: 30,
            paddingMinutes: 15
        )

        #expect(slots.count == 2)
        #expect(slots[0].end == testDate(2026, 10, 16, 9, 45))
        #expect(slots[1].start == testDate(2026, 10, 16, 12, 15))
    }

    @Test("Past time and invalid busy intervals are ignored safely")
    func clipsToNow() throws {
        let slots = FreeSlotFinder.find(
            within: window(8, 18),
            busyIntervals: [
                BusyInterval(start: testDate(2026, 10, 16, 13), end: testDate(2026, 10, 16, 12))
            ],
            minimumDurationMinutes: 30,
            paddingMinutes: 0,
            notBefore: testDate(2026, 10, 16, 11)
        )
        let slot = try #require(slots.first)
        #expect(slot.start == testDate(2026, 10, 16, 11))
        #expect(slot.end == testDate(2026, 10, 16, 18))
    }

    @Test("Preferred period ranks a matching gap before an earlier gap")
    func ranksPreferredPeriod() throws {
        let busy = [
            BusyInterval(start: testDate(2026, 10, 16, 10), end: testDate(2026, 10, 16, 12))
        ]
        let slots = FreeSlotFinder.find(
            within: window(8, 16),
            busyIntervals: busy,
            minimumDurationMinutes: 45,
            paddingMinutes: 0,
            preferredPeriod: .afternoon
        )
        let first = try #require(slots.first)
        #expect(first.start == testDate(2026, 10, 16, 12))
    }

    @Test("Concrete picker trims a long free gap and starts in the preferred period")
    func picksConcretePreferredSlot() throws {
        let gap = FreeSlot(
            start: testDate(2026, 10, 16, 8),
            end: testDate(2026, 10, 16, 20),
            confidence: .calendarDerived
        )
        let slot = try #require(
            FreeSlotFinder.bestFittingSlot(
                in: [gap],
                durationMinutes: 45,
                preferredPeriod: .afternoon
            )
        )
        #expect(slot.start == testDate(2026, 10, 16, 12))
        #expect(slot.end == testDate(2026, 10, 16, 12, 45))
    }

    @Test("Free minutes count only gaps at least fifteen minutes long")
    func totalFreeMinutes() {
        let busy = [
            BusyInterval(start: testDate(2026, 10, 16, 8, 10), end: testDate(2026, 10, 16, 9)),
            BusyInterval(start: testDate(2026, 10, 16, 9, 20), end: testDate(2026, 10, 16, 10))
        ]
        let total = FreeSlotFinder.totalFreeMinutes(
            within: window(8, 10),
            busyIntervals: busy,
            paddingMinutes: 0
        )
        #expect(total == 20)
    }

    @Test("Day window starts after waking and ends before bedtime")
    func dayWindow() throws {
        let result = try #require(
            AvailabilityWindow.dayWindow(
                wakeTime: testDate(2026, 10, 16, 6, 30),
                bedtime: testDate(2026, 10, 16, 23, 30)
            )
        )
        #expect(result.start == testDate(2026, 10, 16, 7, 30))
        #expect(result.end == testDate(2026, 10, 16, 21))
    }
}

private extension FreeSlotFinderTests {
    func window(_ startHour: Int, _ endHour: Int) -> DateRange {
        DateRange(
            start: testDate(2026, 10, 16, startHour),
            end: testDate(2026, 10, 16, endHour)
        )
    }
}
