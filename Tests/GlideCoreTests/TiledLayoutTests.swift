import XCTest
@testable import GlideCore

private extension WorkspaceSet {
    /// Changes one workspace without leaving the active one.
    mutating func edit(_ index: Int, _ change: (inout Workspace) -> Void) {
        let before = activeIndex
        _ = activate(index)
        change(&active)
        _ = activate(before)
    }
}

final class TiledLayoutTests: XCTestCase {
    /// 1212 wide so the maths gives whole numbers with a 12 pt gap: usable width 1188.
    private let viewport = CGRect(x: 0, y: 40, width: 1212, height: 800)

    private func workspace(_ count: Int, widths: [Int]? = nil, layout: LayoutMode? = .tiled, focused: Int = 0) -> Workspace {
        let columns = (1...count).map { Column(windows: [WindowID($0)], widthIndex: widths?[$0 - 1] ?? 1) }
        var ws = Workspace(strip: Strip(columns: columns, focusedColumnIndex: focused), viewport: viewport)
        ws.layoutOverride = layout
        return ws
    }

    private func frames(_ ws: Workspace) -> [WindowID: CGRect] {
        Dictionary(uniqueKeysWithValues: ws.placements().map { ($0.window, $0.frame) })
    }

    private func visibility(_ ws: Workspace) -> [WindowID: Visibility] {
        Dictionary(uniqueKeysWithValues: ws.placements().map { ($0.window, $0.visibility) })
    }

    /// Every column plus the gaps between them.
    private func total(_ ws: Workspace) -> CGFloat {
        ws.strip.columns.indices.reduce(0) { $0 + ws.width(ofColumn: $1) } + ws.settings.gap * CGFloat(ws.strip.columns.count - 1)
    }

    func testColumnsFillTheViewportExactly() {
        for count in [1, 2, 3, 5] {
            let ws = workspace(count)
            XCTAssertEqual(total(ws), ws.usableWidth, "\(count) columns")
            let f = frames(ws)
            XCTAssertEqual(f[1]!.minX, 12)
            XCTAssertEqual(f[WindowID(count)]!.maxX, viewport.maxX - 12)
            XCTAssertTrue(ws.placements().allSatisfy { $0.visibility == .visible })
            XCTAssertEqual(ws.scrollOffset, 0)
        }
    }

    func testDefaultWidthsGiveEqualColumns() {
        let ws = workspace(3)
        XCTAssertEqual(ws.width(ofColumn: 0), ws.width(ofColumn: 1), accuracy: 1)
        XCTAssertEqual(ws.width(ofColumn: 1), ws.width(ofColumn: 2), accuracy: 1)
    }

    func testPresetsActAsWeights() {
        // ⅓ and ⅔ share the room 1 : 2.
        let ws = workspace(2, widths: [0, 2])
        XCTAssertEqual(ws.width(ofColumn: 0) + ws.width(ofColumn: 1), 1176)
        XCTAssertEqual(ws.width(ofColumn: 0), 388)
        XCTAssertEqual(ws.width(ofColumn: 1), 788)
    }

    func testCustomWidthsActAsWeights() {
        var ws = workspace(2)
        _ = ws.strip.setCustomWidth(300, forColumnOf: 1)
        _ = ws.strip.setCustomWidth(900, forColumnOf: 2)
        XCTAssertEqual(ws.width(ofColumn: 0), 294)
        XCTAssertEqual(ws.width(ofColumn: 1), 882)
    }

    func testMinimumWidthsAreKeptAndOthersShareTheRest() {
        var ws = workspace(3)
        ws.minimumWidths[1] = 600
        XCTAssertEqual(ws.width(ofColumn: 0), 600)
        XCTAssertEqual(total(ws), ws.usableWidth)
        XCTAssertEqual(ws.width(ofColumn: 1), ws.width(ofColumn: 2), accuracy: 1)
    }

    func testOverflowingMinimumsScrollLikeTheStrip() {
        var ws = workspace(2)
        ws.minimumWidths[1] = 800
        ws.minimumWidths[2] = 800
        XCTAssertEqual(ws.width(ofColumn: 0), 800)
        XCTAssertEqual(ws.width(ofColumn: 1), 800)
        XCTAssertGreaterThan(ws.contentWidth, ws.usableWidth)
        ws.strip.focus(2)
        ws.ensureFocusedVisible()
        XCTAssertGreaterThan(ws.scrollOffset, 0)
    }

    func testFullWidthZoomsOneColumnAndTheRestStayTiled() {
        var ws = workspace(3, focused: 1)
        ws.perform(.toggleFullWidth)
        XCTAssertEqual(ws.width(ofColumn: 1), ws.usableWidth)
        // The others split the room between themselves, as if the zoomed column weren't there.
        XCTAssertEqual(ws.width(ofColumn: 0), 588)
        XCTAssertEqual(ws.width(ofColumn: 2), 588)
        let v = visibility(ws)
        XCTAssertEqual(v[2], .visible)
        XCTAssertNotEqual(v[1], .visible)
        XCTAssertNotEqual(v[3], .visible)
        ws.perform(.toggleFullWidth)
        XCTAssertEqual(ws.scrollOffset, 0)
        XCTAssertEqual(total(ws), ws.usableWidth)
    }

    func testCyclingWidthChangesTheShare() {
        var ws = workspace(2)
        let before = ws.width(ofColumn: 0)
        ws.perform(.cycleColumnWidth)
        XCTAssertGreaterThan(ws.width(ofColumn: 0), before)
        XCTAssertEqual(total(ws), ws.usableWidth)
    }

    func testCenteringAndSwipesDoNothingWhenEverythingFits() {
        var ws = workspace(3, focused: 1)
        XCTAssertFalse(ws.perform(.centerColumn))
        XCTAssertEqual(ws.scrollBounds, 0...0)
        ws.settleSwipe(projectedOffset: 500)
        XCTAssertEqual(ws.scrollOffset, 0)
    }

    func testResizeLandsNearTheRequestedWidth() {
        for wanted: CGFloat in [400, 700, 900] {
            var ws = workspace(3)
            let others = (ws.width(ofColumn: 1), ws.width(ofColumn: 2))
            XCTAssertTrue(ws.setColumnWidthFromResize(1, to: wanted))
            XCTAssertEqual(ws.width(ofColumn: 0), wanted, accuracy: 2)
            XCTAssertEqual(total(ws), ws.usableWidth)
            // The neighbours keep their proportions.
            XCTAssertEqual(others.0 / others.1, ws.width(ofColumn: 1) / ws.width(ofColumn: 2), accuracy: 0.01)
        }
    }

    func testResizeIsClampedToSomethingSensible() {
        var ws = workspace(2)
        ws.setColumnWidthFromResize(1, to: 5000)
        XCTAssertTrue((50...300).contains(ws.width(ofColumn: 1)))
        ws.setColumnWidthFromResize(1, to: 1)
        XCTAssertTrue((50...200).contains(ws.width(ofColumn: 0)))
    }

    func testResizeOnTheStripIsTheCustomWidth() {
        var ws = workspace(2, layout: .scrolling)
        ws.setColumnWidthFromResize(1, to: 700)
        XCTAssertEqual(ws.width(ofColumn: 0), 700)
        XCTAssertEqual(ws.width(ofColumn: 1), 588)
    }

    func testScrollingWidthsAreUnchanged() {
        let ws = workspace(3, layout: nil)
        XCTAssertEqual(ws.layout, .scrolling)
        XCTAssertEqual(ws.width(ofColumn: 0), 588)
    }

    func testToggleSetsTheOverrideAndFlips() {
        var ws = workspace(3, layout: nil)
        XCTAssertNil(ws.layoutOverride)
        XCTAssertTrue(ws.perform(.toggleLayout))
        XCTAssertEqual(ws.layoutOverride, .tiled)
        ws.toggleLayout()
        XCTAssertEqual(ws.layoutOverride, .scrolling)
    }

    func testTogglingToTiledBringsTheStripBackToZero() {
        var ws = workspace(4, layout: nil, focused: 3)
        ws.ensureFocusedVisible()
        XCTAssertGreaterThan(ws.scrollOffset, 0)
        ws.toggleLayout()
        XCTAssertEqual(ws.layout, .tiled)
        XCTAssertEqual(ws.scrollOffset, 0)
    }

    func testDefaultLayoutAppliesLiveToUntouchedWorkspacesOnly() {
        var set = WorkspaceSet(viewport: viewport)
        set.edit(1) { $0.toggleLayout() } // tiled by hand
        set.settings.defaultLayout = .tiled
        XCTAssertEqual(set.workspaces[0].layout, .tiled)
        set.edit(1) { $0.toggleLayout() } // by hand back to scrolling
        XCTAssertEqual(set.workspaces[1].layout, .scrolling)
        set.settings.defaultLayout = .scrolling
        XCTAssertEqual(set.workspaces[0].layout, .scrolling)
        XCTAssertEqual(set.workspaces[1].layout, .scrolling)
    }

    func testSendingAWindowAwayLeavesBothLayoutsAlone() {
        var set = WorkspaceSet(viewport: viewport)
        set.active.strip.insert(1, widthIndex: 1, at: 0)
        set.active.toggleLayout()
        XCTAssertTrue(set.moveFocusedWindow(to: 1))
        XCTAssertEqual(set.workspaces[0].layoutOverride, .tiled)
        XCTAssertNil(set.workspaces[1].layoutOverride)
    }

    func testSnapshotKeepsLayoutOverrides() throws {
        var set = WorkspaceSet(viewport: viewport)
        set.active.strip.insert(1, widthIndex: 1, at: 0)
        set.edit(0) { $0.toggleLayout() }
        set.edit(2) { $0.layoutOverride = .scrolling }
        let snapshot = StripSnapshot(workspaces: set, userFloating: [], userTiled: [], bootTime: Date(timeIntervalSince1970: 0))
        let data = try JSONEncoder().encode(snapshot)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\"tiled\""))
        let decoded = try JSONDecoder().decode(StripSnapshot.self, from: data)

        let restored = decoded.restoreWorkspaces(windows: [1], widthIndex: 1, presetCount: 4)
        XCTAssertEqual(Array(restored.layouts.prefix(3)), [.tiled, nil, .scrolling])
        var rebuilt = WorkspaceSet(viewport: viewport)
        rebuilt.restore(strips: restored.strips, activeIndex: restored.active, layouts: restored.layouts)
        XCTAssertEqual(rebuilt.workspaces[0].layoutOverride, .tiled)
        XCTAssertNil(rebuilt.workspaces[1].layoutOverride)
        XCTAssertEqual(rebuilt.workspaces[2].layoutOverride, .scrolling)
    }

    func testEachDisplayKeepsItsOwnLayouts() throws {
        var main = WorkspaceSet(viewport: viewport)
        main.active.strip.insert(1, widthIndex: 1, at: 0)
        main.edit(0) { $0.toggleLayout() }
        var side = WorkspaceSet(viewport: viewport)
        side.active.strip.insert(2, widthIndex: 1, at: 0)
        let snapshot = StripSnapshot(displays: [("main", main), ("side", side)], userFloating: [], userTiled: [], bootTime: Date(timeIntervalSince1970: 0))
        let decoded = try JSONDecoder().decode(StripSnapshot.self, from: JSONEncoder().encode(snapshot))
        let restored = decoded.restoreDisplays(windows: [(1, "main"), (2, "side")], displays: ["main", "side"], widthIndex: 1, presetCount: 4)
        XCTAssertEqual(restored["main"]!.layouts[0], .tiled)
        XCTAssertNil(restored["side"]!.layouts[0])
    }

    func testSnapshotsWithoutLayoutsStillLoad() throws {
        let json = """
        {"columns":[{"windows":[1],"focusedRow":0,"widthIndex":1,"isFullWidth":false}],\
        "workspaces":[{"columns":[{"windows":[1],"focusedRow":0,"widthIndex":1,"isFullWidth":false}]}],\
        "userFloating":[],"userTiled":[],"bootTime":0}
        """
        let decoded = try JSONDecoder().decode(StripSnapshot.self, from: Data(json.utf8))
        let restored = decoded.restoreWorkspaces(windows: [1], widthIndex: 1, presetCount: 4)
        XCTAssertEqual(restored.layouts, [nil])
    }

    func testToggleLayoutIsAWorkspaceLevelActionWithItsOwnShortcut() {
        XCTAssertNil(Action.toggleLayout.workspaceCommand)
        XCTAssertEqual(Action.toggleLayout.group, .workspaces)
        XCTAssertEqual(Keymap.defaults[.toggleLayout], KeyCombo(KeyCode.t, [.control, .option]))
        XCTAssertEqual(Keymap.defaults.filter { $0.value == KeyCombo(KeyCode.t, [.control, .option]) }.map(\.key), [.toggleLayout])
        XCTAssertEqual(Action(rawValue: "toggleLayout"), .toggleLayout)
        XCTAssertEqual(Action(rawValue: "toggleTiling"), .toggleTiling)
        XCTAssertEqual(Keymap.defaults[.toggleTiling], KeyCombo(KeyCode.t, [.control, .option, .shift]))
        XCTAssertEqual(Action.allCases.last, .toggleLayout)
    }
}
