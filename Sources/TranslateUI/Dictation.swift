import AVFoundation
import Observation
@preconcurrency import Speech

@MainActor
@Observable
final class Dictation {
    private(set) var isListening = false
    /// What stopped dictation from starting, with the way to fix it.
    private(set) var problem: String?

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var task: SFSpeechRecognitionTask?

    /// `onText` receives the whole transcript so far, each time it grows or is revised.
    func toggle(language: Locale.Language, onText: @escaping @MainActor (String) -> Void) {
        if isListening {
            stop()
        } else {
            Task { await start(language: language, onText: onText) }
        }
    }

    func stop() {
        guard isListening else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        task?.finish()
        task = nil
        isListening = false
    }

    private func start(language: Locale.Language, onText: @escaping @MainActor (String) -> Void) async {
        problem = nil
        guard await Self.isAuthorized() else {
            problem = "Allow Microphone and Speech Recognition for TranslateMac in System Settings > Privacy & Security."
            return
        }
        let identifier = [language.languageCode?.identifier, language.region?.identifier]
            .compactMap { $0 }
            .joined(separator: "-")
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: identifier)),
              recognizer.isAvailable, recognizer.supportsOnDeviceRecognition
        else {
            problem = "This Mac has no on-device dictation for this language. Choose another source language."
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        // The spoken text must not leave the Mac.
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true

        Self.installTap(on: engine.inputNode, feeding: request)
        do {
            engine.prepare()
            try engine.start()
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            problem = error.localizedDescription
            return
        }
        isListening = true
        task = recognizer.recognitionTask(with: request) { @Sendable [weak self] result, error in
            let transcript = result?.bestTranscription.formattedString
            let isFinished = error != nil || result?.isFinal == true
            Task { @MainActor in
                if let transcript {
                    onText(transcript)
                }
                if isFinished {
                    self?.stop()
                }
            }
        }
    }

    // Both callbacks below run off the main thread. They live in nonisolated functions so the
    // closures do not inherit main-actor isolation, which would trap at run time.

    private nonisolated static func isAuthorized() async -> Bool {
        let speechAllowed = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        guard speechAllowed else { return false }
        return await AVCaptureDevice.requestAccess(for: .audio)
    }

    private nonisolated static func installTap(
        on input: AVAudioInputNode, feeding request: SFSpeechAudioBufferRecognitionRequest
    ) {
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
        }
    }
}
