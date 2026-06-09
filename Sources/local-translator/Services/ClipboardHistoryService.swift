import Foundation

@MainActor
final class ClipboardHistoryService: ObservableObject {
    @Published private(set) var items: [String] = []

    private let limit: Int

    init(limit: Int = 20) {
        self.limit = limit
    }

    func add(_ text: String) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        items.removeAll { $0 == normalized }
        items.insert(normalized, at: 0)

        if items.count > limit {
            items = Array(items.prefix(limit))
        }
    }
}
