import AppKit
import SwiftUI
import WebKit

/// Displays Google's own interface. The result is read only when the user requests a native copy.
struct GoogleTranslateView: NSViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme
    let url: URL
    let copyRequest: Int
    let onCopyResult: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let compactStyle = WKUserScript(
            source: """
            if (location.hostname === 'translate.google.com') {
                const style = document.createElement('style');
                style.textContent = `
                    :root {
                        color-scheme: light dark;
                        --tm-background: #f5f5f7;
                        --tm-surface: #ffffff;
                        --tm-text: #1d1d1f;
                        --tm-divider: rgb(0 0 0 / 10%);
                        --tm-hover: rgb(0 0 0 / 6%);
                    }
                    @media (prefers-color-scheme: dark) {
                        :root {
                            --tm-background: #1c1c1e;
                            --tm-surface: #2c2c2e;
                            --tm-text: #f5f5f7;
                            --tm-divider: rgb(255 255 255 / 12%);
                            --tm-hover: rgb(255 255 255 / 10%);
                        }
                    }
                    header, [role="banner"], nav, [aria-label="Translation types"],
                    .VjFXz, .hgbeOc, .qgyq3b,
                    button[aria-label="Save translation"],
                    button[aria-label="Search with Google"],
                    button[aria-label="Rate this translation"],
                    button[aria-label="Share translation"],
                    [aria-label="Show the Input Tools menu"],
                    [aria-label="Turn on Virtual Keyboard"] {
                        display: none !important;
                    }
                    html, body, body div, body section, body main {
                        background-color: var(--tm-background) !important;
                    }
                    body {
                        margin-top: 0 !important;
                    }
                    body, body input, body textarea, body [contenteditable="true"] {
                        font-family: -apple-system, BlinkMacSystemFont, system-ui !important;
                    }
                    body, body *:not(svg):not(path) {
                        color: var(--tm-text) !important;
                    }
                    body svg {
                        color: var(--tm-text) !important;
                    }
                    /* Google's control classes override ordinary element selectors. */
                    :is(body, #tm-style-root) a,
                    :is(body, #tm-style-root) a *,
                    :is(body, #tm-style-root) button,
                    :is(body, #tm-style-root) button *,
                    :is(body, #tm-style-root) [role="button"],
                    :is(body, #tm-style-root) [role="button"] *,
                    :is(body, #tm-style-root) span {
                        background: transparent !important;
                    }
                    body button:hover, body [role="button"]:hover {
                        background-color: var(--tm-hover) !important;
                    }
                    :is(body, #tm-style-root) div {
                        background-image: none !important;
                    }
                    :is(body, #tm-style-root) ul,
                    :is(body, #tm-style-root) ul li,
                    :is(body, #tm-style-root) ul li *,
                    :is(body, #tm-style-root) [role="listbox"],
                    :is(body, #tm-style-root) [role="listbox"] * {
                        background-color: var(--tm-surface) !important;
                        color: var(--tm-text) !important;
                        border-color: var(--tm-divider) !important;
                    }
                    body ::selection {
                        color: #ffffff !important;
                        background-color: #0a84ff !important;
                    }
                    :is(body, #tm-style-root) mark,
                    :is(body, #tm-style-root) mark * {
                        color: var(--tm-text) !important;
                        background: var(--tm-hover) !important;
                        border-radius: 4px !important;
                    }
                    body input, body textarea, body [contenteditable="true"] {
                        background-color: transparent !important;
                        caret-color: var(--tm-text) !important;
                    }
                    body .tm-source-panel, body .tm-source-panel div {
                        background-color: var(--tm-surface) !important;
                    }
                    body hr, body [role="separator"], body div {
                        border-color: var(--tm-divider) !important;
                    }
                `;
                document.documentElement.appendChild(style);
            }
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(compactStyle)
        let panelStyle = WKUserScript(
            source: """
            if (location.hostname === 'translate.google.com') {
                function markPanel(target, className) {
                    if (!target) return;
                    for (let node = target; node && node !== document.body; node = node.parentElement) {
                        const rect = node.getBoundingClientRect();
                        if (rect.width >= window.innerWidth - 16 &&
                            rect.height >= 110 && rect.height <= window.innerHeight * 0.65) {
                            node.classList.add(className);
                            return;
                        }
                    }
                }
                function markTranslationPanels() {
                    markPanel(document.querySelector('[role="combobox"]'),
                              'tm-source-panel');
                }
                let scheduled = false;
                const observer = new MutationObserver(() => {
                    if (scheduled) return;
                    scheduled = true;
                    requestAnimationFrame(() => {
                        scheduled = false;
                        markTranslationPanels();
                    });
                });
                observer.observe(document.documentElement, { childList: true, subtree: true });
                markTranslationPanels();
            }
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(panelStyle)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.underPageBackgroundColor = backgroundColor
        context.coordinator.lastRequestedURL = url
        context.coordinator.lastHandledCopyRequest = copyRequest
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.underPageBackgroundColor = backgroundColor
        if context.coordinator.lastRequestedURL != url {
            context.coordinator.lastRequestedURL = url
            webView.load(URLRequest(url: url))
        }
        guard context.coordinator.lastHandledCopyRequest != copyRequest else { return }
        context.coordinator.lastHandledCopyRequest = copyRequest
        guard webView.url?.host == "translate.google.com" else {
            DispatchQueue.main.async { onCopyResult(false) }
            return
        }
        webView.evaluateJavaScript(Self.translationTextScript) { value, _ in
            guard let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else {
                onCopyResult(false)
                return
            }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            onCopyResult(pasteboard.setString(text, forType: .string))
        }
    }

    final class Coordinator {
        var lastRequestedURL: URL?
        var lastHandledCopyRequest = 0
    }

    private static let translationTextScript = """
        (() => {
            if (location.hostname !== 'translate.google.com') return '';
            const copyButton = Array.from(document.querySelectorAll('button')).find(button =>
                (button.getAttribute('aria-label') || '').toLowerCase() === 'copy translation'
            );
            if (!copyButton) return '';
            // Google's copy control belongs to the result region. innerText excludes hidden
            // feedback and sharing dialogs that textContent would accidentally copy.
            const result = copyButton.closest('[role="region"]');
            if (!result) return '';
            const lines = result.innerText.split('\\n').map(line => line.trim()).filter(Boolean);
            const heading = result.querySelector('[role="heading"], h2')?.innerText.trim();
            const dictionary = result.querySelector('a[href*="/details"]')?.innerText.trim();
            if (heading && lines[0] === heading) lines.shift();
            if (dictionary && lines[lines.length - 1] === dictionary) lines.pop();
            return lines.join('\\n').trim();
        })();
        """

    private var backgroundColor: NSColor {
        colorScheme == .dark
            ? NSColor(srgbRed: 0.110, green: 0.110, blue: 0.118, alpha: 1)
            : NSColor(srgbRed: 0.961, green: 0.961, blue: 0.969, alpha: 1)
    }
}
