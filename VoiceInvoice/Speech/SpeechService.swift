import Foundation
import Speech
import AVFoundation
import Observation

/// Live microphone dictation. Uses on-device recognition when the language supports it,
/// and reports which mode is active so the UI can be honest about it.
@MainActor
@Observable
final class SpeechService {
    enum State: Equatable {
        case idle
        case requestingPermission
        case listening
        case denied(String)
        case failed(String)
    }

    var transcript = ""
    var level: Float = 0
    var state: State = .idle
    var isOnDevice = false

    var isListening: Bool { state == .listening }

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    // MARK: Control

    func start(localeIdentifier: String) async {
        guard state != .listening, state != .requestingPermission else { return }
        transcript = ""
        level = 0
        state = .requestingPermission

        let speechStatus = await Self.requestSpeechAuthorization()
        guard speechStatus == .authorized else {
            state = .denied(String(localized: "Speech recognition is turned off for VoiceInvoice. You can enable it in Settings."))
            return
        }
        guard await Self.requestMicrophone() else {
            state = .denied(String(localized: "Microphone access is turned off for VoiceInvoice. You can enable it in Settings."))
            return
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)),
              recognizer.isAvailable else {
            state = .failed(String(localized: "Speech recognition is not available for this language right now."))
            return
        }

        isOnDevice = recognizer.supportsOnDeviceRecognition
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.addsPunctuation = false
        self.request = request

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(
                onBus: 0,
                bufferSize: 1024,
                format: format,
                block: Self.makeTapBlock(request: request) { [weak self] level in
                    Task { @MainActor in self?.level = level }
                }
            )
            audioEngine.prepare()
            try audioEngine.start()
            state = .listening

            task = recognizer.recognitionTask(
                with: request,
                resultHandler: Self.makeResultHandler { [weak self] text, isFinal, failed in
                    Task { @MainActor in self?.handle(text: text, isFinal: isFinal, failed: failed) }
                }
            )
        } catch {
            teardownAudio()
            state = .failed(error.localizedDescription)
        }
    }

    func stop() {
        guard state == .listening || state == .requestingPermission else { return }
        teardownAudio()
        request?.endAudio()
        state = .idle
    }

    // MARK: Internals

    private func handle(text: String?, isFinal: Bool, failed: Bool) {
        if let text, state == .listening || state == .idle {
            transcript = text
        }
        if isFinal || failed {
            task = nil
            request = nil
            if state == .listening {
                teardownAudio()
                state = .idle
            }
        }
    }

    private func teardownAudio() {
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // These factories are nonisolated so the closures they return are not bound to the main actor;
    // audio and recognition callbacks arrive on background threads.

    nonisolated private static func makeTapBlock(
        request: SFSpeechAudioBufferRecognitionRequest,
        onLevel: @escaping @Sendable (Float) -> Void
    ) -> AVAudioNodeTapBlock {
        return { buffer, _ in
            request.append(buffer)
            onLevel(Self.rms(buffer))
        }
    }

    nonisolated private static func makeResultHandler(
        _ deliver: @escaping @Sendable (String?, Bool, Bool) -> Void
    ) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        return { result, error in
            deliver(result?.bestTranscription.formattedString, result?.isFinal ?? false, error != nil)
        }
    }

    nonisolated private static func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<count { sum += data[i] * data[i] }
        return min(1, (sum / Float(count)).squareRoot() * 8)
    }

    nonisolated private static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
    }

    nonisolated private static func requestMicrophone() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
    }
}
