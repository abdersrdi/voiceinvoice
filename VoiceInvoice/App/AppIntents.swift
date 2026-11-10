import AppIntents
import Foundation

/// Reads today's total aloud without opening the app.
struct TodayTotalIntent: AppIntent {
    static var title: LocalizedStringResource = "Today's total"
    static var description = IntentDescription("Hear how much you invoiced today.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let snapshot = InvoiceSnapshot.load() ?? .empty
        let today = snapshot.today()
        let amount = today.revenue.formatted(.currency(code: snapshot.currencyCode))
        let text: String
        if today.count == 0 {
            text = String(localized: "No invoices yet today.")
        } else {
            text = String(localized: "Today you invoiced \(amount) across \(today.count) invoices.")
        }
        return .result(dialog: IntentDialog(LocalizedStringResource(stringLiteral: text)))
    }
}

struct VoiceInvoiceShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartDictationIntent(),
            phrases: [
                "New invoice in \(.applicationName)",
                "Create an invoice in \(.applicationName)",
                "Start an invoice with \(.applicationName)"
            ],
            shortTitle: "New invoice",
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: TodayTotalIntent(),
            phrases: [
                "Show my total today in \(.applicationName)",
                "How much did I invoice today in \(.applicationName)"
            ],
            shortTitle: "Today's total",
            systemImageName: "banknote"
        )
    }
}
