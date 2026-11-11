import SwiftUI
import StoreKit

enum AppLinks {
    static let terms = URL(string: "https://talkstamp.abdersrdi-950.workers.dev/terms")!
    static let privacy = URL(string: "https://talkstamp.abdersrdi-950.workers.dev/privacy")!
}

/// One-time purchase: pay once, Pro stays unlocked. No subscription, nothing renews.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionStore.self) private var store

    /// True when the sheet opened because the free limit was reached.
    var limitReached = false

    private var product: Product? { store.product(id: SubscriptionStore.proID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    hero
                    benefits
                    priceCard
                    purchaseButton
                    footer
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                if store.products.isEmpty { await store.loadProducts() }
            }
            .onChange(of: store.isPro) { _, isPro in
                if isPro { dismiss() }
            }
        }
    }

    // MARK: Pieces

    private var hero: some View {
        HeroCard {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.glacier)
                Text("Talkstamp Pro")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text(limitReached
                     ? String(localized: "You've used your \(UsagePolicy.freeMonthlyLimit) free invoices this month.")
                     : String(localized: "Unlimited invoices, every month."))
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefit("Pay once, keep it forever. No subscription")
            benefit("Unlimited invoices every month")
            benefit("Everything you already made stays free to view, export and share")
            benefit("Syncs across your devices through your own iCloud")
        }
        .cardStyle()
    }

    private func benefit(_ text: LocalizedStringKey) -> some View {
        Label {
            Text(text).font(.system(.subheadline, design: .rounded))
        } icon: {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
        }
    }

    @ViewBuilder
    private var priceCard: some View {
        if let product {
            priceRow(price: product.displayPrice)
        } else if DemoMode.isActive {
            priceRow(price: "$19.99")
        } else {
            VStack(spacing: 10) {
                if store.isLoadingProducts {
                    ProgressView()
                } else {
                    Text(store.errorMessage ?? String(localized: "Prices are not available right now."))
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.center)
                    Button("Try again") { Task { await store.loadProducts() } }
                }
            }
            .frame(maxWidth: .infinity)
            .cardStyle()
        }
    }

    private func priceRow(price: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Talkstamp Pro")
                    .font(.system(.headline, design: .rounded))
                Text("One-time purchase")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            Spacer()
            Text(verbatim: price)
                .font(Theme.amount(24, weight: .bold))
        }
        .cardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.accent, lineWidth: 2)
        )
    }

    private var purchaseButton: some View {
        VStack(spacing: 8) {
            Button {
                guard let product else { return }
                Task { await store.purchase(product) }
            } label: {
                if store.purchaseInFlight {
                    ProgressView().tint(.white)
                } else {
                    Text("Unlock Pro")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(product == nil || store.purchaseInFlight)
            .opacity(product == nil ? 0.5 : 1)

            if let message = store.errorMessage, product != nil {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button("Restore purchases") {
                Task { await store.restore() }
            }
            .font(.footnote.weight(.semibold))

            Text("Payment is charged to your Apple ID at confirmation of purchase. This is a one-time purchase: there is no subscription and nothing renews. You can restore it on any device signed in with the same Apple ID.")
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Terms of Use", destination: AppLinks.terms)
                Link("Privacy Policy", destination: AppLinks.privacy)
            }
            .font(.caption2)
        }
    }
}
