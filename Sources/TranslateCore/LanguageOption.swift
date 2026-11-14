import Foundation

public struct LanguageOption: Identifiable, Hashable, Sendable {
    public let language: Locale.Language
    public let name: String
    public var id: String { language.minimalIdentifier }

    public init(language: Locale.Language, locale: Locale = .current) {
        self.language = language
        self.name = locale.localizedString(forIdentifier: language.minimalIdentifier)
            ?? language.minimalIdentifier
    }
}

public enum LanguageCatalog {
    public static func options(from languages: [Locale.Language], locale: Locale = .current) -> [LanguageOption] {
        var seen = Set<String>()
        return languages
            .map { LanguageOption(language: $0, locale: locale) }
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// The supported language closest to the first preferred language that has one.
    /// A system language such as "en-TL" is not in the Translation list, so the
    /// region gives way; the script never does ("zh-Hant" must not become "zh-Hans").
    public static func bestMatch(for preferred: [Locale.Language], in supported: [Locale.Language]) -> Locale.Language? {
        for wanted in preferred {
            let sameLanguage = supported
                .filter { $0.languageCode == wanted.languageCode && $0.script == wanted.script }
                .sorted { $0.minimalIdentifier < $1.minimalIdentifier }
            let match = sameLanguage.first { $0.region == wanted.region }
                // The framework lists its base variant without a region ("en", "pt").
                ?? sameLanguage.first { $0.minimalIdentifier == $0.languageCode?.identifier }
                ?? sameLanguage.first
            if let match { return match }
        }
        return nil
    }
}
