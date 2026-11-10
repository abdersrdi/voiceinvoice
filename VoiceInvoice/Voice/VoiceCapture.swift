import Foundation
import AVFoundation
import Observation

/// Records a short clip for voice enrollment. Audio is only kept in memory long enough to
/// compute the voiceprint; it is never saved.
@MainActor
@Observable
final class VoiceCapture {
    var isRecording = false
    var level: Float = 0
    var error: String?

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let buffer = SampleBuffer(maxSeconds: 12)

    func start() async -> Bool {
        error = nil
        guard await Self.requestMicrophone() else {
            error = String(localized: "Microphone access is turned off for VoiceInvoice. You can enable it in Settings.")
            return false
        }
        buffer.reset()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [])
            try session.setActive(true, options: [])

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(
                onBus: 0,
                bufferSize: 1024,
                format: format,
                block: Self.makeTapBlock(buffer: buffer) { [weak self] level in
                    Task { @MainActor in self?.level = level }
                }
            )
            engine.prepare()
            try engine.start()
            isRecording = true
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func stop() -> (samples: [Float], sampleRate: Double) {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isRecording = false
        level = 0
        return buffer.snapshot()
    }

    nonisolated private static func makeTapBlock(
        buffer: SampleBuffer,
        onLevel: @escaping @Sendable (Float) -> Void
    ) -> AVAudioNodeTapBlock {
        return { pcm, _ in
            buffer.append(pcm)
            onLevel(AudioMath.rms(pcm))
        }
    }

    nonisolated private static func requestMicrophone() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
    }
}

enum AudioMath {
    static func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<count { sum += data[i] * data[i] }
        return min(1, (sum / Float(count)).squareRoot() * 8)
    }
}
