import XCTest
@testable import VoiceInvoice

final class UsagePolicyTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    func testMonthKey() {
        XCTAssertEqual(UsagePolicy.monthKey(date(2026, 11, 10), calendar: calendar), "2026-11")
        XCTAssertEqual(UsagePolicy.monthKey(date(2027, 1, 1), calendar: calendar), "2027-01")
    }

    func testFreeUserCanCreateFiveThenIsBlocked() {
        let store = StoreProfile()
        let now = date(2026, 11, 10)
        for i in 0..<5 {
            XCTAssertTrue(UsagePolicy.canCreate(store: store, isPro: false, now: now, calendar: calendar), "invoice \(i + 1)")
            UsagePolicy.register(in: store, now: now, calendar: calendar)
        }
        XCTAssertEqual(UsagePolicy.remaining(in: store, now: now, calendar: calendar), 0)
        XCTAssertFalse(UsagePolicy.canCreate(store: store, isPro: false, now: now, calendar: calendar))
    }

    func testProIsNeverBlocked() {
        let store = StoreProfile()
        let now = date(2026, 11, 10)
        for _ in 0..<20 { UsagePolicy.register(in: store, now: now, calendar: calendar) }
        XCTAssertTrue(UsagePolicy.canCreate(store: store, isPro: true, now: now, calendar: calendar))
    }

    func testCounterResetsInNewMonth() {
        let store = StoreProfile()
        for _ in 0..<5 { UsagePolicy.register(in: store, now: date(2026, 11, 10), calendar: calendar) }
        let december = date(2026, 12, 1)
        XCTAssertEqual(UsagePolicy.used(in: store, now: december, calendar: calendar), 0)
        XCTAssertTrue(UsagePolicy.canCreate(store: store, isPro: false, now: december, calendar: calendar))
        UsagePolicy.register(in: store, now: december, calendar: calendar)
        XCTAssertEqual(store.usageCount, 1)
        XCTAssertEqual(store.usageMonth, "2026-12")
    }

    func testMissingStoreBlocksFreeUsers() {
        XCTAssertFalse(UsagePolicy.canCreate(store: nil, isPro: false))
        XCTAssertTrue(UsagePolicy.canCreate(store: nil, isPro: true))
    }
}
