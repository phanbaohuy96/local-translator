import AppKit
import SwiftUI

@MainActor
final class TranslatorPanelController {
    private let viewModel: TranslationViewModel
    private var panel: NSPanel?

    init(viewModel: TranslationViewModel) {
        self.viewModel = viewModel
    }

    func show() {
        let panel = existingOrNewPanel()
        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    private func existingOrNewPanel() -> NSPanel {
        if let panel {
            return panel
        }

        let rootView = TranslatorView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: rootView)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Local Translator"
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.contentView = hostingView
        panel.minSize = NSSize(width: 520, height: 420)
        self.panel = panel
        return panel
    }
}
