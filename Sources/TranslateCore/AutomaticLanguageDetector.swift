import Foundation
import NaturalLanguage

public enum AutomaticLanguageDetector {
    /// A tentative language is not enough to start a Translation session: an
    /// unclear source makes the system ask the person to choose on every edit.
    public static func confidentLanguage(for text: String) -> Locale.Language? {
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        guard letters >= 5 else { return nil }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 2)
            .sorted { $0.value > $1.value }
        guard let best = hypotheses.first, best.value >= 0.75,
              best.value - (hypotheses.dropFirst().first?.value ?? 0) >= 0.2
        else { return nil }
        return Locale.Language(identifier: best.key.rawValue)
    }
}
