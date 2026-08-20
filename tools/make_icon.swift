// Draws the app icon and assembles AppIcon.icns.
// Usage: swift tools/make_icon.swift <output.icns>
//
// The subject: a black screen on a blue plate — exactly what the app does.
import AppKit
import Foundation

/// A four-pointed sparkle with concave sides.
func sparkle(center: NSPoint, radius: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    let waist = radius * 0.26
    let top = NSPoint(x: center.x, y: center.y + radius)
    let right = NSPoint(x: center.x + radius, y: center.y)
    let bottom = NSPoint(x: center.x, y: center.y - radius)
    let left = NSPoint(x: center.x - radius, y: center.y)

    path.move(to: top)
    path.curve(to: right,
               controlPoint1: NSPoint(x: center.x + waist, y: center.y + waist),
               controlPoint2: NSPoint(x: center.x + waist, y: center.y + waist))
    path.curve(to: bottom,
               controlPoint1: NSPoint(x: center.x + waist, y: center.y - waist),
               controlPoint2: NSPoint(x: center.x + waist, y: center.y - waist))
    path.curve(to: left,
               controlPoint1: NSPoint(x: center.x - waist, y: center.y - waist),
               controlPoint2: NSPoint(x: center.x - waist, y: center.y - waist))
    path.curve(to: top,
               controlPoint1: NSPoint(x: center.x - waist, y: center.y + waist),
               controlPoint2: NSPoint(x: center.x - waist, y: center.y + waist))
    path.close()
    return path
}

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high

    // --- Plate -----------------------------------------------------------
    let inset = size * 0.088
    let plate = NSRect(x: inset, y: inset * 1.15, width: size - inset * 2, height: size - inset * 2)
    let radius = plate.width * 0.2237 // the macOS squircle ratio
    let plateShape = NSBezierPath(roundedRect: plate, xRadius: radius, yRadius: radius)

    NSGraphicsContext.saveGraphicsState()
    let plateShadow = NSShadow()
    plateShadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    plateShadow.shadowBlurRadius = size * 0.045
    plateShadow.shadowOffset = NSSize(width: 0, height: -size * 0.018)
    plateShadow.set()
    NSColor.black.setFill()
    plateShape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: [
        NSColor(calibratedRed: 0.47, green: 0.73, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 0.13, green: 0.29, blue: 0.85, alpha: 1),
    ])?.draw(in: plateShape, angle: -90)

    // Highlight from a light source at the top left.
    NSGraphicsContext.saveGraphicsState()
    plateShape.addClip()
    NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.30),
        NSColor.white.withAlphaComponent(0.0),
    ])?.draw(
        fromCenter: NSPoint(x: plate.minX + plate.width * 0.2, y: plate.maxY),
        radius: 0,
        toCenter: NSPoint(x: plate.minX + plate.width * 0.2, y: plate.maxY),
        radius: plate.width * 0.85,
        options: []
    )
    NSGraphicsContext.restoreGraphicsState()

    NSColor.white.withAlphaComponent(0.20).setStroke()
    plateShape.lineWidth = max(1, size * 0.005)
    plateShape.stroke()

    // --- MacBook ---------------------------------------------------------
    let lidWidth = plate.width * 0.545
    let lidHeight = lidWidth * 0.625
    let baseHeight = plate.height * 0.043
    let stackHeight = lidHeight + baseHeight
    let lid = NSRect(
        x: plate.midX - lidWidth / 2,
        y: plate.midY - stackHeight / 2 + baseHeight,
        width: lidWidth,
        height: lidHeight
    )
    let lidShape = NSBezierPath(
        roundedRect: lid,
        xRadius: lidWidth * 0.055,
        yRadius: lidWidth * 0.055
    )

    NSGraphicsContext.saveGraphicsState()
    let lidShadow = NSShadow()
    lidShadow.shadowColor = NSColor.black.withAlphaComponent(0.42)
    lidShadow.shadowBlurRadius = size * 0.03
    lidShadow.shadowOffset = NSSize(width: 0, height: -size * 0.014)
    lidShadow.set()
    NSColor.black.setFill()
    lidShape.fill()
    NSGraphicsContext.restoreGraphicsState()

    // The lid casing.
    NSGradient(colors: [
        NSColor(calibratedWhite: 0.30, alpha: 1),
        NSColor(calibratedWhite: 0.17, alpha: 1),
    ])?.draw(in: lidShape, angle: -90)

    // The screen itself — black, the whole point of the app.
    let bezel = lidWidth * 0.035
    let screen = lid.insetBy(dx: bezel, dy: bezel)
    let screenShape = NSBezierPath(
        roundedRect: screen,
        xRadius: lidWidth * 0.028,
        yRadius: lidWidth * 0.028
    )
    NSGradient(colors: [
        NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.10, alpha: 1),
        NSColor(calibratedRed: 0.01, green: 0.01, blue: 0.02, alpha: 1),
    ])?.draw(in: screenShape, angle: -90)

    // A diagonal band of glare across the glass.
    NSGraphicsContext.saveGraphicsState()
    screenShape.addClip()
    NSGradient(colorsAndLocations:
        (NSColor.white.withAlphaComponent(0.0), 0.0),
        (NSColor.white.withAlphaComponent(0.0), 0.28),
        (NSColor.white.withAlphaComponent(0.11), 0.42),
        (NSColor.white.withAlphaComponent(0.11), 0.50),
        (NSColor.white.withAlphaComponent(0.0), 0.64),
        (NSColor.white.withAlphaComponent(0.0), 1.0)
    )?.draw(in: screen.insetBy(dx: -screen.width * 0.4, dy: -screen.height * 0.4), angle: 58)
    NSGraphicsContext.restoreGraphicsState()

    // The base with the finger notch.
    let base = NSRect(
        x: lid.minX - lidWidth * 0.075,
        y: lid.minY - baseHeight,
        width: lidWidth * 1.15,
        height: baseHeight
    )
    let baseShape = NSBezierPath(
        roundedRect: base,
        xRadius: baseHeight * 0.42,
        yRadius: baseHeight * 0.42
    )
    NSGraphicsContext.saveGraphicsState()
    let baseShadow = NSShadow()
    baseShadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    baseShadow.shadowBlurRadius = size * 0.022
    baseShadow.shadowOffset = NSSize(width: 0, height: -size * 0.008)
    baseShadow.set()
    NSColor.black.setFill()
    baseShape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: [
        NSColor(calibratedWhite: 0.90, alpha: 1),
        NSColor(calibratedWhite: 0.62, alpha: 1),
    ])?.draw(in: baseShape, angle: -90)

    let notchWidth = lidWidth * 0.16
    let notch = NSBezierPath(
        roundedRect: NSRect(
            x: base.midX - notchWidth / 2,
            y: base.minY,
            width: notchWidth,
            height: baseHeight * 0.42
        ),
        xRadius: baseHeight * 0.2,
        yRadius: baseHeight * 0.2
    )
    NSColor(calibratedWhite: 0.42, alpha: 1).setFill()
    notch.fill()

    // --- Sparkles ---------------------------------------------------------
    NSGraphicsContext.saveGraphicsState()
    let glow = NSShadow()
    glow.shadowColor = NSColor.white.withAlphaComponent(0.5)
    glow.shadowBlurRadius = size * 0.032
    glow.shadowOffset = .zero
    glow.set()
    NSColor.white.setFill()
    sparkle(
        center: NSPoint(x: lid.maxX - lid.width * 0.04, y: lid.maxY - lid.height * 0.05),
        radius: plate.width * 0.125
    ).fill()
    NSGraphicsContext.restoreGraphicsState()

    NSColor.white.withAlphaComponent(0.9).setFill()
    sparkle(
        center: NSPoint(x: lid.maxX - lid.width * 0.26, y: lid.maxY + lid.height * 0.13),
        radius: plate.width * 0.05
    ).fill()

    image.unlockFocus()
    return image
}

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.icns"
let iconset = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("WashMyMac-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let variants: [(Int, String)] = [
    (16, "icon_16x16"), (32, "icon_16x16@2x"),
    (32, "icon_32x32"), (64, "icon_32x32@2x"),
    (128, "icon_128x128"), (256, "icon_128x128@2x"),
    (256, "icon_256x256"), (512, "icon_256x256@2x"),
    (512, "icon_512x512"), (1024, "icon_512x512@2x"),
]

for (pixels, name) in variants {
    let image = drawIcon(size: CGFloat(pixels))
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    try png.write(to: iconset.appendingPathComponent("\(name).png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
exit(iconutil.terminationStatus)
