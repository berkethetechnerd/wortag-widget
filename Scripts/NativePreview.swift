import AppKit
import SwiftUI

/// Capture our own offscreen view hierarchy, including native macOS controls.
/// No window is shown and no desktop screen capture is performed.
@MainActor
enum NativePreview {
    static func bitmap<V: View>(_ view: V, size: CGSize, scheme: ColorScheme = .light,
                                scale: CGFloat? = nil) -> NSBitmapImageRep {
        let hosting = NSHostingView(rootView: view.environment(\.controlActiveState, .active))
        hosting.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: NSRect(x: -20000, y: 0, width: size.width, height: size.height),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentView = hosting
        defer { window.close() }
        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        hosting.layoutSubtreeIfNeeded()
        let scale = scale ?? window.backingScaleFactor
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
            fatalError("Could not allocate a native preview")
        }
        bitmap.size = size
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        return bitmap
    }
}
