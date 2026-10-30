/// Modifier keys of a shortcut, independent of AppKit and Carbon.
public struct KeyModifiers: OptionSet, Hashable, Codable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let control = KeyModifiers(rawValue: 1 << 0)
    public static let option = KeyModifiers(rawValue: 1 << 1)
    public static let shift = KeyModifiers(rawValue: 1 << 2)
    public static let command = KeyModifiers(rawValue: 1 << 3)

    /// The Carbon `EventModifiers` bits used by `RegisterEventHotKey`.
    public var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.command) { flags |= 1 << 8 }
        if contains(.shift) { flags |= 1 << 9 }
        if contains(.option) { flags |= 1 << 11 }
        if contains(.control) { flags |= 1 << 12 }
        return flags
    }

    /// Symbols in the order macOS menus show them.
    public var symbols: String {
        (contains(.control) ? "⌃" : "") + (contains(.option) ? "⌥" : "")
            + (contains(.shift) ? "⇧" : "") + (contains(.command) ? "⌘" : "")
    }
}

/// A shortcut: a virtual key code (physical key position) plus modifiers.
public struct KeyCombo: Hashable, Codable, Sendable, CustomStringConvertible {
    public var keyCode: UInt32
    public var modifiers: KeyModifiers

    public init(_ keyCode: UInt32, _ modifiers: KeyModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Display text using US key names, e.g. "⌃⌥←".
    public var description: String { modifiers.symbols + KeyCode.name(for: keyCode) }

    /// Compact persisted form, e.g. "3:123".
    public var storageValue: String { "\(modifiers.rawValue):\(keyCode)" }

    public init?(storageValue: String) {
        let parts = storageValue.split(separator: ":")
        guard parts.count == 2, let modifiers = UInt32(parts[0]), let keyCode = UInt32(parts[1]) else { return nil }
        self.init(keyCode, KeyModifiers(rawValue: modifiers))
    }
}

/// macOS virtual key codes (kVK_* in Carbon) for the keys Glide names.
public enum KeyCode {
    public static let leftArrow: UInt32 = 123
    public static let rightArrow: UInt32 = 124
    public static let downArrow: UInt32 = 125
    public static let upArrow: UInt32 = 126
    public static let home: UInt32 = 115
    public static let end: UInt32 = 119
    public static let pageUp: UInt32 = 116
    public static let pageDown: UInt32 = 121
    public static let returnKey: UInt32 = 36
    public static let tab: UInt32 = 48
    public static let space: UInt32 = 49
    public static let delete: UInt32 = 51
    public static let escape: UInt32 = 53
    public static let forwardDelete: UInt32 = 117
    public static let leftBracket: UInt32 = 33
    public static let rightBracket: UInt32 = 30
    public static let slash: UInt32 = 44
    public static let grave: UInt32 = 50
    public static let c: UInt32 = 8
    public static let f: UInt32 = 3
    public static let g: UInt32 = 5
    public static let o: UInt32 = 31
    public static let r: UInt32 = 15
    public static let t: UInt32 = 17
    public static let v: UInt32 = 9
    public static let w: UInt32 = 13

    public static let arrows: Set<UInt32> = [leftArrow, rightArrow, downArrow, upArrow]
    /// The number row, 1 through 9.
    public static let digits: [UInt32] = [18, 19, 20, 21, 23, 22, 26, 28, 25]

    static let functionKeys: [UInt32: String] = [
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
        106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20",
    ]

    static let names: [UInt32: String] = [
        leftArrow: "←", rightArrow: "→", downArrow: "↓", upArrow: "↑",
        home: "↖", end: "↘", pageUp: "⇞", pageDown: "⇟",
        returnKey: "↩", tab: "⇥", space: "Space", delete: "⌫", escape: "⎋", forwardDelete: "⌦",
        0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H", 34: "I", 38: "J",
        40: "K", 37: "L", 46: "M", 45: "N", 31: "O", 35: "P", 12: "Q", 15: "R", 1: "S", 17: "T",
        32: "U", 9: "V", 13: "W", 7: "X", 16: "Y", 6: "Z",
        29: "0", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9",
        27: "-", 24: "=", 33: "[", 30: "]", 41: ";", 39: "'", 42: "\\", 43: ",", 47: ".", 44: "/", 50: "`",
    ]

    public static func isFunctionKey(_ keyCode: UInt32) -> Bool { functionKeys[keyCode] != nil }

    public static func name(for keyCode: UInt32) -> String {
        names[keyCode] ?? functionKeys[keyCode] ?? "Key \(keyCode)"
    }
}
