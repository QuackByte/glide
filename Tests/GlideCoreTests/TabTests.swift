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
