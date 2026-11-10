import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context

    @State private var shopName = ""
    @State private var currencyCode = Locale.current.currency?.identifier ?? "USD"
    @State private var taxRate: Double = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HeroCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "waveform.and.mic")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(Theme.glacier)
                        Text("VoiceInvoice")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Speak your sale. Send a finished invoice.")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Set up your shop")
                        .font(.system(.title3, design: .rounded, weight: .semibold))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Shop name").font(.caption).foregroundStyle(Theme.secondaryText)
                        TextField("e.g. Maison Dupont", text: $shopName)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Currency").font(.caption).foregroundStyle(Theme.secondaryText)
                        CurrencyPicker(code: $currencyCode)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Default tax rate (%)").font(.caption).foregroundStyle(Theme.secondaryText)
                        TextField("0", value: $taxRate, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .cardStyle()

                Button("Get started") { createShop() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(shopName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(shopName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)

                Text("Your invoices stay on your devices and sync through your own iCloud.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
    }

    private func createShop() {
        let store = StoreProfile()
        store.name = shopName.trimmingCharacters(in: .whitespaces)
        store.currencyCode = currencyCode
        store.defaultTaxRate = taxRate
        context.insert(store)
        try? context.save()
        Haptics.success()
    }
}

struct CurrencyPicker: View {
    @Binding var code: String

    private static let codes: [String] = Locale.Currency.isoCurrencies
        .map(\.identifier)
        .sorted()

    var body: some View {
        Picker("Currency", selection: $code) {
            ForEach(Self.codes, id: \.self) { value in
                Text("\(value) · \(Locale.current.localizedString(forCurrencyCode: value) ?? value)")
                    .tag(value)
            }
        }
        .pickerStyle(.navigationLink)
    }
}
