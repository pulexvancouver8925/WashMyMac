import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        HotKeyCenter.shared.register { [weak self] in self?.toggleCleaning() }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        CleaningSession.shared.stop()
        return .terminateNow
    }

    // MARK: - Menu bar

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "sparkles",
            accessibilityDescription: "WashMyMac"
        )
        item.button?.toolTip = L.t("status.tooltip")

        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
        rebuild(menu: menu)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild(menu: menu)
    }

    private func rebuild(menu: NSMenu) {
        menu.removeAllItems()

        let start = NSMenuItem(
            title: L.t("menu.start"),
            action: #selector(toggleCleaning),
            keyEquivalent: "w"
        )
        start.keyEquivalentModifierMask = [.control, .option, .command]
        start.target = self
        menu.addItem(start)

        menu.addItem(.separator())

        let autoUnlock = NSMenuItem(title: L.t("menu.autoExit"), action: nil, keyEquivalent: "")
        let autoUnlockMenu = NSMenu()
        for minutes in Settings.autoUnlockChoices {
            let entry = NSMenuItem(
                title: L.minutes(minutes),
                action: #selector(setAutoUnlock(_:)),
                keyEquivalent: ""
            )
            entry.target = self
            entry.tag = minutes
            entry.state = Settings.shared.autoUnlockMinutes == minutes ? .on : .off
            autoUnlockMenu.addItem(entry)
        }
        autoUnlock.submenu = autoUnlockMenu
        menu.addItem(autoUnlock)

        menu.addItem(.separator())

        if !AXIsProcessTrusted() {
            let permission = NSMenuItem(
                title: L.t("menu.permission"),
                action: #selector(requestAccessibility),
                keyEquivalent: ""
            )
            permission.target = self
            permission.image = NSImage(
                systemSymbolName: "exclamationmark.triangle.fill",
                accessibilityDescription: nil
            )
            menu.addItem(permission)
        }

        let about = NSMenuItem(title: L.t("menu.about"), action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: L.t("menu.quit"), action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: - Actions

    @objc private func toggleCleaning() {
        let session = CleaningSession.shared
        if session.isRunning {
            session.stop()
            return
        }
        guard AXIsProcessTrusted() else {
            askForAccessibility()
            return
        }
        session.start()
    }

    @objc private func setAutoUnlock(_ sender: NSMenuItem) {
        Settings.shared.autoUnlockMinutes = sender.tag
    }


    @objc private func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
    }

    @objc private func showAbout() {
        present(
            title: L.t("about.title"),
            text: L.f(
                "about.body",
                CleaningSession.unlockKeyLabel,
                L.decimal(Settings.shared.holdSeconds)
            )
        )
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Dialogs

    private func askForAccessibility() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L.t("permission.title")
        alert.informativeText = L.t("permission.body")
        alert.addButton(withTitle: L.t("permission.open"))
        alert.addButton(withTitle: L.t("permission.continue"))
        alert.addButton(withTitle: L.t("permission.cancel"))

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            requestAccessibility()
        case .alertSecondButtonReturn:
            CleaningSession.shared.start()
        default:
            break
        }
    }

    private func present(title: String, text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.addButton(withTitle: L.t("alert.ok"))
        alert.runModal()
    }
}
