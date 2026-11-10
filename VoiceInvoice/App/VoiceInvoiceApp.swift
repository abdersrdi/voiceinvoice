import SwiftUI
import SwiftData

@main
struct VoiceInvoiceApp: App {
    private let container = Persistence.makeContainer()
    @State private var subscriptions = SubscriptionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.accent)
                .environment(subscriptions)
        }
        .modelContainer(container)
    }
}
