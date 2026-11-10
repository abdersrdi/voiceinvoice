import SwiftUI
import SwiftData

struct DictationView: View {
    @Environment(\.dismiss) private var dismiss

    let currencyCode: String
    let onFinish: ([ParsedItem], String) -> Void

    @Query(sort: \Employee.createdAt) private var employees: [Employee]

    @State private var speech = SpeechService()
    @State private var speakerUID: String?
    @State private var speakerUnrecognized = false
    @AppStorage("dictationLanguage") private var languageRaw = ParserLanguage.preferred().rawValue

    private var language: ParserLanguage { ParserLanguage(rawValue: languageRaw) ?? .en }
    private var items: [ParsedItem] { LineItemParser.parse(speech.transcript, language: language) }
    private var speaker: Employee? { employees.first { $0.uid == speakerUID } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        languageAndPrivacy
                        speakerChip
                        transcriptCard
                        itemsCard
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)

                controls
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Dictate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        speech.stop()
                        dismiss()
                    }
                }
            }
            .onDisappear { speech.stop() }
            .task(id: speech.isListening) { await identifySpeaker() }
        }
    }

    // MARK: Pieces

    private var languageAndPrivacy: some View {
        HStack {
            Menu {
                ForEach(ParserLanguage.allCases) { option in
                    Button {
                        speech.stop()
                        languageRaw = option.rawValue
                    } label: {
                        if option == language {
                            Label(option.displayName, systemImage: "checkmark")
                        } else {
                            Text(option.displayName)
                        }
                    }
                }
            } label: {
                Label(language.displayName, systemImage: "globe")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.card, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.separator, lineWidth: 0.5))
            }
            Spacer()
            if speech.isListening {
                Label(
                    speech.isOnDevice ? String(localized: "On-device") : String(localized: "Apple servers"),
                    systemImage: speech.isOnDevice ? "lock.fill" : "icloud.fill"
                )
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    // MARK: Speaker

    @ViewBuilder
    private var speakerChip: some View {
        if !employees.isEmpty {
            HStack {
                Menu {
                    ForEach(employees) { employee in
                        Button {
                            speakerUID = employee.uid
                            speakerUnrecognized = false
                        } label: {
                            Text(employee.name.isEmpty ? String(localized: "Unnamed") : employee.name)
                        }
                    }
                    Button("Nobody listed") {
                        speakerUID = nil
                        speakerUnrecognized = false
                    }
                } label: {
                    Label(
                        speaker?.name ?? (speakerUnrecognized ? String(localized: "Who's speaking?") : String(localized: "Speaker")),
                        systemImage: speaker != nil ? "waveform.circle.fill" : "person.crop.circle.badge.questionmark"
                    )
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.card, in: Capsule())
                    .overlay(Capsule().strokeBorder(speakerUnrecognized ? Color.orange : Theme.separator, lineWidth: speakerUnrecognized ? 1.5 : 0.5))
                }
                Spacer()
            }
        }
    }

    /// Listens to the first seconds of speech and matches them against enrolled voices.
    /// If nobody matches confidently the user picks from the chip instead.
    private func identifySpeaker() async {
        guard speech.isListening else { return }
        let profiles = VoiceprintStore.profiles(for: employees)
        guard !profiles.isEmpty else { return }
        speakerUnrecognized = false

        while speech.isListening, !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard speech.isListening, !Task.isCancelled else { return }
            let duration = speech.sampleBuffer.duration
            guard duration >= 3 else { continue }

            let clip = speech.sampleBuffer.snapshot()
            let match = await Task.detached(priority: .userInitiated) { () -> SpeakerMatch? in
                guard let embedding = SpeakerEmbedding.make(samples: clip.samples, sampleRate: clip.sampleRate) else {
                    return nil
                }
                return SpeakerMatcher.identify(embedding, profiles: profiles)
            }.value

            if let match {
                speakerUID = match.id
                speakerUnrecognized = false
                Haptics.tap()
                return
            }
            if duration >= 6 {
                if speaker == nil { speakerUnrecognized = true }
                return
            }
        }
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What I heard")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)

            if speech.isListening {
                Text(speech.transcript.isEmpty ? String(localized: "Listening…") : speech.transcript)
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(speech.transcript.isEmpty ? Theme.secondaryText : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField("Tap the mic, or type here", text: $speech.transcript, axis: .vertical)
                    .font(.system(.title3, design: .rounded))
                    .lineLimit(2...8)
            }

            if case .denied(let message) = speech.state {
                notice(message, systemImage: "mic.slash.fill")
            } else if case .failed(let message) = speech.state {
                notice(message, systemImage: "exclamationmark.triangle.fill")
            }
        }
        .cardStyle()
    }

    private func notice(_ message: String, systemImage: String) -> some View {
        Label(message, systemImage: systemImage)
            .font(.footnote)
            .foregroundStyle(.orange)
    }

    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Items")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)

            if items.isEmpty {
                Text("Say something like: “Two shirts at 20 each and a pair of pants for 40.”")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                ForEach(items) { item in
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
                    if item.id != items.last?.id { Divider() }
                }
            }
        }
        .cardStyle()
        .animation(.easeInOut(duration: 0.2), value: items.count)
    }

    private var controls: some View {
        VStack(spacing: 14) {
            micButton
            Button("Use these items") {
                speech.stop()
                Haptics.success()
                onFinish(items, speaker?.name ?? "")
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(items.isEmpty)
            .opacity(items.isEmpty ? 0.4 : 1)
            .padding(.horizontal, 16)
        }
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(.bar)
    }

    private var micButton: some View {
        Button {
            Haptics.tap()
            if speech.isListening {
                speech.stop()
            } else {
                Task { await speech.start(localeIdentifier: language.localeIdentifier) }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Theme.burgundy.opacity(0.18))
                    .frame(width: 96, height: 96)
                    .scaleEffect(speech.isListening ? 1 + CGFloat(speech.level) * 0.7 : 1)
                    .animation(.easeOut(duration: 0.12), value: speech.level)
                Circle()
                    .fill(Theme.heroGradient)
                    .frame(width: 76, height: 76)
                    .shadow(color: Theme.burgundy.opacity(0.4), radius: 12, y: 6)
                Image(systemName: speech.isListening ? "stop.fill" : "mic.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(speech.isListening ? String(localized: "Stop dictation") : String(localized: "Start dictation"))
        .frame(height: 104)
    }
}
