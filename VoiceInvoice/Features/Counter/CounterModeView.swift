import SwiftUI
import SwiftData
import Observation

/// Runs counter mode: the app listens for the wake phrase ("New invoice"), captures what is said
/// until a pause, and offers the result. Foreground only: the screen stays on while it is open.
@MainActor
@Observable
final class CounterModeController {
    enum Phase: Equatable {
        case waiting
        case capturing
        case review
    }

    var phase: Phase = .waiting
    var capturedText = ""
    var items: [ParsedItem] = []
    var speakerName = ""
    var language: ParserLanguage
    let speech = SpeechService()

    @ObservationIgnored private var endpoint = EndpointDetector(now: Date())
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var profiles: [VoiceProfile] = []
    @ObservationIgnored private var names: [String: String] = [:]
    @ObservationIgnored private var starting = false

    init(language: ParserLanguage) {
        self.language = language
    }

    func begin(employees: [Employee]) {
        profiles = VoiceprintStore.profiles(for: employees)
        names = employees.reduce(into: [String: String]()) { $0[$1.uid] = $1.name }
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000)
                self?.tick()
            }
        }
    }

    func end() {
        loop?.cancel()
        loop = nil
        speech.cancel()
    }

    func setLanguage(_ newValue: ParserLanguage) {
        language = newValue
        resetToWaiting()
    }

    func resetToWaiting() {
        speech.cancel()
        phase = .waiting
        capturedText = ""
        items = []
        speakerName = ""
    }

    private func tick() {
        switch phase {
        case .waiting:
            if speech.state == .idle {
                guard !starting else { return }
                starting = true
                let locale = language.localeIdentifier
                Task {
                    await speech.start(localeIdentifier: locale)
                    starting = false
                }
                return
            }
            guard speech.isListening else { return }
            if let rest = WakePhrase.detect(in: speech.transcript, language: language) {
                phase = .capturing
                capturedText = rest
                endpoint = EndpointDetector(now: Date())
                _ = endpoint.update(text: rest, now: Date())
                Haptics.tap()
            } else if speech.transcript.count > 300 {
                speech.cancel() // keep the rolling transcript short; listening restarts on the next tick
            }
        case .capturing:
            if let rest = WakePhrase.detect(in: speech.transcript, language: language) {
                capturedText = rest
            }
            let recognizerStopped = speech.state == .idle
            switch endpoint.update(text: capturedText, now: Date()) {
            case .finish:
                finish()
            case .giveUp:
                resetToWaiting()
            case .keepListening:
                if recognizerStopped {
                    if capturedText.isEmpty { resetToWaiting() } else { finish() }
                }
            }
        case .review:
            break
        }
    }

    private func finish() {
        let text = capturedText
        let clip = speech.sampleBuffer.snapshot()
        speech.cancel()
        let parsed = LineItemParser.parse(text, language: language)
        guard !parsed.isEmpty else {
            resetToWaiting()
            return
        }
        items = parsed
        phase = .review
        Haptics.success()

        let profiles = self.profiles
        let names = self.names
        Task {
            let match = await Task.detached(priority: .userInitiated) { () -> SpeakerMatch? in
                guard !profiles.isEmpty, clip.sampleRate > 0 else { return nil }
                let tail = Array(clip.samples.suffix(Int(clip.sampleRate * 10)))
                guard let embedding = SpeakerEmbedding.make(samples: tail, sampleRate: clip.sampleRate) else {
                    return nil
                }
                return SpeakerMatcher.identify(embedding, profiles: profiles)
            }.value
            if let match, phase == .review {
                speakerName = names[match.id] ?? ""
            }
        }
    }
}

struct CounterModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Employee.createdAt) private var employees: [Employee]

    let currencyCode: String
    let onFinish: ([ParsedItem], String) -> Void

    @AppStorage("dictationLanguage") private var languageRaw = ParserLanguage.preferred().rawValue
    @State private var controller = CounterModeController(language: ParserLanguage.preferred())

    private var language: ParserLanguage { ParserLanguage(rawValue: languageRaw) ?? .en }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.burgundyLight, Theme.burgundy, Theme.burgundyDeep],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                topBar
                Spacer(minLength: 0)
                content
                Spacer(minLength: 0)
                Text("The microphone stays on while this screen is open.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(20)
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            controller.language = language
            controller.begin(employees: employees)
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            controller.end()
        }
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .accessibilityLabel("Close")
            Spacer()
            Menu {
                ForEach(ParserLanguage.allCases) { option in
                    Button(option.displayName) {
                        languageRaw = option.rawValue
                        controller.setLanguage(option)
                    }
                }
            } label: {
                Label(language.displayName, systemImage: "globe")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.16), in: Capsule())
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch controller.phase {
        case .waiting:
            waitingView
        case .capturing:
            capturingView
        case .review:
            reviewView
        }
    }

    private var micCircle: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 150, height: 150)
                .scaleEffect(1 + CGFloat(controller.speech.level) * 0.6)
                .animation(.easeOut(duration: 0.12), value: controller.speech.level)
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 110, height: 110)
            Image(systemName: "mic.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(height: 170)
    }

    private var waitingView: some View {
        VStack(spacing: 18) {
            micCircle
            Text("Counter mode")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.glacier)
            Text(verbatim: "“\(WakePhrase.display(for: language))”")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("Say this to start an invoice")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
            statusNotice
        }
    }

    @ViewBuilder
    private var statusNotice: some View {
        if case .denied(let message) = controller.speech.state {
            Text(message).font(.footnote).foregroundStyle(.orange).multilineTextAlignment(.center)
        } else if case .failed(let message) = controller.speech.state {
            Text(message).font(.footnote).foregroundStyle(.orange).multilineTextAlignment(.center)
        }
    }

    private var capturingView: some View {
        VStack(spacing: 16) {
            micCircle
            Text("Listening…")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Theme.glacier)
            Text(controller.capturedText.isEmpty ? " " : controller.capturedText)
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var reviewView: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                if !controller.speakerName.isEmpty {
                    Label(controller.speakerName, systemImage: "waveform.circle.fill")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                ForEach(controller.items) { item in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name.isEmpty ? String(localized: "Item") : item.name)
                                .font(.system(.body, design: .rounded, weight: .medium))
                            if item.needsReview {
                                Label("Check the price", systemImage: "exclamationmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            } else {
                                Text("\(item.quantity.formatted()) × \(Money.string(item.unitPrice, currencyCode: currencyCode))")
                                    .font(.caption)
                                    .foregroundStyle(Theme.secondaryText)
                            }
                        }
                        Spacer()
                        Text(Money.string(
                            InvoiceMath.lineAmount(quantity: item.quantity, unitPrice: item.unitPrice, currencyCode: currencyCode),
                            currencyCode: currencyCode
                        ))
                        .font(Theme.amount(16))
                    }
                }
            }
            .cardStyle()

            Button("Open invoice") {
                onFinish(controller.items, controller.speakerName)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())

            Button("Discard") {
                controller.resetToWaiting()
            }
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(.white.opacity(0.9))
        }
    }
}
