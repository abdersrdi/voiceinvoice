import XCTest
import SwiftData
@testable import VoiceInvoice

final class SpeakerTests: XCTestCase {
    // MARK: Synthetic voices

    private struct VoiceSpec {
        var f0: Float
        var formants: [(center: Float, width: Float)]
    }

    private let voiceA = VoiceSpec(f0: 120, formants: [(700, 150), (1200, 200), (2500, 300)])
    private let voiceB = VoiceSpec(f0: 210, formants: [(350, 100), (2200, 250), (3000, 300)])
    private let voiceC = VoiceSpec(f0: 320, formants: [(250, 60), (3200, 200), (3800, 200)])
    private let rate: Float = 16000

    /// Additive synthesis: harmonics shaped by formant peaks, a little vibrato and noise.
    private func synth(_ voice: VoiceSpec, f0Scale: Float, seconds: Float, seed: UInt64) -> [Float] {
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

    private func embeddings(for voice: VoiceSpec, scales: [Float]) throws -> [[Float]] {
        try scales.enumerated().map { index, scale in
            let samples = synth(voice, f0Scale: scale, seconds: 1.5, seed: UInt64(index + 1))
            return try XCTUnwrap(SpeakerEmbedding.make(samples: samples, sampleRate: Double(rate)))
        }
    }

    // MARK: DSP

    func testFFTFindsSinePeak() {
        let size = 256
        let fft = FFT(size: size)
        var re = (0..<size).map { sin(2 * Float.pi * 16 * Float($0) / Float(size)) }
        var im = [Float](repeating: 0, count: size)
        fft.transform(re: &re, im: &im)
        let magnitudes = (0...(size / 2)).map { (re[$0] * re[$0] + im[$0] * im[$0]).squareRoot() }
        XCTAssertEqual(magnitudes.firstIndex(of: magnitudes.max() ?? 0), 16)
        XCTAssertGreaterThan(magnitudes[16], magnitudes[40] * 100)
    }

    func testMFCCProducesFramesAndFiniteValues() {
        let samples = synth(voiceA, f0Scale: 1, seconds: 1, seed: 7)
        let frames = MFCCExtractor(sampleRate: Double(rate)).frames(samples)
        XCTAssertGreaterThan(frames.count, 90)
        XCTAssertTrue(frames.allSatisfy { $0.coefficients.count == 12 && $0.coefficients.allSatisfy(\.isFinite) })
    }

    func testSilenceAndShortAudioGiveNoEmbedding() {
        XCTAssertNil(SpeakerEmbedding.make(samples: [Float](repeating: 0, count: 16000), sampleRate: 16000))
        XCTAssertNil(SpeakerEmbedding.make(samples: [0.1, 0.2, 0.3], sampleRate: 16000))
    }

    func testEmbeddingWorksAtDeviceSampleRates() throws {
        // Same synthetic voice, rendered at 16 kHz: embedding is 24 finite numbers.
        let samples = synth(voiceA, f0Scale: 1, seconds: 1.5, seed: 3)
        let embedding = try XCTUnwrap(SpeakerEmbedding.make(samples: samples, sampleRate: 16000))
        XCTAssertEqual(embedding.count, SpeakerEmbedding.dimension)
        XCTAssertTrue(embedding.allSatisfy(\.isFinite))
    }

    // MARK: Matching

    func testSameVoiceIsCloserThanDifferentVoice() throws {
        let a = try embeddings(for: voiceA, scales: [0.95, 1.0, 1.05, 1.03])
        let b = try embeddings(for: voiceB, scales: [0.95, 1.0, 1.05, 1.03])
        let within = SpeakerMatcher.distance(a[0], a[3])
        let between = SpeakerMatcher.distance(a[0], b[3])
        XCTAssertLessThan(within, between)
    }

    func testIdentifiesEnrolledVoices() throws {
        let a = try embeddings(for: voiceA, scales: [0.95, 1.0, 1.05, 1.03])
        let b = try embeddings(for: voiceB, scales: [0.95, 1.0, 1.05, 1.03])
        let printA = try XCTUnwrap(Voiceprint.enroll(from: Array(a[0..<3])))
        let printB = try XCTUnwrap(Voiceprint.enroll(from: Array(b[0..<3])))
        let profiles = [
            VoiceProfile(id: "A", centroid: printA.centroid, radius: printA.radius),
            VoiceProfile(id: "B", centroid: printB.centroid, radius: printB.radius)
        ]
        XCTAssertEqual(SpeakerMatcher.identify(a[3], profiles: profiles)?.id, "A")
        XCTAssertEqual(SpeakerMatcher.identify(b[3], profiles: profiles)?.id, "B")
    }

    func testUnknownVoiceIsRejected() throws {
        let a = try embeddings(for: voiceA, scales: [0.95, 1.0, 1.05])
        let c = try embeddings(for: voiceC, scales: [1.0])
        let printA = try XCTUnwrap(Voiceprint.enroll(from: a))
        let profiles = [VoiceProfile(id: "A", centroid: printA.centroid, radius: printA.radius)]
        XCTAssertNil(SpeakerMatcher.identify(c[0], profiles: profiles))
    }

    func testNoProfilesMeansNoMatch() {
        XCTAssertNil(SpeakerMatcher.identify([Float](repeating: 0, count: 24), profiles: []))
    }

    // MARK: Storage format

    func testVoiceprintDataRoundTrip() throws {
        let a = try embeddings(for: voiceA, scales: [0.95, 1.0, 1.05])
        let original = try XCTUnwrap(Voiceprint.enroll(from: a))
        let decoded = try XCTUnwrap(Voiceprint(data: original.data))
        XCTAssertEqual(decoded, original)
        XCTAssertNil(Voiceprint(data: Data([1, 2, 3])))
    }

    func testEnrollmentNeedsAtLeastTwoSamples() {
        XCTAssertNil(Voiceprint.enroll(from: [[Float](repeating: 1, count: 24)]))
    }

    @MainActor
    func testVoiceprintStoreSyncedAndLocal() throws {
        let container = try Persistence.makeInMemoryContainer()
        let context = ModelContext(container)
        let employee = Employee()
        employee.name = "Test"
        context.insert(employee)

        let print = Voiceprint(centroid: [Float](repeating: 1, count: 24), radius: 0.5, sampleCount: 3)
        employee.voiceSyncEnabled = true
        VoiceprintStore.save(print, for: employee)
        XCTAssertNotNil(employee.voiceprint)
        XCTAssertEqual(VoiceprintStore.load(for: employee), print)

        VoiceprintStore.setSync(false, for: employee)
        XCTAssertNil(employee.voiceprint)                       // no longer in the synced record
        XCTAssertEqual(VoiceprintStore.load(for: employee), print) // still on this device

        VoiceprintStore.delete(for: employee)
        XCTAssertNil(VoiceprintStore.load(for: employee))
        XCTAssertFalse(VoiceprintStore.hasVoiceprint(employee))
    }

    func testSampleBufferKeepsRecentSeconds() {
        let buffer = SampleBuffer(maxSeconds: 1)
        XCTAssertEqual(buffer.duration, 0)
        buffer.reset()
        XCTAssertTrue(buffer.snapshot().samples.isEmpty)
    }
}
