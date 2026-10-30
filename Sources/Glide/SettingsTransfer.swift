import AppKit
import UniformTypeIdentifiers

/// Glide's settings as a readable JSON file, to move them to another Mac or keep them with
/// dotfiles: shortcuts, app rules, layout and appearance. Window layouts and update preferences
/// stay on the Mac they belong to.
enum SettingsTransfer {
    private static let keys = [
        "shortcuts", "glideModifier", "directionKeys", "appRules",
        "defaultLayout", "tiledColumns", "widthPresets", "gap",
        "focusRing", "focusRingWidth", "focusRingColor", "dimUnfocused", "dimAmount", "workspaceHUD",
        "animateWindows", "rememberApps", "focusFollowsMouse", "horizontalWheel", "trackpadSwipe",
    ]
    /// Stored as JSON data; written out as JSON itself so the file stays readable.
    private static let jsonKeys: Set<String> = ["appRules"]
    private static let formatKey = "glideSettings"

    enum Failure: LocalizedError {
        case notGlideSettings

        var errorDescription: String? { String(localized: "This file isn't a Glide settings file.") }
    }

    static func export(from defaults: UserDefaults = .standard) throws -> Data {
        var settings: [String: Any] = [:]
        for key in keys {
            guard let value = defaults.object(forKey: key) else { continue }
            if jsonKeys.contains(key), let data = value as? Data {
                settings[key] = try JSONSerialization.jsonObject(with: data)
            } else {
                settings[key] = value
            }
        }
        return try JSONSerialization.data(withJSONObject: [formatKey: 1, "settings": settings], options: [.prettyPrinted, .sortedKeys])
    }

    /// Replaces the settings with the file's; settings the file leaves out go back to their defaults.
    static func importSettings(_ data: Data, into defaults: UserDefaults = .standard) throws {
        guard let file = try JSONSerialization.jsonObject(with: data) as? [String: Any], file[formatKey] != nil,
              let settings = file["settings"] as? [String: Any] else { throw Failure.notGlideSettings }
        for key in keys {
            guard let value = settings[key], !(value is NSNull) else {
                defaults.removeObject(forKey: key)
                continue
            }
            if jsonKeys.contains(key) {
                defaults.set(try JSONSerialization.data(withJSONObject: value), forKey: key)
            } else {
                defaults.set(value, forKey: key)
            }
        }
    }

    // MARK: Panels

    @MainActor
    static func exportWithPanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Glide Settings.json"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try export().write(to: url, options: .atomic)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    /// Asks first, imports, then relaunches Glide so every part picks the settings up.
    @MainActor
    static func importWithPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let alert = NSAlert()
        alert.messageText = String(localized: "Replace your settings with “\(url.lastPathComponent)”?")
        alert.informativeText = String(localized: "Shortcuts, app rules, layout and appearance settings are replaced. Glide restarts to apply them.")
        alert.addButton(withTitle: String(localized: "Import and Restart"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try importSettings(Data(contentsOf: url))
        } catch {
            NSAlert(error: error).runModal()
            return
        }
        relaunch()
    }

    private static func relaunch() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        try? process.run()
        NSApp.terminate(nil)
    }
}
