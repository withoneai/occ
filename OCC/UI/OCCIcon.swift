import SwiftUI
import AppKit

struct OCCIcon: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        Image(nsImage: tintedIcon(color: NSColor(color)))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }

    private func tintedIcon(color: NSColor) -> NSImage {
        guard let svgURL = Bundle.module.url(forResource: "icon-mark", withExtension: "svg"),
              let svgImage = NSImage(contentsOf: svgURL) else {
            // Fallback: return a circle
            let img = NSImage(size: NSSize(width: size, height: size))
            img.lockFocus()
            color.setFill()
            NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: size, height: size)).fill()
            img.unlockFocus()
            return img
        }

        let targetSize = NSSize(width: size * 2, height: size * 2)
        let tinted = NSImage(size: targetSize)
        tinted.lockFocus()

        svgImage.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: svgImage.size),
            operation: .sourceOver,
            fraction: 1.0
        )

        // Tint by drawing color over with sourceAtop
        color.setFill()
        NSRect(origin: .zero, size: targetSize).fill(using: .sourceAtop)

        tinted.unlockFocus()
        tinted.isTemplate = false
        return tinted
    }
}
