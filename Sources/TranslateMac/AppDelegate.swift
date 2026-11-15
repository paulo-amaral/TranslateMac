import AppKit
import Carbon.HIToolbox
import ServiceManagement
import TranslateCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = TranslatorModel(defaults: .standard)
    private lazy var panel = FloatingPanel(model: model)
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var hotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureLoginItemIfNeeded()
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
        model.receiveExternalText(text)
        panel.present()
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            addLoginItems(to: menu)
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

    private func configureLoginItemIfNeeded() {
        let appDirectory = Bundle.main.bundleURL.deletingLastPathComponent().standardizedFileURL
        let applicationsDirectories = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
        ]
        guard applicationsDirectories.contains(where: { $0.standardizedFileURL == appDirectory }) else { return }
        guard !UserDefaults.standard.bool(forKey: "didConfigureLaunchAtLogin") else { return }

        let service = SMAppService.mainApp
        do {
            if service.status != .enabled && service.status != .requiresApproval {
                try service.register()
            }
            if service.status == .enabled || service.status == .requiresApproval {
                UserDefaults.standard.set(true, forKey: "didConfigureLaunchAtLogin")
            }
        } catch {
            NSLog("Could not enable TranslateMac at login: %@", error.localizedDescription)
        }
    }

    @objc private func toggleLoginItem(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled || service.status == .requiresApproval {
                try service.unregister()
            } else {
                try service.register()
            }
            UserDefaults.standard.set(true, forKey: "didConfigureLaunchAtLogin")
            sender.state = service.status == .enabled ? .on : .off
            if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not change the login setting"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    @objc private func openLoginItemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private func makeMainMenu() -> NSMenu {
        let appMenu = NSMenu()
        addLoginItems(to: appMenu)
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

    private func addLoginItems(to menu: NSMenu) {
        let loginItem = menu.addItem(
            withTitle: "Open at Login",
            action: #selector(toggleLoginItem(_:)),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        if SMAppService.mainApp.status == .requiresApproval {
            let settingsItem = menu.addItem(
                withTitle: "Allow in Login Items…",
                action: #selector(openLoginItemSettings),
                keyEquivalent: ""
            )
            settingsItem.target = self
        }
        menu.addItem(.separator())
    }
}
