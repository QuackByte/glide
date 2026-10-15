import Foundation

/// Which shortcut triggers which action: the defaults plus any user overrides.
public struct Keymap: Equatable, Sendable {
    /// Defaults are ⌃⌥ for focus/commands and ⌃⌥⇧ for "move", plus ⌘ for displays. See the README
    /// for the reasoning.
    public static let defaults: [Action: KeyCombo] = {
        let hyper: KeyModifiers = [.control, .option]
        let move: KeyModifiers = [.control, .option, .shift]
        var map: [Action: KeyCombo] = [
            .focusColumnLeft: KeyCombo(KeyCode.leftArrow, hyper),
            .focusColumnRight: KeyCombo(KeyCode.rightArrow, hyper),
            .focusWindowUp: KeyCombo(KeyCode.upArrow, hyper),
            .focusWindowDown: KeyCombo(KeyCode.downArrow, hyper),
            .focusFirstColumn: KeyCombo(KeyCode.home, hyper),
            .focusLastColumn: KeyCombo(KeyCode.end, hyper),
            .moveColumnLeft: KeyCombo(KeyCode.leftArrow, move),
            .moveColumnRight: KeyCombo(KeyCode.rightArrow, move),
            .moveWindowUp: KeyCombo(KeyCode.upArrow, move),
            .moveWindowDown: KeyCombo(KeyCode.downArrow, move),
            .consumeOrExpelLeft: KeyCombo(KeyCode.leftBracket, hyper),
            .consumeOrExpelRight: KeyCombo(KeyCode.rightBracket, hyper),
            .cycleColumnWidth: KeyCombo(KeyCode.r, hyper),
            .cycleColumnWidthBackward: KeyCombo(KeyCode.r, move),
            .toggleFullWidth: KeyCombo(KeyCode.f, hyper),
            .toggleTabbed: KeyCombo(KeyCode.w, hyper),
            .centerColumn: KeyCombo(KeyCode.c, hyper),
            .toggleOverview: KeyCombo(KeyCode.o, hyper),
            .showShortcuts: KeyCombo(KeyCode.slash, hyper),
            .toggleFloating: KeyCombo(KeyCode.v, hyper),
            .toggleTiling: KeyCombo(KeyCode.t, move),
            .focusPreviousWorkspace: KeyCombo(KeyCode.pageUp, hyper),
            .focusNextWorkspace: KeyCombo(KeyCode.pageDown, hyper),
            .moveColumnToPreviousWorkspace: KeyCombo(KeyCode.pageUp, move),
            .moveColumnToNextWorkspace: KeyCombo(KeyCode.pageDown, move),
            .focusDisplayLeft: KeyCombo(KeyCode.leftArrow, hyper.union(.command)),
            .focusDisplayRight: KeyCombo(KeyCode.rightArrow, hyper.union(.command)),
            .moveColumnToDisplayLeft: KeyCombo(KeyCode.leftArrow, move.union(.command)),
            .moveColumnToDisplayRight: KeyCombo(KeyCode.rightArrow, move.union(.command)),
        ]
        // ⌃⌥1…9 switch workspaces; ⌃⌥⇧1…9 send the focused column there.
        for (index, key) in KeyCode.digits.enumerated() {
            let number = index + 1
            if let focus = Action(rawValue: "focusWorkspace\(number)") { map[focus] = KeyCombo(key, hyper) }
            if let send = Action(rawValue: "moveColumnToWorkspace\(number)") { map[send] = KeyCombo(key, move) }
        }
        return map
    }()

    /// Overrides of the defaults. A nil value means the user removed the shortcut.
    public private(set) var overrides: [Action: KeyCombo?]

    public init(overrides: [Action: KeyCombo?] = [:]) {
        self.overrides = overrides
    }

    public func combo(for action: Action) -> KeyCombo? {
        if let override = overrides[action] { return override }
        return Self.defaults[action]
    }

    public func action(for combo: KeyCombo) -> Action? {
        Action.allCases.first { self.combo(for: $0) == combo }
    }

    /// Bound actions in declaration order.
    public var bindings: [(action: Action, combo: KeyCombo)] {
        Action.allCases.compactMap { action in combo(for: action).map { (action, $0) } }
    }

    /// Binds a combo (or nil to unbind). Any other action using the same combo is unbound
    /// so one key never triggers two actions; those actions are returned.
    @discardableResult
    public mutating func set(_ combo: KeyCombo?, for action: Action) -> [Action] {
        var displaced: [Action] = []
        if let combo {
            for other in Action.allCases where other != action && self.combo(for: other) == combo {
                store(nil, for: other)
                displaced.append(other)
            }
        }
        store(combo, for: action)
        return displaced
    }

    public mutating func reset(_ action: Action) {
        let displaced = Action.allCases.filter { $0 != action && combo(for: $0) == Self.defaults[action] }
        overrides[action] = nil
        for other in displaced { store(nil, for: other) }
    }

    public mutating func resetAll() {
        overrides = [:]
    }

    private mutating func store(_ combo: KeyCombo?, for action: Action) {
        if combo == Self.defaults[action] {
            overrides[action] = nil
        } else {
            overrides[action] = .some(combo)
        }
    }

    // MARK: Persistence

    static let unboundValue = "none"

    /// A property-list friendly form for UserDefaults: only overrides are stored.
    public var storage: [String: String] {
        var result: [String: String] = [:]
        for (action, combo) in overrides {
            result[action.rawValue] = combo?.storageValue ?? Self.unboundValue
        }
        return result
    }

    public init(storage: [String: String]) {
        var overrides: [Action: KeyCombo?] = [:]
        for (key, value) in storage {
            guard let action = Action(rawValue: key) else { continue }
            if value == Self.unboundValue {
                overrides[action] = .some(nil)
            } else if let combo = KeyCombo(storageValue: value) {
                overrides[action] = .some(combo)
            }
        }
        self.init(overrides: overrides)
    }
}

/// Explains why a shortcut is a poor choice. Used to reject or warn while recording.
public enum ShortcutPolicy {
    public enum Verdict: Equatable, Sendable {
        case ok
        /// Allowed, but it shadows a macOS or text-editing shortcut.
        case warning(String)
        /// Not usable as a global shortcut.
        case rejected(String)
    }

    public static func evaluate(_ combo: KeyCombo) -> Verdict {
        let modifiers = combo.modifiers
        let key = combo.keyCode
        let primary = modifiers.subtracting(.shift)

        if primary.isEmpty && !KeyCode.isFunctionKey(key) {
            return .rejected(String(localized: "Add ⌃, ⌥ or ⌘ so the shortcut doesn't block normal typing.", bundle: #bundle))
        }
        if KeyCode.arrows.contains(key) || key == KeyCode.home || key == KeyCode.end {
            if modifiers == .control && KeyCode.arrows.contains(key) {
                return .warning(String(localized: "macOS uses ⌃ + arrows for Spaces and Mission Control.", bundle: #bundle))
            }
            if primary == .option || primary == .command {
                return .warning(String(localized: "\(modifiers.symbols) + arrows move the cursor in text fields.", bundle: #bundle))
            }
        }
        if key == KeyCode.space && (modifiers == .command || modifiers == [.command, .option]
            || modifiers == .control || modifiers == [.control, .option]) {
            return .warning(String(localized: "macOS uses \(modifiers.symbols)Space for Spotlight or input sources.", bundle: #bundle))
        }
        if modifiers == .command && [KeyCode.tab, 12, 13, 4, 46].contains(key) {
            return .warning(String(localized: "\(combo.description) is a standard macOS command.", bundle: #bundle))
        }
        return .ok
    }
}
