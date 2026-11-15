import AppKit
import SwiftUI
@preconcurrency import Translation
import TranslateCore

private enum TranslationService: String {
    case apple
    case google
}

public extension Notification.Name {
    static let translationServiceDidChange = Notification.Name("TranslateMac.translationServiceDidChange")
}

public struct TranslatorView: View {
    @AppStorage("translationService") private var translationService: TranslationService = .apple
    @State private var model: TranslatorModel
    @State private var languages: [LanguageOption] = []
    @State private var speaker = Speaker()
    @State private var typoSuggestion: String?
    @State private var dictation = Dictation()
    @State private var needsSpokenLanguage = false
    @State private var googleCopyRequest = 0
    @State private var googleCopySucceeded = false
    @State private var showGoogleCopyError = false

    public init(model: TranslatorModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("TranslateMac")
                    .font(.headline)
                Picker("Translation service", selection: $translationService) {
                    Text("Apple").tag(TranslationService.apple)
                    Text("Google").tag(TranslationService.google)
                }
                .labelsHidden()
                .fixedSize()
                .help(translationService == .google
                    ? "Google Translate receives text entered in its page or sent from the app"
                    : "Apple translates on this Mac")
                Spacer()
                if translationService == .google {
                    Button {
                        googleCopySucceeded = false
                        googleCopyRequest += 1
                    } label: {
                        Image(systemName: googleCopySucceeded ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Copy Google translation")
                    .help(googleCopySucceeded ? "Translation copied" : "Copy Google translation")
                    Text("Sent to Google")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(translationService == .google
                ? Color(nsColor: .windowBackgroundColor)
                : Color.clear)

            if translationService == .apple {
                inputPane
                swapDivider
                outputPane
            } else {
                googlePane
            }
        }
        .frame(minWidth: 420, minHeight: 300)
        .alert("Translation unavailable", isPresented: $showGoogleCopyError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Wait for Google Translate to show a result, then try copying again.")
        }
        .translationTask(translationService == .apple ? model.configuration : nil) { session in
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
            await model.run(using: SessionTranslator(session: session))
        }
        .onChange(of: model.inputText) {
            typoSuggestion = nil
            if translationService == .apple { model.requestTranslation() }
        }
        .onChange(of: [model.sourceLanguage, model.targetLanguage]) {
            needsSpokenLanguage = false
            model.saveLanguages(to: .standard)
            if translationService == .apple { model.requestTranslation() }
        }
        .onChange(of: translationService) {
            googleCopySucceeded = false
            NotificationCenter.default.post(
                name: .translationServiceDidChange,
                object: translationService.rawValue
            )
            if translationService == .apple { model.requestTranslation() }
        }
        .onChange(of: model.phase) {
            guard model.phase == .idle else { return }
            let (text, language) = (model.inputText, spokenSourceLanguage)
            Task {
                let suggestion = await SentenceCorrector.correctedText(for: text, language: language)
                // The model can take a moment; the person may have typed on meanwhile.
                if model.inputText == text {
                    typoSuggestion = suggestion
                }
            }
        }
        // Hiding the panel must close the microphone and stop any speech.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in
            dictation.stop()
            speaker.stop()
        }
        .task {
            let supported = await LanguageAvailability().supportedLanguages
            languages = LanguageCatalog.options(from: supported)
            // A saved or system language is rarely equal to the framework's own value for the same
            // language ("pt" against Portuguese with the region built in), and a picker needs equality.
            if let source = model.sourceLanguage {
                model.sourceLanguage = LanguageCatalog.bestMatch(for: [source], in: supported)
            }
            let preferred = [model.targetLanguage] + Locale.preferredLanguages.map(Locale.Language.init(identifier:))
            if let match = LanguageCatalog.bestMatch(for: preferred, in: supported) {
                model.targetLanguage = match
            }
        }
    }

    private var spokenSourceLanguage: Locale.Language? {
        model.sourceLanguage ?? model.detectedLanguage
    }

    private var googlePane: some View {
        VStack(spacing: 0) {
            if model.pendingExternalText != nil {
                HStack {
                    Text("Another app sent text to translate.")
                    Spacer()
                    Button("Keep My Text") { model.resolvePendingExternalText(replace: false) }
                    Button("Replace") { model.resolvePendingExternalText(replace: true) }
                }
                .padding(12)
            }
            if model.inputText.count > 5_000 {
                Text("Google Translate receives only the first 5,000 characters from the selected text.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
            GoogleTranslateView(url: googleURL, copyRequest: googleCopyRequest) { copied in
                googleCopySucceeded = copied
                showGoogleCopyError = !copied
                if copied {
                    let request = googleCopyRequest
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        if googleCopyRequest == request { googleCopySucceeded = false }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var googleURL: URL {
        var components = URLComponents(string: "https://translate.google.com/")!
        components.queryItems = [
            URLQueryItem(name: "sl", value: model.sourceLanguage?.minimalIdentifier ?? "auto"),
            URLQueryItem(name: "tl", value: model.targetLanguage.minimalIdentifier),
            URLQueryItem(name: "text", value: String(model.inputText.prefix(5_000))),
            URLQueryItem(name: "op", value: "translate"),
        ]
        return components.url!
    }

    private var inputPane: some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("Source language", selection: $model.sourceLanguage) {
                    Text("Detect Language").tag(Locale.Language?.none)
                    Divider()
                    ForEach(languages) { option in
                        Text(option.name).tag(Optional(option.language))
                    }
                }
                .labelsHidden()
                .fixedSize()
                .help("Language of the text you type")

                if let detected = model.detectedLanguage {
                    Text("Detected: \(LanguageOption(language: detected).name)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    guard let language = spokenSourceLanguage else {
                        needsSpokenLanguage = true
                        return
                    }
                    needsSpokenLanguage = false
                    let typedText = model.inputText
                    dictation.toggle(language: language) { transcript in
                        model.inputText = typedText.isEmpty ? transcript : typedText + " " + transcript
                    }
                } label: {
                    Label(
                        dictation.isListening ? "Stop dictation" : "Dictate",
                        systemImage: dictation.isListening ? "stop.circle.fill" : "mic"
                    )
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help(dictation.isListening ? "Stop listening to the microphone" :
                    spokenSourceLanguage == nil ? "Choose the source language before dictating" :
                    "Speak the text instead of typing it")

                Button {
                    if let language = spokenSourceLanguage {
                        speaker.speak(model.inputText, language: language)
                    }
                } label: {
                    Label("Speak original", systemImage: "speaker.wave.2")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .keyboardShortcut("l", modifiers: .command)
                .disabled(model.inputText.isEmpty || spokenSourceLanguage == nil)
                .help("Listen to the text you typed (⌘L)")

                Button {
                    speaker.stop()
                    dictation.stop()
                    model.clear()
                } label: {
                    Label("Clear", systemImage: "xmark.circle.fill")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .disabled(model.inputText.isEmpty)
                .help("Clear the text")
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $model.inputText)
                    .font(.title2)
                    .scrollContentBackground(.hidden)
                if model.inputText.isEmpty {
                    Text("Enter text")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }

            if needsSpokenLanguage && spokenSourceLanguage == nil {
                Label("Choose the language you will speak above, then start dictation. Voice recognition needs a language before it can transcribe.", systemImage: "waveform")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if model.pendingExternalText != nil {
                HStack {
                    Label("Another app sent text to translate.", systemImage: "square.and.arrow.down")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Keep My Text") {
                        model.resolvePendingExternalText(replace: false)
                    }
                    Button("Replace") {
                        model.resolvePendingExternalText(replace: true)
                    }
                    .help("Discard what you typed and translate the text from the other app")
                }
            } else if model.externalTextWasShortened {
                Label(
                    "Only the first \(TranslatorModel.externalTextLimit.formatted()) characters of the selection were kept.",
                    systemImage: "scissors"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            if let problem = dictation.problem {
                Label(problem, systemImage: "mic.slash")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let typoSuggestion {
                Button {
                    model.inputText = typoSuggestion
                } label: {
                    Text("Did you mean: \(typoSuggestion)")
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .buttonStyle(.link)
                .keyboardShortcut(.return, modifiers: .command)
                .help("Replace the text with this spelling (⌘↩)")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var swapDivider: some View {
        ZStack {
            Divider()
            Button {
                model.swapLanguages()
            } label: {
                Label("Swap languages", systemImage: "arrow.up.arrow.down")
            }
            .labelStyle(.iconOnly)
            .buttonBorderShape(.circle)
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!model.canSwap)
            .help("Swap the languages and move the translation up (⌘S)")
        }
        .padding(.horizontal, 16)
    }

    private var outputPane: some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("Target language", selection: $model.targetLanguage) {
                    ForEach(languages) { option in
                        Text(option.name).tag(option.language)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .help("Language to translate into")

                Spacer()
                if model.phase == .translating {
                    ProgressView().controlSize(.small)
                }
                Button {
                    speaker.speak(model.outputText, language: model.targetLanguage)
                } label: {
                    Label("Speak translation", systemImage: "speaker.wave.2")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .disabled(model.outputText.isEmpty)
                .help("Listen to the translation")

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(model.outputText, forType: .string)
                } label: {
                    Label("Copy translation", systemImage: "doc.on.doc")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .disabled(model.outputText.isEmpty)
                .help("Copy the translation to the clipboard")
            }

            outputContent
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var outputContent: some View {
        if case .failed(let message) = model.phase {
            VStack(alignment: .leading, spacing: 8) {
                Label("Translation failed", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                Text(message)
                    .foregroundStyle(.secondary)
                Text("Choose another language pair, or edit the text to try again.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if model.phase == .needsMoreText {
            Text("Keep typing so the source language can be detected, or choose it above.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if model.phase == .sameLanguage {
            Text("The text is already in the target language. Choose another target language to translate it.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if model.outputText.isEmpty {
            Text("Translation")
                .font(.title2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ScrollView {
                Text(model.outputText)
                    .font(.title2)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
