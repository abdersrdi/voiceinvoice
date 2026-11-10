import XCTest
@testable import VoiceInvoice

final class SharedStateTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    func testSnapshotTotalsForTodayAndMonth() {
        let now = date(2026, 11, 10)
        let inputs = [
            InvoiceSnapshot.Input(date: date(2026, 11, 10, 9), total: 100, currency: "USD"),
            InvoiceSnapshot.Input(date: date(2026, 11, 10, 15), total: 50, currency: "USD"),
            InvoiceSnapshot.Input(date: date(2026, 11, 2), total: 400, currency: "USD"),
            InvoiceSnapshot.Input(date: date(2026, 10, 30), total: 999, currency: "USD"),
            InvoiceSnapshot.Input(date: date(2026, 11, 10), total: 70, currency: "EUR")
        ]
        let snapshot = InvoiceSnapshot.compute(
            inputs: inputs, currencyCode: "USD", freeRemaining: 3, now: now, calendar: calendar
        )
        XCTAssertEqual(snapshot.todayRevenue, 150, accuracy: 0.001)
        XCTAssertEqual(snapshot.todayCount, 3)          // counts every currency
        XCTAssertEqual(snapshot.monthRevenue, 550, accuracy: 0.001)
        XCTAssertEqual(snapshot.monthCount, 4)
        XCTAssertEqual(snapshot.freeRemaining, 3)
    }

    func testStaleSnapshotShowsZeroToday() {
        let snapshot = InvoiceSnapshot.compute(
            inputs: [InvoiceSnapshot.Input(date: date(2026, 11, 10), total: 100, currency: "USD")],
            currencyCode: "USD", freeRemaining: nil, now: date(2026, 11, 10), calendar: calendar
        )
        let sameDay = snapshot.today(now: date(2026, 11, 10, 20), calendar: calendar)
        XCTAssertEqual(sameDay.revenue, 100, accuracy: 0.001)
        let nextDay = snapshot.today(now: date(2026, 11, 11), calendar: calendar)
        XCTAssertEqual(nextDay.revenue, 0)
        XCTAssertEqual(nextDay.count, 0)
    }

    func testSnapshotRoundTripsThroughSharedDefaults() {
        let original = InvoiceSnapshot(
            currencyCode: "EUR", day: date(2026, 11, 10),
            todayRevenue: 12.5, todayCount: 2, monthRevenue: 99, monthCount: 7, freeRemaining: nil
        )
        original.save()
        XCTAssertEqual(InvoiceSnapshot.load(), original)
    }

    func testPendingActionIsConsumedOnce() {
        _ = PendingAction.consume()
        PendingAction.set(.dictate)
        XCTAssertEqual(PendingAction.consume(), .dictate)
        XCTAssertNil(PendingAction.consume())
    }

    @MainActor
    func testRouterHandlesDictateURL() {
        let router = AppRouter()
        router.selectedTab = .shop
        router.handle(url: URL(string: "voiceinvoice://dictate")!)
        XCTAssertTrue(router.dictationRequested)
        XCTAssertEqual(router.selectedTab, .invoices)

        let other = AppRouter()
        other.handle(url: URL(string: "https://example.com")!)
        XCTAssertFalse(other.dictationRequested)
    }
}
