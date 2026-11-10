import SwiftUI
import StoreKit

enum AppLinks {
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacy = URL(string: "https://github.com/abdersrdi/voiceinvoice/blob/main/PRIVACY.md")!
}

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionStore.self) private var subscriptions

    /// True when the sheet opened because the free limit was reached.
    var limitReached = false

    @State private var selectedID = SubscriptionStore.yearlyID

    private var selected: Product? { subscriptions.product(id: selectedID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    hero
                    benefits
                    plans
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
                if subscriptions.products.isEmpty { await subscriptions.loadProducts() }
            }
            .onChange(of: subscriptions.isPro) { _, isPro in
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
                Text("VoiceInvoice Pro")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text(limitReached
                     ? "You've used your \(UsagePolicy.freeMonthlyLimit) free invoices this month."
                     : "Unlimited invoices, every month.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
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
    private var plans: some View {
        if subscriptions.products.isEmpty {
            VStack(spacing: 10) {
                if subscriptions.isLoadingProducts {
                    ProgressView()
                } else {
                    Text(subscriptions.errorMessage ?? String(localized: "Prices are not available right now."))
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.center)
                    Button("Try again") { Task { await subscriptions.loadProducts() } }
                }
            }
            .frame(maxWidth: .infinity)
            .cardStyle()
        } else {
            VStack(spacing: 12) {
                ForEach(subscriptions.products, id: \.id) { product in
                    planCard(product)
                }
            }
        }
    }

    private func planCard(_ product: Product) -> some View {
        let isSelected = product.id == selectedID
        let isYearly = product.id == SubscriptionStore.yearlyID
        return Button {
            Haptics.tap()
            selectedID = product.id
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(isYearly ? "Yearly" : "Monthly")
                            .font(.system(.headline, design: .rounded))
                        if isYearly, let percent = savingsPercent {
                            Text("Save \(percent)%")
                                .font(.system(.caption2, design: .rounded, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.burgundy, in: Capsule())
                        }
                    }
                    if isYearly {
                        Text("\((product.price / 12).formatted(product.priceFormatStyle)) / month")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    if let trial = trialText(product) {
                        Text(trial)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(Theme.amount(20, weight: .bold))
                    Text(isYearly ? "per year" : "per month")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .foregroundStyle(.primary)
            .cardStyle()
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var purchaseButton: some View {
        VStack(spacing: 8) {
            Button {
                guard let product = selected else { return }
                Task { await subscriptions.purchase(product) }
            } label: {
                if subscriptions.purchaseInFlight {
                    ProgressView().tint(.white)
                } else if let product = selected, trialText(product) != nil {
                    Text("Start free trial")
                } else {
                    Text("Subscribe")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(selected == nil || subscriptions.purchaseInFlight)
            .opacity(selected == nil ? 0.5 : 1)

            if let message = subscriptions.errorMessage, !subscriptions.products.isEmpty {
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
                Task { await subscriptions.restore() }
            }
            .font(.footnote.weight(.semibold))

            Text("Payment is charged to your Apple ID at confirmation of purchase. The subscription renews automatically unless it is canceled at least 24 hours before the end of the current period. You can manage or cancel it in your Apple ID settings. Any free trial converts to a paid subscription unless canceled before it ends.")
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

    // MARK: Helpers

    private var savingsPercent: Int? {
        guard let yearly = subscriptions.product(id: SubscriptionStore.yearlyID),
              let monthly = subscriptions.product(id: SubscriptionStore.monthlyID) else { return nil }
        let full = monthly.price * 12
        guard full > 0 else { return nil }
        let saved = (full - yearly.price) / full * 100
        let percent = NSDecimalNumber(decimal: saved).intValue
        return percent > 0 ? percent : nil
    }

    private func trialText(_ product: Product) -> String? {
        guard let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let n = offer.period.value
        switch offer.period.unit {
        case .day: return String(localized: "\(n)-day free trial")
        case .week: return String(localized: "\(n)-week free trial")
        case .month: return String(localized: "\(n)-month free trial")
        case .year: return String(localized: "\(n)-year free trial")
        @unknown default: return nil
        }
    }
}
