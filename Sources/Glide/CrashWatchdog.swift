import AppKit
import GlideCore

/// Glide parks windows at the screen edges and hides tabs in a corner; if it crashed they would
/// stay there. So Glide starts a copy of itself in watchdog mode that waits for Glide to exit. A
/// clean quit stops the watchdog first. Any other exit makes it bring every window back on
/// screen, and if macOS wrote a crash report (a real crash, not a force quit) it relaunches
/// Glide, which then re-tiles from the saved layout.
enum CrashWatchdog {
    static let argument = "--watchdog"
    private static let relaunchKey = "lastCrashRelaunch"
    /// A crash loop shouldn't relaunch forever.
    private static let relaunchInterval: TimeInterval = 60

    /// Starts the watchdog for this process. Terminate it before a clean exit.
    static func launch() -> Process? {
        guard let executable = Bundle.main.executableURL else { return nil }
        let process = Process()
        process.executableURL = executable
        process.arguments = [argument, String(getpid())]
        do {
            try process.run()
            return process
        } catch {
            NSLog("Glide: couldn't start the crash watchdog: \(error.localizedDescription)")
            return nil
        }
    }

    /// The watchdog process: waits for `parent` to exit, then recovers.
    static func run(parent: pid_t) -> Never {
        let source = DispatchSource.makeProcessSource(identifier: parent, eventMask: .exit, queue: .main)
        source.setEventHandler {
            MainActor.assumeIsolated { recover() }
        }
        source.resume()
        // The parent may have died before the source was set up.
        if kill(parent, 0) != 0 { recover() }
        dispatchMain()
    }

    private static func recover() {
        let exitTime = Date()
        _ = NSApplication.shared
        if AXIsProcessTrusted() { restoreWindows() }
        guard crashReportWritten(after: exitTime.addingTimeInterval(-2)) else { exit(0) }
        let defaults = UserDefaults.standard
        if let last = defaults.object(forKey: relaunchKey) as? Date, exitTime.timeIntervalSince(last) < relaunchInterval { exit(0) }
        defaults.set(exitTime, forKey: relaunchKey)
        // The watchdog counts as a running Glide to LaunchServices, so ask for a new instance
        // explicitly; otherwise the request would just activate the watchdog.
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            if let error { NSLog("Glide watchdog: relaunch failed: \(error.localizedDescription)") }
            exit(0)
        }
    }

    /// Moves every standard window that is off screen back on, like turning tiling off does.
    /// Windows in the saved layout come first so they cascade in strip order.
    private static func restoreWindows() {
        guard let viewport = ScreenGeometry.primaryViewport() else { return }
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 1)
        let ownPID = ProcessInfo.processInfo.processIdentifier
        var found: [WindowID: (element: AXUIElement, frame: CGRect)] = [:]
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular && app.processIdentifier != ownPID {
            let elements: [AXUIElement] = AXUIElementCreateApplication(app.processIdentifier).value(kAXWindowsAttribute) ?? []
            for element in elements where WindowClassifier.classify(element) != .ignored {
                if let id = element.windowID, let frame = element.frame { found[id] = (element, frame) }
            }
        }

        let saved = UserDefaults.standard.data(forKey: WindowManager.snapshotKey)
            .flatMap { try? JSONDecoder().decode(StripSnapshot.self, from: $0) }
        let savedOrder = saved?.allWindows ?? []
        let ordered = savedOrder.filter { found[$0] != nil } + found.keys.filter { !savedOrder.contains($0) }.sorted()
        let restored = RestorePlanner.restoredFrames(for: ordered.map { ($0, found[$0]!.frame) }, in: viewport)
        for id in ordered {
            if let frame = restored[id], frame != found[id]?.frame { found[id]?.element.setFrame(frame) }
        }
    }

    /// ReportCrash writes a report within a few seconds of a crash; a force quit leaves none.
    private static func crashReportWritten(after date: Date) -> Bool {
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/DiagnosticReports")
        let name = Bundle.main.executableURL?.lastPathComponent ?? "Glide"
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            let reports = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey])) ?? []
            if reports.contains(where: { url in
                url.lastPathComponent.hasPrefix(name + "-") && url.pathExtension == "ips"
                    && ((try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast) >= date
            }) { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return false
    }
}
