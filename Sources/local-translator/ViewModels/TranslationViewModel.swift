import AppKit
import Foundation

@MainActor
final class TranslationViewModel: ObservableObject {
    @Published var sourceText = ""
    @Published var englishText = ""
    @Published var vietnameseText = ""
    @Published var rawOutput = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var model: String {
        didSet {
            UserDefaults.standard.set(model, forKey: Self.modelDefaultsKey)
        }
    }

    let historyService: ClipboardHistoryService

    private let selectionService: SelectionCapturing
    private let translator: OllamaTranslating
    private var activeTranslationID: UUID?
    private var translationTask: Task<Void, Never>?
    private static let modelDefaultsKey = "ollamaModel"

    init(
        selectionService: SelectionCapturing,
        historyService: ClipboardHistoryService,
        translator: OllamaTranslating
    ) {
        self.selectionService = selectionService
        self.historyService = historyService
        self.translator = translator
        self.model = UserDefaults.standard.string(forKey: Self.modelDefaultsKey) ?? "qwen2.5:7b"
    }

    func captureAndTranslate() async {
        guard let captured = await captureInput() else {
            return
        }

        await translate(captured)
    }

    func captureInput() async -> String? {
        guard !isLoading else { return nil }

        guard let captured = await selectionService.captureText(), !captured.isEmpty else {
            clearOutput()
            errorMessage = "No selected text or clipboard text was found."
            return nil
        }

        sourceText = captured
        errorMessage = nil
        return captured
    }

    func translateHistoryItem(_ text: String) {
        Task {
            await translate(text)
        }
    }

    func translate(_ text: String) async {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        translationTask?.cancel()

        guard !input.isEmpty else {
            clearOutput()
            errorMessage = "Enter or copy text before translating."
            activeTranslationID = nil
            translationTask = nil
            return
        }

        let translationID = UUID()
        activeTranslationID = translationID
        sourceText = input
        historyService.add(input)
        isLoading = true
        errorMessage = nil
        rawOutput = ""
        englishText = ""
        vietnameseText = ""

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.runTranslation(input, translationID: translationID)
        }
        translationTask = task

        await task.value

        if activeTranslationID == translationID {
            translationTask = nil
        }
    }

    func copyVietnameseToClipboard() {
        let text = vietnameseText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func clearOutput() {
        sourceText = ""
        englishText = ""
        vietnameseText = ""
        rawOutput = ""
        isLoading = false
    }

    private func runTranslation(_ input: String, translationID: UUID) async {
        do {
            let finalOutput = try await translator.translate(text: input, model: model) { [weak self] token in
                await MainActor.run {
                    guard let self, self.activeTranslationID == translationID, !Task.isCancelled else {
                        return
                    }
                    self.rawOutput += token
                    self.applySections(from: self.rawOutput)
                }
            }

            guard activeTranslationID == translationID, !Task.isCancelled else {
                return
            }

            rawOutput = finalOutput
            applySections(from: finalOutput)
            isLoading = false
        } catch is CancellationError {
            if activeTranslationID == translationID {
                isLoading = false
            }
        } catch {
            guard activeTranslationID == translationID else {
                return
            }

            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            isLoading = false
        }
    }

    private func applySections(from output: String) {
        let sections = TranslationSections.parse(output)
        englishText = sections.english
        vietnameseText = sections.vietnamese
    }
}

struct TranslationSections: Equatable {
    let english: String
    let vietnamese: String

    static func parse(_ output: String) -> TranslationSections {
        let englishMarker = "English:"
        let vietnameseMarker = "Vietnamese:"

        guard let englishRange = output.range(of: englishMarker, options: [.caseInsensitive]) else {
            return TranslationSections(english: output.trimmingCharacters(in: .whitespacesAndNewlines), vietnamese: "")
        }

        let afterEnglish = output[englishRange.upperBound...]

        guard let vietnameseRange = afterEnglish.range(of: vietnameseMarker, options: [.caseInsensitive]) else {
            return TranslationSections(
                english: String(afterEnglish).trimmingCharacters(in: .whitespacesAndNewlines),
                vietnamese: ""
            )
        }

        return TranslationSections(
            english: String(afterEnglish[..<vietnameseRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines),
            vietnamese: String(afterEnglish[vietnameseRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
