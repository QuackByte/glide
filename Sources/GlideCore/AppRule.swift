import Foundation

/// How Glide treats the windows of one app. Rules apply to windows as they appear; a window
/// you float or tile by hand (⌃⌥V) keeps your choice.
public struct AppRule: Codable, Equatable, Hashable, Sendable, Identifiable {
    public enum Mode: String, Codable, CaseIterable, Sendable {
        /// Glide decides: standard resizable windows tile, everything else floats.
        case automatic
        case float
        /// Tiles resizable windows the classifier would float, e.g. ones lacking a zoom button.
        case tile
    }

    public var bundleID: String
    public var appName: String
    public var mode: Mode
    /// Index into the width presets for new columns; nil uses the default.
    public var widthIndex: Int?
    /// Zero-based workspace new windows open on; nil opens them on the active one.
    public var workspace: Int?

    public var id: String { bundleID }

    public init(bundleID: String, appName: String, mode: Mode = .automatic, widthIndex: Int? = nil, workspace: Int? = nil) {
        self.bundleID = bundleID
        self.appName = appName
        self.mode = mode
        self.widthIndex = widthIndex
        self.workspace = workspace
    }

    /// System Settings has a fixed width and comes and goes, so it floats out of the box.
    public static let defaults = [AppRule(bundleID: "com.apple.systempreferences", appName: "System Settings", mode: .float)]
}

/// The user's rules, keyed by bundle ID.
public struct AppRules: Equatable, Sendable {
    public private(set) var rules: [AppRule]

    public init(_ rules: [AppRule] = AppRule.defaults) {
        // One rule per app; a later duplicate replaces an earlier one.
        var seen: [String: Int] = [:]
        var unique: [AppRule] = []
        for rule in rules {
            if let index = seen[rule.bundleID] {
                unique[index] = rule
            } else {
                seen[rule.bundleID] = unique.count
                unique.append(rule)
            }
        }
        self.rules = unique
    }

    public func rule(for bundleID: String?) -> AppRule? {
        guard let bundleID else { return nil }
        return rules.first { $0.bundleID == bundleID }
    }

    /// Adds a rule, or replaces the app's existing one in place.
    public mutating func set(_ rule: AppRule) {
        if let index = rules.firstIndex(where: { $0.bundleID == rule.bundleID }) {
            rules[index] = rule
        } else {
            rules.append(rule)
        }
    }

    public mutating func remove(_ bundleID: String) {
        rules.removeAll { $0.bundleID == bundleID }
    }

    /// Whether a new window should tile. `classifiedTileable` is Glide's own judgement;
    /// `canTile` says whether the window could be tiled at all (resizable, not a dialog).
    public static func shouldTile(rule: AppRule?, classifiedTileable: Bool, canTile: Bool, userFloating: Bool, userTiled: Bool) -> Bool {
        if userTiled { return canTile }
        if userFloating { return false }
        switch rule?.mode ?? .automatic {
        case .automatic: return classifiedTileable
        case .float: return false
        case .tile: return canTile
        }
    }
}
