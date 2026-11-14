# Changelog

This project follows [Semantic Versioning](https://semver.org) and the format of
[Keep a Changelog](https://keepachangelog.com).

## [0.1.0]

First public release.

### Added

- Floating panel in the style of Spotlight, shown from any app with `Cmd + \` or from the menu bar icon.
- On-device translation with Apple's Translation framework, with language detection and translation while typing.
- "Translate with TranslateMac" in the Services menu, to translate text selected in any app or browser.
- Dictation with on-device speech recognition.
- Listen to the original and the translation, copy the translation, swap languages.
- Spelling suggestion from the system spell checker, applied with `Cmd + Return`.
- The last language pair is remembered.

### Known limits

- The app is not notarized. macOS asks for confirmation the first time it opens.
- Spelling suggestions work word by word, without sentence context.
