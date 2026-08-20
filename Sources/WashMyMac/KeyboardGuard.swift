import AppKit
import CoreGraphics

/// System-wide input interception through CGEventTap.
/// Needs Accessibility permission; without it `start()` returns false and the
/// app falls back to window-level interception.
final class KeyboardGuard {

    /// Returns true when the event has to be swallowed.
    var handler: ((CGEventType, CGEvent) -> Bool)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    /// Everything a cloth can produce: keys, mouse, trackpad, gestures, media keys.
    private static let watchedTypes: [UInt32] = [
        UInt32(CGEventType.keyDown.rawValue),
        UInt32(CGEventType.keyUp.rawValue),
        UInt32(CGEventType.flagsChanged.rawValue),
        UInt32(CGEventType.leftMouseDown.rawValue),
        UInt32(CGEventType.leftMouseUp.rawValue),
        UInt32(CGEventType.rightMouseDown.rawValue),
        UInt32(CGEventType.rightMouseUp.rawValue),
        UInt32(CGEventType.otherMouseDown.rawValue),
        UInt32(CGEventType.otherMouseUp.rawValue),
        UInt32(CGEventType.mouseMoved.rawValue),
        UInt32(CGEventType.leftMouseDragged.rawValue),
        UInt32(CGEventType.rightMouseDragged.rawValue),
        UInt32(CGEventType.otherMouseDragged.rawValue),
        UInt32(CGEventType.scrollWheel.rawValue),
        14, // NSEvent.EventType.systemDefined — media keys, volume
        18, // rotate
        19, // beginGesture
        20, // endGesture
        29, // gesture
        30, // magnify
        31, // swipe
        32, // smartMagnify
        34, // pressure
    ]

    var isActive: Bool { tap != nil }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        guard AXIsProcessTrusted() else { return false }

        var mask: CGEventMask = 0
        for type in Self.watchedTypes { mask |= (CGEventMask(1) << CGEventMask(type)) }

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let guardObject = Unmanaged<KeyboardGuard>.fromOpaque(refcon).takeUnretainedValue()
            return guardObject.process(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        self.source = source
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        source = nil
    }

    private func process(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // The system disables the tap if the callback stalls. Turn it back on.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let swallow = handler?(type, event) ?? false
        return swallow ? nil : Unmanaged.passUnretained(event)
    }
}
