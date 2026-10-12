import AppKit
import GlideCore
import Observation

/// The user's keymap, persisted in UserDefaults as overrides of the defaults.
@Observable
final class ShortcutStore {
    private static let key = "shortcuts"
    private let defaults: UserDefaults

    private(set) var keymap: Keymap {
        didSet {
            defaults.set(keymap.storage, forKey: Self.key)
            onChange?()
        }
    }

    @ObservationIgnored var onChange: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        keymap = Keymap(storage: defaults.dictionary(forKey: Self.key) as? [String: String] ?? [:])
    }

    @discardableResult
    func set(_ combo: KeyCombo?, for action: Action) -> [Action] {
        keymap.set(combo, for: action)
    }

    func reset(_ action: Action) { keymap.reset(action) }
    func resetAll() { keymap.resetAll() }
}

extension KeyModifiers {
    init(_ flags: NSEvent.ModifierFlags) {
        self = []
        if flags.contains(.control) { insert(.control) }
        if flags.contains(.option) { insert(.option) }
        if flags.contains(.shift) { insert(.shift) }
        if flags.contains(.command) { insert(.command) }
    }

    var eventFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if contains(.control) { flags.insert(.control) }
        if contains(.option) { flags.insert(.option) }
        if contains(.shift) { flags.insert(.shift) }
        if contains(.command) { flags.insert(.command) }
        return flags
    }
}

extension KeyCombo {
    /// The string NSMenuItem needs to draw this combo natively, when there is one.
    var menuKeyEquivalent: String? {
        let special: [UInt32: Int] = [
            KeyCode.leftArrow: NSLeftArrowFunctionKey, KeyCode.rightArrow: NSRightArrowFunctionKey,
            KeyCode.upArrow: NSUpArrowFunctionKey, KeyCode.downArrow: NSDownArrowFunctionKey,
            KeyCode.home: NSHomeFunctionKey, KeyCode.end: NSEndFunctionKey,
            KeyCode.pageUp: NSPageUpFunctionKey, KeyCode.pageDown: NSPageDownFunctionKey,
        ]
        if let scalar = special[keyCode].flatMap(UnicodeScalar.init) { return String(Character(scalar)) }
        let name = KeyCode.name(for: keyCode)
        guard name.count == 1, name.allSatisfy(\.isASCII) else { return nil }
        return name.lowercased()
    }
}
