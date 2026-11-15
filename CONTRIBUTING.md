# Contributing

Thanks for helping. A few rules keep the app small and private.

## Rules

- Apple frameworks only. No third-party packages.
- Apple translation must remain on device. Google translation uses the website in `WKWebView`; do not add another
  network service, analytics, or storage or logging of translated text without updating the privacy documentation.
- Rules and state go in `TranslateCore`, with tests. Views go in `TranslateUI`. App plumbing goes in `TranslateMac`.
- The interface follows Apple's Human Interface Guidelines: system colors and text styles, a tooltip on every
  icon-only control, no app-only light or dark switch.

## Workflow

1. Open an issue first for anything larger than a small fix.
2. Write the test, then the change.
3. Run `make test`, then `make run` and check the panel yourself.
4. Open a pull request that says what changes and why.

Design notes live in `docs/architecture.md`.
