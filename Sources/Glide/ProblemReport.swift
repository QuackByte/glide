import AppKit
import GlideCore
import OSLog

/// Report a Problem: zips Glide's recent log, settings and layout, shows the zip in Finder, and
/// opens a new GitHub issue already filled in. Nothing is sent; the user attaches the zip.
enum ProblemReport {
    private static let repository = "QuackByte/glide"
    private static let bundleID = "dev.quackbyte.glide"

    /// How far back the log goes. The log store only sees this run of Glide.
    private nonisolated static let logWindow: TimeInterval = 6 * 3600

    /// Builds the report off the main thread, then reveals it and opens the issue.
    static func open(layout: String) {
        let system = systemSummary()
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let url = try write(system: system, layout: layout)
                DispatchQueue.main.async {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                    if let issue = GlideCore.ProblemReport.issueURL(repository: repository, system: system, zipName: url.lastPathComponent) {
                        NSWorkspace.shared.open(issue)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = String(localized: "Couldn’t Create the Report")
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                }
            }
        }
    }

    private static func systemSummary() -> GlideCore.ProblemReport.System {
        let info = Bundle.main.infoDictionary
        #if arch(arm64)
        let architecture = "Apple silicon"
        #else
        let architecture = "Intel"
        #endif
        return .init(
            version: info?["CFBundleShortVersionString"] as? String ?? "?",
            build: info?["CFBundleVersion"] as? String ?? "?",
            macOS: ProcessInfo.processInfo.operatingSystemVersionString.replacingOccurrences(of: "Version ", with: ""),
            model: sysctlString("hw.model") ?? "Mac",
            architecture: architecture,
            displays: NSScreen.screens.count
        )
    }

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &bytes, &size, nil, 0) == 0 else { return nil }
        return String(cString: bytes)
    }

    /// Stages the files in a temporary folder and zips it into ~/Library/Caches/dev.quackbyte.glide.
    private nonisolated static func write(system: GlideCore.ProblemReport.System, layout: String) throws -> URL {
        let fileManager = FileManager.default
        let name = GlideCore.ProblemReport.fileName(for: Date())
        let staging = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let content = staging.appendingPathComponent((name as NSString).deletingPathExtension)
        try fileManager.createDirectory(at: content, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }

        try system.text.write(to: content.appendingPathComponent("system.txt"), atomically: true, encoding: .utf8)
        try GlideCore.ProblemReport.withoutTitles(recentLog()).write(to: content.appendingPathComponent("glide.log"), atomically: true, encoding: .utf8)
        try layout.write(to: content.appendingPathComponent("layout.txt"), atomically: true, encoding: .utf8)
        if let defaults = UserDefaults.standard.persistentDomain(forName: bundleID) {
            let plist = try PropertyListSerialization.data(fromPropertyList: defaults, format: .xml, options: 0)
            try plist.write(to: content.appendingPathComponent("settings.plist"))
        }

        let folder = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(bundleID)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let zip = folder.appendingPathComponent(name)
        try? fileManager.removeItem(at: zip)

        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-c", "-k", "--keepParent", content.path, zip.path]
        try ditto.run()
        ditto.waitUntilExit()
        guard ditto.terminationStatus == 0 else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSLocalizedDescriptionKey: String(localized: "Zipping the report failed (ditto exited with \(Int(ditto.terminationStatus))).")])
        }
        return zip
    }

    /// Glide's log lines from the last few hours, one per line.
    private nonisolated static func recentLog() -> String {
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let since = store.position(date: Date(timeIntervalSinceNow: -logWindow))
            let entries = try store.getEntries(at: since, matching: NSPredicate(format: "subsystem == %@", bundleID))
            let stamp = ISO8601DateFormatter()
            let lines = entries.compactMap { $0 as? OSLogEntryLog }.map { "\(stamp.string(from: $0.date)) [\($0.category)] \($0.composedMessage)" }
            return lines.isEmpty ? "No log entries since Glide started.\n" : lines.joined(separator: "\n") + "\n"
        } catch {
            return "Couldn't read the log: \(error.localizedDescription)\n"
        }
    }
}
