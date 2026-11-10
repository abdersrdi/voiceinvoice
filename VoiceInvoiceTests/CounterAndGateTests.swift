import XCTest
@testable import VoiceInvoice

enum TestAudio {
    struct Voice {
        var f0: Float
        var formants: [(center: Float, width: Float)]
    }

    static let voiceA = Voice(f0: 120, formants: [(700, 150), (1200, 200), (2500, 300)])
    static let voiceB = Voice(f0: 210, formants: [(350, 100), (2200, 250), (3000, 300)])
    static let rate: Float = 16000

    /// Additive synthesis: harmonics shaped by formant peaks, light vibrato and noise.
    static func synth(_ voice: Voice, f0Scale: Float = 1, seconds: Float, seed: UInt64 = 1) -> [Float] {
        let f0 = voice.f0 * f0Scale
        let harmonics = max(1, Int((rate / 2 * 0.9) / f0))
        var amplitudes = [Float](repeating: 0, count: harmonics + 1)
        for h in 1...harmonics {
            let freq = f0 * Float(h)
            var amp: Float = 0
            for formant in voice.formants {
                let d = (freq - formant.center) / formant.width
                amp += exp(-d * d)
            }
            amplitudes[h] = amp
        }
        var state = seed
        func noise() -> Float {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Float(Int64(bitPattern: state >> 11) % 2000) / 1000 - 1
        }
        let count = Int(seconds * rate)
        var phases = [Float](repeating: 0, count: harmonics + 1)
        var out = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let t = Float(i) / rate
            let vibrato = 1 + 0.01 * sin(2 * Float.pi * 5 * t)
            var sample: Float = 0
            for h in 1...harmonics {
                phases[h] += 2 * Float.pi * f0 * vibrato * Float(h) / rate
                sample += amplitudes[h] * sin(phases[h]) / Float(h)
            }
            out[i] = sample * 0.05 + noise() * 0.001
        }
        return out
    }
}

final class WakePhraseTests: XCTestCase {
    func testDetectsEnglishAndReturnsWhatFollows() {
        XCTAssertEqual(
            WakePhrase.detect(in: "ok new invoice two shirts at twenty each", language: .en),
            "two shirts at twenty each"
        )
        XCTAssertNil(WakePhrase.detect(in: "two shirts at twenty each", language: .en))
    }

    func testIgnoresCaseAndAccents() {
        XCTAssertEqual(WakePhrase.detect(in: "Nouvelle facture, trois cafés pour douze euros", language: .fr),
                       "trois cafés pour douze euros")
        XCTAssertEqual(WakePhrase.detect(in: "NUOVA FATTURA due camicie a venti euro", language: .it),
                       "due camicie a venti euro")
        XCTAssertEqual(WakePhrase.detect(in: "nueva factura dos camisas", language: .es), "dos camisas")
    }

    func testChinese() {
        XCTAssertEqual(WakePhrase.detect(in: "新发票 两件衬衫每件二十块", language: .zh), "两件衬衫每件二十块")
    }

    func testNothingAfterThePhraseGivesEmptyText() {
        XCTAssertEqual(WakePhrase.detect(in: "new invoice", language: .en), "")
    }

    func testDisplayTextIsCapitalised() {
        XCTAssertEqual(WakePhrase.display(for: .en), "New invoice")
        XCTAssertEqual(WakePhrase.display(for: .fr), "Nouvelle facture")
    }

    func testWhatFollowsParsesIntoItems() throws {
        let rest = try XCTUnwrap(WakePhrase.detect(in: "new invoice two shirts at 20 each and a hat for 15", language: .en))
        let items = LineItemParser.parse(rest, language: .en)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first?.unitPrice, 20)
    }
}

final class EndpointDetectorTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000)

    func testFinishesAfterEnoughSilence() {
        var detector = EndpointDetector(now: start)
        XCTAssertEqual(detector.update(text: "two shirts", now: start + 0.5), .keepListening)
        XCTAssertEqual(detector.update(text: "two shirts at twenty", now: start + 1.5), .keepListening)
        XCTAssertEqual(detector.update(text: "two shirts at twenty", now: start + 3.0), .keepListening)
        XCTAssertEqual(detector.update(text: "two shirts at twenty", now: start + 3.6), .finish)
    }

    func testNewWordsRestartTheClock() {
        var detector = EndpointDetector(now: start)
        _ = detector.update(text: "two shirts", now: start + 1)
        _ = detector.update(text: "two shirts at twenty", now: start + 2.5)
        XCTAssertEqual(detector.update(text: "two shirts at twenty", now: start + 4.0), .keepListening)
    }

    func testGivesUpWhenNothingIsSaid() {
        var detector = EndpointDetector(now: start)
        XCTAssertEqual(detector.update(text: "", now: start + 3), .keepListening)
        XCTAssertEqual(detector.update(text: "  ", now: start + 6.5), .giveUp)
    }
}

final class SpeakerGateTests: XCTestCase {
    private func embedding(_ samples: [Float]) throws -> [Float] {
        try XCTUnwrap(SpeakerEmbedding.make(samples: samples, sampleRate: Double(TestAudio.rate)))
    }

    func testPhrasesAreSplitAtPauses() {
        let words = [
            TimedWord(text: "a", start: 0, duration: 0.4),
            TimedWord(text: "b", start: 0.5, duration: 0.4),
            TimedWord(text: "c", start: 2.0, duration: 0.4)
        ]
        let phrases = SpeakerGate.phrases(words)
        XCTAssertEqual(phrases.map { $0.map(\.text) }, [["a", "b"], ["c"]])
    }

    func testJoinsChineseWithoutSpaces() {
        let words = [TimedWord(text: "两件", start: 0, duration: 0.3), TimedWord(text: "衬衫", start: 0.3, duration: 0.3)]
        XCTAssertEqual(SpeakerGate.text(from: words, language: .zh), "两件衬衫")
        XCTAssertEqual(SpeakerGate.text(from: words, language: .en), "两件 衬衫")
    }

    func testGateDropsAPhraseFromAnotherVoice() throws {
        let rate = Double(TestAudio.rate)
        let enrollment = try [Float(0.95), 1.0, 1.05].enumerated().map { index, scale in
            try embedding(TestAudio.synth(TestAudio.voiceA, f0Scale: scale, seconds: 1.5, seed: UInt64(index + 1)))
        }
        let voiceprint = try XCTUnwrap(Voiceprint.enroll(from: enrollment))
        let profile = VoiceProfile(id: "A", centroid: voiceprint.centroid, radius: voiceprint.radius)

        let voiceA = TestAudio.synth(TestAudio.voiceA, f0Scale: 1.03, seconds: 1.5, seed: 11)
        let silence = [Float](repeating: 0, count: Int(rate))
        let voiceB = TestAudio.synth(TestAudio.voiceB, seconds: 1.5, seed: 12)
        let samples = voiceA + silence + voiceB

        let words = [
            TimedWord(text: "two", start: 0.0, duration: 0.7),
            TimedWord(text: "shirts", start: 0.7, duration: 0.8),
            TimedWord(text: "something", start: 2.5, duration: 0.7),
            TimedWord(text: "else", start: 3.2, duration: 0.8)
        ]

        // Put the gate halfway between "same voice" and "other voice" so the test checks the
        // mechanics (slicing audio by timestamps, keeping and dropping) rather than tuning.
        let same = SpeakerMatcher.distance(try embedding(voiceA), profile.centroid)
        let other = SpeakerMatcher.distance(try embedding(voiceB), profile.centroid)
        XCTAssertLessThan(same, other)

        let result = SpeakerGate.filter(
            words: words, samples: samples, sampleRate: rate, profile: profile, gate: (same + other) / 2
        )
        XCTAssertEqual(result.kept.map(\.text), ["two", "shirts"])
        XCTAssertEqual(result.droppedPhrases, 1)
    }

    func testUnjudgeablePhrasesAreKept() {
        let profile = VoiceProfile(id: "A", centroid: [Float](repeating: 0, count: 24), radius: 1)
        let words = [TimedWord(text: "hi", start: 0, duration: 0.2)]
        // No audio at all: the phrase cannot be judged, so it stays.
        let result = SpeakerGate.filter(words: words, samples: [], sampleRate: 16000, profile: profile)
        XCTAssertEqual(result.kept.count, 1)
        XCTAssertEqual(result.droppedPhrases, 0)
    }

    func testSampleBufferTracksDiscardedSamples() throws {
        let buffer = SampleBuffer(maxSeconds: 1)
        let snapshot = buffer.snapshotWithOffset()
        XCTAssertEqual(snapshot.startOffset, 0)
        XCTAssertTrue(snapshot.samples.isEmpty)
    }
}

final class DocumentLanguageTests: XCTestCase {
    func testMoneyFollowsTheDocumentLocale() {
        let french = Money.string(1234.5, currencyCode: "EUR", locale: Locale(identifier: "fr"))
        XCTAssertTrue(french.contains("234,50"), french)
        let english = Money.string(1234.5, currencyCode: "EUR", locale: Locale(identifier: "en_US"))
        XCTAssertTrue(english.contains("1,234.50"), english)
    }

    func testDocumentLocale() {
        var document = InvoiceDocument()
        document.languageCode = "zh-Hans"
        XCTAssertEqual(document.locale.language.languageCode?.identifier, "zh")
        document.languageCode = ""
        XCTAssertEqual(document.locale, Locale.current)
    }

    @MainActor
    func testPDFRendersInAnotherLanguage() throws {
        var document = InvoiceDocument()
        document.languageCode = "fr"
        document.shopName = "Boutique"
        document.number = "INV-AA-0001"
        document.customerName = "Client"
        document.currencyCode = "EUR"
        document.lines = [InvoiceDocument.Line(name: "Chemise", quantity: 2, unitPrice: 20)]
        let url = try InvoicePDFRenderer.render(document)
        XCTAssertGreaterThan(try Data(contentsOf: url).count, 1000)
    }
}
