import Foundation
import Observation
import Translation

public struct TranslatedText: Equatable, Sendable {
    public let source: Locale.Language
    public let target: Locale.Language
    public let text: String

    public init(source: Locale.Language, target: Locale.Language, text: String) {
        self.source = source
        self.target = target
        self.text = text
    }
}

@MainActor
public protocol TextTranslating {
    func translate(_ text: String) async throws -> TranslatedText
}

@MainActor
@Observable
public final class TranslatorModel {
    public enum Phase: Equatable {
        case idle
        case translating
        case failed(String)
    }

    /// nil means "Detect Language".
    public var sourceLanguage: Locale.Language?
    public var targetLanguage: Locale.Language
    public var inputText = ""
    public private(set) var outputText = ""
    public private(set) var detectedLanguage: Locale.Language?
    public private(set) var phase: Phase = .idle
    public private(set) var configuration: TranslationSession.Configuration?

    public init(sourceLanguage: Locale.Language? = nil, targetLanguage: Locale.Language) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }

    /// Starts from the language pair saved by `saveLanguages`. Only language codes are kept, never text.
    public convenience init(defaults: UserDefaults) {
        self.init(
            sourceLanguage: defaults.string(forKey: "sourceLanguage").map(Locale.Language.init(identifier:)),
            targetLanguage: defaults.string(forKey: "targetLanguage").map(Locale.Language.init(identifier:))
                ?? Locale.current.language
        )
    }

    public func saveLanguages(to defaults: UserDefaults) {
        defaults.set(sourceLanguage?.minimalIdentifier, forKey: "sourceLanguage")
        defaults.set(targetLanguage.minimalIdentifier, forKey: "targetLanguage")
    }

    public var canSwap: Bool {
        (sourceLanguage ?? detectedLanguage) != nil
    }

    /// Asks the view layer to open a new translation session. The session only
    /// exists inside the SwiftUI `translationTask` modifier, so the model cannot
    /// create one itself.
    public func requestTranslation() {
        if var current = configuration, current.source == sourceLanguage, current.target == targetLanguage {
            current.invalidate()
            configuration = current
        } else {
            configuration = TranslationSession.Configuration(source: sourceLanguage, target: targetLanguage)
        }
    }

    public func swapLanguages() {
        guard let newTarget = sourceLanguage ?? detectedLanguage else { return }
        let newSource = targetLanguage
        let carriedText = outputText
        sourceLanguage = newSource
        targetLanguage = newTarget
        detectedLanguage = nil
        inputText = carriedText
        outputText = ""
        requestTranslation()
    }

    public func clear() {
        inputText = ""
        outputText = ""
        detectedLanguage = nil
        phase = .idle
    }

    public func run(using translator: some TextTranslating) async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            outputText = ""
            detectedLanguage = nil
            phase = .idle
            return
        }
        phase = .translating
        let (source, target) = (sourceLanguage, targetLanguage)
        // A newer edit or language choice replaces this request; its own run owns the output and the phase.
        let isCurrent = {
            self.inputText.trimmingCharacters(in: .whitespacesAndNewlines) == text
                && self.sourceLanguage == source && self.targetLanguage == target
        }
        do {
            let result = try await translator.translate(text)
            guard isCurrent() else { return }
            outputText = result.text
            detectedLanguage = sourceLanguage == nil ? result.source : nil
            phase = .idle
        } catch {
            guard isCurrent() else { return }
            // The session reports a replaced request, or a system sheet the person closed, as a
            // Cocoa "user cancelled" error. Neither is a failure to show.
            let wasCancelled = error is CancellationError || Task.isCancelled
                || (error as? CocoaError)?.code == .userCancelled
            phase = wasCancelled ? .idle : .failed(error.localizedDescription)
        }
    }
}
