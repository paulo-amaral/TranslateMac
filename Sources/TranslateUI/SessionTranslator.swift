@preconcurrency import Translation
import TranslateCore

struct SessionTranslator: TextTranslating {
    let session: TranslationSession

    func translate(_ text: String) async throws -> TranslatedText {
        let response = try await session.translate(text)
        return TranslatedText(
            source: response.sourceLanguage,
            target: response.targetLanguage,
            text: response.targetText
        )
    }
}
