import Carbon.HIToolbox

/// A system-wide shortcut. Carbon hot keys are the Apple API that needs no
/// Accessibility permission, unlike a global `NSEvent` monitor.
@MainActor
final class GlobalHotKey {
    private let action: () -> Void
    private var hotKeyRef: EventHotKeyRef?

    /// Fails when another app already owns the shortcut.
    init?(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        self.action = action
        let id = EventHotKeyID(signature: OSType(0x544D_4143), id: 1)
        let status = RegisterEventHotKey(
            UInt32(keyCode), UInt32(modifiers), id, GetEventDispatcherTarget(), 0, &hotKeyRef
        )
        guard status == noErr else { return nil }

        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
            // Carbon delivers hot key events on the main run loop.
            MainActor.assumeIsolated { hotKey.action() }
            return noErr
        }, 1, &pressed, Unmanaged.passUnretained(self).toOpaque(), nil)
    }
}
