import AppKit

@MainActor
final class AppCoordinator {
    private let loginItemService = LoginItemService()
    private let hotkeyService = HotkeyService()
    private let historyService = ClipboardHistoryService()
    private let selectionService = SelectionCaptureService()
    private let replacementService = SelectionReplacementService()
    private let ollamaClient = OllamaClient()

    private lazy var translationViewModel = TranslationViewModel(
        selectionService: selectionService,
        historyService: historyService,
        replacementService: replacementService,
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
        hotkeyService.onTranslateHotkey = { [weak self] in
            self?.openTranslatorAndCapture()
        }
        hotkeyService.onRewriteHotkey = { [weak self] in
            self?.openTranslatorAndRewrite()
        }
        hotkeyService.registerHotkeys()
    }

    private func showTranslator() {
        translatorPanelController.show()
    }

    private func openTranslatorAndCapture() {
        Task { @MainActor in
            let capturedText = await translationViewModel.captureInput()
            showTranslator()

            if let capturedText {
                await translationViewModel.translate(capturedText, preserveReplacementEligibility: true)
            }
        }
    }

    private func openTranslatorAndRewrite() {
        Task { @MainActor in
            let capturedText = await translationViewModel.captureInput()
            showTranslator()

            if capturedText != nil {
                await translationViewModel.rewriteCurrentSource()
            }
        }
    }

    private func showSettings() {
        settingsWindowController.show()
    }
}
