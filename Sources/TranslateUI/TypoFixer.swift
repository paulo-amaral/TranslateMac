import AppKit

@MainActor
enum TypoFixer {
    static let longestCheckedText = 2_000

    /// The text with every misspelled word replaced by the system's first suggestion,
    /// or nil when there is nothing to fix or no dictionary for the language.
    static func correctedText(for text: String, language: Locale.Language?) -> String? {
        // The check runs on the main thread and visits every word; a long text would freeze the panel.
        guard text.utf16.count <= longestCheckedText else { return nil }
        let checker = NSSpellChecker.shared
        guard let code = language?.languageCode?.identifier,
              let dictionary = checker.availableLanguages.first(where: { $0 == code || $0.hasPrefix(code + "_") })
        else { return nil }

        var corrected = text
        var searchStart = 0
        while searchStart < (corrected as NSString).length {
            let misspelled = checker.checkSpelling(
                of: corrected, startingAt: searchStart, language: dictionary,
                wrap: false, inSpellDocumentWithTag: 0, wordCount: nil
            )
            guard misspelled.location != NSNotFound else { break }
            let replacement = checker.correction(
                forWordRange: misspelled, in: corrected, language: dictionary, inSpellDocumentWithTag: 0
            ) ?? checker.guesses(
                forWordRange: misspelled, in: corrected, language: dictionary, inSpellDocumentWithTag: 0
            )?.first
            if let replacement {
                corrected = (corrected as NSString).replacingCharacters(in: misspelled, with: replacement)
                searchStart = misspelled.location + (replacement as NSString).length
            } else {
                searchStart = NSMaxRange(misspelled)
            }
        }
        return corrected == text ? nil : corrected
    }
}
