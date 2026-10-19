#!/usr/bin/env swift
// Renders the App Store product page header (3840 × 1646) and search results (3840 × 2560) images:
// the app icon's line, drawn level as a waveform, on the icon's purple.
//
// Usage: scripts/render-store-art.swift [output directory, default build/store-art]
import AppKit
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

let title = "Your music, your server."
let subtitle = "Album-first listening for your Navidrome library"

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/store-art")

func color(_ red: Int, _ green: Int, _ blue: Int, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: alpha)
}

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let iconBackground = color(33, 18, 47)
let lineStart = color(109, 70, 194)
let lineEnd = color(252, 157, 195)

/// The icon's line traced from its artwork, level and centered on the origin, in units where the stroke is 112 wide.
enum Waveform {
    static let strokeWidth: CGFloat = 112
    static let tailEnd: CGFloat = 1422
    static let height: CGFloat = 1412
    private static let strokes: [CGFloat] = [-1061.9, -797.3, -493.0, -164.1, 164.1, 493.0, 797.3, 1061.9]
    /// Where each U-turn's straight sides end; negative is above the baseline.
    private static let turns: [CGFloat] = [-223.2, 220.4, -648.0, 649.4, -648.0, 220.4, -223.2]
    private static let cornerRadius: CGFloat = 100

    static func path(tailEnd: CGFloat = tailEnd) -> CGPath {
        let path = CGMutablePath()
        let first = strokes[0], last = strokes[strokes.count - 1]
        path.move(to: CGPoint(x: -tailEnd, y: 0))
        path.addArc(tangent1End: CGPoint(x: first, y: 0), tangent2End: CGPoint(x: first, y: -cornerRadius), radius: cornerRadius)
        for (index, turn) in turns.enumerated() {
            let x = strokes[index]
            let radius = (strokes[index + 1] - x) / 2
            path.addLine(to: CGPoint(x: x, y: turn))
            path.addArc(center: CGPoint(x: x + radius, y: turn), radius: radius, startAngle: .pi, endAngle: 0, clockwise: turn > 0)
        }
        path.addArc(tangent1End: CGPoint(x: last, y: 0), tangent2End: CGPoint(x: last + cornerRadius, y: 0), radius: cornerRadius)
        path.addLine(to: CGPoint(x: tailEnd, y: 0))
        return path
    }
}

struct Canvas {
    let context: CGContext
    let size: CGSize

    init(width: Int, height: Int) {
        size = CGSize(width: width, height: height)
        context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        // Top-left origin, y down.
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
    }

    func fillBackground(glowCenterY: CGFloat) {
        context.setFillColor(iconBackground)
        context.fill(CGRect(origin: .zero, size: size))
        let glow = CGGradient(colorsSpace: colorSpace, colors: [color(56, 32, 80), iconBackground, color(22, 12, 32)] as CFArray,
                              locations: [0, 0.55, 1])!
        let center = CGPoint(x: size.width / 2, y: glowCenterY)
        context.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center,
                                   endRadius: max(size.width, size.height) * 0.62, options: [.drawsAfterEndLocation])
    }

    /// Draws the waveform `height` tall, centered at `center`, with its tails running off both edges.
    func drawWaveform(center: CGPoint, height: CGFloat) {
        let scale = height / (Waveform.height + Waveform.strokeWidth)
        var transform = CGAffineTransform(translationX: center.x, y: center.y).scaledBy(x: scale, y: scale)
        let tailEnd = (size.width / 2) / scale + Waveform.strokeWidth
        let path = Waveform.path(tailEnd: tailEnd).copy(using: &transform)!
        let lineWidth = Waveform.strokeWidth * scale

        context.saveGState()
        context.clip(to: CGRect(origin: .zero, size: size), mask: edgeFadeMask(fraction: 0.2))
        context.saveGState()
        context.setShadow(offset: .zero, blur: lineWidth * 2.5, color: color(182, 114, 194, 0.45))
        context.addPath(path)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setStrokeColor(color(150, 95, 200, 0.5))
        context.strokePath()
        context.restoreGState()

        context.saveGState()
        context.addPath(path)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.replacePathWithStrokedPath()
        context.clip()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: [lineStart, lineEnd] as CFArray, locations: [0, 1])!
        let span = Waveform.tailEnd * scale
        context.drawLinearGradient(gradient, start: CGPoint(x: center.x - span, y: 0), end: CGPoint(x: center.x + span, y: 0),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        context.restoreGState()
        context.restoreGState()
    }

    /// A horizontal mask that eases the tails out over `fraction` of the width at each edge.
    private func edgeFadeMask(fraction: CGFloat) -> CGImage {
        let width = Int(size.width)
        let mask = CGContext(data: nil, width: width, height: 1, bitsPerComponent: 8, bytesPerRow: width,
                             space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        let pixels = mask.data!.bindMemory(to: UInt8.self, capacity: width)
        let fadeWidth = size.width * fraction
        for x in 0..<width {
            let distance = min(CGFloat(x), size.width - CGFloat(x)) / fadeWidth
            let t = min(max(distance, 0), 1)
            pixels[x] = UInt8((t * t * (3 - 2 * t) * 255).rounded())
        }
        return mask.makeImage()!
    }

    func drawCenteredText(_ text: String, size fontSize: CGFloat, weight: NSFont.Weight, color textColor: CGColor, centerY: CGFloat) {
        let font = NSFont.systemFont(ofSize: fontSize, weight: weight)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(cgColor: textColor)!, .kern: -fontSize * 0.01]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        context.saveGState()
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        context.textPosition = CGPoint(x: (size.width - bounds.width) / 2 - bounds.minX, y: centerY + bounds.height / 2 + bounds.minY)
        CTLineDraw(line, context)
        context.restoreGState()
    }

    func write(to url: URL) throws {
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        print("Wrote \(url.path)")
    }
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

// Header: the waveform alone in the middle band, clear of whatever the App Store overlays at the edges.
let header = Canvas(width: 3840, height: 1646)
header.fillBackground(glowCenterY: header.size.height / 2)
header.drawWaveform(center: CGPoint(x: header.size.width / 2, y: header.size.height / 2), height: header.size.height * 0.56)
try header.write(to: outputDirectory.appending(path: "header.png"))

// Search results: the tagline above the waveform.
let search = Canvas(width: 3840, height: 2560)
search.fillBackground(glowCenterY: search.size.height * 0.64)
search.drawCenteredText(title, size: search.size.height * 0.085, weight: .bold, color: color(247, 241, 252), centerY: search.size.height * 0.24)
search.drawCenteredText(subtitle, size: search.size.height * 0.042, weight: .medium, color: color(196, 178, 214), centerY: search.size.height * 0.33)
search.drawWaveform(center: CGPoint(x: search.size.width / 2, y: search.size.height * 0.66), height: search.size.height * 0.44)
try search.write(to: outputDirectory.appending(path: "search.png"))
