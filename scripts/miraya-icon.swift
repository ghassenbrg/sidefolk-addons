#!/usr/bin/env swift
// Makes extensions/miraya/icon.pdf from the Miraya app's own icon, the approved Beam artwork it ships
// (assets/beam/macos-icon/icon-1024.png in github.com/ghassenbrg/miraya):
//   swift scripts/miraya-icon.swift <miraya checkout>
// That PNG is a macOS tile: a rounded square with a rim and transparent corners. Sidefolk rounds an extension's icon
// itself, so the tile's inside is cropped (no rim, no corners) and laid full bleed on the tile's own dark ground. The
// picture goes in as a JPEG, which the PDF keeps as is: the icon stays far under Sidefolk's 256 KB.
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count == 2 else { fatalError("usage: swift scripts/miraya-icon.swift <miraya checkout>") }
let source = URL(fileURLWithPath: arguments[1]).appendingPathComponent("assets/beam/macos-icon/icon-1024.png")
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let out = root.appendingPathComponent("extensions/miraya/icon.pdf")

guard let png = CGImageSourceCreateWithURL(source as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(png, 0, nil) else {
    fatalError("Can't read \(source.path)")
}
// The tile is the opaque part, measured on the 1024 px artwork from x 62 to 964 and y 72 to 943, its corners rounded
// about 200 px. A square of 743 px around its middle, 64 px inside its edges, leaves the rim and the curves out and
// keeps the two planes and their seam whole (they span about 210 to 810 across).
let scale = CGFloat(image.width) / 1024
let crop = CGRect(x: 142 * scale, y: 136 * scale, width: 743 * scale, height: 743 * scale)
guard let tile = image.cropping(to: crop) else { fatalError("crop") }

// 512 px on the tile's darkest navy, as JPEG.
let side = 512
let ground = CGColor(srgbRed: 8 / 255, green: 14 / 255, blue: 27 / 255, alpha: 1)
let bitmap = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
bitmap.setFillColor(ground)
bitmap.fill(CGRect(x: 0, y: 0, width: side, height: side))
bitmap.interpolationQuality = .high
bitmap.draw(tile, in: CGRect(x: 0, y: 0, width: side, height: side))
let jpeg = NSMutableData()
let destination = CGImageDestinationCreateWithData(jpeg, UTType.jpeg.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, bitmap.makeImage()!, [kCGImageDestinationLossyCompressionQuality: 0.88] as CFDictionary)
CGImageDestinationFinalize(destination)
let picture = CGImage(jpegDataProviderSource: CGDataProvider(data: jpeg)!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!

var box = CGRect(x: 0, y: 0, width: 512, height: 512)
let pdf = CGContext(out as CFURL, mediaBox: &box, [kCGPDFContextCreator: "sidefolk-addons miraya-icon.swift"] as CFDictionary)!
pdf.beginPDFPage(nil)
pdf.draw(picture, in: box)
pdf.endPDFPage()
pdf.closePDF()
print("wrote \(out.path)")
