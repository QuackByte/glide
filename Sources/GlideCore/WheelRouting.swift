/// When tilting the mouse wheel (or a thumb wheel) glides the strip, as set in Settings.
public enum HorizontalWheelMode: String, CaseIterable, Sendable {
    /// Tilting always glides the strip.
    case always
    /// Tilting glides the strip only while ⌃⌥ is held.
    case withModifier
    /// Tilting is left to the app under the pointer.
    case off
}

public enum WheelRouting {
    /// Whether a mouse-wheel tick moves the strip instead of reaching the app under the pointer.
    /// ⌃⌥ with the wheel always moves the strip, like Win+wheel on Windows; tilting follows `mode`.
    public static func movesStrip(horizontal: Bool, chordHeld: Bool, mode: HorizontalWheelMode) -> Bool {
        guard horizontal else { return chordHeld }
        switch mode {
        case .always: return true
        case .withModifier: return chordHeld
        case .off: return false
        }
    }
}
