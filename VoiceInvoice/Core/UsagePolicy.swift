import Foundation

/// Freemium rule: 5 invoices created per calendar month without a subscription.
/// Only creating invoices is limited. Viewing, exporting and re-sharing are always free.
enum UsagePolicy {
    static let freeMonthlyLimit = 5

    static func monthKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    static func used(in store: StoreProfile, now: Date = Date(), calendar: Calendar = .current) -> Int {
        store.usageMonth == monthKey(now, calendar: calendar) ? store.usageCount : 0
    }

    static func remaining(in store: StoreProfile, now: Date = Date(), calendar: Calendar = .current) -> Int {
        max(0, freeMonthlyLimit - used(in: store, now: now, calendar: calendar))
    }

    static func canCreate(store: StoreProfile?, isPro: Bool, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        if isPro { return true }
        guard let store else { return false }
        return remaining(in: store, now: now, calendar: calendar) > 0
    }

    /// Call once when a new invoice is finalized.
    static func register(in store: StoreProfile, now: Date = Date(), calendar: Calendar = .current) {
        let key = monthKey(now, calendar: calendar)
        if store.usageMonth != key {
            store.usageMonth = key
            store.usageCount = 0
        }
        store.usageCount += 1
    }
}
