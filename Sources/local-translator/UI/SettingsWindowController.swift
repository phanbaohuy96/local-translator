import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let loginItemService: LoginItemService
    private let translationViewModel: TranslationViewModel
    private var window: NSWindow?

    init(loginItemService: LoginItemService, translationViewModel: TranslationViewModel) {
        self.loginItemService = loginItemService
        self.translationViewModel = translationViewModel
    }

    func show() {
        let window = existingOrNewWindow()
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func existingOrNewWindow() -> NSWindow {
        if let window {
            return window
        }

        let rootView = SettingsView(
            loginItemService: loginItemService,
            viewModel: translationViewModel
        )
        let hostingView = NSHostingView(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Local Translator Settings"
        window.contentView = hostingView
        self.window = window
        return window
    }
}
