import AppKit
import SwiftUI
@preconcurrency import Translation
import TranslateCore

public struct TranslatorView: View {
    @State private var model: TranslatorModel
    @State private var languages: [LanguageOption] = []
    @State private var speaker = Speaker()
    @State private var typoSuggestion: String?
    @State private var dictation = Dictation()

    public init(model: TranslatorModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        VStack(spacing: 0) {
            inputPane
            swapDivider
            outputPane
        }
        .frame(minWidth: 420, minHeight: 300)
        .translationTask(model.configuration) { session in
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
            await model.run(using: SessionTranslator(session: session))
        }
        .onChange(of: model.inputText) {
            typoSuggestion = nil
            model.requestTranslation()
        }
        .onChange(of: [model.sourceLanguage, model.targetLanguage]) {
            model.saveLanguages(to: .standard)
            model.requestTranslation()
        }
        .onChange(of: model.phase) {
            guard model.phase == .idle else { return }
            typoSuggestion = TypoFixer.correctedText(for: model.inputText, language: spokenSourceLanguage)
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
                    let typedText = model.inputText
                    let language = spokenSourceLanguage ?? Locale.current.language
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
                .help(dictation.isListening ? "Stop listening to the microphone" : "Speak the text instead of typing it")

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
