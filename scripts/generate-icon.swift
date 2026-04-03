#!/usr/bin/env swift
// Generates macOS app icon PNGs from the dog chibi pixel art
import AppKit

// Dog pixel grid (10x10) — values map to colors
let grid: [[Int]] = [
    [0,0,0,0,0,0,0,0,0,0],
    [0,2,2,0,0,0,0,2,2,0],
    [2,2,1,1,1,1,1,1,2,2],
    [0,1,1,1,1,1,1,1,1,0],
    [0,1,3,1,1,1,3,1,1,0],
    [0,1,1,1,4,4,1,1,1,0],
    [0,1,1,5,1,1,5,1,1,0],
    [0,0,1,1,1,1,1,1,0,0],
    [0,1,1,1,1,1,1,1,1,0],
    [0,1,1,0,0,0,0,1,1,0],
]

// Dog colors
func color(for v: Int) -> NSColor {
    switch v {
    case 1: return NSColor(red: 0.82, green: 0.68, blue: 0.50, alpha: 1)  // tan body
    case 2: return NSColor(red: 0.60, green: 0.42, blue: 0.25, alpha: 1)  // dark brown ears
    case 3: return NSColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1)  // eyes
    case 4: return NSColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1)  // nose
    case 5: return NSColor(red: 0.95, green: 0.78, blue: 0.70, alpha: 1)  // cheeks
    default: return .clear
    }
}

// Background gradient colors (dark, subtle)
let bgTop = NSColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1)
let bgBottom = NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1)

func renderIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let ctx = NSGraphicsContext.current!.cgContext

    // Draw rounded rect background with gradient
    let cornerRadius = CGFloat(size) * 0.22
    let bgPath = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size), xRadius: cornerRadius, yRadius: cornerRadius)
    bgPath.addClip()

    // Gradient background
    let gradient = NSGradient(starting: bgBottom, ending: bgTop)!
    gradient.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: 90)

    // Subtle border ring
    let borderColor = NSColor(white: 1.0, alpha: 0.08)
    borderColor.setStroke()
    let insetPath = NSBezierPath(roundedRect: NSRect(x: 1, y: 1, width: size - 2, height: size - 2), xRadius: cornerRadius - 1, yRadius: cornerRadius - 1)
    insetPath.lineWidth = max(1, CGFloat(size) / 256.0)
    insetPath.stroke()

    // Calculate pixel grid placement — center it with padding
    let padding = CGFloat(size) * 0.15
    let gridSize = CGFloat(size) - padding * 2
    let pixelSize = gridSize / 10.0
    let offsetX = padding
    let offsetY = padding

    // Subtle glow behind the character
    let glowCenter = NSPoint(x: CGFloat(size) / 2, y: CGFloat(size) / 2)
    let glowRadius = gridSize * 0.55
    let glowGradient = NSGradient(colors: [
        NSColor(red: 0.82, green: 0.68, blue: 0.50, alpha: 0.15),
        NSColor(red: 0.82, green: 0.68, blue: 0.50, alpha: 0.0)
    ])!
    let glowPath = NSBezierPath(ovalIn: NSRect(
        x: glowCenter.x - glowRadius,
        y: glowCenter.y - glowRadius,
        width: glowRadius * 2,
        height: glowRadius * 2
    ))
    glowGradient.draw(in: glowPath, relativeCenterPosition: .zero)

    // Draw pixel grid (flip Y so row 0 is top)
    for row in 0..<10 {
        for col in 0..<10 {
            let v = grid[row][col]
            if v == 0 { continue }

            let c = color(for: v)
            c.setFill()

            let x = offsetX + CGFloat(col) * pixelSize
            let y = offsetY + CGFloat(9 - row) * pixelSize // flip Y
            let gap = max(0.5, pixelSize * 0.08)
            let r = max(1, pixelSize * 0.2)

            let rect = NSRect(x: x + gap/2, y: y + gap/2, width: pixelSize - gap, height: pixelSize - gap)
            let pixelPath = NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r)
            pixelPath.fill()
        }
    }

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for \(path)")
        return
    }
    do {
        try png.write(to: URL(fileURLWithPath: path))
        print("Wrote \(path)")
    } catch {
        print("Error writing \(path): \(error)")
    }
}

// macOS icon sizes: 16, 32, 64, 128, 256, 512, 1024
let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let sizes = [16, 32, 64, 128, 256, 512, 1024]

for size in sizes {
    let icon = renderIcon(size: size)
    savePNG(icon, to: "\(outputDir)/icon_\(size)x\(size).png")
}

print("Done! Now run: iconutil to create .icns")
