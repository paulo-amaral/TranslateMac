import AppKit
import Carbon.HIToolbox
import SwiftUI
import TranslateCore
import TranslateUI

/// Spotlight-style window: floats over every space and takes the keyboard
/// without activating the app, so the app the person was using stays in front.
final class FloatingPanel: NSPanel {
    private var previousApp: NSRunningApplication?

    init(model: TranslatorModel) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 360),
            styleMask: [.nonactivatingPanel, .titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        title = "Translate"
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentMinSize = NSSize(width: 420, height: 300)

        let background = NSVisualEffectView()
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        let hosting = NSHostingView(rootView: TranslatorView(model: model).ignoresSafeArea())
        hosting.frame = background.bounds
        hosting.autoresizingMask = [.width, .height]
        background.addSubview(hosting)
        contentView = background
        center()
    }

    override var canBecomeKey: Bool { true }

    /// Shortcut behaviour: hide when the panel has the keyboard, otherwise show or refocus it.
    func toggle() {
        if isVisible, isKeyWindow {
            close()
        } else {
            present()
        }
    }

    func present() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost != .current {
            previousApp = frontmost
        }
        makeKeyAndOrderFront(nil)
        // The SwiftUI text view may not exist until the first layout pass after ordering front.
        Task { focusAndSelectInput() }
    }

    override func sendEvent(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        // Escape and Tab belong to the input method while it is composing text.
        let isComposing = (firstResponder as? NSTextView)?.hasMarkedText() ?? false
        if event.type == .keyDown, modifiers.isEmpty, !isComposing {
            if event.keyCode == kVK_Escape {
                close()
                return
            }
            // Only inside the text to translate: other controls keep Tab for keyboard navigation.
            if event.keyCode == kVK_Tab, let textView = firstResponder as? NSTextView, !textView.isFieldEditor {
                focusPreviousApp()
                return
            }
        }
        super.sendEvent(event)
    }

    private func focusPreviousApp() {
        resignKey()
        if NSApp.isActive {
            previousApp?.activate()
        }
    }

    private func focusAndSelectInput() {
        guard let input = contentView?.firstEditableTextView() else { return }
        makeFirstResponder(input)
        input.selectAll(nil)
    }
}

private extension NSView {
    func firstEditableTextView() -> NSTextView? {
        if let textView = self as? NSTextView, textView.isEditable {
            return textView
        }
        for subview in subviews {
            if let found = subview.firstEditableTextView() {
                return found
            }
        }
        return nil
    }
}
