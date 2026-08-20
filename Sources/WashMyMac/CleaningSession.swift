import AppKit
import Carbon.HIToolbox
import Combine
import SwiftUI

enum GuardMode {
    /// CGEventTap: everything is intercepted, ⌘Space, ⌘Tab and media keys included.
    case fullSystem
    /// Only events that reach our window. Some system shortcuts cannot be caught.
    case windowOnly
}

/// Cleaning mode: a black screen on every display, input blocked, exit by combination.
final class CleaningSession: ObservableObject {
    static let shared = CleaningSession()

    @Published private(set) var isRunning = false
    @Published private(set) var unlockProgress: Double = 0
    @Published private(set) var secondsLeft: Int = 0
    @Published private(set) var guardMode: GuardMode = .windowOnly
    @Published private(set) var hintVisible = true

    /// Unlock combination: ⌃⌥⌘U.
    static let unlockKeyCode = UInt16(kVK_ANSI_U)
    static let unlockKeyLabel = "U"

    /// How long ⌃⌥⌘ must be held to bring the hint back.
    static let recallDelay: TimeInterval = 0.35

    private struct Modifiers {
        var control = false
        var option = false
        var command = false
        var shift = false
    }

    private var windows: [OverlayWindow] = []
    private let inputGuard = KeyboardGuard()
    private var ticker: Timer?
    private var startedAt = Date()
    private var hintShownAt = Date()
    private var comboStartedAt: Date?
    private var modifiersHeldSince: Date?
    private let displayKeeper = DisplayKeeper()
    private var pressedKeys: Set<UInt16> = []
    private var modifiers = Modifiers()
    private var activityToken: NSObjectProtocol?
    private var savedPresentation: NSApplication.PresentationOptions = []
    private var screenObserver: NSObjectProtocol?
    private var didHideCursor = false

    private init() {}

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }

        isRunning = true
        startedAt = Date()
        hintShownAt = Date()
        comboStartedAt = nil
        modifiersHeldSince = nil
        pressedKeys = []
        modifiers = Modifiers()
        unlockProgress = 0
        hintVisible = true
        secondsLeft = Settings.shared.autoUnlockMinutes * 60

        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.idleDisplaySleepDisabled, .idleSystemSleepDisabled, .userInitiated],
            reason: "WashMyMac cleaning mode"
        )
        displayKeeper.start()

        NSApp.activate(ignoringOtherApps: true)
        buildWindows()

        inputGuard.handler = { [weak self] type, event in
            self?.handleTapEvent(type: type, event: event) ?? false
        }
        guardMode = inputGuard.start() ? .fullSystem : .windowOnly

        savedPresentation = NSApp.presentationOptions
        NSApp.presentationOptions = [
            .hideDock,
            .hideMenuBar,
            .disableProcessSwitching,
            .disableForceQuit,
            .disableSessionTermination,
            .disableHideApplication,
        ]

        NSCursor.hide()
        CGDisplayHideCursor(CGMainDisplayID())
        didHideCursor = true

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.buildWindows()
        }

        let ticker = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(ticker, forMode: .common)
        self.ticker = ticker
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false

        ticker?.invalidate()
        ticker = nil
        displayKeeper.stop()
        inputGuard.stop()
        inputGuard.handler = nil

        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }

        NSApp.presentationOptions = savedPresentation

        if didHideCursor {
            CGDisplayShowCursor(CGMainDisplayID())
            NSCursor.unhide()
            didHideCursor = false
        }

        if let activityToken {
            ProcessInfo.processInfo.endActivity(activityToken)
            self.activityToken = nil
        }

        let closing = windows
        windows = []
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            closing.forEach { $0.animator().alphaValue = 0 }
        } completionHandler: {
            closing.forEach { $0.orderOut(nil) }
        }

        unlockProgress = 0
        pressedKeys = []
        comboStartedAt = nil
        modifiersHeldSince = nil
    }

    func toggle() {
        isRunning ? stop() : start()
    }

    /// For `--preview` only: show the overlay without blocking any input.
    func configureForPreview(secondsLeft: Int, hintVisible: Bool, guardMode: GuardMode, unlockProgress: Double) {
        self.secondsLeft = secondsLeft
        self.hintVisible = hintVisible
        self.guardMode = guardMode
        self.unlockProgress = unlockProgress
    }

    // MARK: - Windows

    private func buildWindows() {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map { screen in
            let isPrimary = screen == NSScreen.main || screen == NSScreen.screens.first
            let window = OverlayWindow(screen: screen, isPrimary: isPrimary)
            window.alphaValue = 0
            window.orderFrontRegardless()
            return window
        }
        windows.first?.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            windows.forEach { $0.animator().alphaValue = 1 }
        }
    }

    // MARK: - Tick

    private func tick() {
        let now = Date()
        let elapsed = now.timeIntervalSince(startedAt)

        // ⌃⌥⌘ held with nothing else — bring the hint back.
        if let modifiersHeldSince, now.timeIntervalSince(modifiersHeldSince) > Self.recallDelay {
            hintShownAt = now
            hintVisible = true
        } else if hintVisible && now.timeIntervalSince(hintShownAt) > Settings.shared.hintSeconds {
            hintVisible = false
        }

        let total = TimeInterval(Settings.shared.autoUnlockMinutes * 60)
        let left = max(0, total - elapsed)
        let leftRounded = Int(ceil(left))
        if leftRounded != secondsLeft { secondsLeft = leftRounded }
        if left <= 0 {
            stop()
            return
        }

        var progress = 0.0
        if let comboStartedAt {
            progress = min(1, Date().timeIntervalSince(comboStartedAt) / Settings.shared.holdSeconds)
        }
        if abs(progress - unlockProgress) > 0.001 { unlockProgress = progress }
        if progress >= 1 { stop() }
    }

    // MARK: - Combination tracking

    /// The combination counts only when exactly ⌃⌥⌘ and the U key are down —
    /// not one extra key. A cloth always presses neighbouring keys, so it can
    /// never unlock the Mac by accident.
    private func refreshCombo() {
        let modifiersReady = modifiers.control
            && modifiers.option
            && modifiers.command
            && !modifiers.shift

        let matched = modifiersReady && pressedKeys == [Self.unlockKeyCode]
        if matched {
            if comboStartedAt == nil { comboStartedAt = Date() }
        } else {
            comboStartedAt = nil
        }

        // The same three modifiers with no key at all — the "show the hint" gesture.
        if modifiersReady && pressedKeys.isEmpty {
            if modifiersHeldSince == nil { modifiersHeldSince = Date() }
        } else {
            modifiersHeldSince = nil
        }
    }

    private func handleTapEvent(type: CGEventType, event: CGEvent) -> Bool {
        switch type {
        case .keyDown, .keyUp:
            apply(flags: event.flags)
            let code = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
            if type == .keyDown { pressedKeys.insert(code) } else { pressedKeys.remove(code) }
            refreshCombo()
        case .flagsChanged:
            apply(flags: event.flags)
            refreshCombo()
        default:
            break
        }
        return true // swallow everything
    }

    private func apply(flags: CGEventFlags) {
        modifiers.control = flags.contains(.maskControl)
        modifiers.option = flags.contains(.maskAlternate)
        modifiers.command = flags.contains(.maskCommand)
        modifiers.shift = flags.contains(.maskShift)
        if !modifiers.control || !modifiers.option || !modifiers.command {
            // A modifier went up, so this state can no longer unlock anything.
            // Rebuild the pressed-key set from scratch while we are at it.
            pressedKeys.removeAll()
        }
    }

    // MARK: - Fallback mode (window events)

    func windowKeyEvent(_ event: NSEvent, isDown: Bool) {
        guard isRunning else { return }
        apply(modifierFlags: event.modifierFlags)
        if isDown { pressedKeys.insert(event.keyCode) } else { pressedKeys.remove(event.keyCode) }
        refreshCombo()
    }

    func windowFlagsChanged(_ event: NSEvent) {
        guard isRunning else { return }
        apply(modifierFlags: event.modifierFlags)
        refreshCombo()
    }

    private func apply(modifierFlags: NSEvent.ModifierFlags) {
        modifiers.control = modifierFlags.contains(.control)
        modifiers.option = modifierFlags.contains(.option)
        modifiers.command = modifierFlags.contains(.command)
        modifiers.shift = modifierFlags.contains(.shift)
        if !modifiers.control || !modifiers.option || !modifiers.command {
            pressedKeys.removeAll()
        }
    }
}
