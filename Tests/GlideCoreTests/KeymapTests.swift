import XCTest
@testable import GlideCore

final class KeymapTests: XCTestCase {
    func testEveryActionHasADefault() {
        for action in Action.allCases {
            XCTAssertNotNil(Keymap.defaults[action], "\(action) has no default shortcut")
        }
    }

    func testDefaultsAreUnique() {
        let combos = Keymap.defaults.values
        XCTAssertEqual(Set(combos).count, combos.count)
    }

    func testDefaultsPassShortcutPolicy() {
        for (action, combo) in Keymap.defaults {
            XCTAssertEqual(ShortcutPolicy.evaluate(combo), .ok, "\(action) default \(combo) is flagged")
        }
    }

    func testDefaultsAvoidTextEditingAndSpacesCombos() {
        for combo in Keymap.defaults.values where KeyCode.arrows.contains(combo.keyCode) {
            let primary = combo.modifiers.subtracting(.shift)
            XCTAssertNotEqual(primary, .option)
            XCTAssertNotEqual(primary, .command)
            XCTAssertNotEqual(primary, .control)
        }
    }

    func testDefaultDisplayNames() {
        XCTAssertEqual(Keymap.defaults[.focusColumnLeft]?.description, "⌃⌥←")
        XCTAssertEqual(Keymap.defaults[.moveColumnRight]?.description, "⌃⌥⇧→")
        XCTAssertEqual(Keymap.defaults[.consumeOrExpelLeft]?.description, "⌃⌥[")
        XCTAssertEqual(Keymap.defaults[.showShortcuts]?.description, "⌃⌥/")
    }

    func testOverrideAndReset() {
        var keymap = Keymap()
        let combo = KeyCombo(4, [.control, .option])
        keymap.set(combo, for: .focusColumnLeft)
        XCTAssertEqual(keymap.combo(for: .focusColumnLeft), combo)
        XCTAssertEqual(keymap.action(for: combo), .focusColumnLeft)
        keymap.reset(.focusColumnLeft)
        XCTAssertEqual(keymap.combo(for: .focusColumnLeft), Keymap.defaults[.focusColumnLeft])
        XCTAssertTrue(keymap.overrides.isEmpty)
    }

    func testUnbinding() {
        var keymap = Keymap()
        keymap.set(nil, for: .centerColumn)
        XCTAssertNil(keymap.combo(for: .centerColumn))
        XCTAssertFalse(keymap.bindings.contains { $0.action == .centerColumn })
    }

    func testBindingDuplicateDisplacesOtherAction() {
        var keymap = Keymap()
        let displaced = keymap.set(Keymap.defaults[.focusColumnRight], for: .focusColumnLeft)
        XCTAssertEqual(displaced, [.focusColumnRight])
        XCTAssertNil(keymap.combo(for: .focusColumnRight))
        XCTAssertEqual(keymap.action(for: Keymap.defaults[.focusColumnRight]!), .focusColumnLeft)
    }

    func testResetDisplacesActionHoldingTheDefault() {
        var keymap = Keymap()
        keymap.set(KeyCombo(4, [.control, .option]), for: .focusColumnLeft)
        keymap.set(Keymap.defaults[.focusColumnLeft], for: .centerColumn)
        keymap.reset(.focusColumnLeft)
        XCTAssertEqual(keymap.combo(for: .focusColumnLeft), Keymap.defaults[.focusColumnLeft])
        XCTAssertNil(keymap.combo(for: .centerColumn))
    }

    func testStorageRoundTrip() {
        var keymap = Keymap()
        keymap.set(KeyCombo(4, [.control, .option, .command]), for: .focusColumnLeft)
        keymap.set(nil, for: .toggleTiling)
        let restored = Keymap(storage: keymap.storage)
        XCTAssertEqual(restored, keymap)
        XCTAssertEqual(restored.combo(for: .focusColumnLeft), KeyCombo(4, [.control, .option, .command]))
        XCTAssertNil(restored.combo(for: .toggleTiling))
    }

    func testStorageIgnoresUnknownAndMalformedEntries() {
        let keymap = Keymap(storage: ["notAnAction": "3:4", "centerColumn": "garbage"])
        XCTAssertEqual(keymap, Keymap())
    }

    func testOptionModifierDefaults() {
        let defaults = Keymap.defaults(for: .option)
        XCTAssertEqual(Set(defaults.keys), Set(Keymap.defaults.keys))
        XCTAssertEqual(Set(defaults.values).count, defaults.count)
        XCTAssertEqual(defaults[.focusColumnLeft]?.description, "⌥←")
        XCTAssertEqual(defaults[.moveColumnRight]?.description, "⌥⇧→")
        XCTAssertEqual(defaults[.focusDisplayLeft]?.description, "⌥⌘←")
        XCTAssertEqual(defaults[.focusWorkspace1], KeyCombo(18, .option))
    }

    func testChangingModifierKeepsCustomShortcuts() {
        var keymap = Keymap()
        keymap.set(KeyCombo(KeyCode.c, .option), for: .toggleOverview)
        keymap.set(nil, for: .toggleTiling)
        keymap.setModifier(.option)
        XCTAssertEqual(keymap.combo(for: .focusColumnLeft), KeyCombo(KeyCode.leftArrow, .option))
        XCTAssertNil(keymap.combo(for: .toggleTiling))
        // The custom ⌥C wins over centerColumn's new default.
        XCTAssertEqual(keymap.action(for: KeyCombo(KeyCode.c, .option)), .toggleOverview)
        XCTAssertNil(keymap.combo(for: .centerColumn))
        XCTAssertEqual(Set(keymap.bindings.map(\.combo)).count, keymap.bindings.count)

        keymap.reset(.centerColumn)
        XCTAssertEqual(keymap.combo(for: .centerColumn), KeyCombo(KeyCode.c, .option))
        XCTAssertNil(keymap.combo(for: .toggleOverview))
    }

    func testModifierSurvivesStorage() {
        var keymap = Keymap(modifier: .option)
        keymap.set(KeyCombo(4, [.control, .option, .command]), for: .focusColumnLeft)
        XCTAssertEqual(Keymap(modifier: .option, storage: keymap.storage), keymap)
    }

    func testCarbonFlags() {
        XCTAssertEqual(KeyModifiers([.control, .option]).carbonFlags, 0x1800)
        XCTAssertEqual(KeyModifiers([.command, .shift]).carbonFlags, 0x0300)
    }

    func testPolicy() {
        XCTAssertEqual(ShortcutPolicy.evaluate(KeyCombo(0, [])).isRejected, true)
        XCTAssertEqual(ShortcutPolicy.evaluate(KeyCombo(0, .shift)).isRejected, true)
        XCTAssertEqual(ShortcutPolicy.evaluate(KeyCombo(122, [])), .ok, "Bare F1 is allowed")
        XCTAssertEqual(ShortcutPolicy.evaluate(KeyCombo(KeyCode.leftArrow, .control)).isWarning, true)
        XCTAssertEqual(ShortcutPolicy.evaluate(KeyCombo(KeyCode.leftArrow, [.option, .shift])).isWarning, true)
        XCTAssertEqual(ShortcutPolicy.evaluate(KeyCombo(KeyCode.rightArrow, .command)).isWarning, true)
        XCTAssertEqual(ShortcutPolicy.evaluate(KeyCombo(KeyCode.space, .command)).isWarning, true)
        XCTAssertEqual(ShortcutPolicy.evaluate(KeyCombo(KeyCode.leftArrow, [.control, .option])), .ok)
    }
}

private extension ShortcutPolicy.Verdict {
    var isRejected: Bool { if case .rejected = self { true } else { false } }
    var isWarning: Bool { if case .warning = self { true } else { false } }
}
