import Carbon
import Foundation

@MainActor
final class HotkeyService {
    var onTranslateHotkey: (() -> Void)?
    var onRewriteHotkey: (() -> Void)?

    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?

    func registerHotkeys() {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else {
                    return noErr
                }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr else {
                    return noErr
                }

                let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    switch Hotkey(rawValue: hotKeyID.id) {
                    case .translate:
                        service.onTranslateHotkey?()
                    case .rewrite:
                        service.onRewriteHotkey?()
                    case .none:
                        break
                    }
                }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )

        register(.translate, keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey))
        register(.rewrite, keyCode: UInt32(kVK_ANSI_R), modifiers: UInt32(optionKey | cmdKey))
    }

    func unregister() {
        for hotKeyRef in hotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRefs = []

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private func register(_ hotkey: Hotkey, keyCode: UInt32, modifiers: UInt32) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: hotkey.rawValue)

        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if let hotKeyRef {
            hotKeyRefs.append(hotKeyRef)
        }
    }

    private static let signature: OSType = 0x4C545250

    private enum Hotkey: UInt32 {
        case translate = 1
        case rewrite = 2
    }
}
