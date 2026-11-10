import SwiftUI
import SwiftData

@main
struct VoiceInvoiceApp: App {
    private let container = Persistence.makeContainer()
    @State private var subscriptions = SubscriptionStore()
    @State private var router = AppRouter()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.accent)
                .environment(subscriptions)
                .environment(router)
                .onOpenURL { router.handle(url: $0) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { router.checkPending() }
                }
                .task { router.checkPending() }
        }
        .modelContainer(container)
    }
}
