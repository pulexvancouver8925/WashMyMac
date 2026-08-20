import AppKit
import Carbon.HIToolbox

/// Global shortcut that starts cleaning mode.
/// Carbon hot keys work without Accessibility permission.
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var handlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var action: (() -> Void)?

    private init() {}

    /// ⌃⌥⌘W
    func register(action: @escaping () -> Void) {
        self.action = action
        guard hotKeyRef == nil else { return }

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, event, _ in
            guard let event else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &id
            )
            guard status == noErr else { return status }
            HotKeyCenter.shared.fire(id: id.id)
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &spec, nil, &handlerRef)

        let hotKeyID = EventHotKeyID(signature: OSType(0x574D4D43), id: 1) // 'WMMC'
        RegisterEventHotKey(
            UInt32(kVK_ANSI_W),
            UInt32(controlKey | optionKey | cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    fileprivate func fire(id: UInt32) {
        guard id == 1 else { return }
        DispatchQueue.main.async { [weak self] in self?.action?() }
    }
}
