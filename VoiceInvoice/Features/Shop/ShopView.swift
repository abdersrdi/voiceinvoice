import SwiftUI
import SwiftData
import PhotosUI
import VisionKit

struct ShopView: View {
    @Query private var stores: [StoreProfile]

    var body: some View {
        NavigationStack {
            if let store = stores.first {
                ShopForm(store: store)
            } else {
                ProgressView()
            }
        }
    }
}

private struct ShopForm: View {
    @Bindable var store: StoreProfile
    @Environment(SubscriptionStore.self) private var subscriptions
    @State private var showingSignature = false
    @State private var showPaywall = false
    @State private var showManage = false
    @State private var showScanner = false
    @State private var showStampPhotos = false
    @State private var stampPhotoItem: PhotosPickerItem?
    @State private var pendingStampImage: UIImage?
    @State private var stampSource: StampSource?

    var body: some View {
        Form {
            Section("Subscription") {
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        Label(subscriptions.isPro ? "VoiceInvoice Pro" : "Free plan", systemImage: "crown.fill")
                        Spacer()
                        Text(subscriptions.isPro
                             ? String(localized: "Active")
                             : "\(UsagePolicy.remaining(in: store)) of \(UsagePolicy.freeMonthlyLimit) left")
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                if subscriptions.isPro {
                    Button("Manage subscription") { showManage = true }
                }
            }

            Section("Shop") {
                TextField("Shop name", text: $store.name)
                TextField("Address", text: $store.address, axis: .vertical)
                    .lineLimit(1...3)
                TextField("Tax ID", text: $store.taxID)
                TextField("Phone", text: $store.phone)
                    .keyboardType(.phonePad)
                TextField("Email", text: $store.email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Invoicing") {
                CurrencyPicker(code: $store.currencyCode)
                HStack {
                    Text("Default tax (%)")
                    Spacer()
                    TextField("0", value: $store.defaultTaxRate, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                }
                HStack {
                    Text("Number prefix")
                    Spacer()
                    TextField("INV", text: $store.invoicePrefix)
                        .textInputAutocapitalization(.characters)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                }
                TextField("Footer note", text: $store.footerNote, axis: .vertical)
                    .lineLimit(1...3)
            }

            Section("Branding") {
                BrandAssetRow(title: "Logo", systemImage: "photo", data: $store.logoData)
                stampRow
                signatureRow
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Shop")
        .manageSubscriptionsSheet(isPresented: $showManage)
        .fullScreenCover(isPresented: $showScanner, onDismiss: presentPendingStamp) {
            DocumentScanner { image in
                pendingStampImage = image
                showScanner = false
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showStampPhotos, selection: $stampPhotoItem, matching: .images)
        .onChange(of: stampPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    stampSource = StampSource(image: image)
                }
                stampPhotoItem = nil
            }
        }
        .sheet(item: $stampSource) { source in
            StampEditorView(source: source) { png in
                store.stampData = png
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showingSignature) {
            SignatureSheet { png in
                store.signatureData = png
            }
        }
    }

    private func presentPendingStamp() {
        if let image = pendingStampImage {
            stampSource = StampSource(image: image)
            pendingStampImage = nil
        }
    }

    private var stampRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "seal")
                .frame(width: 28)
                .foregroundStyle(Theme.accent)
            Text("Company stamp")
            Spacer()
            if let data = store.stampData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 32)
                    .padding(4)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                Button(role: .destructive) {
                    store.stampData = nil
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            Menu(store.stampData == nil ? "Add" : "Replace") {
                if VNDocumentCameraViewController.isSupported {
                    Button {
                        showScanner = true
                    } label: {
                        Label("Scan with camera", systemImage: "camera.viewfinder")
                    }
                }
                Button {
                    showStampPhotos = true
                } label: {
                    Label("Choose photo", systemImage: "photo")
                }
            }
        }
    }

    private var signatureRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "signature")
                .frame(width: 28)
                .foregroundStyle(Theme.accent)
            Text("Signature")
            Spacer()
            if let data = store.signatureData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 32)
                    .padding(4)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                Button(role: .destructive) {
                    store.signatureData = nil
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            Button(store.signatureData == nil ? "Sign" : "Redo") {
                showingSignature = true
            }
            .buttonStyle(.borderless)
        }
    }
}

struct BrandAssetRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    @Binding var data: Data?

    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 28)
                .foregroundStyle(Theme.accent)
            Text(title)
            Spacer()
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 32)
                    .padding(4)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                Button(role: .destructive) {
                    self.data = nil
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Text(data == nil ? "Choose" : "Replace")
            }
            .buttonStyle(.borderless)
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let raw = try? await item.loadTransferable(type: Data.self),
                   let png = ImageTools.normalizedPNG(from: raw) {
                    data = png
                }
                pickerItem = nil
            }
        }
    }
}

enum ImageTools {
    /// Downscales to a sensible size and re-encodes as PNG (keeps transparency).
    static func normalizedPNG(from data: Data, maxDimension: CGFloat = 1200) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxDimension / longest)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.pngData { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
