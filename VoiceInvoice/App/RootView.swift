import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var stores: [StoreProfile]
    @State private var waitedForCloud = false

    /// Signed in to iCloud: a shop created on another device may still be on its way.
    private var mayHaveCloudData: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    var body: some View {
        Group {
            if stores.isEmpty && mayHaveCloudData && !waitedForCloud {
                CloudCheckView()
                    .task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        waitedForCloud = true
                    }
                    .transition(.opacity)
            } else if stores.isEmpty {
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

struct CloudCheckView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Looking for your shop in iCloud…")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
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
