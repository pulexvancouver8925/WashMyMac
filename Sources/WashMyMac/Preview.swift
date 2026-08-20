import AppKit
import SwiftUI

/// Debug mode `--preview`: draws the overlay in an ordinary window so the
/// design can be reviewed without blocking anything.
final class PreviewDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let arguments = CommandLine.arguments
        let unlocking = arguments.contains("--unlocking")
        let degraded = arguments.contains("--degraded")

        CleaningSession.shared.configureForPreview(
            secondsLeft: 293,
            hintVisible: !arguments.contains("--beacon"),
            guardMode: degraded ? .windowOnly : .fullSystem,
            unlockProgress: unlocking ? 0.62 : 0
        )

        let frame = NSRect(x: 80, y: 80, width: 1200, height: 760)
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "WashMyMac — preview"
        window.backgroundColor = .black
        window.contentView = NSHostingView(
            rootView: OverlayView(session: .shared, isPrimary: true)
        )
        window.setFrameOrigin(NSPoint(x: 80, y: 80))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}
