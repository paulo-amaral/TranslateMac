import Foundation
import Testing
import Translation
@testable import TranslateCore

private let english = Locale.Language(identifier: "en")
private let portuguese = Locale.Language(identifier: "pt")
private let german = Locale.Language(identifier: "de")

private struct StubTranslator: TextTranslating {
    var detected: Locale.Language = english
    var target: Locale.Language = portuguese
    var failure: (any Error)?

    func translate(_ text: String) async throws -> TranslatedText {
        if let failure { throw failure }
        return TranslatedText(source: detected, target: target, text: "[\(text)]")
    }
}

/// Simulates the person typing again while a request is still in flight.
private struct InterruptedTranslator: TextTranslating {
    let model: TranslatorModel

    func translate(_ text: String) async throws -> TranslatedText {
        model.inputText = "newer text"
        throw StubError()
    }
}

/// Simulates the person picking another target language while a request is still in flight.
private struct LanguageChangingTranslator: TextTranslating {
    let model: TranslatorModel

    func translate(_ text: String) async throws -> TranslatedText {
        model.targetLanguage = german
        return TranslatedText(source: english, target: portuguese, text: "olá")
    }
}

private struct ReplacedRequestTranslator: TextTranslating {
    let model: TranslatorModel

    func translate(_ text: String) async throws -> TranslatedText {
        model.requestTranslation()
        return TranslatedText(source: english, target: portuguese, text: "old result")
    }
}

private struct StubError: LocalizedError {
    var errorDescription: String? { "pair unavailable" }
}

@MainActor
@Suite("TranslatorModel")
struct TranslatorModelTests {
    @Test func emptyInputClearsOutputAndSkipsTranslator() async {
        let model = TranslatorModel(targetLanguage: portuguese)
        model.inputText = "   \n"
        await model.run(using: StubTranslator(failure: StubError()))
        #expect(model.outputText.isEmpty)
        #expect(model.phase == .idle)
    }

    @Test func translatesTrimmedTextAndStoresDetectedLanguage() async {
        let model = TranslatorModel(targetLanguage: portuguese)
        model.inputText = "  hello \n"
        await model.run(using: StubTranslator())
        #expect(model.outputText == "[hello]")
        #expect(model.detectedLanguage == english)
        #expect(model.phase == .idle)
    }

    @Test func explicitSourceDoesNotReportDetection() async {
        let model = TranslatorModel(sourceLanguage: english, targetLanguage: portuguese)
        model.inputText = "hello"
        await model.run(using: StubTranslator())
        #expect(model.detectedLanguage == nil)
    }

    @Test func failureIsReportedWithMessage() async {
        let model = TranslatorModel(targetLanguage: portuguese)
        model.inputText = "hello"
        await model.run(using: StubTranslator(failure: StubError()))
        #expect(model.phase == .failed("pair unavailable"))
        #expect(model.outputText.isEmpty)
    }

    @Test func cancellationReturnsToIdle() async {
        let model = TranslatorModel(targetLanguage: portuguese)
        model.inputText = "hello"
        await model.run(using: StubTranslator(failure: CancellationError()))
        #expect(model.phase == .idle)
    }

    @Test func dismissedSystemSheetIsNotAFailure() async {
        let model = TranslatorModel(targetLanguage: portuguese)
        model.inputText = "hello"
        await model.run(using: StubTranslator(failure: CocoaError(.userCancelled)))
        #expect(model.phase == .idle)
    }

    @Test func failureOfAStaleRequestIsDropped() async {
        let model = TranslatorModel(targetLanguage: portuguese)
        model.inputText = "hello"
        await model.run(using: InterruptedTranslator(model: model))
        #expect(model.phase == .translating)
    }

    @Test func answerForAPreviousLanguagePairIsDropped() async {
        let model = TranslatorModel(targetLanguage: portuguese)
        model.inputText = "hello"
        await model.run(using: LanguageChangingTranslator(model: model))
        #expect(model.outputText.isEmpty)
    }

    @Test func editingClearsPreviousTranslationAndDetectionImmediately() async {
        let model = TranslatorModel(targetLanguage: portuguese)
        model.inputText = "hello"
        await model.run(using: StubTranslator())
        model.inputText = "This is a longer sentence written in English."
        model.requestTranslation()
        #expect(model.outputText.isEmpty)
        #expect(model.detectedLanguage == nil)
        #expect(model.phase == .translating)
    }

    @Test func replacedRequestDropsAnswerEvenWhenTextIsUnchanged() async {
        let model = TranslatorModel(sourceLanguage: english, targetLanguage: portuguese)
        model.inputText = "hello"
        model.requestTranslation()
        await model.run(using: ReplacedRequestTranslator(model: model))
        #expect(model.outputText.isEmpty)
        #expect(model.phase == .translating)
    }

    @Test func uncertainAutomaticDetectionAsksForMoreText() async {
        let model = TranslatorModel(targetLanguage: portuguese)
        model.inputText = "a"
        await model.run(using: StubTranslator(failure: TranslationError.unableToIdentifyLanguage))
        #expect(model.phase == .needsMoreText)
        #expect(model.detectedLanguage == nil)
    }

    @Test func shortAmbiguousInputDoesNotOpenATranslationSession() {
        let model = TranslatorModel(targetLanguage: portuguese)
        model.inputText = "a"
        model.requestTranslation()
        #expect(model.configuration == nil)
        #expect(model.phase == .needsMoreText)
    }

    @Test func confidentAutomaticDetectionSetsTheSessionSource() {
        let model = TranslatorModel(targetLanguage: portuguese)
        model.inputText = "This is a longer sentence written in English."
        model.requestTranslation()
        #expect(model.configuration?.source?.languageCode?.identifier == "en")
        #expect(model.phase == .translating)
    }

    @Test func confidentPortugueseDetectionSetsTheSessionSource() {
        let model = TranslatorModel(targetLanguage: english)
        model.inputText = "Esta é uma frase escrita em português para identificar o idioma."
        model.requestTranslation()
        #expect(model.configuration?.source?.languageCode?.identifier == "pt")
        #expect(model.phase == .translating)
    }

    @Test func explicitSourceAllowsShortInput() {
        let model = TranslatorModel(sourceLanguage: english, targetLanguage: portuguese)
        model.inputText = "a"
        model.requestTranslation()
        #expect(model.configuration?.source == english)
        #expect(model.phase == .translating)
    }

    @Test func detectedSourceMatchingTargetDoesNotStartTranslation() {
        let model = TranslatorModel(targetLanguage: english)
        model.inputText = "This is a longer sentence written in English."
        model.requestTranslation()
        #expect(model.configuration == nil)
        #expect(model.detectedLanguage?.languageCode?.identifier == "en")
        #expect(model.phase == .sameLanguage)
        #expect(model.canSwap == false)
    }

    @Test func explicitSourceMatchingTargetDoesNotStartTranslation() {
        let model = TranslatorModel(sourceLanguage: english, targetLanguage: Locale.Language(identifier: "en-US"))
        model.inputText = "hello"
        model.requestTranslation()
        #expect(model.configuration == nil)
        #expect(model.phase == .sameLanguage)
    }

    @Test func languagePairSurvivesARestart() throws {
        let suite = "TranslatorModelTests.languagePair"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = TranslatorModel(sourceLanguage: portuguese, targetLanguage: german)
        first.saveLanguages(to: defaults)
        let restored = TranslatorModel(defaults: defaults)
        #expect(restored.sourceLanguage == portuguese)
        #expect(restored.targetLanguage == german)

        first.sourceLanguage = nil
        first.saveLanguages(to: defaults)
        #expect(TranslatorModel(defaults: defaults).sourceLanguage == nil)
    }

    @Test func textFromAnotherAppFillsAnEmptyPanel() {
        let model = TranslatorModel(sourceLanguage: portuguese, targetLanguage: english)
        model.receiveExternalText("bom dia")
        #expect(model.inputText == "bom dia")
        #expect(model.pendingExternalText == nil)
        #expect(model.configuration != nil)
    }

    @Test func textFromAnotherAppDoesNotReplaceTypedTextUntilThePersonAgrees() {
        let model = TranslatorModel(sourceLanguage: portuguese, targetLanguage: english)
        model.inputText = "texto que eu digitei"
        model.receiveExternalText("texto de outro app")
        #expect(model.inputText == "texto que eu digitei")
        #expect(model.pendingExternalText == "texto de outro app")

        model.resolvePendingExternalText(replace: true)
        #expect(model.inputText == "texto de outro app")
        #expect(model.pendingExternalText == nil)
    }

    @Test func decliningKeepsTheTypedText() {
        let model = TranslatorModel(sourceLanguage: portuguese, targetLanguage: english)
        model.inputText = "texto que eu digitei"
        model.receiveExternalText("texto de outro app")
        model.resolvePendingExternalText(replace: false)
        #expect(model.inputText == "texto que eu digitei")
        #expect(model.pendingExternalText == nil)
    }

    @Test func aSecondHandoverReplacesTheFirstWithoutAsking() {
        let model = TranslatorModel(sourceLanguage: portuguese, targetLanguage: english)
        model.receiveExternalText("primeira seleção")
        model.receiveExternalText("segunda seleção")
        #expect(model.inputText == "segunda seleção")
        #expect(model.pendingExternalText == nil)
    }

    @Test func textFromAnotherAppIsCutAtTheLimit() {
        let model = TranslatorModel(sourceLanguage: portuguese, targetLanguage: english)
        model.receiveExternalText(String(repeating: "a", count: TranslatorModel.externalTextLimit + 10))
        #expect(model.inputText.count == TranslatorModel.externalTextLimit)
        #expect(model.externalTextWasShortened)

        model.receiveExternalText("curto")
        #expect(!model.externalTextWasShortened)
    }

    @Test func swapUsesDetectedLanguageAndCarriesOutputAsInput() async {
        let model = TranslatorModel(targetLanguage: portuguese)
        model.inputText = "hello"
        await model.run(using: StubTranslator())
        model.swapLanguages()
        #expect(model.sourceLanguage == portuguese)
        #expect(model.targetLanguage == english)
        #expect(model.inputText == "[hello]")
        #expect(model.outputText.isEmpty)
        #expect(model.configuration != nil)
    }

    @Test func swapDoesNothingWhenSourceIsUnknown() {
        let model = TranslatorModel(targetLanguage: portuguese)
        #expect(model.canSwap == false)
        model.swapLanguages()
        #expect(model.sourceLanguage == nil)
        #expect(model.targetLanguage == portuguese)
    }

    @Test func clearResetsTextsAndPhase() async {
        let model = TranslatorModel(targetLanguage: portuguese)
        model.inputText = "hello"
        await model.run(using: StubTranslator())
        model.clear()
        #expect(model.inputText.isEmpty)
        #expect(model.outputText.isEmpty)
        #expect(model.detectedLanguage == nil)
    }

    @Test func requestTranslationReusesConfigurationForSamePair() {
        let model = TranslatorModel(sourceLanguage: english, targetLanguage: portuguese)
        model.inputText = "hello"
        model.requestTranslation()
        let first = model.configuration
        model.requestTranslation()
        #expect(first != nil)
        #expect(model.configuration?.source == english)
        #expect(model.configuration?.target == portuguese)
        #expect(model.configuration != first, "invalidate() must change the configuration so the task reruns")
    }
}

@Suite("LanguageCatalog")
struct LanguageCatalogTests {
    @Test func removesDuplicatesAndSortsByLocalizedName() {
        let locale = Locale(identifier: "en_US")
        let options = LanguageCatalog.options(from: [portuguese, german, english, german], locale: locale)
        #expect(options.map(\.name) == ["English", "German", "Portuguese"])
    }

    @Test func sortsUsingTheGivenLocale() {
        let locale = Locale(identifier: "pt_BR")
        let options = LanguageCatalog.options(from: [english, german, portuguese], locale: locale)
        #expect(options.map(\.name) == ["alemão", "inglês", "português"])
    }

    @Test func bestMatchKeepsAnExactVariant() {
        let supported = ["pt", "pt-PT", "en"].map(Locale.Language.init(identifier:))
        let match = LanguageCatalog.bestMatch(for: [Locale.Language(identifier: "pt-PT")], in: supported)
        #expect(match?.minimalIdentifier == "pt-PT")
    }

    @Test func bestMatchFallsBackToTheBaseVariantForAnUnsupportedRegion() {
        let supported = ["en-GB", "en-AU", "en", "pt"].map(Locale.Language.init(identifier:))
        let match = LanguageCatalog.bestMatch(for: [Locale.Language(identifier: "en-TL")], in: supported)
        #expect(match?.minimalIdentifier == "en")
    }

    @Test func bestMatchReturnsTheListedValueForAnEquivalentLanguage() {
        let listed = Locale.Language(languageCode: "pt", region: "BR")
        let saved = Locale.Language(identifier: "pt")
        #expect(saved != listed)
        #expect(LanguageCatalog.bestMatch(for: [saved], in: [listed, english]) == listed)
    }

    @Test func bestMatchKeepsTheScript() {
        let supported = ["zh", "zh-TW", "zh-HK"].map(Locale.Language.init(identifier:))
        let match = LanguageCatalog.bestMatch(for: [Locale.Language(identifier: "zh-MO")], in: supported)
        #expect(match?.minimalIdentifier == "zh-HK")
    }

    @Test func bestMatchTriesPreferredLanguagesInOrder() {
        let supported = [english, portuguese]
        let preferred = ["tet-TL", "pt-TL"].map(Locale.Language.init(identifier:))
        #expect(LanguageCatalog.bestMatch(for: preferred, in: supported) == portuguese)
    }

    @Test func bestMatchIsNilWhenNothingIsSupported() {
        let match = LanguageCatalog.bestMatch(for: [Locale.Language(identifier: "tet-TL")], in: [english, portuguese])
        #expect(match == nil)
    }
}
