#!/usr/bin/env swift

import AppKit
import Foundation

final class PulseGlyphIconRenderer {
    private let pixelSize: CGFloat

    init(pixelSize: Int) {
        self.pixelSize = CGFloat(pixelSize)
    }

    func render() -> NSImage {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixelSize),
            pixelsHigh: Int(pixelSize),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        bitmap.size = NSSize(width: pixelSize, height: pixelSize)

        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        defer {
            context.flushGraphics()
            NSGraphicsContext.restoreGraphicsState()
        }

        NSGraphicsContext.current?.imageInterpolation = .high

        drawIconShadow()
        drawWhiteBase()
        drawSubtleRim()
        drawGaugeRing()
        drawGaugeFace()
        drawPulseWaveform()
        drawSpecularHighlights()

        let image = NSImage(size: bitmap.size)
        image.addRepresentation(bitmap)
        return image
    }

    private func drawIconShadow() {
        let shadowPath = NSBezierPath(
            roundedRect: rect(x: 78, y: 82, width: 868, height: 856),
            xRadius: scale(210),
            yRadius: scale(210)
        )

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(calibratedRed: 0.13, green: 0.22, blue: 0.28, alpha: 0.20)
        shadow.shadowBlurRadius = scale(52)
        shadow.shadowOffset = NSSize(width: 0, height: -scale(18))
        shadow.set()
        NSColor.black.withAlphaComponent(0.08).setFill()
        shadowPath.fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawWhiteBase() {
        let basePath = NSBezierPath(
            roundedRect: rect(x: 72, y: 84, width: 880, height: 856),
            xRadius: scale(216),
            yRadius: scale(216)
        )

        NSGradient(colors: [
            NSColor(calibratedRed: 1.00, green: 1.00, blue: 1.00, alpha: 1),
            NSColor(calibratedRed: 0.96, green: 0.985, blue: 1.00, alpha: 1),
            NSColor(calibratedRed: 0.90, green: 0.94, blue: 0.97, alpha: 1)
        ])?.draw(in: basePath, angle: -68)

        let upperGlow = NSBezierPath(
            roundedRect: rect(x: 118, y: 662, width: 788, height: 214),
            xRadius: scale(128),
            yRadius: scale(128)
        )
        NSGradient(colors: [
            NSColor.white.withAlphaComponent(0.72),
            NSColor.white.withAlphaComponent(0.02)
        ])?.draw(in: upperGlow, angle: -90)
    }

    private func drawSubtleRim() {
        let outer = NSBezierPath(
            roundedRect: rect(x: 72, y: 84, width: 880, height: 856),
            xRadius: scale(216),
            yRadius: scale(216)
        )
        NSColor(calibratedRed: 0.66, green: 0.74, blue: 0.80, alpha: 0.32).setStroke()
        outer.lineWidth = scale(4)
        outer.stroke()

        let inner = NSBezierPath(
            roundedRect: rect(x: 92, y: 106, width: 840, height: 812),
            xRadius: scale(194),
            yRadius: scale(194)
        )
        NSColor.white.withAlphaComponent(0.72).setStroke()
        inner.lineWidth = scale(3)
        inner.stroke()
    }

    private func drawGaugeRing() {
        let center = point(x: 512, y: 512)
        let radius = scale(310)
        let lineWidth = scale(62)

        NSGraphicsContext.saveGraphicsState()
        let ringShadow = NSShadow()
        ringShadow.shadowColor = NSColor(calibratedRed: 0.04, green: 0.32, blue: 0.48, alpha: 0.18)
        ringShadow.shadowBlurRadius = scale(28)
        ringShadow.shadowOffset = NSSize(width: 0, height: -scale(8))
        ringShadow.set()
        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        track.lineWidth = lineWidth
        track.lineCapStyle = .round
        NSColor(calibratedRed: 0.82, green: 0.88, blue: 0.92, alpha: 1).setStroke()
        track.stroke()
        NSGraphicsContext.restoreGraphicsState()

        strokeArc(start: 134, end: 222, center: center, radius: radius, lineWidth: lineWidth, color: NSColor(calibratedRed: 0.15, green: 0.58, blue: 0.98, alpha: 1))
        strokeArc(start: 222, end: 362, center: center, radius: radius, lineWidth: lineWidth, color: NSColor(calibratedRed: 0.35, green: 0.88, blue: 0.67, alpha: 1))

        let knobCenter = point(x: 820, y: 512)
        NSGraphicsContext.saveGraphicsState()
        let knobShadow = NSShadow()
        knobShadow.shadowColor = NSColor(calibratedRed: 0.05, green: 0.24, blue: 0.36, alpha: 0.26)
        knobShadow.shadowBlurRadius = scale(12)
        knobShadow.shadowOffset = NSSize(width: 0, height: -scale(3))
        knobShadow.set()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: knobCenter.x - scale(35), y: knobCenter.y - scale(35), width: scale(70), height: scale(70))).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawGaugeFace() {
        let face = NSBezierPath(ovalIn: rect(x: 240, y: 240, width: 544, height: 544))

        NSGradient(colors: [
            NSColor(calibratedRed: 0.08, green: 0.16, blue: 0.22, alpha: 1),
            NSColor(calibratedRed: 0.03, green: 0.08, blue: 0.13, alpha: 1)
        ])?.draw(in: face, angle: -72)

        NSColor.white.withAlphaComponent(0.08).setStroke()
        face.lineWidth = scale(3)
        face.stroke()

        drawDialTick(x: 512, y: 704, width: 8, height: 42, alpha: 0.18)
        drawDialTick(x: 512, y: 278, width: 8, height: 42, alpha: 0.14)
        drawDialTick(x: 704, y: 512, width: 42, height: 8, alpha: 0.14)
        drawDialTick(x: 278, y: 512, width: 42, height: 8, alpha: 0.14)
    }

    private func drawPulseWaveform() {
        let path = NSBezierPath()
        path.move(to: point(x: 318, y: 512))
        path.line(to: point(x: 394, y: 512))
        path.line(to: point(x: 428, y: 472))
        path.line(to: point(x: 484, y: 622))
        path.line(to: point(x: 536, y: 406))
        path.line(to: point(x: 586, y: 552))
        path.line(to: point(x: 632, y: 512))
        path.line(to: point(x: 706, y: 512))

        path.lineWidth = scale(36)
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        NSGraphicsContext.saveGraphicsState()
        let glow = NSShadow()
        glow.shadowColor = NSColor(calibratedRed: 0.20, green: 0.86, blue: 1.00, alpha: 0.50)
        glow.shadowBlurRadius = scale(30)
        glow.shadowOffset = .zero
        glow.set()
        NSColor(calibratedRed: 0.30, green: 0.88, blue: 1.00, alpha: 1).setStroke()
        path.stroke()
        NSGraphicsContext.restoreGraphicsState()

        path.lineWidth = scale(11)
        NSColor.white.withAlphaComponent(0.92).setStroke()
        path.stroke()
    }

    private func drawSpecularHighlights() {
        let faceHighlight = NSBezierPath(ovalIn: rect(x: 304, y: 602, width: 416, height: 122))
        NSColor.white.withAlphaComponent(0.055).setFill()
        faceHighlight.fill()

        let baseHighlight = NSBezierPath(
            roundedRect: rect(x: 136, y: 724, width: 752, height: 90),
            xRadius: scale(45),
            yRadius: scale(45)
        )
        NSColor.white.withAlphaComponent(0.20).setFill()
        baseHighlight.fill()
    }

    private func strokeArc(start: CGFloat, end: CGFloat, center: NSPoint, radius: CGFloat, lineWidth: CGFloat, color: NSColor) {
        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end)
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        color.setStroke()
        path.stroke()
    }

    private func drawDialTick(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, alpha: CGFloat) {
        let tick = NSBezierPath(
            roundedRect: rect(x: x - width / 2, y: y - height / 2, width: width, height: height),
            xRadius: scale(min(width, height) / 2),
            yRadius: scale(min(width, height) / 2)
        )
        NSColor.white.withAlphaComponent(alpha).setFill()
        tick.fill()
    }

    private func rect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> NSRect {
        NSRect(x: scale(x), y: scale(y), width: scale(width), height: scale(height))
    }

    private func point(x: CGFloat, y: CGFloat) -> NSPoint {
        NSPoint(x: scale(x), y: scale(y))
    }

    private func scale(_ value: CGFloat) -> CGFloat {
        value * pixelSize / 1024
    }
}

private func writePNG(_ image: NSImage, to url: URL) throws {
    guard let bitmap = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first,
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "AppIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode PNG"])
    }

    try pngData.write(to: url, options: .atomic)
}

private func runIconutil(iconsetURL: URL, outputURL: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", "-o", outputURL.path, iconsetURL.path]
    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        throw NSError(domain: "AppIcon", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed"])
    }
}

private let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
private let rootURL = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
private let resourcesURL = rootURL.appendingPathComponent("Resources", isDirectory: true)
private let iconsetURL = resourcesURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)
private let icnsURL = resourcesURL.appendingPathComponent("AppIcon.icns")
private let fileManager = FileManager.default

try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let iconRenditions: [(name: String, size: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for rendition in iconRenditions {
    let image = PulseGlyphIconRenderer(pixelSize: rendition.size).render()
    try writePNG(image, to: iconsetURL.appendingPathComponent(rendition.name))
}

try? fileManager.removeItem(at: icnsURL)
try runIconutil(iconsetURL: iconsetURL, outputURL: icnsURL)
print(icnsURL.path)
