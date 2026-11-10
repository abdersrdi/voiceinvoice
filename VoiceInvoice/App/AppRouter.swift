import Foundation
import Observation
import WidgetKit

enum AppTab: Hashable {
    case invoices
    case shop
}

/// Turns outside requests (widget tap, control, Siri) into app navigation.
@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .invoices
    var dictationRequested = false

    func requestDictation() {
        selectedTab = .invoices
        dictationRequested = true
    }

    func checkPending() {
        if PendingAction.consume() == .dictate {
            requestDictation()
        }
    }

    func handle(url: URL) {
        if url.scheme == "voiceinvoice", url.host == "dictate" {
            requestDictation()
        }
    }
}

enum SnapshotWriter {
    /// Saves what the widget shows and asks WidgetKit to refresh.
    @MainActor
    static func update(invoices: [Invoice], store: StoreProfile?, isPro: Bool) {
        let code = store?.currencyCode ?? "USD"
        let inputs = invoices
            .filter { !$0.number.isEmpty }
            .map { InvoiceSnapshot.Input(date: $0.issueDate, total: $0.total, currency: $0.currencyCode) }
        let remaining: Int? = isPro ? nil : store.map { UsagePolicy.remaining(in: $0) }
        let snapshot = InvoiceSnapshot.compute(inputs: inputs, currencyCode: code, freeRemaining: remaining)
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
