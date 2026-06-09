import AppKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let loginItemService: LoginItemService
    private let onOpenTranslator: () -> Void
    private let onOpenHistory: () -> Void
    private let onOpenSettings: () -> Void
    private let onQuit: () -> Void

    private let openItem = NSMenuItem(title: "Open Translator", action: #selector(openTranslator), keyEquivalent: "")
    private let historyItem = NSMenuItem(title: "Clipboard History", action: #selector(openHistory), keyEquivalent: "")
    private let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: "")
    private let startAtLoginItem = NSMenuItem(title: "Start at Login", action: #selector(toggleStartAtLogin), keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")

    init(
        loginItemService: LoginItemService,
        onOpenTranslator: @escaping () -> Void,
        onOpenHistory: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.loginItemService = loginItemService
        self.onOpenTranslator = onOpenTranslator
        self.onOpenHistory = onOpenHistory
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
        super.init()
    }

    func install() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "globe.asia.australia", accessibilityDescription: "Local Translator")
            button.imagePosition = .imageOnly
        }

        for item in [openItem, historyItem, settingsItem, startAtLoginItem, quitItem] {
            item.target = self
        }

        menu.delegate = self
        menu.addItem(openItem)
        menu.addItem(historyItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(settingsItem)
        menu.addItem(startAtLoginItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        startAtLoginItem.state = loginItemService.isEnabled ? .on : .off
        startAtLoginItem.toolTip = loginItemService.statusDescription
    }

    @objc private func openTranslator() {
        onOpenTranslator()
    }

    @objc private func openHistory() {
        onOpenHistory()
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func toggleStartAtLogin() {
        loginItemService.toggle()
    }

    @objc private func quit() {
        onQuit()
    }
}
