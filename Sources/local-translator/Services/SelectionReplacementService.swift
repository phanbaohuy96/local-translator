import AppKit

@MainActor
protocol SelectionReplacing: AnyObject {
    func rememberCurrentSourceApplication()
    func clearSourceApplication()
    func replaceSelection(with text: String) async throws
}

enum SelectionReplacementError: LocalizedError, Equatable {
    case emptyText
    case noSourceApplication
    case sourceApplicationUnavailable

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "No rewritten text is available to replace the selection."
        case .noSourceApplication:
            return "No source app is available for replacing selected text."
        case .sourceApplicationUnavailable:
            return "The source app could not be activated for replacement."
        }
    }
}

@MainActor
final class SelectionReplacementService: SelectionReplacing {
    private let pasteboard: NSPasteboard
    private var sourceApplication: NSRunningApplication?

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    func rememberCurrentSourceApplication() {
        let application = NSWorkspace.shared.frontmostApplication

        if application?.bundleIdentifier == Bundle.main.bundleIdentifier {
            sourceApplication = nil
        } else {
            sourceApplication = application
        }
    }

    func clearSourceApplication() {
        sourceApplication = nil
    }

    func replaceSelection(with text: String) async throws {
        let replacement = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !replacement.isEmpty else {
            throw SelectionReplacementError.emptyText
        }

        guard let sourceApplication else {
            throw SelectionReplacementError.noSourceApplication
        }

        let snapshot = savePasteboard()
        pasteboard.clearContents()
        pasteboard.setString(replacement, forType: .string)

        guard sourceApplication.activate(options: [.activateIgnoringOtherApps]) else {
            restorePasteboard(snapshot)
            throw SelectionReplacementError.sourceApplicationUnavailable
        }

        try await Task.sleep(nanoseconds: 150_000_000)
        sendPasteShortcut()
        try await Task.sleep(nanoseconds: 200_000_000)
        restorePasteboard(snapshot)
    }

    private func savePasteboard() -> PasteboardSnapshot {
        let items = pasteboard.pasteboardItems?.map { item in
            item.types.reduce(into: [NSPasteboard.PasteboardType: Data]()) { result, type in
                result[type] = item.data(forType: type)
            }
        } ?? []

        return PasteboardSnapshot(items: items)
    }

    private func restorePasteboard(_ snapshot: PasteboardSnapshot) {
        pasteboard.clearContents()

        let restoredItems = snapshot.items.map { savedItem in
            let item = NSPasteboardItem()
            for (type, data) in savedItem {
                item.setData(data, forType: type)
            }
            return item
        }

        if !restoredItems.isEmpty {
            pasteboard.writeObjects(restoredItems)
        }
    }

    private func sendPasteShortcut() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
