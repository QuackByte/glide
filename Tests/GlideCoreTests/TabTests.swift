import XCTest
@testable import GlideCore

final class TabTests: XCTestCase {
    private let viewport = CGRect(x: 0, y: 40, width: 1212, height: 800)

    /// A tabbed column holding windows 1, 2 and 3, next to a plain column with window 4.
    private func workspace(focusedRow: Int = 0) -> Workspace {
        let columns = [Column(windows: [1, 2, 3], focusedRow: focusedRow, widthIndex: 1, isTabbed: true), Column(windows: [4], widthIndex: 1)]
        return Workspace(strip: Strip(columns: columns), viewport: viewport)
    }

    private func placements(_ ws: Workspace) -> [WindowID: WindowPlacement] {
        Dictionary(uniqueKeysWithValues: ws.placements().map { ($0.window, $0) })
    }

    func testToggleTabbed() {
        var strip = Strip(columns: [Column(windows: [1, 2], widthIndex: 1)])
        XCTAssertTrue(strip.toggleTabbed())
        XCTAssertTrue(strip.columns[0].isTabbed)
        XCTAssertTrue(strip.toggleTabbed())
        XCTAssertFalse(strip.columns[0].isTabbed)
        var empty = Strip()
        XCTAssertFalse(empty.toggleTabbed())
    }

    func testOnlyTheActiveTabIsShownBelowTheTabBar() {
        let p = placements(workspace(focusedRow: 1))
        // 28 pt bar + 4 pt spacing below the 12 pt gap; full column height otherwise.
        XCTAssertEqual(p[2]?.frame, CGRect(x: 12, y: 84, width: 588, height: 744))
        XCTAssertEqual(p[2]?.visibility, .visible)
        for hidden: WindowID in [1, 3] {
            XCTAssertEqual(p[hidden]?.visibility, .hiddenTab)
            XCTAssertEqual(p[hidden]?.frame.origin, CGPoint(x: viewport.maxX - 1, y: viewport.maxY - 1))
            XCTAssertEqual(p[hidden]?.frame.size, p[2]?.frame.size)
        }
        XCTAssertEqual(p[4]?.frame, CGRect(x: 612, y: 52, width: 588, height: 776), "Plain columns are unaffected")
    }

    func testTabBarSitsAboveTheActiveTab() {
        let bars = workspace(focusedRow: 2).tabBars()
        XCTAssertEqual(bars.count, 1)
        XCTAssertEqual(bars[0].frame, CGRect(x: 12, y: 52, width: 588, height: 28))
        XCTAssertEqual(bars[0].windows, [1, 2, 3])
        XCTAssertEqual(bars[0].activeWindow, 3)
    }

    func testFocusUpAndDownSwitchTabs() {
        var ws = workspace()
        XCTAssertTrue(ws.perform(.focusWindowDown))
        XCTAssertEqual(placements(ws)[2]?.visibility, .visible)
        XCTAssertEqual(placements(ws)[1]?.visibility, .hiddenTab)
        XCTAssertTrue(ws.perform(.moveWindowUp), "Reorders tabs")
        XCTAssertEqual(ws.strip.columns[0].windows, [2, 1, 3])
        XCTAssertEqual(ws.tabBars()[0].activeIndex, 0)
    }

    func testConsumeAddsATabAndExpelMakesAPlainColumn() {
        var ws = workspace()
        ws.strip.focus(4)
        XCTAssertTrue(ws.perform(.consumeOrExpelLeft))
        XCTAssertEqual(ws.strip.columns.count, 1)
        XCTAssertEqual(ws.strip.columns[0].windows, [1, 2, 3, 4])
        XCTAssertEqual(placements(ws)[4]?.visibility, .visible, "The consumed window becomes the active tab")
        XCTAssertTrue(ws.perform(.consumeOrExpelRight))
        XCTAssertTrue(ws.strip.columns[0].isTabbed)
        XCTAssertFalse(ws.strip.columns[1].isTabbed)
    }

    private func tiled(_ columns: [Column], focused: Int = 0) -> Workspace {
        var ws = Workspace(strip: Strip(columns: columns, focusedColumnIndex: focused), viewport: viewport)
        ws.layoutOverride = .tiled
        return ws
    }

    func testTiledLoneWindowJoinsTheTileOnItsLeftAsAFocusedTab() {
        var ws = tiled([Column(windows: [1], widthIndex: 1), Column(windows: [2], widthIndex: 1), Column(windows: [3], widthIndex: 1)], focused: 1)
        XCTAssertTrue(ws.perform(.consumeOrExpelLeft))
        XCTAssertEqual(ws.strip.columns.map(\.windows), [[1, 2], [3]], "One tile fewer")
        XCTAssertTrue(ws.strip.columns[0].isTabbed, "Stays one tile rather than splitting back into columns")
        XCTAssertEqual(ws.strip.focusedWindow, 2)
        XCTAssertEqual(ws.tabBars().map(\.column), [0])
        XCTAssertEqual(ws.tabBars()[0].activeWindow, 2)
        XCTAssertEqual(placements(ws)[2]?.frame, CGRect(x: 12, y: 84, width: 588, height: 744))
        XCTAssertEqual(placements(ws)[1]?.visibility, .hiddenTab)
    }

    func testTiledLoneWindowJoinsAnExistingTabGroupOnItsRight() {
        var ws = tiled([Column(windows: [1], widthIndex: 1), Column(windows: [2, 3], widthIndex: 1, isTabbed: true), Column(windows: [4], widthIndex: 1)])
        XCTAssertTrue(ws.perform(.consumeOrExpelRight))
        XCTAssertEqual(ws.strip.columns.map(\.windows), [[2, 3, 1], [4]])
        XCTAssertTrue(ws.strip.columns[0].isTabbed)
        XCTAssertEqual(ws.strip.focusedWindow, 1)
        XCTAssertEqual(ws.tabBars()[0].activeWindow, 1)
    }

    func testTiledTabExpelsIntoANewTileOnItsSide() {
        var ws = tiled([Column(windows: [4], widthIndex: 1), Column(windows: [1, 2, 3], focusedRow: 1, widthIndex: 1, isTabbed: true)], focused: 1)
        XCTAssertTrue(ws.perform(.consumeOrExpelLeft))
        XCTAssertEqual(ws.strip.columns.map(\.windows), [[4], [2], [1, 3]])
        XCTAssertEqual(ws.strip.focusedWindow, 2)
        XCTAssertFalse(ws.strip.columns[1].isTabbed)
        XCTAssertTrue(ws.strip.columns[2].isTabbed)
        XCTAssertEqual(placements(ws)[2]?.visibility, .visible)
        XCTAssertEqual(ws.tabBars().map(\.column), [2])
    }

    func testTiledTabExpelsRight() {
        var ws = tiled([Column(windows: [1, 2, 3], focusedRow: 1, widthIndex: 1, isTabbed: true), Column(windows: [4], widthIndex: 1)])
        XCTAssertTrue(ws.perform(.consumeOrExpelRight))
        XCTAssertEqual(ws.strip.columns.map(\.windows), [[1, 3], [2], [4]])
        XCTAssertEqual(ws.strip.focusedWindow, 2)
        XCTAssertEqual(placements(ws)[2]?.visibility, .visible)
    }

    /// Five tiles as in TiledLayoutTests: 0 on the left, 1 top right with 2 below it, then 3 and 4. Tile 1 is a tab group.
    private func tiledWithTabGroup(focusedRow: Int = 0) -> Workspace {
        let columns = [Column(windows: [1], widthIndex: 1), Column(windows: [10, 11, 12], focusedRow: focusedRow, widthIndex: 1, isTabbed: true)]
            + [13, 14, 15].map { Column(windows: [$0], widthIndex: 1) }
        var ws = Workspace(strip: Strip(columns: columns, focusedColumnIndex: 1), viewport: viewport)
        ws.layoutOverride = .tiled
        ws.tiledColumnsOverride = 2
        return ws
    }

    func testTiledFocusUpAndDownSwitchTabsInTheFocusedTile() {
        var ws = tiledWithTabGroup()
        ws.strip.focus(10)
        XCTAssertTrue(ws.perform(.focusWindowDown))
        XCTAssertEqual(ws.strip.focusedWindow, 11)
        XCTAssertEqual(ws.strip.focusedColumnIndex, 1, "Still the same tile")
        XCTAssertEqual(ws.tabBars()[0].activeWindow, 11)
        XCTAssertTrue(ws.perform(.focusWindowDown))
        XCTAssertEqual(ws.strip.focusedWindow, 12)
        XCTAssertTrue(ws.perform(.focusWindowUp))
        XCTAssertEqual(ws.strip.focusedWindow, 11)
        XCTAssertTrue(ws.perform(.focusWindowUp))
        XCTAssertEqual(ws.strip.focusedWindow, 10)
        XCTAssertEqual(placements(ws)[10]?.visibility, .visible)
        XCTAssertEqual(placements(ws)[11]?.visibility, .hiddenTab)
    }

    func testTiledFocusFallsBackToTheTileBelowWhenTheTabsRunOut() {
        var ws = tiledWithTabGroup(focusedRow: 1)
        XCTAssertTrue(ws.perform(.focusWindowDown))
        XCTAssertEqual(ws.strip.focusedWindow, 12)
        XCTAssertTrue(ws.perform(.focusWindowDown), "No tab below, so the tile below")
        XCTAssertEqual(ws.strip.focusedColumnIndex, 2)
        XCTAssertEqual(ws.strip.focusedWindow, 13)
        XCTAssertEqual(ws.tabBars()[0].activeWindow, 12, "The tab group keeps its active tab")
        XCTAssertTrue(ws.perform(.focusWindowUp), "Back into the tab group from below")
        XCTAssertEqual(ws.strip.focusedColumnIndex, 1)
        XCTAssertEqual(ws.strip.focusedWindow, 12)
    }

    func testTiledFocusInATabGroupWithNoTileInThatDirectionDoesNothing() {
        var ws = tiledWithTabGroup(focusedRow: 0)
        XCTAssertFalse(ws.perform(.focusWindowUp), "No tab above and no tile above")
        XCTAssertEqual(ws.strip.focusedWindow, 10)
    }

    func testTiledFocusOnAPlainTileIsUnchangedByTabGroupsElsewhere() {
        var ws = tiledWithTabGroup()
        ws.strip.focus(13)
        XCTAssertTrue(ws.perform(.focusWindowUp))
        XCTAssertEqual(ws.strip.focusedColumnIndex, 1)
        XCTAssertEqual(ws.strip.focusedWindow, 10, "Lands on the tab group's active tab")
        ws.strip.focus(14)
        XCTAssertTrue(ws.perform(.focusWindowDown))
        XCTAssertEqual(ws.strip.focusedColumnIndex, 4)
        XCTAssertEqual(ws.strip.focusedWindow, 15)
        XCTAssertFalse(ws.perform(.focusWindowDown))
    }

    func testZoomedOnlyTheFocusedTilesTabBarShows() {
        var ws = Workspace(strip: Strip(columns: [Column(windows: [1, 2], widthIndex: 1, isTabbed: true),
                                                  Column(windows: [3, 4], widthIndex: 1, isTabbed: true)]), viewport: viewport)
        ws.layoutOverride = .tiled
        ws.perform(.toggleFullWidth)
        XCTAssertEqual(ws.tabBars().map(\.column), [0])
        ws.perform(.focusColumnRight)
        XCTAssertEqual(ws.tabBars().map(\.column), [1])
    }

    func testAZoomedTabGroupStaysZoomedAndShowsTheNewTab() {
        var ws = tiledWithTabGroup()
        ws.strip.focus(10)
        ws.perform(.toggleFullWidth)
        XCTAssertTrue(ws.perform(.focusWindowDown))
        XCTAssertTrue(ws.isZoomed)
        XCTAssertEqual(ws.tabBars()[0].activeWindow, 11)
        XCTAssertEqual(placements(ws)[11]?.visibility, .visible)
        XCTAssertEqual(placements(ws)[11]?.frame, CGRect(x: 12, y: 84, width: 1188, height: 744))
    }

    func testParkedTabbedColumnHasNoTabBar() {
        let columns = [Column(windows: [1, 2], widthIndex: 1, isTabbed: true)] + (3...5).map { Column(windows: [WindowID($0)], widthIndex: 1) }
        var ws = Workspace(strip: Strip(columns: columns), viewport: viewport)
        ws.perform(.focusLastColumn)
        XCTAssertEqual(placements(ws)[1]?.visibility, .parkedLeft)
        XCTAssertEqual(ws.tabBars(), [])
    }

    func testSnapshotKeepsTabs() throws {
        let strip = workspace(focusedRow: 1).strip
        let snapshot = StripSnapshot(strip: strip, userFloating: [], userTiled: [], bootTime: Date(timeIntervalSince1970: 0))
        let decoded = try JSONDecoder().decode(StripSnapshot.self, from: JSONEncoder().encode(snapshot))
        let restored = decoded.restore(windows: [1, 2, 3, 4], widthIndex: 1, presetCount: 4)
        XCTAssertTrue(restored.columns[0].isTabbed)
        XCTAssertEqual(restored.columns[0].focusedRow, 1)
    }

    func testSnapshotsFromBeforeTabsStillLoad() throws {
        let json = #"{"columns":[{"windows":[1],"focusedRow":0,"widthIndex":1,"isFullWidth":false}],"userFloating":[],"userTiled":[],"bootTime":0}"#
        let decoded = try JSONDecoder().decode(StripSnapshot.self, from: Data(json.utf8))
        XCTAssertFalse(decoded.restore(windows: [1], widthIndex: 1, presetCount: 4).columns[0].isTabbed)
    }
}
