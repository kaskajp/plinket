#!/usr/bin/env swift
// Draws abstract cover art for the sample library: one cover per album, a portrait per artist (their first
// album's cover) and a 2×2 mosaic per playlist, as covers/<id>.jpg.
//
// Usage: scripts/sample-library/render-covers.swift [data directory, default build/sample-library]
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let directory = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/sample-library")
let coverSize = 1200
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

struct Library: Decodable {
    struct Album: Decodable { let id: String; let style: Int }
    struct Artist: Decodable { let id: String; let albumIDs: [String] }
    struct Playlist: Decodable { let id: String; let coverAlbums: [String] }
    let albums: [Album]
    let artists: [Artist]
    let playlists: [Playlist]
}

func hex(_ value: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255, alpha: 1)
}

/// Background, two accents and a highlight.
let palettes: [[UInt32]] = [
    [0x0E1A2B, 0x2E6F95, 0x8FD3E8, 0xF4E9D8],
    [0x2B1B3D, 0x7B4B94, 0xE58F65, 0xF9D9A6],
    [0xF2E8D5, 0xD9663D, 0x2F5D50, 0x1C2321],
    [0x07121F, 0x3A86FF, 0xFF006E, 0xFFBE0B],
    [0x101418, 0x264653, 0x2A9D8F, 0xE9C46A],
    [0x1A1A1A, 0xB23A48, 0xF2C14E, 0xF7F4EA],
    [0xDCE6E4, 0x6A8D92, 0x324A5F, 0x0C1821],
    [0x3D1C02, 0xC1440E, 0xF2A65A, 0xFCEBCF],
    [0xEDE7F6, 0x9575CD, 0x4527A0, 0x1A0F3D],
    [0x0B0C2A, 0x5F0F99, 0xFF5F9E, 0x00E0C6],
    [0x12263A, 0x06BCC1, 0xF4EDEA, 0xC5D8D1],
    [0x0D1B2A, 0x415A77, 0x778DA9, 0xE0E1DD],
    [0x2D0A12, 0x8C1C3A, 0xE07A5F, 0xF4D3A1],
    [0xF1F0EA, 0x111111, 0xE63946, 0x457B9D],
    [0x1F1300, 0x8A5A19, 0xE9B44C, 0xFFF3D6],
    [0x150734, 0x0F2557, 0xFF7B54, 0xFFD56F],
    [0x011627, 0x2EC4B6, 0xFF9F1C, 0xFDFFFC],
    [0x1B1B1E, 0x5C3D2E, 0xB85C38, 0xE0C097],
    [0xE8EDF2, 0x9DB4C0, 0x5C6B73, 0x253237],
    [0xFFF1E6, 0xF28482, 0x84A59D, 0x2F3E46],
    [0x0F2A1D, 0x375534, 0x6B9071, 0xE3EED4],
    [0x1C1427, 0x4A3B6B, 0x9A8FD1, 0xF2C6DE],
    [0x2A1F14, 0xD9C5A0, 0x8C6A4F, 0xF5EFE6],
    [0x020B1A, 0x1B3B6F, 0x21D4FD, 0xB721FF],
]

struct Painter {
    let context: CGContext
    let size: CGFloat
    let colors: [CGColor]
    var rng: SeededGenerator

    var background: CGColor { colors[0] }

    func fill(_ color: CGColor, _ rect: CGRect) {
        context.setFillColor(color)
        context.fill(rect)
    }

    func ellipse(_ color: CGColor, center: CGPoint, radius: CGFloat) {
        context.setFillColor(color)
        context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    func linear(_ from: CGColor, _ to: CGColor, start: CGPoint, end: CGPoint) {
        let gradient = CGGradient(colorsSpace: colorSpace, colors: [from, to] as CFArray, locations: [0, 1])!
        context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    func glow(_ color: CGColor, center: CGPoint, radius: CGFloat, alpha: CGFloat = 0.9) {
        let gradient = CGGradient(colorsSpace: colorSpace,
                                  colors: [color.copy(alpha: alpha)!, color.copy(alpha: 0)!] as CFArray, locations: [0, 1])!
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
    }

    mutating func random(_ range: ClosedRange<CGFloat>) -> CGFloat { CGFloat.random(in: range, using: &rng) }
}

struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state ^ (state >> 33)
    }
}

/// Soft blurred orbs on a dark ground.
func orbs(_ p: inout Painter) {
    p.fill(p.background, CGRect(x: 0, y: 0, width: p.size, height: p.size))
    for index in 0..<5 {
        let center = CGPoint(x: p.random(0.1...0.9) * p.size, y: p.random(0.1...0.9) * p.size)
        p.glow(p.colors[1 + index % 3], center: center, radius: p.random(0.3...0.6) * p.size, alpha: 0.75)
    }
}

/// A low sun over striped water.
func sunset(_ p: inout Painter) {
    let s = p.size
    p.linear(p.colors[0], p.colors[1], start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: s * 0.4))
    p.ellipse(p.colors[3], center: CGPoint(x: s / 2, y: s * 0.48), radius: s * 0.24)
    p.fill(p.colors[0], CGRect(x: 0, y: 0, width: s, height: s * 0.42))
    for line in 0..<9 {
        let y = s * 0.42 - CGFloat(line) * s * 0.045 - s * 0.02
        let width = s * (0.46 - CGFloat(line) * 0.035)
        p.fill(p.colors[2].copy(alpha: 0.85 - CGFloat(line) * 0.08)!, CGRect(x: s / 2 - width / 2, y: y, width: width, height: s * 0.012))
    }
}

/// A Bauhaus grid of squares and quarter circles.
func bauhaus(_ p: inout Painter) {
    let cells = 4, cell = p.size / CGFloat(cells)
    p.fill(p.background, CGRect(x: 0, y: 0, width: p.size, height: p.size))
    for row in 0..<cells {
        for column in 0..<cells {
            let origin = CGPoint(x: CGFloat(column) * cell, y: CGFloat(row) * cell)
            let color = p.colors[1 + Int(p.random(0...2.99))]
            switch Int(p.random(0...3.99)) {
            case 0:
                p.fill(color, CGRect(origin: origin, size: CGSize(width: cell, height: cell)))
            case 1:
                let corner = CGPoint(x: origin.x + (p.random(0...1) > 0.5 ? cell : 0), y: origin.y + (p.random(0...1) > 0.5 ? cell : 0))
                p.context.saveGState()
                p.context.clip(to: CGRect(origin: origin, size: CGSize(width: cell, height: cell)))
                p.ellipse(color, center: corner, radius: cell)
                p.context.restoreGState()
            case 2:
                p.ellipse(color, center: CGPoint(x: origin.x + cell / 2, y: origin.y + cell / 2), radius: cell * 0.42)
            default:
                break
            }
        }
    }
}

/// Layered hills receding into haze.
func hills(_ p: inout Painter) {
    let s = p.size
    p.linear(p.colors[3], p.colors[2], start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0))
    for layer in 0..<5 {
        let base = s * (0.62 - CGFloat(layer) * 0.12)
        let amplitude = s * p.random(0.04...0.09)
        let frequency = p.random(1.2...2.6), phase = p.random(0...6)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        for step in 0...60 {
            let x = s * CGFloat(step) / 60
            path.addLine(to: CGPoint(x: x, y: base + amplitude * sin(phase + frequency * x / s * .pi * 2)))
        }
        path.addLine(to: CGPoint(x: s, y: 0))
        path.closeSubpath()
        let t = CGFloat(layer) / 4
        p.context.addPath(path)
        p.context.setFillColor(mix(p.colors[1], p.colors[0], t))
        p.context.fillPath()
    }
}

/// Concentric rings around an off-center point.
func rings(_ p: inout Painter) {
    let s = p.size
    p.fill(p.background, CGRect(x: 0, y: 0, width: s, height: s))
    let center = CGPoint(x: s * p.random(0.3...0.7), y: s * p.random(0.3...0.7))
    p.context.setLineWidth(s * 0.028)
    for ring in (1...14).reversed() {
        p.context.setStrokeColor(p.colors[1 + ring % 3])
        let radius = CGFloat(ring) * s * 0.06
        p.context.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}

/// Diagonal bands of color.
func bands(_ p: inout Painter) {
    let s = p.size
    p.fill(p.background, CGRect(x: 0, y: 0, width: s, height: s))
    p.context.saveGState()
    p.context.translateBy(x: s / 2, y: s / 2)
    p.context.rotate(by: .pi / 4 * (p.random(0...1) > 0.5 ? 1 : -1))
    var x = -s
    var index = 0
    while x < s {
        let width = s * p.random(0.05...0.16)
        p.fill(p.colors[index % 4], CGRect(x: x, y: -s, width: width, height: s * 2))
        x += width
        index += 1
    }
    p.context.restoreGState()
}

/// A halftone field fading across the cover.
func halftone(_ p: inout Painter) {
    let s = p.size
    p.fill(p.background, CGRect(x: 0, y: 0, width: s, height: s))
    let focus = CGPoint(x: s * p.random(0.2...0.8), y: s * p.random(0.2...0.8))
    let spacing = s / 24
    for row in 0...24 {
        for column in 0...24 {
            let center = CGPoint(x: CGFloat(column) * spacing, y: CGFloat(row) * spacing)
            let distance = hypot(center.x - focus.x, center.y - focus.y) / s
            let radius = spacing * 0.48 * max(0.08, 1 - distance * 1.4)
            p.ellipse(mix(p.colors[2], p.colors[1], min(1, distance * 1.5)), center: center, radius: radius)
        }
    }
}

/// Stacked arches like a doorway in sunlight.
func arches(_ p: inout Painter) {
    let s = p.size
    p.fill(p.colors[3], CGRect(x: 0, y: 0, width: s, height: s))
    for arch in 0..<4 {
        let inset = CGFloat(arch) * s * 0.09
        let width = s * 0.7 - inset * 2, x = s * 0.15 + inset, height = s * 0.78 - inset
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x, y: 0))
        path.addLine(to: CGPoint(x: x, y: height - width / 2))
        path.addArc(center: CGPoint(x: x + width / 2, y: height - width / 2), radius: width / 2, startAngle: .pi, endAngle: 0, clockwise: true)
        path.addLine(to: CGPoint(x: x + width, y: 0))
        path.closeSubpath()
        p.context.addPath(path)
        p.context.setFillColor(p.colors[[1, 2, 0, 1][arch]])
        p.context.fillPath()
    }
}

func mix(_ a: CGColor, _ b: CGColor, _ t: CGFloat) -> CGColor {
    let x = a.components!, y = b.components!
    return CGColor(srgbRed: x[0] + (y[0] - x[0]) * t, green: x[1] + (y[1] - x[1]) * t, blue: x[2] + (y[2] - x[2]) * t, alpha: 1)
}

/// Fine film grain so flat fills read as printed.
func grain(_ context: CGContext, size: Int, seed: UInt64) {
    var rng = SeededGenerator(state: seed)
    let noise = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size,
                          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    let pixels = noise.data!.bindMemory(to: UInt8.self, capacity: size * size)
    for index in 0..<(size * size) { pixels[index] = UInt8.random(in: 0...255, using: &rng) }
    context.saveGState()
    context.setAlpha(0.05)
    context.setBlendMode(.overlay)
    context.draw(noise.makeImage()!, in: CGRect(x: 0, y: 0, width: size, height: size))
    context.restoreGState()
}

let styles: [(inout Painter) -> Void] = [orbs, sunset, bauhaus, hills, rings, bands, halftone, arches]

func renderCover(style: Int) -> CGImage {
    let context = CGContext(data: nil, width: coverSize, height: coverSize, bitsPerComponent: 8, bytesPerRow: 0,
                            space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    var painter = Painter(context: context, size: CGFloat(coverSize), colors: palettes[(style + style / palettes.count * 5) % palettes.count].map(hex),
                          rng: SeededGenerator(state: UInt64(style + 1) &* 2654435761))
    styles[style % styles.count](&painter)
    grain(context, size: coverSize, seed: UInt64(style + 7))
    return context.makeImage()!
}

func renderMosaic(_ covers: [CGImage]) -> CGImage {
    let context = CGContext(data: nil, width: coverSize, height: coverSize, bitsPerComponent: 8, bytesPerRow: 0,
                            space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let half = CGFloat(coverSize) / 2
    for (index, cover) in covers.prefix(4).enumerated() {
        context.draw(cover, in: CGRect(x: CGFloat(index % 2) * half, y: CGFloat(1 - index / 2) * half, width: half, height: half))
    }
    return context.makeImage()!
}

func write(_ image: CGImage, id: String) throws {
    let url = directory.appending(path: "covers/\(id).jpg")
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.88] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}

let library = try JSONDecoder().decode(Library.self, from: Data(contentsOf: directory.appending(path: "library.json")))
try FileManager.default.createDirectory(at: directory.appending(path: "covers"), withIntermediateDirectories: true)

var covers: [String: CGImage] = [:]
for album in library.albums {
    covers[album.id] = renderCover(style: album.style)
    try write(covers[album.id]!, id: album.id)
}
for artist in library.artists {
    try write(covers[artist.albumIDs[0]]!, id: artist.id)
}
for playlist in library.playlists {
    try write(renderMosaic(playlist.coverAlbums.compactMap { covers[$0] }), id: playlist.id)
}
print("Wrote \(covers.count) album covers, \(library.artists.count) artist images and \(library.playlists.count) playlist mosaics")
