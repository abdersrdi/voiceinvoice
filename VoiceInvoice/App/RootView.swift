import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var stores: [StoreProfile]

    var body: some View {
        Group {
            if stores.isEmpty {
                OnboardingView()
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: stores.isEmpty)
    }
}

struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            InvoiceListView()
                .tabItem { Label("Invoices", systemImage: "doc.text.fill") }
                .tag(AppTab.invoices)

            ShopView()
                .tabItem { Label("Shop", systemImage: "storefront.fill") }
                .tag(AppTab.shop)
        }
    }
}
