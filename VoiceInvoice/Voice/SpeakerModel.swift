import Foundation
import AVFoundation

// A lightweight, fully on-device speaker model. It averages MFCC statistics of the voiced
// part of an utterance into a 24-number "embedding" and compares embeddings by distance.
// It is intentionally simple and replaceable: anything that turns audio into [Float] can
// stand in for `SpeakerEmbedding.make` (for example a Core ML speaker model).

enum SpeakerEmbedding {
    /// 12 means + 12 standard deviations of c1...c12.
    static let dimension = MFCCExtractor.numCoefficients * 2
    static let minimumVoicedFrames = 25

    static func make(samples: [Float], sampleRate: Double) -> [Float]? {
        guard sampleRate >= 8000 else { return nil }
        let frames = MFCCExtractor(sampleRate: sampleRate).frames(samples)
        guard frames.count >= minimumVoicedFrames,
              let loudest = frames.map(\.energy).max(), loudest > -9 else { return nil }

        // Keep only frames within ~20 dB of the loudest: the person actually speaking.
        let threshold = loudest - 4.6
        let voiced = frames.filter { $0.energy >= threshold }
        guard voiced.count >= minimumVoicedFrames else { return nil }

        let n = Float(voiced.count)
        let count = MFCCExtractor.numCoefficients
        var means = [Float](repeating: 0, count: count)
        for frame in voiced {
            for k in 0..<count { means[k] += frame.coefficients[k] }
        }
        for k in 0..<count { means[k] /= n }
        var deviations = [Float](repeating: 0, count: count)
        for frame in voiced {
            for k in 0..<count {
                let d = frame.coefficients[k] - means[k]
                deviations[k] += d * d
            }
        }
        for k in 0..<count { deviations[k] = (deviations[k] / n).squareRoot() }
        return means + deviations
    }
}

struct VoiceProfile: Equatable {
    let id: String
    let centroid: [Float]
    let radius: Float
}

struct SpeakerMatch: Equatable {
    let id: String
    let distance: Float
    let runnerUp: Float?
}

enum SpeakerMatcher {
    /// Euclidean distance; the spread (std) dimensions count half as much as the means.
    static func distance(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return .infinity }
        let half = a.count / 2
        var sum: Float = 0
        for i in a.indices {
            let weight: Float = i < half ? 1 : 0.5
            let d = (a[i] - b[i]) * weight
            sum += d * d
        }
        return sum.squareRoot()
    }

    /// Returns the enrolled voice that matches, or nil when nobody matches confidently.
    static func identify(
        _ embedding: [Float],
        profiles: [VoiceProfile],
        gateFactor: Float = 2.5,
        minimumGate: Float = 2.0,
        ratio: Float = 0.8
    ) -> SpeakerMatch? {
        guard !profiles.isEmpty else { return nil }
        let ranked = profiles
            .map { ($0, distance(embedding, $0.centroid)) }
            .sorted { $0.1 < $1.1 }
        let (best, bestDistance) = ranked[0]
        let gate = max(best.radius * gateFactor, minimumGate)
        guard bestDistance <= gate else { return nil }
        var runnerUp: Float?
        if ranked.count > 1 {
            let second = ranked[1].1
            guard bestDistance <= second * ratio else { return nil }
            runnerUp = second
        }
        return SpeakerMatch(id: best.id, distance: bestDistance, runnerUp: runnerUp)
    }
}

/// What gets stored for one person: the average embedding and how tightly their samples cluster.
struct Voiceprint: Equatable {
    var centroid: [Float]
    var radius: Float
    var sampleCount: Int

    static func enroll(from embeddings: [[Float]]) -> Voiceprint? {
        guard embeddings.count >= 2, let size = embeddings.first?.count, size > 0,
              embeddings.allSatisfy({ $0.count == size }) else { return nil }
        var centroid = [Float](repeating: 0, count: size)
        for embedding in embeddings {
            for i in 0..<size { centroid[i] += embedding[i] }
        }
        for i in 0..<size { centroid[i] /= Float(embeddings.count) }
        let radius = embeddings.map { SpeakerMatcher.distance($0, centroid) }.max() ?? 0
        return Voiceprint(centroid: centroid, radius: radius, sampleCount: embeddings.count)
    }

    var profileValues: [Float] { centroid + [radius, Float(sampleCount)] }

    var data: Data {
        profileValues.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    init(centroid: [Float], radius: Float, sampleCount: Int) {
        self.centroid = centroid
        self.radius = radius
        self.sampleCount = sampleCount
    }

    init?(data: Data) {
        let floatSize = MemoryLayout<Float>.size
        let total = SpeakerEmbedding.dimension + 2
        guard data.count == total * floatSize else { return nil }
        let values: [Float] = data.withUnsafeBytes { raw in
            (0..<total).map { raw.loadUnaligned(fromByteOffset: $0 * floatSize, as: Float.self) }
        }
        guard values.allSatisfy({ $0.isFinite }) else { return nil }
        centroid = Array(values[0..<SpeakerEmbedding.dimension])
        radius = values[SpeakerEmbedding.dimension]
        sampleCount = Int(values[SpeakerEmbedding.dimension + 1])
    }
}

/// Thread-safe rolling buffer of the most recent microphone samples (first channel).
final class SampleBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var samples: [Float] = []
    private var rate: Double = 0
    private var dropped = 0
    private let maxSeconds: Double

    init(maxSeconds: Double = 10) {
        self.maxSeconds = maxSeconds
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return }
        lock.lock()
        defer { lock.unlock() }
        if rate == 0 { rate = buffer.format.sampleRate }
        samples.append(contentsOf: UnsafeBufferPointer(start: channel, count: count))
        let limit = Int(maxSeconds * rate)
        if samples.count > limit {
            let excess = samples.count - limit
            samples.removeFirst(excess)
            dropped += excess
        }
    }

    func snapshot() -> (samples: [Float], sampleRate: Double) {
        lock.lock()
        defer { lock.unlock() }
        return (samples, rate)
    }

    /// Samples plus how many older samples were already discarded, so word timestamps can be mapped to positions.
    func snapshotWithOffset() -> (samples: [Float], sampleRate: Double, startOffset: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (samples, rate, dropped)
    }

    var duration: Double {
        lock.lock()
        defer { lock.unlock() }
        return rate > 0 ? Double(samples.count) / rate : 0
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        samples.removeAll(keepingCapacity: true)
        rate = 0
        dropped = 0
    }
}
