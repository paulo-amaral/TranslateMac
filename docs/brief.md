# Brief: TranslateMac

## Purpose
A compact macOS text translator available from any app. Apple translation runs on device by default; an optional
Google Translate mode opens Google's website in an embedded WebKit view.

## Users
People who translate short texts between languages throughout the day and want a floating panel with a choice of
on-device or web translation.

## Current scope
- Floating panel opened from the menu bar or `Cmd + \`, including text selected through macOS Services.
- Apple mode: stacked input and output panes, language detection, translation after a short typing pause, and
  clear, copy, speak, swap, dictation, and spelling suggestion actions.
- Google mode: compact Google Translate website inside `WKWebView`, with text already in the app prefilled when the
  mode is selected. Text can also be entered directly on the site.
- Service and language choices remembered between launches; translated text is not stored by the native app.

## Success measures
- `swift build` and `swift test` pass from a clean checkout.
- Translating a short sentence returns a result in Apple mode on macOS 15 or later; Google mode loads its site and
  allows translation when the site and internet access are available.
- The window passes the checks of the `macos-hig` skill (light and dark, narrow and wide, Reduce Motion).

## Non-goals
Conversation mode, camera or image translation, favorites, history, file translation, a language download manager
(the system asks to download a language when it is needed), Settings window, iOS target.

## Constraints
- Native Apple frameworks only: Translation, SwiftUI, AVFoundation, and WebKit. No third-party packages.
- Minimum macOS 15, the first release that includes the Translation framework
  (`@available(macOS 15.0 ...)` in the SDK interface).
- Privacy: Apple mode runs on device. Google mode sends text entered on its page or prefilled from the app to Google;
  the app does not save translated text or add analytics.
- No hosted app backend or Google Cloud Translation API key. Google mode depends on the public website.
