#!/usr/bin/env swift
//
// Draws Sorty's app icon.
//
// The icon is generated rather than drawn by hand so it can be regenerated
// instead of being a mystery PNG in the asset catalogue: change the geometry
// here, re-run, and every appearance updates together. `SortyMark` in the app
// draws the same shape from the same numbers, so the icon and the in-app mark
// cannot drift apart.
//
// **The mark.** Four pills of descending length. Sorty's subject is
// *reordering*, and its own visual signature is already the position bar, so
// the icon is that motif taken to its conclusion: a set of things put in order.
// A musical note would say "music", which is the one thing Sorty is not about.
//
// **What it deliberately is not.** Not green, not a circle, not waves. Spotify's
// guidelines forbid a third-party logo that includes or resembles their brand
// elements, and those three are named expressly. Descending straight pills read
// as a sorted list rather than as a waveform, whose bars would be uneven.
//
//   swift scripts/make_icon.swift Resources/Assets.xcassets/AppIcon.appiconset
//
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let side = 1024.0

/// Fractions of the drawable width, longest first. Monotonic on purpose: the
/// read is "these are in order", and any bar out of sequence turns it into a
/// level meter.
let barWidths = [1.0, 0.78, 0.56, 0.34]
let barHeight = 88.0
let barGap = 60.0
let margin = 176.0

struct RGBA {
    let r, g, b, a: Double
    static let indigo = RGBA(r: 0.357, g: 0.294, b: 0.878, a: 1)   // #5B4BE0, the light accent
    static let indigoLight = RGBA(r: 0.545, g: 0.482, b: 1.0, a: 1) // #8B7BFF, the dark accent
    static let white = RGBA(r: 1, g: 1, b: 1, a: 1)
    static let nearBlack = RGBA(r: 0.05, g: 0.05, b: 0.055, a: 1)
    static let clear = RGBA(r: 0, g: 0, b: 0, a: 0)
}

/// An opaque icon is written with *no alpha channel at all*, not merely with
/// every pixel opaque. App Store validation rejects a primary app icon that
/// carries an alpha channel, and it rejects it on the channel's presence rather
/// than on its contents, so `premultipliedLast` with a fully opaque background
/// still fails. Only the tinted variant, which the system composites, keeps one.
func draw(background: RGBA, bars: RGBA, to url: URL) throws {
    let isOpaque = background.a >= 1
    guard let context = CGContext(
        data: nil,
        width: Int(side),
        height: Int(side),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: isOpaque
            ? CGImageAlphaInfo.noneSkipLast.rawValue
            : CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }

    if background.a > 0 {
        context.setFillColor(red: background.r, green: background.g, blue: background.b, alpha: background.a)
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
    }

    let drawable = side - margin * 2
    let stackHeight = barHeight * Double(barWidths.count) + barGap * Double(barWidths.count - 1)
    // CoreGraphics counts up from the bottom, and the widths are listed
    // longest-first, so the stack is laid out from the top down.
    var y = (side - stackHeight) / 2 + stackHeight - barHeight

    context.setFillColor(red: bars.r, green: bars.g, blue: bars.b, alpha: bars.a)
    for fraction in barWidths {
        let rect = CGRect(x: margin, y: y, width: drawable * fraction, height: barHeight)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: barHeight / 2, cornerHeight: barHeight / 2, transform: nil))
        context.fillPath()
        y -= barHeight + barGap
    }

    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}

let arguments = CommandLine.arguments
guard arguments.count > 1 else {
    FileHandle.standardError.write(Data("usage: make_icon.swift <output-directory>\n".utf8))
    exit(1)
}
let outputDirectory = URL(fileURLWithPath: arguments[1])
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

// The default appearance carries the identity, so it is the accent with the
// mark reversed out of it. No alpha: the primary icon may not have any.
try draw(background: .indigo, bars: .white, to: outputDirectory.appending(path: "icon.png"))

// Dark keeps a background of its own rather than relying on a composite, so the
// mark's contrast is a decision here rather than a surprise on someone's
// wallpaper.
try draw(background: .nearBlack, bars: .indigoLight, to: outputDirectory.appending(path: "icon-dark.png"))

// Tinted must be grayscale on transparency: the system supplies both the tint
// and the background, and any colour of ours would be thrown away.
try draw(background: .clear, bars: .white, to: outputDirectory.appending(path: "icon-tinted.png"))

print("Wrote icon.png, icon-dark.png and icon-tinted.png to \(outputDirectory.path)")
