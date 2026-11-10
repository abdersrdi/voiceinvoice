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
    var body: some View {
        TabView {
            InvoiceListView()
                .tabItem { Label("Invoices", systemImage: "doc.text.fill") }

            ShopView()
                .tabItem { Label("Shop", systemImage: "storefront.fill") }
        }
    }
}
