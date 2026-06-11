import AppKit
import ApplicationServices

protocol SelectionCapturing {
    func captureText() async -> CapturedText?
}

struct CapturedText: Equatable {
    let text: String
    let source: CaptureSource
}

enum CaptureSource: Equatable {
    case selection
    case clipboard
}

struct PasteboardSnapshot {
    let items: [[NSPasteboard.PasteboardType: Data]]
}

final class SelectionCaptureService: SelectionCapturing {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    func captureText() async -> CapturedText? {
        let snapshot = savePasteboard()
        let clipboardFallback = pasteboard.string(forType: .string)

        if Self.isAccessibilityTrusted {
            pasteboard.clearContents()
            sendCopyShortcut()
            try? await Task.sleep(nanoseconds: 180_000_000)

            let selectedText = pasteboard.string(forType: .string)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            restorePasteboard(snapshot)

            if let selectedText, !selectedText.isEmpty {
                return CapturedText(text: selectedText, source: .selection)
            }
        }

        restorePasteboard(snapshot)
        return clipboardFallback?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
            .map { CapturedText(text: $0, source: .clipboard) }
    }

    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
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

    private func sendCopyShortcut() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let cKey: CGKeyCode = 8

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: cKey, keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: cKey, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
