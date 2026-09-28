import AppKit
import Combine
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct DisplayInfo: Identifiable, Equatable {
    let id: CGDirectDisplayID
    let name: String
    let isBuiltin: Bool
    let wallpaperPath: String?
}

/// Keeps every non-built-in display on a solid black wallpaper.
@MainActor
final class WallpaperManager: ObservableObject {
    static let shared = WallpaperManager()

    @Published var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            defaults.set(isEnabled, forKey: Keys.enabled)
            if isEnabled {
                // Wallpapers may have been changed while disabled, so capture them fresh.
                originals = [:]
                applyNow()
            } else {
                restoreOriginals()
            }
        }
    }
    @Published private(set) var displays: [DisplayInfo] = []
    @Published private(set) var lastApplied: Date?
    @Published private(set) var lastError: String?

    let blackImageURL: URL

    private let defaults = UserDefaults.standard
    private var observers: [NSObjectProtocol] = []
    private var pendingApply: DispatchWorkItem?
    private static let debounceInterval: TimeInterval = 0.5

    private enum Keys {
        static let enabled = "enabled"
        static let originals = "originalWallpapers"
    }

    /// Wallpaper URL each external display had before we turned it black, keyed by display UUID.
    private var originals: [String: String] {
        get { defaults.dictionary(forKey: Keys.originals) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: Keys.originals) }
    }

    private var blackOptions: [NSWorkspace.DesktopImageOptionKey: Any] {
        [
            .imageScaling: NSImageScaling.scaleAxesIndependently.rawValue,
            .allowClipping: true,
            .fillColor: NSColor.black,
        ]
    }

    private init() {
        defaults.register(defaults: [Keys.enabled: true])
        isEnabled = defaults.bool(forKey: Keys.enabled)

        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AlwaysBlackWallpaper", isDirectory: true)
        blackImageURL = support.appendingPathComponent("black.png")

        do {
            try Self.ensureBlackImage(at: blackImageURL)
        } catch {
            lastError = "black.png 생성 실패: \(error.localizedDescription)"
        }

        startObserving()
        refreshDisplays()
        if isEnabled { applyNow() }
    }

    // MARK: - Observing

    private func startObserving() {
        let center = NotificationCenter.default
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        // Display connected/disconnected, resolution or arrangement changed.
        observers.append(center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleApply() }
        })

        // setDesktopImageURL only affects the current Space of each display, so re-apply on Space switch.
        // Waking from sleep can also bring displays back with their old wallpaper.
        for name in [
            NSWorkspace.activeSpaceDidChangeNotification,
            NSWorkspace.didWakeNotification,
            NSWorkspace.screensDidWakeNotification,
        ] {
            observers.append(workspaceCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleApply() }
            })
        }
    }

    /// Coalesces bursts of notifications into one apply.
    func scheduleApply() {
        pendingApply?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.refreshDisplays()
                if self.isEnabled { self.applyNow() }
            }
        }
        pendingApply = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.debounceInterval, execute: work)
    }

    // MARK: - Applying

    func applyNow() {
        let workspace = NSWorkspace.shared
        var stored = originals
        var errors: [String] = []

        for screen in NSScreen.screens {
            guard let id = screen.displayID, CGDisplayIsBuiltin(id) == 0 else { continue }
            let current = workspace.desktopImageURL(for: screen)

            if let uuid = Self.uuid(for: id), stored[uuid] == nil,
               let current, !isBlackImage(current) {
                stored[uuid] = current.absoluteString
            }

            if let current, isBlackImage(current) { continue }
            do {
                try workspace.setDesktopImageURL(blackImageURL, for: screen, options: blackOptions)
            } catch {
                errors.append("\(screen.localizedName): \(error.localizedDescription)")
            }
        }

        originals = stored
        lastApplied = Date()
        lastError = errors.isEmpty ? nil : errors.joined(separator: "\n")
        refreshDisplays()
    }

    private func restoreOriginals() {
        pendingApply?.cancel()
        let workspace = NSWorkspace.shared
        let stored = originals
        var errors: [String] = []

        for screen in NSScreen.screens {
            guard let id = screen.displayID, CGDisplayIsBuiltin(id) == 0,
                  let uuid = Self.uuid(for: id),
                  let string = stored[uuid], let url = URL(string: string) else { continue }
            guard FileManager.default.fileExists(atPath: url.path) else {
                errors.append("\(screen.localizedName): 원래 배경화면 파일이 없음 (\(url.path))")
                continue
            }
            do {
                try workspace.setDesktopImageURL(url, for: screen, options: [:])
            } catch {
                errors.append("\(screen.localizedName): \(error.localizedDescription)")
            }
        }

        lastError = errors.isEmpty ? nil : errors.joined(separator: "\n")
        refreshDisplays()
    }

    func refreshDisplays() {
        displays = NSScreen.screens.compactMap { screen in
            guard let id = screen.displayID else { return nil }
            return DisplayInfo(
                id: id,
                name: screen.localizedName,
                isBuiltin: CGDisplayIsBuiltin(id) != 0,
                wallpaperPath: NSWorkspace.shared.desktopImageURL(for: screen)?.path
            )
        }
    }

    // MARK: - Helpers

    private func isBlackImage(_ url: URL) -> Bool {
        url.standardizedFileURL.path == blackImageURL.standardizedFileURL.path
    }

    private static func uuid(for id: CGDirectDisplayID) -> String? {
        guard let cfUUID = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, cfUUID) as String
    }

    private static func ensureBlackImage(at url: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) { return }
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        let size = 64
        guard let context = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { throw CocoaError(.fileWriteUnknown) }
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))

        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
