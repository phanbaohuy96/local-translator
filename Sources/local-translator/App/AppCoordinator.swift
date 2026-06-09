import AppKit

@MainActor
final class AppCoordinator {
    private let loginItemService = LoginItemService()
    private let hotkeyService = HotkeyService()
    private let historyService = ClipboardHistoryService()
    private let selectionService = SelectionCaptureService()
    private let ollamaClient = OllamaClient()

    private lazy var translationViewModel = TranslationViewModel(
        selectionService: selectionService,
        historyService: historyService,
        translator: ollamaClient
    )

    private lazy var statusBarController = StatusBarController(
        loginItemService: loginItemService,
        onOpenTranslator: { [weak self] in
            self?.openTranslatorAndCapture()
        },
        onOpenHistory: { [weak self] in
            self?.showTranslator()
        },
        onOpenSettings: { [weak self] in
            self?.showSettings()
        },
        onQuit: {
            NSApp.terminate(nil)
        }
    )

    private lazy var translatorPanelController = TranslatorPanelController(
        viewModel: translationViewModel
    )

    private lazy var settingsWindowController = SettingsWindowController(
        loginItemService: loginItemService,
        translationViewModel: translationViewModel
    )

    func start() {
        statusBarController.install()
        hotkeyService.onHotkey = { [weak self] in
            self?.openTranslatorAndCapture()
        }
        hotkeyService.registerOptionSpace()
    }

    private func showTranslator() {
        translatorPanelController.show()
    }

    private func openTranslatorAndCapture() {
        Task { @MainActor in
            let capturedText = await translationViewModel.captureInput()
            showTranslator()

            if let capturedText {
                await translationViewModel.translate(capturedText)
            }
        }
    }

    private func showSettings() {
        settingsWindowController.show()
    }
}
