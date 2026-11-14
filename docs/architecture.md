# Architecture: TranslateMac

## Components

| Target | Role | Depends on |
| --- | --- | --- |
| `TranslateCore` | State and rules: `TranslatorModel`, `LanguageOption`, `LanguageCatalog`, the `TextTranslating` protocol | Foundation, Observation, Translation (only for `TranslationSession.Configuration`) |
| `TranslateUI` | SwiftUI views, the adapter from `TranslationSession` to `TextTranslating`, speech | `TranslateCore`, SwiftUI, Translation, AVFoundation |
| `TranslateMac` | AppKit entry point: floating panel, global shortcut, menu bar item, Services handler | `TranslateUI`, `TranslateCore`, AppKit, Carbon (hot key only) |
| `TranslateCoreTests` | Unit tests with a stub translator | `TranslateCore` |

## Data flow

1. The person types. `TranslatorView` sees `inputText` change and calls `model.requestTranslation()`.
2. The model publishes a new `TranslationSession.Configuration` (or calls `invalidate()` on the same pair).
3. The `translationTask` modifier opens a session, waits 300 ms, and calls `model.run(using: SessionTranslator(session:))`.
4. `run` trims the text, calls the translator, drops the answer if the input changed meanwhile, then stores the output
   and the detected language.
5. Failures become `phase = .failed(message)`; the view shows the message and a next step.

## Data model
No persistence. State lives in memory: source (optional, nil means detect), target, input, output, detected language,
phase (`idle`, `translating`, `failed`).

## Decisions

### ADR 1. The session is owned by the view, the logic by the model
- Context: `TranslationSession` is created by the SwiftUI `translationTask` modifier (the modifier lives in the
  `_Translation_SwiftUI` overlay of the SDK). The model cannot build one on its own.
- Decision: the model owns a `Configuration` and the rules; the view hands the session to the model through the
  `TextTranslating` protocol.
- Consequence: all logic is unit-tested with a stub. The real session path is only exercised by running the app.

### ADR 2. `TextTranslating` is main-actor isolated and Translation is imported with `@preconcurrency`
- Context: Swift 6 language mode rejects passing the non-Sendable `TranslationSession` across actors
  (`SendingRisksDataRace`). The Translation module does not declare its types Sendable.
- Decision: isolate the protocol to `@MainActor` and use `@preconcurrency import Translation` in the two UI files that
  touch session or availability types.
- Consequence: the build is clean in Swift 6 mode. If Apple marks the types Sendable, the attribute can go.

### ADR 3. Last-write-wins instead of a request queue
- Context: translation runs on every pause in typing.
- Decision: after the await, `run` compares the trimmed input with the text it sent and discards stale answers.
- Consequence: no queue and no extra state. The system may still translate a stale text once; the result is dropped.

### ADR 4. No app-only appearance, language list from the system
- Decision: follow system light and dark mode; read languages from `LanguageAvailability().supportedLanguages`.
- Consequence: the picker shows exactly what the Translation framework supports on that Mac.

### ADR 5. Floating panel in an accessory app, AppKit entry point
- Context: the app should behave like Spotlight: one shortcut from any app, no Dock icon, the app in front keeps its
  place. SwiftUI scenes offer no non-activating floating window and no click-to-toggle menu bar item.
- Decision: `main.swift` and `AppDelegate` own an `NSPanel` (`.nonactivatingPanel`, floating level) that hosts
  `TranslatorView`. The global shortcut uses Carbon `RegisterEventHotKey`, the Apple API that needs no Accessibility
  permission. A hand-built main menu keeps the Edit shortcuts working, because an accessory app shows no menu bar.
- Consequence: Escape and Tab are handled in `FloatingPanel.sendEvent`. Tab leaves the panel only from the text view,
  so other controls keep keyboard navigation.

### ADR 6. Selections arrive through a macOS Service
- Context: translate selected text from the context menu of any app, browsers included.
- Decision: declare `NSServices` in `App/Info.plist`; `AppDelegate.translateSelection` puts the text in the model and
  shows the panel. `scripts/make-app.sh` builds the bundle, since SwiftPM only produces a bare executable.
- Consequence: no browser extension and no Accessibility permission. The entry sits under Services in the context menu.

### ADR 7. Spelling suggestion from the system spell checker
- Context: the Translation framework gives no "did you mean" correction.
- Decision: `TypoFixer` asks `NSSpellChecker` for a word-by-word correction in the source language.
- Consequence: works offline. Corrections are per word, with no sentence context, so some suggestions are wrong.

### ADR 8. The language pair is remembered
- Decision: `saveLanguages` writes the two language codes to UserDefaults; `init(defaults:)` restores them.
- Consequence: the panel reopens on the last pair. No text is stored.

## Left out on purpose
Database, cache, history, network layer, settings, dependency injection container, a language download screen.
Each can be added when a real need appears.
