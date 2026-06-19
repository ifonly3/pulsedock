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

        drawDockShadow()
        drawAquaRoundedBase()
        drawDepthRim()
        drawMonitorGlyph()
        drawPulseWaveform()
        drawMetricCapsules()
        drawSpecularHighlights()

        let image = NSImage(size: bitmap.size)
        image.addRepresentation(bitmap)
        return image
    }

    private func drawDockShadow() {
        let shadowPath = NSBezierPath(
            roundedRect: rect(x: 68, y: 70, width: 888, height: 878),
            xRadius: scale(210),
            yRadius: scale(210)
        )

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
        shadow.shadowBlurRadius = scale(62)
        shadow.shadowOffset = NSSize(width: 0, height: -scale(24))
        shadow.set()
        NSColor.black.withAlphaComponent(0.10).setFill()
        shadowPath.fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawAquaRoundedBase() {
        let basePath = NSBezierPath(
            roundedRect: rect(x: 58, y: 72, width: 908, height: 884),
            xRadius: scale(212),
            yRadius: scale(212)
        )

        NSGradient(colors: [
            NSColor(calibratedRed: 0.96, green: 0.99, blue: 0.96, alpha: 1),
            NSColor(calibratedRed: 0.62, green: 0.86, blue: 0.84, alpha: 1),
            NSColor(calibratedRed: 0.12, green: 0.52, blue: 0.45, alpha: 1),
            NSColor(calibratedRed: 0.05, green: 0.13, blue: 0.14, alpha: 1)
        ])?.draw(in: basePath, angle: -44)

        let upperGlow = NSBezierPath(
            roundedRect: rect(x: 108, y: 684, width: 808, height: 218),
            xRadius: scale(134),
            yRadius: scale(134)
        )
        NSGradient(colors: [
            NSColor.white.withAlphaComponent(0.50),
            NSColor.white.withAlphaComponent(0.10)
        ])?.draw(in: upperGlow, angle: -90)

        let lowerShade = NSBezierPath(
            roundedRect: rect(x: 118, y: 102, width: 788, height: 222),
            xRadius: scale(130),
            yRadius: scale(130)
        )
        NSColor.black.withAlphaComponent(0.13).setFill()
        lowerShade.fill()
    }

    private func drawDepthRim() {
        let outer = NSBezierPath(
            roundedRect: rect(x: 58, y: 72, width: 908, height: 884),
            xRadius: scale(212),
            yRadius: scale(212)
        )
        NSColor.white.withAlphaComponent(0.56).setStroke()
        outer.lineWidth = scale(8)
        outer.stroke()

        let inner = NSBezierPath(
            roundedRect: rect(x: 84, y: 100, width: 856, height: 828),
            xRadius: scale(190),
            yRadius: scale(190)
        )
        NSColor.black.withAlphaComponent(0.12).setStroke()
        inner.lineWidth = scale(4)
        inner.stroke()
    }

    private func drawMonitorGlyph() {
        let panelPath = NSBezierPath(
            roundedRect: rect(x: 176, y: 286, width: 672, height: 500),
            xRadius: scale(118),
            yRadius: scale(118)
        )

        NSGraphicsContext.saveGraphicsState()
        let panelShadow = NSShadow()
        panelShadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
        panelShadow.shadowBlurRadius = scale(46)
        panelShadow.shadowOffset = NSSize(width: 0, height: -scale(16))
        panelShadow.set()
        NSGradient(colors: [
            NSColor.white.withAlphaComponent(0.54),
            NSColor(calibratedRed: 0.89, green: 1.00, blue: 0.96, alpha: 0.31),
            NSColor(calibratedRed: 0.07, green: 0.22, blue: 0.22, alpha: 0.20)
        ])?.draw(in: panelPath, angle: 88)
        NSGraphicsContext.restoreGraphicsState()

        NSColor.white.withAlphaComponent(0.64).setStroke()
        panelPath.lineWidth = scale(7)
        panelPath.stroke()

        let screen = NSBezierPath(
            roundedRect: rect(x: 228, y: 354, width: 568, height: 344),
            xRadius: scale(72),
            yRadius: scale(72)
        )
        NSGradient(colors: [
            NSColor(calibratedRed: 0.04, green: 0.18, blue: 0.18, alpha: 0.56),
            NSColor(calibratedRed: 0.04, green: 0.34, blue: 0.31, alpha: 0.36),
            NSColor.white.withAlphaComponent(0.18)
        ])?.draw(in: screen, angle: 92)

        NSColor.white.withAlphaComponent(0.20).setStroke()
        screen.lineWidth = scale(3)
        screen.stroke()

        let stand = NSBezierPath(
            roundedRect: rect(x: 426, y: 254, width: 172, height: 64),
            xRadius: scale(32),
            yRadius: scale(32)
        )
        NSColor.white.withAlphaComponent(0.32).setFill()
        stand.fill()

        let base = NSBezierPath(
            roundedRect: rect(x: 350, y: 214, width: 324, height: 62),
            xRadius: scale(31),
            yRadius: scale(31)
        )
        NSColor(calibratedRed: 0.02, green: 0.18, blue: 0.18, alpha: 0.26).setFill()
        base.fill()
        NSColor.white.withAlphaComponent(0.20).setStroke()
        base.lineWidth = scale(3)
        base.stroke()

        for index in 0..<3 {
            let dot = NSBezierPath(
                ovalIn: rect(x: CGFloat(288 + index * 48), y: 648, width: 18, height: 18)
            )
            NSColor.white.withAlphaComponent(0.42 - CGFloat(index) * 0.07).setFill()
            dot.fill()
        }
    }

    private func drawPulseWaveform() {
        let path = NSBezierPath()
        path.move(to: point(x: 284, y: 526))
        path.line(to: point(x: 356, y: 526))
        path.line(to: point(x: 392, y: 612))
        path.line(to: point(x: 454, y: 426))
        path.line(to: point(x: 516, y: 586))
        path.line(to: point(x: 570, y: 526))
        path.line(to: point(x: 626, y: 526))
        path.line(to: point(x: 662, y: 476))
        path.line(to: point(x: 714, y: 560))
        path.line(to: point(x: 760, y: 560))

        path.lineWidth = scale(34)
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        NSGraphicsContext.saveGraphicsState()
        let glow = NSShadow()
        glow.shadowColor = NSColor(calibratedRed: 0.00, green: 0.72, blue: 0.52, alpha: 0.46)
        glow.shadowBlurRadius = scale(34)
        glow.shadowOffset = .zero
        glow.set()
        NSColor(calibratedRed: 0.00, green: 0.66, blue: 0.47, alpha: 1).setStroke()
        path.stroke()
        NSGraphicsContext.restoreGraphicsState()

        path.lineWidth = scale(12)
        NSColor.white.withAlphaComponent(0.92).setStroke()
        path.stroke()
    }

    private func drawMetricCapsules() {
        let colors = [
            NSColor(calibratedRed: 0.05, green: 0.62, blue: 0.40, alpha: 1),
            NSColor(calibratedRed: 0.12, green: 0.42, blue: 0.95, alpha: 1),
            NSColor(calibratedRed: 0.93, green: 0.54, blue: 0.10, alpha: 1)
        ]
        let widths: [CGFloat] = [258, 188, 302]

        for index in 0..<3 {
            let y = 376 + CGFloat(index) * 52
            let track = NSBezierPath(
                roundedRect: rect(x: 314, y: y, width: 396, height: 16),
                xRadius: scale(8),
                yRadius: scale(8)
            )
            NSColor.white.withAlphaComponent(0.22).setFill()
            track.fill()

            let fill = NSBezierPath(
                roundedRect: rect(x: 314, y: y, width: widths[index], height: 16),
                xRadius: scale(8),
                yRadius: scale(8)
            )
            colors[index].setFill()
            fill.fill()
        }
    }

    private func drawSpecularHighlights() {
        let highlight = NSBezierPath()
        highlight.move(to: point(x: 162, y: 734))
        highlight.curve(
            to: point(x: 554, y: 914),
            controlPoint1: point(x: 270, y: 858),
            controlPoint2: point(x: 404, y: 930)
        )
        highlight.curve(
            to: point(x: 858, y: 720),
            controlPoint1: point(x: 700, y: 902),
            controlPoint2: point(x: 788, y: 806)
        )
        highlight.line(to: point(x: 806, y: 674))
        highlight.curve(
            to: point(x: 530, y: 804),
            controlPoint1: point(x: 720, y: 744),
            controlPoint2: point(x: 638, y: 790)
        )
        highlight.curve(
            to: point(x: 190, y: 684),
            controlPoint1: point(x: 386, y: 824),
            controlPoint2: point(x: 256, y: 768)
        )
        highlight.close()

        NSColor.white.withAlphaComponent(0.12).setFill()
        highlight.fill()
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
