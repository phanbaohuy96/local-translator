import Foundation

protocol OllamaTranslating {
    func translate(
        text: String,
        model: String,
        onToken: @escaping (String) async -> Void
    ) async throws -> String
}

enum OllamaClientError: LocalizedError, Equatable {
    case invalidResponse
    case serverError(Int)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Ollama returned an invalid response."
        case .serverError(let status):
            return "Ollama returned HTTP \(status). Check that Ollama is running and the model is installed."
        case .emptyResponse:
            return "Ollama returned no translation."
        }
    }
}

struct TranslationPrompt {
    static func messages(for text: String) -> [OllamaMessage] {
        [
            OllamaMessage(
                role: "system",
                content: """
                You are a local translation assistant. Translate the user's text into Vietnamese and explain the English meaning briefly.
                Return concise plain text with exactly these labels:
                English:
                Vietnamese:
                Keep English to short meaning and usage notes. Keep Vietnamese natural and accurate.
                """
            ),
            OllamaMessage(role: "user", content: text)
        ]
    }
}

final class OllamaClient: OllamaTranslating {
    private let endpoint: URL
    private let session: URLSession

    init(
        endpoint: URL = URL(string: "http://localhost:11434/api/chat")!,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.session = session
    }

    func translate(
        text: String,
        model: String,
        onToken: @escaping (String) async -> Void
    ) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONEncoder().encode(
            OllamaChatRequest(
                model: model,
                messages: TranslationPrompt.messages(for: text),
                stream: true
            )
        )

        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw OllamaClientError.serverError(httpResponse.statusCode)
        }

        var output = ""

        for try await line in bytes.lines {
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            let chunk = try JSONDecoder().decode(OllamaChatChunk.self, from: Data(line.utf8))
            if let content = chunk.message?.content, !content.isEmpty {
                output += content
                await onToken(content)
            }

            if chunk.done {
                break
            }
        }

        guard !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OllamaClientError.emptyResponse
        }

        return output
    }
}

struct OllamaChatRequest: Codable, Equatable {
    let model: String
    let messages: [OllamaMessage]
    let stream: Bool
}

struct OllamaMessage: Codable, Equatable {
    let role: String
    let content: String
}

private struct OllamaChatChunk: Decodable {
    let message: OllamaMessage?
    let done: Bool
}
