// SPDX-FileCopyrightText: 2026 the Folio Project
// SPDX-License-Identifier: MIT
import AppKit

let args = CommandLine.arguments
let image = NSImage(contentsOfFile: args[1])!
let size = Int(args[3])!

func bitmap(_ size: Int) -> NSBitmapImageRep {
    NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                    isPlanar: false, colorSpaceName: .deviceRGB,
                    bytesPerRow: 0, bitsPerPixel: 0)!
}

// Backgrounds occupy the system's full document canvas, including transparent areas.
if args.contains("--canvas") {
    let output = bitmap(size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: output)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    try output.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
    exit(0)
}

// Measure the complete artwork, including strokes and the optional ZIP overlay,
// at higher resolution than any output. The SVG canvas is an editing convenience,
// not padding to carry into the system's already-inset document badge.
let measurementSize = max(2048, size * 2)
let measurement = bitmap(measurementSize)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: measurement)
image.draw(in: NSRect(x: 0, y: 0, width: measurementSize, height: measurementSize))
NSGraphicsContext.restoreGraphicsState()

let pixels = measurement.bitmapData!
var left = measurementSize, top = measurementSize, right = -1, bottom = -1
for y in 0..<measurementSize {
    for x in 0..<measurementSize where pixels[y * measurement.bytesPerRow + x * 4 + 3] != 0 {
        left = min(left, x)
        right = max(right, x)
        top = min(top, y)
        bottom = max(bottom, y)
    }
}
precondition(right >= left && bottom >= top, "Badge artwork must not be empty")
let bounds = CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)
let cropped = measurement.cgImage!.cropping(to: bounds)!
let artwork = NSImage(cgImage: cropped, size: bounds.size)
let scale = CGFloat(size) / max(bounds.width, bounds.height)
let width = bounds.width * scale, height = bounds.height * scale
let destination = NSRect(x: (CGFloat(size) - width) / 2,
                         y: (CGFloat(size) - height) / 2, width: width, height: height)
let output = bitmap(size)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: output)
NSGraphicsContext.current?.imageInterpolation = .high
artwork.draw(in: destination)
NSGraphicsContext.restoreGraphicsState()
try output.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
