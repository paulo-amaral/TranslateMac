import AVFoundation

@MainActor
final class Speaker {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String, language: Locale.Language) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language.minimalIdentifier)
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
