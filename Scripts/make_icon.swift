import AppKit
import Foundation

// A small code-drawn app mark, with no downloaded artwork.
let root = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
var images: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let s = CGFloat(pixels)
        let tile = NSBezierPath(roundedRect: NSRect(x: s * 0.06, y: s * 0.06, width: s * 0.88, height: s * 0.88), xRadius: s * 0.19, yRadius: s * 0.19)
        NSColor(calibratedRed: 0.79, green: 0.31, blue: 0.20, alpha: 1).setFill()
        tile.fill()
        let text = "W" as NSString
        let font = NSFont(name: "Georgia", size: s * 0.56) ?? NSFont.systemFont(ofSize: s * 0.56)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(calibratedRed: 0.97, green: 0.95, blue: 0.90, alpha: 1)]
        let measure = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: (s - measure.width) / 2, y: (s - measure.height) / 2 + s * 0.015), withAttributes: attrs)
        NSColor(calibratedRed: 0.88, green: 0.91, blue: 0.84, alpha: 1).setFill()
        let leaf = NSBezierPath()
        leaf.move(to: NSPoint(x: s * 0.64, y: s * 0.77))
        leaf.curve(to: NSPoint(x: s * 0.82, y: s * 0.86), controlPoint1: NSPoint(x: s * 0.65, y: s * 0.89), controlPoint2: NSPoint(x: s * 0.76, y: s * 0.90))
        leaf.curve(to: NSPoint(x: s * 0.64, y: s * 0.77), controlPoint1: NSPoint(x: s * 0.82, y: s * 0.76), controlPoint2: NSPoint(x: s * 0.72, y: s * 0.74))
        leaf.fill()
        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Icon rendering failed") }
        let filename = "icon-\(size)@\(scale)x.png"
        try png.write(to: root.appendingPathComponent(filename))
        images.append(["filename": filename, "idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x"])
    }
}
let contents: [String: Any] = ["images": images, "info": ["version": 1, "author": "xcode"]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]).write(to: root.appendingPathComponent("Contents.json"))
