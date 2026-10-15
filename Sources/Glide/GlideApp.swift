import AppKit
import GlideCore
import ServiceManagement
import SwiftUI

@main
enum GlideMain {
    static func main() {
        let arguments = CommandLine.arguments
        if let index = arguments.firstIndex(of: CrashWatchdog.argument), index + 1 < arguments.count, let parent = pid_t(arguments[index + 1]) {
            CrashWatchdog.run(parent: parent)
        }
        GlideApp.main()
    }
}

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
        controller.stopWatchdog()
    }
}

/// Owns the long-lived pieces and decides when tiling runs.
@Observable
final class AppController {
    @ObservationIgnored let windowManager = WindowManager()
    @ObservationIgnored let hotkeys = HotkeyCenter()
    @ObservationIgnored let permission = AccessibilityPermission()
    @ObservationIgnored private let trackpad = TrackpadMonitor()
    @ObservationIgnored private var swipeTracker = SwipeTracker(fingerCount: 3)
    @ObservationIgnored private let wheel = WheelMonitor()
    @ObservationIgnored let updates = Updates()
    let shortcuts = ShortcutStore()
    let appRules = RuleStore()
    /// Bumped whenever tiling or hotkey state changes, so SwiftUI views refresh.
    private(set) var revision = 0

    @ObservationIgnored private var statusMenu: StatusMenu?
    @ObservationIgnored private var watchdog: Process?
    @ObservationIgnored private lazy var overview = OverviewController(manager: windowManager)
    @ObservationIgnored private let workspaceHUD = WorkspaceHUD()
    @ObservationIgnored private let shortcutSheet = ShortcutSheetController()
    @ObservationIgnored private lazy var settingsWindow = SettingsWindowController(controller: self)
    @ObservationIgnored private lazy var onboardingWindow = OnboardingWindowController(controller: self)
    @ObservationIgnored private lazy var whatsNewWindow = WhatsNewWindowController()

    private static let tilingEnabledKey = "tilingEnabled"

    var isTilingPreferred: Bool {
        get { UserDefaults.standard.object(forKey: Self.tilingEnabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.tilingEnabledKey) }
    }

    var isTrusted: Bool { permission.isTrusted }

    func launch() {
        watchdog = CrashWatchdog.launch()
        updates.start()
        statusMenu = StatusMenu(controller: self)
        hotkeys.onAction = { [weak self] action in self?.perform(action) }
        shortcuts.onChange = { [weak self] in self?.registerHotkeys() }
        windowManager.onChange = { [weak self] in self?.stateChanged() }
        windowManager.rules = appRules.rules
        appRules.onChange = { [weak self] rules in self?.windowManager.rulesChanged(rules) }
        windowManager.onWorkspaceEvent = { [weak self] message in self?.showWorkspaceHUD(message) }
        permission.onChange = { [weak self] trusted in self?.permissionChanged(trusted) }
        permission.startMonitoring()
        registerHotkeys()
        trackpad.onFrame = { [weak self] touches, time in self?.handleTouches(touches, at: time) }
        updateTrackpad()
        wheel.handle = { [weak self] tick in self?.handleWheel(tick) ?? false }
        updateWheel()

        if permission.isTrusted {
            if isTilingPreferred { windowManager.start() }
        } else {
            showOnboarding()
        }
        // For development: `open Glide.app --args -GlideShowOnboarding YES`.
        if UserDefaults.standard.bool(forKey: "GlideShowOnboarding") { onboardingWindow.show() }
        showWhatsNewAfterUpdate()
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
        if action == .toggleOverview {
            overview.toggle()
            return
        }
        if action == .showShortcuts {
            shortcutSheet.toggle(keymap: shortcuts.keymap, problems: hotkeys.problems, on: windowManager.focusedScreen)
            return
        }
        if shortcutSheet.isShown { shortcutSheet.close() }
        // Anything else acts on the layout behind the overview, which would make it stale.
        if overview.isShown { overview.close(goingTo: nil) }
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
        updateWheel()
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

    private func showWorkspaceHUD(_ message: String) {
        guard Appearance.showsWorkspaceHUD else { return }
        workspaceHUD.show(entries: windowManager.workspaceSummary.map { .init(number: $0.number, isActive: $0.isActive) }, message: message,
                          on: windowManager.focusedScreen)
    }

    /// Tells the watchdog this is a clean quit, so it doesn't step in.
    func stopWatchdog() {
        watchdog?.terminate()
        watchdog = nil
    }

    // MARK: Login item

    var opensAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    /// macOS registered the login item but wants the user to allow it in System Settings.
    var loginItemNeedsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    func setOpensAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Glide: couldn't \(enabled ? "add" : "remove") the login item: \(error.localizedDescription)")
        }
        stateChanged()
    }

    // MARK: What's new

    private static let lastSeenVersionKey = "lastSeenVersion"

    /// The first launch of a newer version shows what changed since the last one seen. A new
    /// install (no Accessibility access yet) only remembers its version. Copies from before this
    /// never saved one, so they see the current version's notes.
    private func showWhatsNewAfterUpdate() {
        guard let current = Self.currentVersion else { return }
        let seen = UserDefaults.standard.string(forKey: Self.lastSeenVersionKey).flatMap { Changelog.Version($0) }
        guard seen != current else { return }
        UserDefaults.standard.set(current.description, forKey: Self.lastSeenVersionKey)
        if seen == nil && !permission.isTrusted { return }
        whatsNewWindow.show(WhatsNewWindowController.changelog.since(seen, current: current))
    }

    /// Every release up to the one running, so notes for unreleased versions stay out of the menu.
    func showWhatsNew() {
        guard let current = Self.currentVersion else { return }
        whatsNewWindow.show(WhatsNewWindowController.changelog.releases.filter { $0.version <= current })
    }

    private static var currentVersion: Changelog.Version? {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String).flatMap { Changelog.Version($0) }
    }

    // MARK: Report a problem

    func reportProblem() {
        ProblemReport.open(layout: windowManager.stripDescription + "\n")
    }

    // MARK: Updates

    var checksForUpdates: Bool {
        get { updates.checksAutomatically }
        set {
            updates.checksAutomatically = newValue
            stateChanged()
        }
    }

    var installsUpdates: Bool {
        get { updates.installsAutomatically }
        set {
            updates.installsAutomatically = newValue
            stateChanged()
        }
    }

    // MARK: Trackpad

    private static let trackpadSwipeKey = "trackpadSwipe"

    var isTrackpadSwipeEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.trackpadSwipeKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.trackpadSwipeKey)
            updateTrackpad()
            stateChanged()
        }
    }

    /// True when macOS also switches Spaces with a three-finger horizontal swipe.
    var systemUsesThreeFingerSwipe: Bool {
        ["com.apple.AppleMultitouchTrackpad", "com.apple.driver.AppleBluetoothMultitouch.trackpad"].contains {
            UserDefaults(suiteName: $0)?.integer(forKey: "TrackpadThreeFingerHorizSwipeGesture") == 2
        }
    }

    private func updateTrackpad() {
        if isTrackpadSwipeEnabled {
            if !trackpad.start() { NSLog("Glide: no trackpad available for swipes") }
        } else {
            trackpad.stop()
            swipeTracker = SwipeTracker(fingerCount: 3)
        }
    }

    /// One trackpad width of finger travel scrolls one and a half screens.
    private var swipeGain: CGFloat { windowManager.viewportWidth * 1.5 }

    private func handleTouches(_ touches: [Touch], at time: Double) {
        // A full-screen app keeps its gestures; a swipe in progress is let go.
        let touches = windowManager.gesturesPassThrough ? [] : touches
        for event in swipeTracker.update(touches: touches, at: time) {
            switch event {
            case .began:
                windowManager.beginSwipe()
            case .changed(let dx):
                // The strip follows the fingers: moving them left reveals columns on the right.
                windowManager.swipe(by: -CGFloat(dx) * swipeGain)
            case .ended(let velocity):
                windowManager.endSwipe(velocity: -CGFloat(velocity) * swipeGain)
            }
        }
    }

    // MARK: Mouse wheel

    private static let horizontalWheelKey = "horizontalWheel"

    var horizontalWheelMode: HorizontalWheelMode {
        get { UserDefaults.standard.string(forKey: Self.horizontalWheelKey).flatMap(HorizontalWheelMode.init(rawValue:)) ?? .always }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Self.horizontalWheelKey)
            stateChanged()
        }
    }

    private func updateWheel() {
        guard permission.isTrusted else { return wheel.stop() }
        if !wheel.start() { NSLog("Glide: couldn't watch the mouse wheel") }
    }

    private func handleWheel(_ tick: WheelTick) -> Bool {
        guard windowManager.isEnabled else { return false }
        // A full-screen video or game keeps its wheel; ⌃⌥ is asked for, so it still goes to the strip.
        if windowManager.gesturesPassThrough, !tick.chordHeld { return false }
        let mode = horizontalWheelMode
        guard WheelRouting.movesStrip(horizontal: tick.horizontal, chordHeld: tick.chordHeld, mode: mode) else { return false }
        windowManager.scrollWheel(notches: tick.notches)
        return true
    }

    /// Applies gap, focus ring and dimming changes made in Settings.
    func appearanceChanged() {
        windowManager.appearanceChanged()
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
