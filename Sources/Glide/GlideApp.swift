import AppKit
import GlideCore
import SwiftUI

@main
struct GlideApp: App {
    @NSApplicationDelegateAdaptor(GlideAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class GlideAppDelegate: NSObject, NSApplicationDelegate {
    private let controller = AppController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.launch()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Never leave windows parked off screen.
        controller.windowManager.stop()
    }
}

/// Owns the long-lived pieces and decides when tiling runs.
@Observable
final class AppController {
    @ObservationIgnored let windowManager = WindowManager()
    @ObservationIgnored let hotkeys = HotkeyCenter()
    @ObservationIgnored let permission = AccessibilityPermission()
    let shortcuts = ShortcutStore()
    /// Bumped whenever tiling or hotkey state changes, so SwiftUI views refresh.
    private(set) var revision = 0

    @ObservationIgnored private var statusMenu: StatusMenu?
    @ObservationIgnored private lazy var settingsWindow = SettingsWindowController(controller: self)
    @ObservationIgnored private lazy var onboardingWindow = OnboardingWindowController(controller: self)

    private static let tilingEnabledKey = "tilingEnabled"

    var isTilingPreferred: Bool {
        get { UserDefaults.standard.object(forKey: Self.tilingEnabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.tilingEnabledKey) }
    }

    var isTrusted: Bool { permission.isTrusted }

    func launch() {
        statusMenu = StatusMenu(controller: self)
        hotkeys.onAction = { [weak self] action in self?.perform(action) }
        shortcuts.onChange = { [weak self] in self?.registerHotkeys() }
        windowManager.onChange = { [weak self] in self?.stateChanged() }
        permission.onChange = { [weak self] trusted in self?.permissionChanged(trusted) }
        permission.startMonitoring()
        registerHotkeys()

        if permission.isTrusted {
            if isTilingPreferred { windowManager.start() }
        } else {
            showOnboarding()
        }
        // For development: `open Glide.app --args -GlideShowOnboarding YES`.
        if UserDefaults.standard.bool(forKey: "GlideShowOnboarding") { onboardingWindow.show() }
        stateChanged()
    }

    func registerHotkeys() {
        guard !hotkeys.isSuspended else { return }
        hotkeys.register(shortcuts.keymap)
        stateChanged()
    }

    func suspendHotkeys() { hotkeys.suspend() }

    func resumeHotkeys() {
        hotkeys.register(shortcuts.keymap)
        stateChanged()
    }

    func perform(_ action: Action) {
        guard permission.isTrusted else {
            showOnboarding()
            return
        }
        if action == .toggleTiling {
            setTiling(!windowManager.isEnabled)
        } else {
            windowManager.perform(action)
        }
    }

    func setTiling(_ enabled: Bool) {
        isTilingPreferred = enabled
        if enabled {
            guard permission.isTrusted else { return showOnboarding() }
            windowManager.start()
        } else {
            windowManager.stop()
        }
        stateChanged()
    }

    private func permissionChanged(_ trusted: Bool) {
        if trusted {
            onboardingWindow.close()
            if isTilingPreferred { windowManager.start() }
        } else {
            // The grant was revoked: AX calls now fail, so stop cleanly and explain.
            windowManager.stop()
            showOnboarding()
        }
        stateChanged()
    }

    private func stateChanged() {
        revision += 1
        statusMenu?.refreshIcon()
    }

    func showOnboarding() {
        permission.requestPrompt()
        onboardingWindow.show()
    }

    func showSettings() {
        settingsWindow.show()
    }
}
