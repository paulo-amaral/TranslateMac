# Security

## Reporting a vulnerability

Report it privately through GitHub: Security tab, then "Report a vulnerability". Please do not open a public issue.
Include the app version, the macOS version and the steps to reproduce. Expect a first answer within 7 days.

## Supported versions

Only the latest release receives fixes.

## What the app does with your data

- Apple translation runs on the Mac with Apple's Translation framework. The optional Google Translate mode loads
  `translate.google.com` in a WebKit view. Text entered there, or up to 5,000 characters prefilled from the app,
  is sent to Google when this mode is selected. It requires internet access.
- Dictation uses on-device speech recognition only. A language without it is refused, not sent to a server.
- The native app does not write translated text to disk or a log. The Google web view uses an in-memory website
  data store. When you press the app's Google copy button, it reads the displayed translation and writes it to the
  system clipboard. The app saves two language codes and the selected translation service.
- The app asks for Microphone and Speech Recognition access, and only when you start dictation.

## Release integrity

Releases are built by GitHub Actions from the tagged commit. Each release has a SHA-256 checksum and a build
provenance attestation. The checksum is published next to the archive, so it only detects a damaged download; the
attestation is what shows the archive came from this repository's release workflow:

```sh
shasum -a 256 -c TranslateMac.zip.sha256
gh attestation verify TranslateMac.zip --repo paulo-amaral/TranslateMac \
  --signer-workflow paulo-amaral/TranslateMac/.github/workflows/release.yml
```

The app is signed ad hoc with the hardened runtime. It is not notarized by Apple, so macOS asks for confirmation the
first time it opens.
