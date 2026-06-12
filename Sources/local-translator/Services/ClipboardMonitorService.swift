import AppKit
import Foundation

protocol ClipboardTextReading: AnyObject {
    var changeCount: Int { get }
    func stringForHistory() -> String?
}

extension NSPasteboard: ClipboardTextReading {
    func stringForHistory() -> String? {
        string(forType: .string)
    }
}

@MainActor
final class ClipboardMonitorService {
    private let historyService: ClipboardHistoryService
    private let pasteboard: ClipboardTextReading
    private let interval: TimeInterval
    private var observedChangeCount: Int
    private var timer: Timer?

    init(
        historyService: ClipboardHistoryService,
        pasteboard: ClipboardTextReading = NSPasteboard.general,
        interval: TimeInterval = 0.5
    ) {
        self.historyService = historyService
        self.pasteboard = pasteboard
        self.interval = interval
        self.observedChangeCount = pasteboard.changeCount
    }

    func start() {
        stop()
        recordCurrentText()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func poll() {
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != observedChangeCount else {
            return
        }

        observedChangeCount = currentChangeCount
        recordCurrentText()
    }

    private func recordCurrentText() {
        historyService.add(pasteboard.stringForHistory() ?? "")
    }
}
