import AppKit
import SwiftUI

/// A window above everything, menu bar and Dock included: screen-saver level.
final class OverlayWindow: NSWindow {

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    init(screen: NSScreen, isPrimary: Bool) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        backgroundColor = .black
        isOpaque = true
        hasShadow = false
        isMovable = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        let hosting = NSHostingView(rootView: OverlayView(session: .shared, isPrimary: isPrimary))
        hosting.frame = CGRect(origin: .zero, size: screen.frame.size)
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting

        setFrame(screen.frame, display: true)
    }

    // Anything that reaches the window (the no-Accessibility mode) is tracked and swallowed.

    override func keyDown(with event: NSEvent) {
        CleaningSession.shared.windowKeyEvent(event, isDown: true)
    }

    override func keyUp(with event: NSEvent) {
        CleaningSession.shared.windowKeyEvent(event, isDown: false)
    }

    override func flagsChanged(with event: NSEvent) {
        CleaningSession.shared.windowFlagsChanged(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        CleaningSession.shared.windowKeyEvent(event, isDown: true)
        return true // do not let ⌘ shortcuts through
    }

    override func cancelOperation(_ sender: Any?) {
        // Esc does nothing: the combination is the only way out.
    }

    override func mouseDown(with event: NSEvent) {}
    override func rightMouseDown(with event: NSEvent) {}
    override func otherMouseDown(with event: NSEvent) {}
    override func scrollWheel(with event: NSEvent) {}
}
