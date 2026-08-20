import AppKit

let application = NSApplication.shared

if CommandLine.arguments.contains("--preview") {
    // Design showcase: an ordinary window, no input blocking.
    let previewDelegate = PreviewDelegate()
    application.delegate = previewDelegate
    application.setActivationPolicy(.regular)
    application.run()
} else {
    let delegate = AppDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.accessory)
    application.run()
}
