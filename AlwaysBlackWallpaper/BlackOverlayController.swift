import AppKit

/// Places a black, click-through window directly above the wallpaper of each external display.
/// The window joins every Space, so the old wallpaper never shows while switching Spaces,
/// and it appears as soon as a display is connected, before the wallpaper change lands.
@MainActor
final class BlackOverlayController {
    private var windows: [CGDirectDisplayID: NSWindow] = [:]

    /// One level above the wallpaper, below desktop widgets and desktop icons.
    private static let level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) - 2)

    func update(enabled: Bool) {
        guard enabled else {
            removeAll()
            return
        }

        var seen = Set<CGDirectDisplayID>()
        for screen in NSScreen.screens {
            guard let id = screen.displayID, CGDisplayIsBuiltin(id) == 0 else { continue }
            seen.insert(id)
            let window = windows[id] ?? makeWindow()
            windows[id] = window
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
        }

        for (id, window) in windows where !seen.contains(id) {
            window.orderOut(nil)
            windows[id] = nil
        }
    }

    func removeAll() {
        windows.values.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        window.isOpaque = true
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = Self.level
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        return window
    }
}
