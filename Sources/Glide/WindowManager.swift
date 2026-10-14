import AppKit
import ApplicationServices
import GlideCore
import OSLog
import QuartzCore

private let log = Logger(subsystem: "dev.quackbyte.glide", category: "windows")

/// Connects the pure layout engine to real windows: tracks windows through the AX API and
/// NSWorkspace, feeds membership and focus changes into the workspaces, and applies their frames.
final class WindowManager {
    private struct TrackedWindow {
        let id: WindowID
        let pid: pid_t
        let element: AXUIElement
    }

    private(set) var isEnabled = false
    private var spaces = WorkspaceSet(viewport: .zero)
    /// The active workspace. Everything on screen belongs to it; the windows of the other
    /// workspaces wait hidden in the corner.
    private var workspace: Workspace {
        get { spaces.active }
        set { spaces.active = newValue }
    }
    /// Every managed window, tiled or floating. The strip says which ones are tiled.
    private var windows: [WindowID: TrackedWindow] = [:]
    /// Windows the user floated, and floating-by-default windows the user tiled.
    private var userFloating: Set<WindowID> = []
    private var userTiled: Set<WindowID> = []
    private var observers: [pid_t: AXObserver] = [:]
    /// The frame Glide last asked for, and the frame the window actually took.
    private var lastApplied: [WindowID: CGRect] = [:]
    private var lastObserved: [WindowID: CGRect] = [:]
    private var pendingReconcile: Set<pid_t> = []
    private var reconcileScheduled = false
    private var reassertWork: DispatchWorkItem?
    /// Ignores focus notifications for other windows briefly after Glide focuses one, so
    /// late notifications from the previously focused app don't pull focus back.
    private var focusLock: (window: WindowID, until: Date)?
    private var workspaceObservers: [NSObjectProtocol] = []
    /// The layout to rebuild when tiling starts, saved when it stops or after changes.
    private var snapshot: StripSnapshot?
    private var saveWork: DispatchWorkItem?
    static let snapshotKey = "stripSnapshot"
    private let decorations = FocusDecorations()
    private let tabBars = TabBarOverlay()
    /// Hidden tabs and the windows of inactive workspaces. They jump into place rather than
    /// sliding in from the corner they wait in.
    private var hiddenWindows: Set<WindowID> = []
    /// Ignores focus that lands on another workspace's window just after switching, since apps
    /// report the old focus late.
    private var workspaceSwitchLock: Date?
    /// Where windows were when their app was hidden or they were minimized, so they return there.
    private var departures: [WindowID: WorkspaceSet.Departure] = [:]
    /// Tiled windows the user resized with the mouse since the last snap-back.
    private var userResized: Set<WindowID> = []
    /// The window the user is dragging with the mouse, until they let go.
    private var draggedWindow: WindowID?

    /// Per-app float/tile, width and workspace rules, applied as windows appear.
    var rules = AppRules()

    /// Called after the layout or window membership changes.
    var onChange: (() -> Void)?
    /// Called after switching workspaces or sending a column to one, with a description.
    var onWorkspaceEvent: ((String) -> Void)?

    var tiledWindowCount: Int { workspace.strip.windows.count }
    var viewportWidth: CGFloat { workspace.viewport.width }
    var viewportSize: CGSize { workspace.viewport.size }
    var columnCount: Int { workspace.strip.columns.count }
    var floatingWindowCount: Int { windows.count - tiledWindowCount }

    // MARK: Lifecycle

    func start() {
        guard !isEnabled, AXIsProcessTrusted() else { return }
        isEnabled = true
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 1)
        spaces = WorkspaceSet(viewport: ScreenGeometry.primaryViewport() ?? .zero, settings: LayoutSettings(gap: Appearance.gap))
        loadSnapshot()
        tabBars.onSelect = { [weak self] window in self?.selectTab(window) }
        observeWorkspace()
        let apps = NSWorkspace.shared.runningApplications.filter(isManageable)
        for app in apps { observe(app) }
        reconcile(Set(apps.map(\.processIdentifier)), adopting: true)
    }

    /// Stops tiling and moves every window somewhere fully on screen.
    func stop() {
        guard isEnabled else { return }
        finishAnimations()
        // Every workspace's windows: the hidden ones come back on screen too.
        let ordered = spaces.allWindows.compactMap { id in
            windows[id].flatMap { window in window.element.frame.map { (window, $0) } }
        }
        let restored = RestorePlanner.restoredFrames(for: ordered.map { ($0.0.id, $0.1) }, in: workspace.viewport)
        for (window, _) in ordered {
            if let frame = restored[window.id] { window.element.setFrame(frame) }
        }

        saveSnapshot()
        decorations.hide()
        tabBars.hide()
        hiddenWindows = []
        departures = [:]
        isEnabled = false
        reassertWork?.cancel()
        for observer in observers.values {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observers = [:]
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            NotificationCenter.default.removeObserver(observer)
        }
        workspaceObservers = []
        windows = [:]
        userFloating = []
        userTiled = []
        lastApplied = [:]
        lastObserved = [:]
        pendingReconcile = []
        spaces = WorkspaceSet(viewport: .zero)
        onChange?()
    }

    // MARK: Persistence

    private func didChange() {
        onChange?()
        // Saved shortly after changes too, so a crash doesn't lose the layout.
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveSnapshot() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }

    private func saveSnapshot() {
        saveWork?.cancel()
        guard isEnabled, let bootTime = Self.bootTime else { return }
        let snapshot = StripSnapshot(workspaces: spaces, userFloating: userFloating, userTiled: userTiled, bootTime: bootTime)
        self.snapshot = snapshot
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.snapshotKey)
        }
    }

    /// Restores the user's float/tile choices now; columns are rebuilt when windows are adopted.
    private func loadSnapshot() {
        if snapshot == nil, let data = UserDefaults.standard.data(forKey: Self.snapshotKey) {
            snapshot = try? JSONDecoder().decode(StripSnapshot.self, from: data)
        }
        guard let saved = snapshot, let bootTime = Self.bootTime, abs(saved.bootTime.timeIntervalSince(bootTime)) < 1 else {
            snapshot = nil
            return
        }
        userFloating = Set(saved.userFloating)
        userTiled = Set(saved.userTiled)
    }

    private static let bootTime: Date? = {
        var time = timeval()
        var size = MemoryLayout<timeval>.size
        guard sysctlbyname("kern.boottime", &time, &size, nil, 0) == 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(time.tv_sec) + TimeInterval(time.tv_usec) / 1_000_000)
    }()

    /// Applies changed gap, focus ring and dimming settings.
    func appearanceChanged() {
        guard isEnabled else { return }
        if spaces.settings.gap != Appearance.gap {
            spaces.settings.gap = Appearance.gap
            workspace.minimumWidths = [:]
            workspace.settleScroll()
            applyLayout()
        }
        tabBars.invalidate()
        refreshOverlays()
    }

    // MARK: Actions

    func perform(_ action: Action) {
        guard isEnabled else { return }
        if let command = action.workspaceCommand {
            performWorkspace(command.target, movesColumn: command.movesColumn)
            return
        }
        if action == .toggleFloating {
            toggleFloating()
            return
        }
        // Start from the window the user is actually in, in case a notification was missed.
        if let focused = focusedWindowID(), workspace.strip.contains(focused) {
            workspace.strip.focus(focused)
        }
        guard workspace.perform(action) else {
            log.debug("\(action.rawValue, privacy: .public): no change. \(self.stripDescription, privacy: .public)")
            return
        }
        log.debug("\(action.rawValue, privacy: .public): \(self.stripDescription, privacy: .public)")
        applyLayout()
        if let target = workspace.strip.focusedWindow, target != focusedWindowID() {
            focus(target)
        }
        didChange()
    }

    private func toggleFloating() {
        guard let id = focusedWindowID() else { return NSSound.beep() }
        if windows[id] == nil, let element = focusedWindowElement(), let pid = element.pid,
           WindowClassifier.classify(element) != .ignored {
            track(id, pid: pid, element: element)
        }
        guard let window = windows[id] else { return NSSound.beep() }

        if workspace.strip.contains(id) {
            workspace.strip.remove(id)
            userTiled.remove(id)
            userFloating.insert(id)
            lastApplied[id] = nil
            workspace.settleScroll()
            applyLayout()
            window.element.setFrame(floatingFrame(for: window.element))
            focus(id)
        } else {
            guard window.element.isSettable(kAXSizeAttribute) else { return NSSound.beep() }
            userFloating.remove(id)
            userTiled.insert(id)
            workspace.strip.insert(id, widthIndex: workspace.settings.defaultWidthIndex)
            workspace.ensureFocusedVisible()
            applyLayout()
        }
        didChange()
    }

    /// A floated window keeps its size (up to 70% of the screen) and moves to the center.
    private func floatingFrame(for element: AXUIElement) -> CGRect {
        let viewport = workspace.viewport
        let current = element.size ?? CGSize(width: viewport.width / 2, height: viewport.height / 2)
        let size = CGSize(width: min(current.width, viewport.width * 0.7), height: min(current.height, viewport.height * 0.7))
        return CGRect(x: (viewport.midX - size.width / 2).rounded(), y: (viewport.midY - size.height / 2).rounded(), width: size.width, height: size.height)
    }

    // MARK: Observing apps

    private func isManageable(_ app: NSRunningApplication) -> Bool {
        app.activationPolicy == .regular && app.processIdentifier != ProcessInfo.processInfo.processIdentifier && !app.isTerminated
    }

    private func observeWorkspace() {
        let center = NSWorkspace.shared.notificationCenter
        func on(_ name: Notification.Name, _ handler: @escaping (NSRunningApplication) -> Void) {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                MainActor.assumeIsolated { handler(app) }
            })
        }
        on(NSWorkspace.didLaunchApplicationNotification) { [weak self] app in
            guard let self, isManageable(app) else { return }
            observe(app)
            scheduleReconcile(app.processIdentifier, retries: [0.2, 0.6, 1.5])
        }
        on(NSWorkspace.didTerminateApplicationNotification) { [weak self] app in
            self?.forgetApp(app.processIdentifier)
        }
        on(NSWorkspace.didActivateApplicationNotification) { [weak self] app in
            guard let self, isManageable(app) else { return }
            if observers[app.processIdentifier] == nil { observe(app) }
            scheduleReconcile(app.processIdentifier)
            syncFocus()
        }
        on(NSWorkspace.didDeactivateApplicationNotification) { [weak self] app in
            // Catches windows that disappear when their app loses focus.
            self?.scheduleReconcile(app.processIdentifier, retries: [0.3])
            self?.refreshOverlays()
        }
        on(NSWorkspace.didHideApplicationNotification) { [weak self] app in
            self?.scheduleReconcile(app.processIdentifier)
        }
        on(NSWorkspace.didUnhideApplicationNotification) { [weak self] app in
            self?.scheduleReconcile(app.processIdentifier, retries: [0.3])
        }
        workspaceObservers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenParametersChanged() }
        })
    }

    private func screenParametersChanged() {
        guard isEnabled, let viewport = ScreenGeometry.primaryViewport(), viewport != workspace.viewport else { return }
        spaces.viewport = viewport
        workspace.settleScroll()
        lastApplied = [:]
        applyLayout()
        // The corner hidden windows wait in has moved.
        hide(inactiveWindows)
    }

    private static let appNotifications = [
        kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification,
        kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification,
        kAXApplicationHiddenNotification, kAXApplicationShownNotification,
    ]
    private static let windowNotifications = [
        kAXUIElementDestroyedNotification, kAXWindowMiniaturizedNotification, kAXWindowMovedNotification, kAXWindowResizedNotification,
        kAXTitleChangedNotification,
    ]

    private func observe(_ app: NSRunningApplication, attempt: Int = 0) {
        let pid = app.processIdentifier
        guard isEnabled, observers[pid] == nil, isManageable(app) else { return }
        var created: AXObserver?
        guard AXObserverCreate(pid, axObserverCallback, &created) == .success, let observer = created else { return }
        let element = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let results = Self.appNotifications.map { AXObserverAddNotification(observer, element, $0 as CFString, refcon) }
        // Apps that just launched may not answer yet; try again shortly.
        if !results.contains(.success) {
            if attempt < 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.observe(app, attempt: attempt + 1) }
            }
            return
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        observers[pid] = observer
    }

    private func forgetApp(_ pid: pid_t) {
        if let observer = observers.removeValue(forKey: pid) {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        let gone = windows.values.filter { $0.pid == pid }.map(\.id)
        guard !gone.isEmpty else { return }
        gone.forEach(forget)
        workspace.settleScroll()
        applyLayout()
        syncFocus()
        refreshOverlays()
        didChange()
    }

    fileprivate func handle(_ notification: String, element: AXUIElement) {
        guard isEnabled, let pid = element.pid else { return }
        switch notification {
        case kAXWindowCreatedNotification:
            scheduleReconcile(pid, retries: [0.3, 1.0])
        case kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification:
            syncFocus()
        case kAXWindowMovedNotification, kAXWindowResizedNotification:
            // The ring can't follow a drag smoothly; hide it until the window snaps back.
            if notification == kAXWindowResizedNotification, NSEvent.pressedMouseButtons != 0, let id = element.windowID {
                userResized.insert(id)
            }
            // A move while the mouse is down that Glide didn't make is the user dragging the window.
            if notification == kAXWindowMovedNotification, NSEvent.pressedMouseButtons != 0, let id = element.windowID,
               motions[id] == nil, element.position != lastApplied[id]?.origin {
                draggedWindow = id
            }
            if NSEvent.pressedMouseButtons != 0, element.windowID == decorations.target {
                decorations.hide()
                tabBars.hide()
            }
            scheduleReassert()
        case kAXTitleChangedNotification:
            if motions.isEmpty, !isSwiping, workspace.strip.columns.contains(where: \.isTabbed) { refreshTabBars() }
        default:
            scheduleReconcile(pid)
        }
    }

    // MARK: Membership

    private func scheduleReconcile(_ pid: pid_t, retries: [TimeInterval] = []) {
        pendingReconcile.insert(pid)
        if !reconcileScheduled {
            reconcileScheduled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self else { return }
                reconcileScheduled = false
                let pids = pendingReconcile
                pendingReconcile = []
                reconcile(pids, adopting: false)
            }
        }
        for delay in retries {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.scheduleReconcile(pid) }
        }
    }

    /// Brings tracking in line with the apps' current windows: closed, minimized and hidden
    /// windows leave; new ones join. When adopting existing windows at startup they are added
    /// left to right in their current on-screen order.
    private func reconcile(_ pids: Set<pid_t>, adopting: Bool) {
        guard isEnabled, !pids.isEmpty else { return }
        let onScreen = onScreenWindowIDs()
        let focusedID = focusedWindowID()
        var changed = false
        var newTiles: [(id: WindowID, x: CGFloat)] = []
        // Some apps order windows out without minimizing or hiding (e.g. windows that close on
        // deactivate); AX still lists them. Treat those as gone, unless the whole strip is off
        // screen, which means the user switched to another Space.
        let stripOnScreen = workspace.strip.windows.contains(where: onScreen.contains)

        for pid in pids {
            let app = NSRunningApplication(processIdentifier: pid)
            let visible = app.map { !$0.isHidden && !$0.isTerminated } ?? false
            let elements: [AXUIElement] = visible ? (AXUIElementCreateApplication(pid).value(kAXWindowsAttribute) ?? []) : []

            var present: [WindowID: (element: AXUIElement, kind: WindowKind)] = [:]
            for element in elements {
                guard let id = element.windowID else { continue }
                let kind = WindowClassifier.classify(element)
                if kind != .ignored { present[id] = (element, kind) }
            }

            for window in windows.values where window.pid == pid
                && (present[window.id] == nil || (stripOnScreen && !onScreen.contains(window.id))) {
                // Hidden and minimized windows come back with the same ID; closed ones never do.
                if let departure = spaces.departure(of: window.id) { departures[window.id] = departure }
                forget(window.id)
                changed = true
            }

            for (id, entry) in present where windows[id] == nil {
                // Windows on other Spaces, or not drawn yet, are picked up once they appear.
                guard onScreen.contains(id) else { continue }
                track(id, pid: pid, element: entry.element)
                changed = true
                if shouldTile(id, pid: pid, element: entry.element, kind: entry.kind) {
                    newTiles.append((id, entry.element.position?.x ?? 0))
                }
            }
        }

        let width = workspace.settings.defaultWidthIndex
        if adopting {
            let ordered = newTiles.sorted { $0.x < $1.x }.map(\.id)
            if let snapshot {
                let restored = snapshot.restoreWorkspaces(windows: ordered, widthIndex: width, presetCount: workspace.settings.widthPresets.count)
                spaces.restore(strips: restored.strips, activeIndex: restored.active)
                hide(inactiveWindows)
            } else {
                for id in ordered {
                    let rule = rule(for: id)
                    if let target = rule?.workspace, target != spaces.activeIndex {
                        spaces.insert(id, widthIndex: widthIndex(for: rule), workspace: target, focus: false)
                        hide([id])
                    } else {
                        workspace.strip.insert(id, widthIndex: widthIndex(for: rule), at: workspace.strip.columns.count, focus: false)
                    }
                }
            }
        } else {
            for tile in newTiles.sorted(by: { $0.x < $1.x }) {
                if let departure = departures.removeValue(forKey: tile.id) {
                    let landed = spaces.rejoin(tile.id, from: departure, focus: tile.id == focusedID)
                    if landed != spaces.activeIndex { hide([tile.id]) }
                } else {
                    let rule = rule(for: tile.id)
                    let landed = spaces.insert(tile.id, widthIndex: widthIndex(for: rule), workspace: rule?.workspace, focus: tile.id == focusedID)
                    if landed != spaces.activeIndex { hide([tile.id]) }
                }
            }
            if departures.count > 500 { departures = [:] }
        }

        if let focusedID, workspace.strip.contains(focusedID) {
            changed = workspace.strip.focus(focusedID) || changed
        } else if !adopting, let focusedID, let index = spaces.index(of: focusedID), index != spaces.activeIndex {
            // A new window a rule sent to another workspace has focus: follow it there.
            switchWorkspace(to: index, focusing: focusedID)
            return
        }
        guard changed || adopting else { return }
        log.debug("reconciled \(pids.count) apps: \(self.stripDescription, privacy: .public)")
        workspace.settleScroll()
        applyLayout()
        refreshOverlays()
        didChange()
    }

    // MARK: App rules

    private func rule(for id: WindowID) -> AppRule? {
        windows[id].flatMap { rules.rule(for: NSRunningApplication(processIdentifier: $0.pid)?.bundleIdentifier) }
    }

    private func widthIndex(for rule: AppRule?) -> Int {
        let presets = workspace.settings.widthPresets.indices
        return rule?.widthIndex.flatMap { presets.contains($0) ? $0 : nil } ?? workspace.settings.defaultWidthIndex
    }

    private func shouldTile(_ id: WindowID, pid: pid_t, element: AXUIElement, kind: WindowKind) -> Bool {
        AppRules.shouldTile(
            rule: rules.rule(for: NSRunningApplication(processIdentifier: pid)?.bundleIdentifier),
            classifiedTileable: kind == .tileable,
            canTile: kind == .tileable || WindowClassifier.canTile(element),
            userFloating: userFloating.contains(id),
            userTiled: userTiled.contains(id)
        )
    }

    /// Applies edited rules to windows already open: windows of apps whose rule changed float
    /// or tile now. Widths and workspaces only apply to new windows, so nothing gets reshuffled.
    func rulesChanged(_ rules: AppRules) {
        let affected = Set(self.rules.rules.map(\.bundleID)).symmetricDifference(rules.rules.map(\.bundleID))
            .union(rules.rules.filter { self.rules.rule(for: $0.bundleID) != $0 }.map(\.bundleID))
        self.rules = rules
        guard isEnabled, !affected.isEmpty else { return }
        var changed = false
        for window in windows.values {
            guard let bundleID = NSRunningApplication(processIdentifier: window.pid)?.bundleIdentifier, affected.contains(bundleID) else { continue }
            let kind = WindowClassifier.classify(window.element)
            guard kind != .ignored else { continue }
            let tile = shouldTile(window.id, pid: window.pid, element: window.element, kind: kind)
            let tiled = spaces.index(of: window.id) != nil
            if tiled, !tile {
                spaces.remove(window.id)
                lastApplied[window.id] = nil
                hiddenWindows.remove(window.id)
                window.element.setFrame(floatingFrame(for: window.element))
                changed = true
            } else if !tiled, tile {
                let rule = rules.rule(for: bundleID)
                let landed = spaces.insert(window.id, widthIndex: widthIndex(for: rule), workspace: rule?.workspace, focus: false)
                if landed != spaces.activeIndex { hide([window.id]) }
                changed = true
            }
        }
        guard changed else { return }
        workspace.settleScroll()
        applyLayout()
        refreshOverlays()
        didChange()
    }

    private func track(_ id: WindowID, pid: pid_t, element: AXUIElement) {
        windows[id] = TrackedWindow(id: id, pid: pid, element: element)
        guard let observer = observers[pid] else { return }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for notification in Self.windowNotifications {
            AXObserverAddNotification(observer, element, notification as CFString, refcon)
        }
    }

    private func forget(_ id: WindowID) {
        spaces.remove(id)
        windows[id] = nil
        userFloating.remove(id)
        userTiled.remove(id)
        lastApplied[id] = nil
        lastObserved[id] = nil
        motions[id] = nil
        hiddenWindows.remove(id)
    }

    private func onScreenWindowIDs() -> Set<WindowID> {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        return Set(info.compactMap { $0[kCGWindowNumber as String] as? WindowID })
    }

    // MARK: Focus

    private func focusedWindowElement() -> AXUIElement? {
        // The system-wide focused application can stay nil for apps that just launched (seen
        // with Chrome and Electron apps), so ask the frontmost app first.
        if let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
           let window: AXUIElement = AXUIElementCreateApplication(pid).value(kAXFocusedWindowAttribute) {
            return window
        }
        let system = AXUIElementCreateSystemWide()
        guard let app: AXUIElement = system.value(kAXFocusedApplicationAttribute) else { return nil }
        return app.value(kAXFocusedWindowAttribute)
    }

    private func focusedWindowID() -> WindowID? { focusedWindowElement()?.windowID }

    /// Follows focus changes made outside Glide (clicks, ⌘-Tab, new windows) and scrolls to them.
    private func syncFocus() {
        guard isEnabled else { return }
        defer { refreshOverlays() }
        guard let id = focusedWindowID() else { return }
        if let lock = focusLock, Date() < lock.until, lock.window != id { return }
        // ⌘-Tab, the Dock or a click on a notification focused a window on another workspace.
        if let index = spaces.index(of: id), index != spaces.activeIndex {
            if let lock = workspaceSwitchLock, Date() < lock { return }
            switchWorkspace(to: index, focusing: id)
            return
        }
        guard workspace.strip.contains(id) else {
            if windows[id] == nil, let pid = focusedWindowElement()?.pid { scheduleReconcile(pid) }
            return
        }
        workspace.strip.focus(id)
        workspace.ensureFocusedVisible()
        applyLayout()
        didChange()
    }

    private func focus(_ id: WindowID) {
        guard let window = windows[id] else { return }
        focusLock = (id, Date().addingTimeInterval(0.4))
        AXUIElementCreateApplication(window.pid).set(kAXFrontmostAttribute, kCFBooleanTrue)
        window.element.set(kAXMainAttribute, kCFBooleanTrue)
        AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
        refreshOverlays()
        // Apps raise windows asynchronously; restack once the raise has landed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.refreshOverlays() }
    }

    // MARK: Workspaces

    var activeWorkspaceNumber: Int { spaces.activeIndex + 1 }

    /// Workspaces holding windows, plus the active one, with how many windows each has.
    var workspaceSummary: [(number: Int, windowCount: Int, isActive: Bool)] {
        spaces.workspaces.indices.compactMap { index in
            let count = spaces.workspaces[index].strip.windows.count
            guard count > 0 || index == spaces.activeIndex else { return nil }
            return (index + 1, count, index == spaces.activeIndex)
        }
    }

    private var inactiveWindows: [WindowID] {
        spaces.workspaces.indices.filter { $0 != spaces.activeIndex }.flatMap { spaces.workspaces[$0].strip.windows }
    }

    private func performWorkspace(_ target: WorkspaceTarget, movesColumn: Bool) {
        guard let index = spaces.resolve(target) else { return }
        if movesColumn {
            guard let moved = workspace.strip.focusedColumn?.windows, spaces.moveFocusedColumn(to: index) else { return }
            log.debug("moved column to workspace \(index + 1): \(self.stripDescription, privacy: .public)")
            hide(moved)
            applyLayout()
            if let next = workspace.strip.focusedWindow { focus(next) }
            didChange()
            onWorkspaceEvent?("Column sent to workspace \(index + 1)")
        } else {
            switchWorkspace(to: index, focusing: nil)
        }
    }

    /// Shows another workspace: hides the current one's windows and lays out the new one.
    private func switchWorkspace(to index: Int, focusing target: WindowID?) {
        let leaving = workspace.strip.windows
        guard spaces.activate(index) else { return }
        workspaceSwitchLock = Date().addingTimeInterval(0.6)
        finishAnimations()
        if let target {
            workspace.strip.focus(target)
            workspace.ensureFocusedVisible()
        }
        // Bring the new workspace in before hiding the old one, so the screen is never empty.
        applyLayout()
        hide(leaving)
        if let focused = workspace.strip.focusedWindow, focused != focusedWindowID() { focus(focused) }
        log.debug("workspace \(index + 1): \(self.stripDescription, privacy: .public)")
        refreshOverlays()
        didChange()
        onWorkspaceEvent?(workspace.strip.isEmpty ? "Workspace \(index + 1) is empty" : "Workspace \(index + 1)")
    }

    // MARK: Overview

    func makeOverview() -> Overview? {
        guard isEnabled else { return nil }
        return Overview(spaces: spaces)
    }

    func windowSummary(_ id: WindowID) -> (title: String, pid: pid_t?) {
        let tab = tab(for: id)
        return (tab.title, tab.pid)
    }

    /// Goes to a window chosen in the overview, switching workspace if needed.
    func focusFromOverview(_ id: WindowID) {
        guard isEnabled, let index = spaces.index(of: id) else { return }
        if index != spaces.activeIndex {
            switchWorkspace(to: index, focusing: id)
            return
        }
        workspace.strip.focus(id)
        workspace.ensureFocusedVisible()
        applyLayout()
        focus(id)
        didChange()
    }

    /// Moves windows to the corner hidden windows wait in, each app's on its own thread.
    private func hide(_ ids: [WindowID]) {
        let origin = workspace.hiddenOrigin
        var moves: [pid_t: [AXUIElement]] = [:]
        for id in ids {
            guard let window = windows[id] else { continue }
            motions[id] = nil
            hiddenWindows.insert(id)
            let size = lastApplied[id]?.size ?? window.element.size ?? .zero
            guard lastApplied[id] != CGRect(origin: origin, size: size) else { continue }
            lastApplied[id] = CGRect(origin: origin, size: size)
            moves[window.pid, default: []].append(window.element)
        }
        let groups = Array(moves.values)
        DispatchQueue.concurrentPerform(iterations: groups.count) { index in
            for element in groups[index] { element.setPosition(origin) }
        }
    }

    // MARK: Focus ring, dimming and tab bars

    /// Puts the focus ring, dimming and tab bars where windows have come to rest. While windows
    /// move, the ring and tab bars are hidden: an overlay can't keep pace with another app's
    /// window mid-flight, so it would drift away from it.
    private func refreshOverlays() {
        guard isEnabled else {
            decorations.hide()
            tabBars.hide()
            return
        }
        if isSwiping || !motions.isEmpty {
            decorations.hideRing()
            tabBars.hide()
            return
        }
        let systemFocus = focusedWindowID()
        refreshDecorations(systemFocus: systemFocus)
        refreshTabBars(systemFocus: systemFocus)
    }

    /// Decorates the focused tiled window, restacking the overlays around it. Hides them when
    /// something else has focus: a floating window, another Space, or Glide's own windows.
    private func refreshDecorations(systemFocus: WindowID?) {
        guard Appearance.showsFocusRing || Appearance.dimsUnfocusedWindows,
              let id = workspace.strip.focusedWindow, var frame = lastObserved[id] ?? lastApplied[id] else { return decorations.hide() }
        guard isFocusedNow(id, systemFocus: systemFocus) else { return decorations.hide() }
        // A tabbed column's ring takes in its tab bar.
        if let bar = workspace.tabBars().first(where: { $0.activeWindow == id }) { frame = frame.union(bar.frame) }
        decorations.show(around: id, frame: frame)
    }

    private func refreshTabBars(systemFocus: WindowID? = nil) {
        let systemFocus = systemFocus ?? focusedWindowID()
        let bars = workspace.tabBars().map { bar in
            TabBarOverlay.Bar(
                frame: bar.frame,
                tabs: bar.windows.map(tab(for:)),
                activeIndex: bar.activeIndex,
                isFocused: isFocusedNow(bar.activeWindow, systemFocus: systemFocus)
            )
        }
        tabBars.show(bars)
    }

    private func tab(for id: WindowID) -> TabBarOverlay.Tab {
        let window = windows[id]
        let title: String? = window?.element.value(kAXTitleAttribute)
        let appName = window.flatMap { NSRunningApplication(processIdentifier: $0.pid)?.localizedName }
        return TabBarOverlay.Tab(window: id, title: title.flatMap { $0.isEmpty ? nil : $0 } ?? appName ?? "Window", pid: window?.pid)
    }

    /// Whether `id` has keyboard focus, counting a focus change Glide just asked for.
    private func isFocusedNow(_ id: WindowID, systemFocus: WindowID?) -> Bool {
        let locked = focusLock.map { $0.window == id && Date() < $0.until } ?? false
        return locked || systemFocus == id
    }

    /// Switches a tabbed column to the tab clicked in its tab bar.
    private func selectTab(_ id: WindowID) {
        guard isEnabled, workspace.strip.contains(id) else { return }
        workspace.strip.focus(id)
        workspace.ensureFocusedVisible()
        applyLayout()
        focus(id)
        didChange()
    }

    /// e.g. "[Ghostty#2208] [*Safari#31 Safari#40] scroll 600" with * marking focus.
    private var stripDescription: String {
        let strip = workspace.strip
        let columns = strip.columns.enumerated().map { index, column in
            let names = column.windows.map { id in
                let app = windows[id].flatMap { NSRunningApplication(processIdentifier: $0.pid)?.localizedName } ?? "?"
                return (index == strip.focusedColumnIndex && id == column.focusedWindow ? "*" : "") + "\(app)#\(id)"
            }
            return "[" + names.joined(separator: " ") + "]"
        }
        return columns.joined(separator: " ") + " scroll \(Int(workspace.scrollOffset))"
    }

    // MARK: Applying frames

    /// Whether layout changes slide into place. Read each time so the setting applies at once.
    static var animatesWindows: Bool {
        get { UserDefaults.standard.object(forKey: "animateWindows") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "animateWindows") }
    }

    private func applyLayout(pass: Int = 0, duration: Double = FrameAnimation.defaultDuration) {
        guard isEnabled else { return }
        let animate = Self.animatesWindows
        let now = CACurrentMediaTime()
        var learnedMinimum = false
        for placement in workspace.placements() {
            let id = placement.window
            let hidden = placement.visibility == .hiddenTab
            let wasHidden = hidden ? !hiddenWindows.insert(id).inserted : hiddenWindows.remove(id) != nil
            guard let window = windows[id], lastApplied[id] != placement.frame else { continue }
            let from = motions[id].map { $0.frame(at: now) }
                ?? lastApplied[id]
            lastApplied[id] = placement.frame
            // Tabs switch in place: sliding in from the corner they wait in would look odd.
            if animate, !hidden, !wasHidden, let from, FrameAnimation.shouldAnimate(from: from, to: placement.frame, in: workspace.viewport) {
                if motions[id] == nil || motions[id]?.to.size != placement.frame.size {
                    // Resize once up front, then only move: see FrameAnimation.frame.
                    window.element.setSize(placement.frame.size)
                }
                motions[id] = Motion(from: from, to: placement.frame, start: now, duration: duration)
            } else {
                motions[id] = nil
                setFrame(placement.frame, of: window)
                learnedMinimum = settle(window, at: placement.frame) || learnedMinimum
            }
        }
        // Before the first animation step, so the ring is gone before anything moves.
        refreshOverlays()
        if !motions.isEmpty { startAnimationTimer() }
        if learnedMinimum, pass < 2 {
            workspace.ensureFocusedVisible()
            applyLayout(pass: pass + 1)
        }
    }

    /// Records where a window actually landed. Returns true if it revealed a minimum width
    /// (some apps refuse to shrink further), so the layout needs another pass.
    private func settle(_ window: TrackedWindow, at frame: CGRect) -> Bool {
        let actual = window.element.frame
        lastObserved[window.id] = actual
        guard let actual, actual.width > frame.width + 2, actual.width > workspace.minimumWidths[window.id] ?? 0 else { return false }
        workspace.minimumWidths[window.id] = actual.width
        return true
    }

    // MARK: Trackpad swipes

    private(set) var isSwiping = false
    private var swipeApplyScheduled = false

    /// How far momentum carries the strip after release: seconds of travel at release speed.
    private static let momentum: Double = 0.35
    private static let settleDuration: Double = 0.25

    func beginSwipe() {
        guard isEnabled, !workspace.strip.isEmpty else { return }
        finishAnimations()
        isSwiping = true
        refreshOverlays()
        log.debug("swipe began")
    }

    /// Moves the strip by `delta` points while the fingers move. Updates are coalesced so a
    /// slow app can't queue up a backlog of frames.
    func swipe(by delta: CGFloat) {
        guard isSwiping else { return }
        workspace.scroll(by: delta)
        guard !swipeApplyScheduled else { return }
        swipeApplyScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            swipeApplyScheduled = false
            if isSwiping { applyLayoutImmediately() }
        }
    }

    /// `velocity` in points per second. Snaps to a column and focuses one that is on screen.
    func endSwipe(velocity: CGFloat) {
        guard isSwiping else { return }
        isSwiping = false
        let projected = workspace.scrollOffset + velocity * Self.momentum
        let focusMoved = workspace.settleSwipe(projectedOffset: projected)
        log.debug("swipe ended at velocity \(Int(velocity)) pt/s: \(self.stripDescription, privacy: .public)")
        applyLayout(duration: Self.settleDuration)
        if focusMoved, let target = workspace.strip.focusedWindow { focus(target) }
        didChange()
    }

    /// Applies the layout without animation, moving each app's windows on its own thread.
    private func applyLayoutImmediately() {
        var resized: [(TrackedWindow, CGRect)] = []
        var moves: [pid_t: [(AXUIElement, CGPoint)]] = [:]
        for placement in workspace.placements() {
            guard let window = windows[placement.window], let previous = lastApplied[placement.window],
                  previous != placement.frame else { continue }
            lastApplied[placement.window] = placement.frame
            lastObserved[placement.window] = placement.frame
            if previous.size == placement.frame.size {
                moves[window.pid, default: []].append((window.element, placement.frame.origin))
            } else {
                resized.append((window, placement.frame))
            }
        }
        let groups = Array(moves.values)
        DispatchQueue.concurrentPerform(iterations: groups.count) { index in
            for (element, origin) in groups[index] { element.setPosition(origin) }
        }
        for (window, frame) in resized { setFrame(frame, of: window) }
    }

    // MARK: Animation

    private struct Motion {
        let from: CGRect
        let to: CGRect
        let start: CFTimeInterval
        let duration: Double

        func frame(at time: CFTimeInterval) -> CGRect {
            FrameAnimation.frame(from: from, to: to, progress: (time - start) / duration)
        }
    }

    private var motions: [WindowID: Motion] = [:]
    private var animationTimer: Timer?

    private func startAnimationTimer() {
        guard animationTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.animationTick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        // The first step waits for the timer (≤ 8 ms) so the run loop can first take the ring
        // and tab bars off screen; AX calls would otherwise block until windows had moved.
        animationTimer = timer
    }

    /// Time-based, so a slow AX call skips frames instead of stretching the animation.
    private func animationTick() {
        let now = CACurrentMediaTime()
        var finished: [(TrackedWindow, CGRect)] = []
        var steps: [pid_t: [(AXUIElement, CGPoint)]] = [:]
        for (id, motion) in motions {
            guard let window = windows[id] else {
                motions[id] = nil
                continue
            }
            if now - motion.start >= motion.duration {
                motions[id] = nil
                finished.append((window, motion.to))
            } else {
                let origin = motion.frame(at: now).origin
                steps[window.pid, default: []].append((window.element, origin))
            }
        }
        // AX calls block until the target app answers. Apps answer independently, so move each
        // app's windows on its own thread; one slow app then doesn't hold the others back.
        let groups = Array(steps.values)
        DispatchQueue.concurrentPerform(iterations: groups.count) { index in
            for (element, origin) in groups[index] { element.setPosition(origin) }
        }

        var learnedMinimum = false
        for (window, frame) in finished {
            setFrame(frame, of: window)
            learnedMinimum = settle(window, at: frame) || learnedMinimum
        }
        if motions.isEmpty {
            animationTimer?.invalidate()
            animationTimer = nil
            refreshOverlays()
        }
        if learnedMinimum {
            workspace.ensureFocusedVisible()
            applyLayout(pass: 1)
        }
    }

    /// Jumps every moving window to its destination.
    private func finishAnimations() {
        animationTimer?.invalidate()
        animationTimer = nil
        for (id, motion) in motions {
            if let window = windows[id] { setFrame(motion.to, of: window) }
        }
        motions = [:]
    }

    private func setFrame(_ frame: CGRect, of window: TrackedWindow) {
        // AXEnhancedUserInterface (set by assistive apps) makes some apps animate each change.
        let app = AXUIElementCreateApplication(window.pid)
        let enhanced: Bool = app.value("AXEnhancedUserInterface") ?? false
        if enhanced { app.set("AXEnhancedUserInterface", kCFBooleanFalse) }
        window.element.setFrame(frame)
        if enhanced { app.set("AXEnhancedUserInterface", kCFBooleanTrue) }
    }

    /// Puts tiled windows back after the user drags or resizes them, once the mouse is released.
    private func scheduleReassert() {
        reassertWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, isEnabled else { return }
            if NSEvent.pressedMouseButtons != 0 || !motions.isEmpty || isSwiping {
                scheduleReassert()
                return
            }
            if let dragged = draggedWindow {
                draggedWindow = nil
                if drop(dragged) { return }
            }
            reassert()
        }
        reassertWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    /// Puts a window the user dragged and released into the column under the pointer: on a tab bar
    /// it becomes a tab there, on another window it stacks into that window's column. Returns false
    /// when it was dropped anywhere else, so it snaps back.
    private func drop(_ id: WindowID) -> Bool {
        guard isEnabled, windows[id] != nil, !userResized.contains(id), !hiddenWindows.contains(id) else { return false }
        let point = ScreenGeometry.axPoint(fromCocoa: NSEvent.mouseLocation)
        guard let target = workspace.dropTarget(at: point, dragging: id) else { return false }
        guard let targetColumn = workspace.strip.location(of: target)?.column,
              workspace.strip.location(of: id)?.column != targetColumn else { return false }

        // A floating window dropped on a tile joins the tiles.
        spaces.remove(id)
        userFloating.remove(id)
        userTiled.insert(id)
        guard workspace.strip.join(id, columnOf: target) else {
            spaces.insert(id, widthIndex: workspace.settings.defaultWidthIndex, focus: false)
            return false
        }
        lastApplied[id] = nil
        log.debug("dropped \(id) onto \(target): \(self.stripDescription, privacy: .public)")
        workspace.settleScroll()
        applyLayout()
        focus(id)
        didChange()
        return true
    }

    /// A window the user dragged snaps back to its slot. One the user resized keeps its new
    /// width: its column takes that width and the strip reflows around it.
    private func reassert() {
        var moved = false
        var resized = false
        defer { userResized = [] }
        for id in workspace.strip.windows {
            guard let window = windows[id], let actual = window.element.frame else { continue }
            if userResized.contains(id), !hiddenWindows.contains(id), let applied = lastApplied[id], abs(actual.width - applied.width) > 2,
               let (column, _) = workspace.strip.location(of: id) {
                workspace.strip.setCustomWidth(actual.width, forColumnOf: id)
                for sibling in workspace.strip.columns[column].windows { lastApplied[sibling] = nil }
                resized = true
                moved = true
                continue
            }
            if let observed = lastObserved[id], Self.roughlyEqual(observed, actual) { continue }
            lastApplied[id] = nil
            moved = true
        }
        if resized {
            log.debug("adopted a resized width: \(self.stripDescription, privacy: .public)")
            workspace.ensureFocusedVisible()
        }
        if moved { applyLayout() }
        refreshOverlays()
        if resized { didChange() }
    }

    private static func roughlyEqual(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= 2 && abs(a.minY - b.minY) <= 2 && abs(a.width - b.width) <= 2 && abs(a.height - b.height) <= 2
    }
}

private func axObserverCallback(_ observer: AXObserver, _ element: AXUIElement, _ notification: CFString, _ refcon: UnsafeMutableRawPointer?) {
    guard let refcon else { return }
    let manager = Unmanaged<WindowManager>.fromOpaque(refcon).takeUnretainedValue()
    let name = notification as String
    MainActor.assumeIsolated { manager.handle(name, element: element) }
}
