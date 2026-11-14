# Brief: TranslateMac

## Purpose
A macOS text translator that looks and behaves like Apple's Translate app and uses only Apple's own translation
framework (Translation). Text never leaves the Mac for a third-party service.

## Users
One person (the owner) who translates short texts between languages every day and wants the Apple Translate layout
with a few fixes of their own.

## Version 1 scope
- Two panes side by side: input on the left, translation on the right.
- Source language picker with "Detect Language", swap button, target language picker, all centered in the toolbar.
- Automatic translation while typing (300 ms pause).
- Clear, copy and speak (AVSpeechSynthesizer) actions.
- Empty, translating and failed states with a next step.

## Success measures
- `swift build` and `swift test` pass from a clean checkout.
- Translating a short sentence returns a result in the app on macOS 15 or later.
- The window passes the checks of the `macos-hig` skill (light and dark, narrow and wide, Reduce Motion).

## Non-goals (version 1)
Conversation mode, camera or image translation, favorites, history, file translation, a language download manager
(the system asks to download a language when it is needed), Settings window, iOS target.

## Constraints
- Native Apple frameworks only: Translation, SwiftUI, AVFoundation. No third-party packages.
- Minimum macOS 15, the first release that includes the Translation framework
  (`@available(macOS 15.0 ...)` in the SDK interface).
- Privacy: no network code, no analytics, no storage of the translated text.
- Hosting and budget: none. Local app.
