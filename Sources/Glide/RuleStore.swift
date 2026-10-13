import AppKit
import GlideCore
import Observation

/// The user's app rules, persisted in UserDefaults as JSON. Until the user edits them, the
/// built-in defaults apply (System Settings floats).
@Observable
final class RuleStore {
    private static let key = "appRules"
    private let defaults: UserDefaults

    private(set) var rules: AppRules {
        didSet {
            if let data = try? JSONEncoder().encode(rules.rules) { defaults.set(data, forKey: Self.key) }
            onChange?(rules)
        }
    }

    @ObservationIgnored var onChange: ((AppRules) -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key), let saved = try? JSONDecoder().decode([AppRule].self, from: data) {
            rules = AppRules(saved)
        } else {
            rules = AppRules()
        }
    }

    func set(_ rule: AppRule) { rules.set(rule) }
    func remove(_ bundleID: String) { rules.remove(bundleID) }

    /// Running apps with windows that don't have a rule yet, for the Add menu.
    var appsWithoutRules: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil && rules.rule(for: $0.bundleIdentifier) == nil
                && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            .sorted { ($0.localizedName ?? "") .localizedCaseInsensitiveCompare($1.localizedName ?? "") == .orderedAscending }
    }

    /// Adds a rule for an app chosen in a file panel.
    func addApp(at url: URL) {
        guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return }
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        set(AppRule(bundleID: id, appName: name, mode: .float))
    }
}
