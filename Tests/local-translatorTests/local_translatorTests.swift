import Foundation
import Testing
@testable import local_translator

@Test func promptConstructionUsesExpectedModelRolesAndLabels() {
    let messages = TranslationPrompt.messages(for: "hello")

    #expect(messages.count == 2)
    #expect(messages[0].role == "system")
    #expect(messages[0].content.contains("English:"))
    #expect(messages[0].content.contains("Vietnamese:"))
    #expect(messages[1] == OllamaMessage(role: "user", content: "hello"))
}

@MainActor
@Test func clipboardHistoryDeduplicatesMovesToTopAndCapsAtLimit() {
    let history = ClipboardHistoryService(limit: 3)

    history.add(" one ")
    history.add("two")
    history.add("three")
    history.add("two")
    history.add("four")

    #expect(history.items == ["four", "two", "three"])
}

@MainActor
@Test func emptyCaptureDoesNotCallTranslatorAndShowsReadableError() async {
    let translator = FakeTranslator()
    let viewModel = TranslationViewModel(
        selectionService: FakeSelection(text: nil),
        historyService: ClipboardHistoryService(),
        translator: translator
    )

    await viewModel.captureAndTranslate()

    #expect(translator.calls.isEmpty)
    #expect(viewModel.errorMessage == "No selected text or clipboard text was found.")
    #expect(!viewModel.isLoading)
}

@MainActor
@Test func ollamaErrorIsSurfacedAndHistoryStillRecordsInput() async {
    let translator = FakeTranslator(error: OllamaClientError.serverError(404))
    let history = ClipboardHistoryService()
    let viewModel = TranslationViewModel(
        selectionService: FakeSelection(text: "Hello"),
        historyService: history,
        translator: translator
    )

    await viewModel.captureAndTranslate()

    #expect(translator.calls == ["Hello"])
    #expect(history.items == ["Hello"])
    #expect(viewModel.errorMessage == "Ollama returned HTTP 404. Check that Ollama is running and the model is installed.")
    #expect(!viewModel.isLoading)
}

@MainActor
@Test func streamedTranslationUpdatesSections() async {
    let translator = FakeTranslator(tokens: [
        "English:\nGreeting",
        "\nVietnamese:\nXin chao"
    ])
    let viewModel = TranslationViewModel(
        selectionService: FakeSelection(text: "Hello"),
        historyService: ClipboardHistoryService(),
        translator: translator
    )

    await viewModel.captureAndTranslate()

    #expect(viewModel.englishText == "Greeting")
    #expect(viewModel.vietnameseText == "Xin chao")
    #expect(viewModel.rawOutput == "English:\nGreeting\nVietnamese:\nXin chao")
}

@MainActor
@Test func translateUsesCurrentModelValue() async {
    let translator = FakeTranslator(tokens: [
        "English:\nGreeting\nVietnamese:\nXin chao"
    ])
    let viewModel = TranslationViewModel(
        selectionService: FakeSelection(text: "Hello"),
        historyService: ClipboardHistoryService(),
        translator: translator
    )
    viewModel.model = "custom-model"

    await viewModel.captureAndTranslate()

    #expect(translator.models == ["custom-model"])
}

@MainActor
@Test func newerTranslationWinsWhenRequestsOverlap() async {
    let translator = DelayedTranslator()
    let viewModel = TranslationViewModel(
        selectionService: FakeSelection(text: nil),
        historyService: ClipboardHistoryService(),
        translator: translator
    )

    let first = Task {
        await viewModel.translate("first")
    }
    try? await Task.sleep(nanoseconds: 20_000_000)
    await viewModel.translate("second")
    await first.value

    #expect(translator.calls == ["first", "second"])
    #expect(viewModel.sourceText == "second")
    #expect(viewModel.englishText == "second English")
    #expect(viewModel.vietnameseText == "second Vietnamese")
    #expect(!viewModel.rawOutput.contains("first English"))
    #expect(!viewModel.isLoading)
}

private struct FakeSelection: SelectionCapturing {
    let text: String?

    func captureText() async -> String? {
        text
    }
}

private final class FakeTranslator: OllamaTranslating {
    private(set) var calls: [String] = []
    private(set) var models: [String] = []
    let tokens: [String]
    let error: Error?

    init(tokens: [String] = [], error: Error? = nil) {
        self.tokens = tokens
        self.error = error
    }

    func translate(
        text: String,
        model: String,
        onToken: @escaping (String) async -> Void
    ) async throws -> String {
        calls.append(text)
        models.append(model)

        if let error {
            throw error
        }

        var output = ""
        for token in tokens {
            output += token
            await onToken(token)
        }
        return output
    }
}

private final class DelayedTranslator: OllamaTranslating {
    private(set) var calls: [String] = []

    func translate(
        text: String,
        model: String,
        onToken: @escaping (String) async -> Void
    ) async throws -> String {
        calls.append(text)

        if text == "first" {
            try await Task.sleep(nanoseconds: 200_000_000)
        } else {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        let output = "English:\n\(text) English\nVietnamese:\n\(text) Vietnamese"
        await onToken(output)
        return output
    }
}
