// Builds only with Tools/screenshot.sh (-D SCREENSHOT). Opens the menu over a plain
// backdrop, captures it for docs/menu.png, then quits. Not part of the app.

import AppKit

func key(_ code: UInt16, _ scalar: Int) {
    let chars = String(UnicodeScalar(scalar)!)
    for type in [NSEvent.EventType.keyDown, .keyUp] {
        if let e = NSEvent.keyEvent(with: type, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                    windowNumber: 0, context: nil, characters: chars, charactersIgnoringModifiers: chars,
                                    isARepeat: false, keyCode: code) {
            NSApp.postEvent(e, atStart: false)
        }
    }
}

final class Backdrop: NSView {
    var iconRect = NSRect.zero   // in view coords
    var barHeight: CGFloat = 32
    override func draw(_ dirtyRect: NSRect) {
        let dark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let g = NSGradient(colors: dark
            ? [NSColor(calibratedRed: 0.16, green: 0.20, blue: 0.30, alpha: 1), NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.16, alpha: 1)]
            : [NSColor(calibratedRed: 0.62, green: 0.74, blue: 0.92, alpha: 1), NSColor(calibratedRed: 0.86, green: 0.80, blue: 0.93, alpha: 1)])!
        g.draw(in: bounds, angle: -60)
        (dark ? NSColor(white: 0, alpha: 0.35) : NSColor(white: 1, alpha: 0.45)).setFill()
        NSRect(x: 0, y: bounds.height - barHeight, width: bounds.width, height: barHeight).fill()
        (dark ? NSColor(white: 1, alpha: 0.18) : NSColor(white: 0, alpha: 0.10)).setFill()
        NSBezierPath(roundedRect: iconRect.insetBy(dx: 2, dy: 4), xRadius: 6, yRadius: 6).fill()
        (dark ? NSColor.white : NSColor.black).set()
        Glyph.draw(in: NSRect(x: iconRect.midX - 9, y: iconRect.midY - 9, width: 18, height: 18))
    }
}

var backdropWindow: NSWindow?

func screenshotHarness(_ d: AppDelegate) {
    let out = ProcessInfo.processInfo.environment["SHOT_OUT"] ?? "/tmp/menu.png"
    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
        // Use a Retina screen when there is one, so the image comes out sharp, and
        // pretend the menu bar icon sits near its top right.
        guard let screen = NSScreen.screens.first(where: { $0.backingScaleFactor >= 2 }) ?? NSScreen.main else { exit(2) }
        let barH = screen.frame.maxY - screen.visibleFrame.maxY
        let icon = NSRect(x: screen.frame.maxX - 640, y: screen.frame.maxY - barH, width: 34, height: barH)
        let sf = screen.frame
        let left = max(sf.minX, icon.minX - 500), right = min(sf.maxX, icon.minX + 800)
        let bd = NSRect(x: left, y: sf.maxY - 420, width: right - left, height: 420)
        let w = NSWindow(contentRect: bd, styleMask: .borderless, backing: .buffered, defer: false)
        w.level = .popUpMenu   // above other apps' menu bar popovers; our menu opens on top of it
        w.isOpaque = true
        let v = Backdrop(frame: NSRect(origin: .zero, size: bd.size))
        v.barHeight = sf.maxY - screen.visibleFrame.maxY
        v.iconRect = NSRect(x: icon.minX - bd.minX, y: bd.height - v.barHeight, width: icon.width, height: v.barHeight)
        w.contentView = v
        w.orderFrontRegardless()
        backdropWindow = w

        let primaryH = NSScreen.screens[0].frame.maxY
        let steps: [(Double, () -> Void)] = [
            (0.6, { key(125, NSDownArrowFunctionKey) }),
            (1.2, { key(124, NSRightArrowFunctionKey) }),
            (2.6, {
                let pid = ProcessInfo.processInfo.processIdentifier
                let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
                var union = CGRect(x: icon.minX, y: primaryH - icon.maxY, width: icon.width, height: icon.height)
                for win in info where (win[kCGWindowOwnerPID as String] as? Int32) == pid && (win[kCGWindowLayer as String] as? Int) == 101
                    && (win[kCGWindowNumber as String] as? Int) != w.windowNumber {
                    let b = win[kCGWindowBounds as String] as! [String: CGFloat]
                    union = union.union(CGRect(x: b["X"]!, y: b["Y"]!, width: b["Width"]!, height: b["Height"]!))
                }
                let bdCG = CGRect(x: bd.minX, y: primaryH - bd.maxY, width: bd.width, height: bd.height)
                let r = union.insetBy(dx: -40, dy: -30).intersection(bdCG)
                let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                p.arguments = ["-x", "-R\(Int(r.minX)),\(Int(r.minY)),\(Int(r.width)),\(Int(r.height))", out]
                try? p.run(); p.waitUntilExit()
                d.statusItem.menu?.cancelTracking()
            }),
            (3.1, { exit(0) }),
        ]
        for (t, f) in steps { RunLoop.main.add(Timer(timeInterval: t, repeats: false) { _ in f() }, forMode: .common) }
        d.statusItem.menu!.popUp(positioning: nil, at: NSPoint(x: icon.minX, y: icon.minY - 3), in: nil)
    }
}
