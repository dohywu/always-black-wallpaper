import AppKit
import SwiftUI

@main
struct AlwaysBlackWallpaperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var wallpaper = WallpaperManager.shared
    @StateObject private var loginItem = LoginItemManager.shared

    var body: some Scene {
        Window("Always Black Wallpaper", id: AppDelegate.mainWindowID) {
            ContentView()
                .environmentObject(wallpaper)
                .environmentObject(loginItem)
        }
        .windowResizability(.contentSize)
        // Launching at login should stay quiet; the window opens from the menu bar or the Dock icon.
        .defaultLaunchBehavior(.suppressed)

        MenuBarExtra {
            MenuBarContent()
                .environmentObject(wallpaper)
        } label: {
            MenuBarLabel(isEnabled: wallpaper.isEnabled)
        }
    }
}

enum AppVersion {
    /// "1.1.0 (2)" from CFBundleShortVersionString and CFBundleVersion.
    static var display: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let mainWindowID = "main"
    /// Set by the menu bar label so the Dock icon can open the SwiftUI window.
    @MainActor static var openMainWindow: (() -> Void)?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Ignore `flag`: the black overlay windows count as visible, but the user wants the main window.
        MainActor.assumeIsolated { Self.openMainWindow?() }
        return true
    }
}

private struct MenuBarLabel: View {
    let isEnabled: Bool
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: isEnabled ? "rectangle.fill.on.rectangle.fill" : "rectangle.on.rectangle")
            .onAppear {
                AppDelegate.openMainWindow = {
                    openWindow(id: AppDelegate.mainWindowID)
                    NSApp.activate()
                }
            }
    }
}

private struct MenuBarContent: View {
    @EnvironmentObject private var wallpaper: WallpaperManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("Always Black Wallpaper \(AppVersion.display)")
        Divider()
        Toggle("외장 디스플레이 검은 배경 유지", isOn: $wallpaper.isEnabled)
        Toggle("즉시 적용", isOn: $wallpaper.applyImmediately)
            .disabled(!wallpaper.isEnabled)
        Toggle("깜빡임 방지 덮개", isOn: $wallpaper.overlayEnabled)
            .disabled(!wallpaper.isEnabled)
        Button("지금 다시 적용") { wallpaper.applyNow() }
            .disabled(!wallpaper.isEnabled)
        Divider()
        Button("창 열기…") {
            openWindow(id: AppDelegate.mainWindowID)
            NSApp.activate()
        }
        Divider()
        Button("종료") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
