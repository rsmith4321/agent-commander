// The Agent Commander mark: a geometric "A" with a small spark at its
// upper right. Drawn from paths so it stays sharp at any size and works as
// a template image (macOS tints it for light and dark menu bars).

import AppKit

enum Glyph {
    /// Draws the mark in the current fill/stroke color, fitted to `rect`.
    /// Designed on an 18 x 18 grid.
    static func draw(in rect: NSRect, running: Bool = false) {
        let s = min(rect.width, rect.height) / 18
        let ox = rect.midX - 9 * s, oy = rect.midY - 9 * s
        func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: ox + x * s, y: oy + y * s) }

        let a = NSBezierPath()
        a.move(to: p(2.6, 1.8))
        a.line(to: p(8.2, 15.4))
        a.line(to: p(13.8, 1.8))
        a.move(to: p(5.1, 6.6))
        a.line(to: p(11.3, 6.6))
        a.lineWidth = 2.3 * s
        a.lineCapStyle = .round
        a.lineJoinStyle = .round
        a.stroke()

        // While agents are running the spark becomes a solid dot.
        if running {
            let c = p(14.9, 13.9), r = 2.7 * s
            NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)).fill()
            return
        }

        // Four-point spark.
        let c = p(14.9, 13.9), r = 3.1 * s, w = 0.75 * s
        let spark = NSBezierPath()
        spark.move(to: NSPoint(x: c.x, y: c.y + r))
        spark.curve(to: NSPoint(x: c.x + r, y: c.y), controlPoint1: NSPoint(x: c.x + w * 0.4, y: c.y + w), controlPoint2: NSPoint(x: c.x + w, y: c.y + w * 0.4))
        spark.curve(to: NSPoint(x: c.x, y: c.y - r), controlPoint1: NSPoint(x: c.x + w, y: c.y - w * 0.4), controlPoint2: NSPoint(x: c.x + w * 0.4, y: c.y - w))
        spark.curve(to: NSPoint(x: c.x - r, y: c.y), controlPoint1: NSPoint(x: c.x - w * 0.4, y: c.y - w), controlPoint2: NSPoint(x: c.x - w, y: c.y - w * 0.4))
        spark.curve(to: NSPoint(x: c.x, y: c.y + r), controlPoint1: NSPoint(x: c.x - w, y: c.y + w * 0.4), controlPoint2: NSPoint(x: c.x - w * 0.4, y: c.y + w))
        spark.close()
        spark.fill()
    }

    /// The menu bar icon: 18 pt, monochrome, template.
    static func menuBarImage(running: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            NSColor.black.set()
            draw(in: rect, running: running)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Agent Commander"
        return image
    }
}
