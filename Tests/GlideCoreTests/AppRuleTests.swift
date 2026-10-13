import XCTest
@testable import GlideCore

final class AppRuleTests: XCTestCase {
    func testSystemSettingsFloatsByDefault() {
        XCTAssertEqual(AppRules().rule(for: "com.apple.systempreferences")?.mode, .float)
        XCTAssertNil(AppRules().rule(for: "com.apple.Safari"))
        XCTAssertNil(AppRules().rule(for: nil))
    }

    func testSetReplacesInPlaceAndRemove() {
        var rules = AppRules([])
        rules.set(AppRule(bundleID: "a", appName: "A", mode: .float))
        rules.set(AppRule(bundleID: "b", appName: "B", widthIndex: 0))
        rules.set(AppRule(bundleID: "a", appName: "A", mode: .tile, workspace: 2))
        XCTAssertEqual(rules.rules.map(\.bundleID), ["a", "b"])
        XCTAssertEqual(rules.rule(for: "a")?.mode, .tile)
        XCTAssertEqual(rules.rule(for: "a")?.workspace, 2)
        rules.remove("a")
        XCTAssertEqual(rules.rules.map(\.bundleID), ["b"])
    }

    func testDuplicatesCollapseToTheLastOne() {
        let rules = AppRules([AppRule(bundleID: "a", appName: "A", mode: .float), AppRule(bundleID: "a", appName: "A", mode: .tile)])
        XCTAssertEqual(rules.rules.count, 1)
        XCTAssertEqual(rules.rule(for: "a")?.mode, .tile)
    }

    func testShouldTile() {
        let float = AppRule(bundleID: "a", appName: "A", mode: .float)
        let tile = AppRule(bundleID: "a", appName: "A", mode: .tile)
        func decide(_ rule: AppRule?, tileable: Bool = true, canTile: Bool = true, floating: Bool = false, tiled: Bool = false) -> Bool {
            AppRules.shouldTile(rule: rule, classifiedTileable: tileable, canTile: canTile, userFloating: floating, userTiled: tiled)
        }
        XCTAssertTrue(decide(nil))
        XCTAssertFalse(decide(nil, tileable: false))
        XCTAssertFalse(decide(float), "The rule floats a window Glide would tile")
        XCTAssertTrue(decide(tile, tileable: false), "The rule tiles a resizable window Glide would float")
        XCTAssertFalse(decide(tile, tileable: false, canTile: false), "Dialogs and fixed-size windows still float")
        XCTAssertTrue(decide(float, tiled: true), "A hand-made choice beats the rule")
        XCTAssertFalse(decide(tile, floating: true))
    }

    func testRulesRoundTripThroughJSON() throws {
        let rules = [AppRule(bundleID: "com.mitchellh.ghostty", appName: "Ghostty", mode: .tile, widthIndex: 0, workspace: 1)]
        let decoded = try JSONDecoder().decode([AppRule].self, from: JSONEncoder().encode(rules))
        XCTAssertEqual(decoded, rules)
    }

    func testInsertOnAnotherWorkspace() {
        var set = WorkspaceSet(viewport: CGRect(x: 0, y: 0, width: 1200, height: 800))
        set.insert(1, widthIndex: 1, focus: true)
        XCTAssertEqual(set.insert(2, widthIndex: 0, workspace: 3, focus: false), 3)
        XCTAssertEqual(set.workspaces[3].strip.columns.first?.widthIndex, 0)
        XCTAssertEqual(set.activeIndex, 0)
        XCTAssertEqual(set.insert(3, widthIndex: 1, workspace: 42, focus: true), 0, "Unknown workspace falls back to the active one")
    }
}
