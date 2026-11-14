import AppKit
import Carbon.HIToolbox
import TranslateCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = TranslatorModel(defaults: .standard)
    private lazy var panel = FloatingPanel(model: model)
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var hotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // An accessory app shows no menu bar, but the Edit shortcuts (⌘C, ⌘V, ⌘Z) only work through a main menu.
        NSApp.mainMenu = makeMainMenu()
        NSApp.servicesProvider = self

        hotKey = GlobalHotKey(keyCode: kVK_ANSI_Backslash, modifiers: cmdKey) { [weak self] in
            self?.panel.toggle()
        }

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "translate", accessibilityDescription: "Translate")
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = hotKey == nil
                ? "Show or hide the translator. Right-click to quit."
                : "Show or hide the translator (⌘\\). Right-click to quit."
        }

        panel.present()
    }

    /// Services menu entry "Translate with TranslateMac", declared under NSServices in Info.plist.
    @objc func translateSelection(
        _ pasteboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        guard let text = pasteboard.string(forType: .string) else { return }
        model.inputText = text
        // The view requests on its own once it exists; this covers a launch caused by the service.
        model.requestTranslation()
        panel.present()
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "Quit TranslateMac", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            // A permanent menu would swallow the left click that toggles the panel.
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else if panel.isVisible {
            panel.close()
        } else {
            panel.present()
        }
    }

    private func makeMainMenu() -> NSMenu {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit TranslateMac", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let mainMenu = NSMenu()
        for menu in [appMenu, editMenu] {
            let item = NSMenuItem()
            item.submenu = menu
            mainMenu.addItem(item)
        }
        return mainMenu
    }
}
