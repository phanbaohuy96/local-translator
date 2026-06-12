import AppKit
import Foundation

@MainActor
final class TranslationViewModel: ObservableObject {
    @Published var sourceText = ""
    @Published var englishText = ""
    @Published var vietnameseText = ""
    @Published var rewriteText = ""
    @Published var rawOutput = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var outputMode: TranslationOutputMode = .none
    @Published var model: String {
        didSet {
            UserDefaults.standard.set(model, forKey: Self.modelDefaultsKey)
        }
    }

    let historyService: ClipboardHistoryService

    private let selectionService: SelectionCapturing
    private let replacementService: SelectionReplacing
    private let translator: OllamaTranslating
    private var activeOperationID: UUID?
    private var generationTask: Task<Void, Never>?
    private var rewriteSourceText = ""
    private var currentSourceSupportsReplacement = false
    private static let modelDefaultsKey = "ollamaModel"

    var canReplaceSelection: Bool {
        !isLoading
            && currentSourceSupportsReplacement
            && !rewriteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && rewriteSourceText == sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(
        selectionService: SelectionCapturing,
        historyService: ClipboardHistoryService,
        replacementService: SelectionReplacing,
        translator: OllamaTranslating
    ) {
        self.selectionService = selectionService
        self.historyService = historyService
        self.replacementService = replacementService
        self.translator = translator
        self.model = UserDefaults.standard.string(forKey: Self.modelDefaultsKey) ?? "qwen2.5:7b"
    }

    func captureAndTranslate() async {
        guard let captured = await captureInput() else {
            return
        }

        await translate(captured, preserveReplacementEligibility: true)
    }

    func captureInput() async -> String? {
        guard !isLoading else { return nil }

        replacementService.rememberCurrentSourceApplication()

        guard let captured = await selectionService.captureText(), !captured.text.isEmpty else {
            clearOutput()
            replacementService.clearSourceApplication()
            currentSourceSupportsReplacement = false
            errorMessage = "No selected text or clipboard text was found."
            return nil
        }

        sourceText = captured.text
        currentSourceSupportsReplacement = captured.source == .selection
        if !currentSourceSupportsReplacement {
            replacementService.clearSourceApplication()
        }
        errorMessage = nil
        return captured.text
    }

    func translateHistoryItem(_ text: String) {
        Task {
            await translate(text)
        }
    }

    func translate(_ text: String, preserveReplacementEligibility: Bool = false) async {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        generationTask?.cancel()

        guard !input.isEmpty else {
            clearOutput()
            errorMessage = "Enter or copy text before translating."
            activeOperationID = nil
            generationTask = nil
            return
        }

        let operationID = UUID()
        activeOperationID = operationID
        sourceText = input
        if !preserveReplacementEligibility {
            currentSourceSupportsReplacement = false
            replacementService.clearSourceApplication()
        }
        historyService.add(input)
        isLoading = true
        errorMessage = nil
        outputMode = .translation
        rawOutput = ""
        englishText = ""
        vietnameseText = ""
        rewriteText = ""
        rewriteSourceText = ""

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.runTranslation(input, operationID: operationID)
        }
        generationTask = task

        await task.value

        if activeOperationID == operationID {
            generationTask = nil
        }
    }

    func rewriteCurrentSource() async {
        let input = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        generationTask?.cancel()

        guard !input.isEmpty else {
            rewriteText = ""
            rewriteSourceText = ""
            errorMessage = "No source text is available to rewrite."
            activeOperationID = nil
            generationTask = nil
            return
        }

        let operationID = UUID()
        activeOperationID = operationID
        sourceText = input
        historyService.add(input)
        isLoading = true
        errorMessage = nil
        outputMode = .rewrite
        rawOutput = ""
        englishText = ""
        vietnameseText = ""
        rewriteText = ""
        rewriteSourceText = ""

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.runRewrite(input, operationID: operationID)
        }
        generationTask = task

        await task.value

        if activeOperationID == operationID {
            generationTask = nil
        }
    }

    func replaceSelectionWithRewrite() async {
        let output = rewriteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canReplaceSelection, !output.isEmpty else {
            errorMessage = "No rewritten text is available to replace the selection."
            return
        }

        do {
            try await replacementService.replaceSelection(with: output)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func copyVietnameseToClipboard() {
        copyToClipboard(vietnameseText)
    }

    func copyRewriteToClipboard() {
        copyToClipboard(rewriteText)
    }

    private func copyToClipboard(_ value: String) {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func clearOutput() {
        sourceText = ""
        englishText = ""
        vietnameseText = ""
        rewriteText = ""
        rewriteSourceText = ""
        currentSourceSupportsReplacement = false
        replacementService.clearSourceApplication()
        rawOutput = ""
        isLoading = false
        outputMode = .none
    }

    private func runTranslation(_ input: String, operationID: UUID) async {
        do {
            let finalOutput = try await translator.translate(text: input, model: model) { [weak self] token in
                await MainActor.run {
                    guard let self, self.activeOperationID == operationID, !Task.isCancelled else {
                        return
                    }
                    self.rawOutput += token
                    self.applySections(from: self.rawOutput)
                }
            }

            guard activeOperationID == operationID, !Task.isCancelled else {
                return
            }

            rawOutput = finalOutput
            applySections(from: finalOutput)
            isLoading = false
        } catch is CancellationError {
            if activeOperationID == operationID {
                isLoading = false
            }
        } catch {
            guard activeOperationID == operationID else {
                return
            }

            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            isLoading = false
        }
    }

    private func runRewrite(_ input: String, operationID: UUID) async {
        do {
            let finalOutput = try await translator.rewrite(text: input, model: model) { [weak self] token in
                await MainActor.run {
                    guard let self, self.activeOperationID == operationID, !Task.isCancelled else {
                        return
                    }
                    self.rewriteText += token
                }
            }

            guard activeOperationID == operationID, !Task.isCancelled else {
                return
            }

            rewriteText = finalOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            rewriteSourceText = input
            isLoading = false
        } catch is CancellationError {
            if activeOperationID == operationID {
                isLoading = false
            }
        } catch {
            guard activeOperationID == operationID else {
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
            guard let vietnameseRange = output.range(of: vietnameseMarker, options: [.caseInsensitive]) else {
                return TranslationSections(
                    english: "",
                    vietnamese: output.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }

            return TranslationSections(
                english: "",
                vietnamese: String(output[vietnameseRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            )
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

enum TranslationOutputMode {
    case none
    case translation
    case rewrite
}
