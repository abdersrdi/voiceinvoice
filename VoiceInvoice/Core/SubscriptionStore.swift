import Foundation
import StoreKit
import Observation

/// StoreKit 2 subscriptions: Pro monthly and yearly in one group.
/// Prices and the free-trial offer come from App Store Connect, so they can change without an app update.
@MainActor
@Observable
final class SubscriptionStore {
    static let monthlyID = "cc.voiceinvoice.app.pro.monthly"
    static let yearlyID = "cc.voiceinvoice.app.pro.yearly"
    static let productIDs = [yearlyID, monthlyID]

    var products: [Product] = []
    var isPro = false
    var isLoadingProducts = false
    var purchaseInFlight = false
    var errorMessage: String?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task { [weak self] in
            await self?.loadProducts()
            await self?.refreshEntitlements()
        }
    }

    func product(id: String) -> Product? {
        products.first { $0.id == id }
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: Self.productIDs)
            products = loaded.sorted { $0.price > $1.price }
            errorMessage = nil
        } catch {
            products = []
            errorMessage = String(localized: "Prices could not be loaded. Check your connection and try again.")
        }
    }

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               Self.productIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                active = true
            }
        }
        isPro = active
    }

    func purchase(_ product: Product) async {
        purchaseInFlight = true
        errorMessage = nil
        defer { purchaseInFlight = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                } else {
                    errorMessage = String(localized: "The purchase could not be verified.")
                }
            case .pending:
                errorMessage = String(localized: "The purchase is waiting for approval.")
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        errorMessage = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isPro {
                errorMessage = String(localized: "No active subscription was found for this Apple ID.")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        if case .verified(let transaction) = result {
            await transaction.finish()
            await refreshEntitlements()
        }
    }
}
