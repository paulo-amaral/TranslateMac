# TranslateMac (agent rules)

- Native Apple frameworks only (Translation, SwiftUI, AppKit, AVFoundation, Speech). Do not add third-party packages.
- No network code. The text stays on the Mac.
- Keep rules in `TranslateCore` and views in `TranslateUI`. Core must stay testable without a window.
- Build and test with `swift build` and `swift test`. Both must pass before a change is done.
- UI follows the `macos-hig` skill: system colors and text styles, tooltips on icon-only controls, no app-only
  light/dark switch. Run the app and check the window before calling UI work done.
- Never store or log the text the person translates. Saving the chosen language pair is allowed.
- Do not commit or push unless the owner asks.
