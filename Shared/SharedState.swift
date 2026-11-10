import Foundation

/// State shared between the app, its widgets and its controls through an App Group.
enum AppGroup {
    static let id = "group.cc.voiceinvoice.app"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: id) ?? .standard
    }
}

/// What the widget shows. The app writes it whenever invoices change.
struct InvoiceSnapshot: Codable, Equatable {
    var currencyCode: String
    var day: Date
    var todayRevenue: Double
    var todayCount: Int
    var monthRevenue: Double
    var monthCount: Int
    /// Free invoices left this month, or nil when the user has Pro.
    var freeRemaining: Int?

    struct Input {
        var date: Date
        var total: Double
        var currency: String

        init(date: Date, total: Double, currency: String) {
            self.date = date
            self.total = total
            self.currency = currency
        }
    }

    static let empty = InvoiceSnapshot(
        currencyCode: "USD", day: .distantPast,
        todayRevenue: 0, todayCount: 0, monthRevenue: 0, monthCount: 0, freeRemaining: nil
    )

    static func compute(
        inputs: [Input],
        currencyCode: String,
        freeRemaining: Int?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> InvoiceSnapshot {
        var todayRevenue = 0.0
        var monthRevenue = 0.0
        var todayCount = 0
        var monthCount = 0
        for input in inputs {
            let isToday = calendar.isDate(input.date, inSameDayAs: now)
            let isMonth = calendar.isDate(input.date, equalTo: now, toGranularity: .month)
            if isToday { todayCount += 1 }
            if isMonth { monthCount += 1 }
            guard input.currency == currencyCode else { continue }
            if isToday { todayRevenue += input.total }
            if isMonth { monthRevenue += input.total }
        }
        return InvoiceSnapshot(
            currencyCode: currencyCode,
            day: calendar.startOfDay(for: now),
            todayRevenue: todayRevenue,
            todayCount: todayCount,
            monthRevenue: monthRevenue,
            monthCount: monthCount,
            freeRemaining: freeRemaining
        )
    }

    /// Today's numbers, or zeros if the snapshot is from an earlier day.
    func today(now: Date = Date(), calendar: Calendar = .current) -> (revenue: Double, count: Int) {
        calendar.isDate(day, inSameDayAs: now) ? (todayRevenue, todayCount) : (0, 0)
    }

    private static let key = "voiceinvoice.snapshot"

    static func load() -> InvoiceSnapshot? {
        guard let data = AppGroup.defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(InvoiceSnapshot.self, from: data)
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            AppGroup.defaults.set(data, forKey: Self.key)
        }
    }
}

/// A request from a widget, control or Siri for the app to do something once it opens.
enum PendingAction: String {
    case dictate

    private static let key = "voiceinvoice.pendingAction"

    static func set(_ action: PendingAction) {
        AppGroup.defaults.set(action.rawValue, forKey: key)
    }

    static func consume() -> PendingAction? {
        let defaults = AppGroup.defaults
        guard let raw = defaults.string(forKey: key), let action = PendingAction(rawValue: raw) else {
            return nil
        }
        defaults.removeObject(forKey: key)
        return action
    }
}
