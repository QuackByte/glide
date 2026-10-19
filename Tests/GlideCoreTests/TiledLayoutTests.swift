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

    private func make(_ count: Int, columns: Int = 2, layout: LayoutMode? = .tiled, focused: Int = 0) -> Workspace {
        let strip = Strip(columns: (0..<count).map { Column(windows: [WindowID($0 + 1)], widthIndex: 1) }, focusedColumnIndex: focused)
        var ws = Workspace(strip: strip, viewport: viewport)
        ws.layoutOverride = layout
        ws.tiledColumnsOverride = columns
        return ws
    }

    private func workspace(_ columns: [Column], focused: Int = 0, layout: LayoutMode? = .tiled) -> Workspace {
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

    private func layout(_ strip: Strip) -> [[WindowID]] { strip.columns.map(\.windows) }

    private func placed(_ ws: Workspace) -> [CGRect] { ws.placements().map(\.frame) }

    private func expected(_ ws: Workspace, count: Int? = nil, ratios: [CGFloat]? = nil) -> [CGRect] {
        TiledLayout.frames(in: ws.viewport, count: count ?? ws.strip.windows.count, columns: ws.tiledColumns, gap: ws.settings.gap, ratios: ratios)
    }

    // MARK: Placement

    func testPlacementsFollowTheSpiralAndNothingScrollsOrParks() {
        for (count, columns) in [(1, 2), (2, 2), (3, 2), (5, 2), (3, 3), (6, 3)] {
            let ws = make(count, columns: columns)
            XCTAssertEqual(placed(ws), expected(ws), "\(count) in \(columns)")
            XCTAssertTrue(ws.placements().allSatisfy { $0.visibility == .visible })
            XCTAssertEqual(ws.placements().map(\.window), (1...count).map { WindowID($0) })
            XCTAssertEqual(ws.scrollOffset, 0)
        }
    }

    func testThreeWindowsOnTwoColumns() {
        let f = frames(make(3))
        XCTAssertEqual(f[1], CGRect(x: 12, y: 52, width: 588, height: 776))
        XCTAssertEqual(f[2], CGRect(x: 612, y: 52, width: 588, height: 382))
        XCTAssertEqual(f[3], CGRect(x: 612, y: 446, width: 588, height: 382))
    }

    func testTheColumnCountComesFromTheOverrideThenTheDefaultThenTheScreen() {
        var ws = make(3, columns: 3)
        ws.tiledColumnsOverride = nil
        XCTAssertEqual(ws.tiledColumns, 2, "1212 × 800 is not ultrawide")
        ws.settings.defaultTiledColumns = 3
        XCTAssertEqual(ws.tiledColumns, 3)
        ws.tiledColumnsOverride = 2
        XCTAssertEqual(ws.tiledColumns, 2)
        ws.tiledColumnsOverride = nil
        ws.settings = .standard
        ws.viewport = CGRect(x: 0, y: 0, width: 3440, height: 1440)
        XCTAssertEqual(ws.tiledColumns, 3)
        XCTAssertEqual(LayoutSettings(defaultTiledColumns: 1).defaultTiledColumns, 2, "Clamped to 2…3")
        XCTAssertEqual(LayoutSettings(defaultTiledColumns: 9).defaultTiledColumns, 3)
        XCTAssertNil(LayoutSettings().defaultTiledColumns)
    }

    func testTheDefaultColumnCountAppliesLiveToUntouchedWorkspacesOnly() {
        var set = WorkspaceSet(viewport: viewport)
        set.edit(1) { $0.cycleTiledColumns() } // 2 → 3 by hand
        set.settings.defaultTiledColumns = 3
        XCTAssertEqual(set.workspaces[0].tiledColumns, 3)
        set.settings.defaultTiledColumns = 2
        XCTAssertEqual(set.workspaces[0].tiledColumns, 2)
        XCTAssertEqual(set.workspaces[1].tiledColumns, 3)
    }

    func testMinimumWidthsGiveTheTileItsMinimumWithinItsX() {
        var ws = make(2)
        ws.minimumWidths[1] = 800
        XCTAssertEqual(frames(ws)[1], CGRect(x: 12, y: 52, width: 800, height: 776), "Overlaps its neighbour at x = 612")
        XCTAssertEqual(frames(ws)[2], CGRect(x: 612, y: 52, width: 588, height: 776))
        ws.minimumWidths[2] = 700
        XCTAssertEqual(frames(ws)[2], CGRect(x: 500, y: 52, width: 700, height: 776), "Pulled left so it stays on screen")
        ws.minimumWidths[2] = 5000
        XCTAssertEqual(frames(ws)[2]?.width, ws.usableWidth)
    }

    func testATabbedColumnIsOneTileWithItsBarAtTheTop() {
        let ws = workspace([Column(windows: [1], widthIndex: 1), Column(windows: [2, 3, 4], focusedRow: 1, widthIndex: 1, isTabbed: true)])
        let tile = expected(ws, count: 2)[1]
        let bars = ws.tabBars()
        XCTAssertEqual(bars.count, 1)
        XCTAssertEqual(bars[0].column, 1)
        XCTAssertEqual(bars[0].frame, CGRect(x: tile.minX, y: tile.minY, width: tile.width, height: ws.settings.tabBarHeight))
        XCTAssertEqual(bars[0].activeWindow, 3)
        let reserved = ws.settings.tabBarHeight + ws.settings.tabBarSpacing
        XCTAssertEqual(frames(ws)[3], CGRect(x: tile.minX, y: tile.minY + reserved, width: tile.width, height: tile.height - reserved))
        XCTAssertEqual(visibility(ws)[3], .visible)
        XCTAssertEqual(visibility(ws)[2], .hiddenTab)
        XCTAssertEqual(visibility(ws)[4], .hiddenTab)
        XCTAssertEqual(frames(ws)[2], ws.hiddenFrame(size: frames(ws)[3]!.size))
    }

    func testAStackThatSneaksInIsPlacedAsTilesAndThenSplitIntoColumns() {
        var ws = workspace([Column(windows: [1], widthIndex: 1), Column(windows: [2, 3], widthIndex: 1)])
        XCTAssertEqual(placed(ws), expected(ws, count: 3), "Already three tiles")
        ws.ensureFocusedVisible()
        XCTAssertEqual(layout(ws.strip), [[1], [2], [3]])
    }

    func testDroppingWindowsOnAColumnKeepsOneTilePerColumn() {
        var ws = make(3, focused: 1)
        ws.strip.join(9, columnOf: 2)
        ws.ensureFocusedVisible()
        XCTAssertEqual(layout(ws.strip), [[1], [2], [9], [3]])
        XCTAssertEqual(ws.strip.focusedWindow, 9)
    }

    func testNewWindowsBecomeTheNextTileAfterTheFocusedOne() {
        var set = WorkspaceSet(viewport: viewport)
        set.active.layoutOverride = .tiled
        for id: WindowID in [1, 2, 3] { set.insert(id, widthIndex: 1, focus: true) }
        set.active.strip.focus(1)
        set.insert(4, widthIndex: 1, focus: true)
        XCTAssertEqual(set.active.strip.windows, [1, 4, 2, 3])
        XCTAssertEqual(set.active.scrollOffset, 0)
        XCTAssertEqual(set.active.placements().count, 4)
    }

    // MARK: Focus and move

    func testFocusGoesToTheTileInThatDirection() {
        var ws = make(5, focused: 0) // [0][1 over (2 | (3 over 4))]
        func step(_ action: Action, to index: Int?, _ line: UInt = #line) {
            XCTAssertEqual(ws.perform(action), index != nil, line: line)
            if let index { XCTAssertEqual(ws.strip.focusedColumnIndex, index, line: line) }
        }
        step(.focusColumnRight, to: 1)
        step(.focusWindowDown, to: 2)
        step(.focusColumnRight, to: 3)
        step(.focusWindowDown, to: 4)
        step(.focusWindowDown, to: nil)
        step(.focusColumnLeft, to: 2)
        step(.focusWindowUp, to: 1)
        step(.focusWindowUp, to: nil)
        step(.focusColumnLeft, to: 0)
        step(.focusColumnLeft, to: nil)
        XCTAssertEqual(ws.scrollOffset, 0)
    }

    func testFocusFirstAndLastAreTheFirstAndLastTiles() {
        var ws = make(4, focused: 1)
        XCTAssertTrue(ws.perform(.focusLastColumn))
        XCTAssertEqual(ws.strip.focusedColumnIndex, 3)
        XCTAssertFalse(ws.perform(.focusLastColumn))
        XCTAssertTrue(ws.perform(.focusFirstColumn))
        XCTAssertEqual(ws.strip.focusedColumnIndex, 0)
    }

    func testMoveSwapsWithTheNeighbourAndFocusFollowsTheWindow() {
        var ws = make(3, focused: 0) // [0][1 over 2]
        XCTAssertTrue(ws.perform(.moveColumnRight))
        XCTAssertEqual(layout(ws.strip), [[2], [1], [3]])
        XCTAssertEqual(ws.strip.focusedWindow, 1)
        XCTAssertEqual(frames(ws)[1], CGRect(x: 612, y: 52, width: 588, height: 382))
        XCTAssertTrue(ws.perform(.moveWindowDown))
        XCTAssertEqual(layout(ws.strip), [[2], [3], [1]])
        XCTAssertEqual(ws.strip.focusedWindow, 1)
        XCTAssertTrue(ws.perform(.moveColumnLeft))
        XCTAssertEqual(layout(ws.strip), [[1], [3], [2]])
        XCTAssertFalse(ws.perform(.moveColumnLeft))
        XCTAssertFalse(ws.perform(.moveWindowUp))
    }

    func testConsumeAndExpelDoNothingWhileTiled() {
        var ws = make(3, focused: 1)
        XCTAssertFalse(ws.perform(.consumeOrExpelLeft))
        XCTAssertFalse(ws.perform(.consumeOrExpelRight))
        XCTAssertEqual(layout(ws.strip), [[1], [2], [3]])
    }

    func testCenterColumnAndScrollingDoNothingWhileTiled() {
        var ws = make(3, focused: 1)
        XCTAssertFalse(ws.perform(.centerColumn))
        XCTAssertEqual(ws.scrollOffset, 0)
        XCTAssertEqual(ws.scrollBounds, 0...0)
        ws.scroll(by: 300)
        ws.settleSwipe(projectedOffset: 500)
        XCTAssertEqual(ws.scrollOffset, 0)
    }

    func testActionsOnAnEmptyTiledWorkspaceAreHarmless() {
        var ws = make(0)
        for action in [Action.focusColumnLeft, .moveColumnRight, .cycleColumnWidth, .toggleFullWidth] {
            XCTAssertFalse(ws.perform(action), "\(action)")
        }
        XCTAssertTrue(ws.perform(.toggleLayout))
        XCTAssertEqual(ws.layout, .scrolling)
    }

    // MARK: Zoom

    func testFullWidthZoomsTheFocusedTileUntilToggledAgain() {
        var ws = make(3, focused: 1)
        let before = frames(ws)
        XCTAssertTrue(ws.perform(.toggleFullWidth))
        let zoomed = frames(ws)
        XCTAssertEqual(zoomed[2], CGRect(x: 12, y: 52, width: 1188, height: 776))
        XCTAssertEqual(zoomed[1], before[1], "The others stay put, underneath")
        XCTAssertEqual(zoomed[3], before[3])
        XCTAssertTrue(ws.perform(.toggleFullWidth))
        XCTAssertEqual(frames(ws), before)
    }

    func testAZoomEndsWhenFocusLeavesAndDoesNotComeBack() {
        var ws = make(3, focused: 0)
        ws.perform(.toggleFullWidth)
        XCTAssertTrue(ws.perform(.focusColumnRight))
        XCTAssertNil(ws.zoomedWindow)
        ws.perform(.focusColumnLeft)
        XCTAssertNotEqual(frames(ws)[1], CGRect(x: 12, y: 52, width: 1188, height: 776))
    }

    func testAZoomEndsWhenItsWindowLeaves() {
        var set = WorkspaceSet(viewport: viewport)
        set.active.layoutOverride = .tiled
        for id: WindowID in [1, 2] { set.insert(id, widthIndex: 1, focus: true) }
        set.active.perform(.toggleFullWidth)
        XCTAssertEqual(set.active.zoomedWindow, 2)
        set.remove(2)
        XCTAssertNil(set.active.zoomedWindow)
        set.insert(2, widthIndex: 1, focus: true)
        XCTAssertEqual(frames(set.active)[2], CGRect(x: 612, y: 52, width: 588, height: 776))
    }

    func testATabbedTileCanBeZoomedToo() {
        var ws = workspace([Column(windows: [1], widthIndex: 1), Column(windows: [2, 3], widthIndex: 1, isTabbed: true)], focused: 1)
        ws.perform(.toggleFullWidth)
        XCTAssertEqual(ws.tabBars()[0].frame.minX, 12)
        XCTAssertEqual(ws.tabBars()[0].frame.width, 1188)
    }

    // MARK: Width: split ratios

    func testCyclingWidthStepsTheFocusedTilesSplitThroughThirdHalfTwoThirds() {
        var ws = make(2, focused: 0)
        func width() -> CGFloat { frames(ws)[1]!.width }
        XCTAssertEqual(width(), 588)
        XCTAssertTrue(ws.perform(.cycleColumnWidth))
        XCTAssertEqual(width(), 784) // ⅔
        XCTAssertTrue(ws.perform(.cycleColumnWidth))
        XCTAssertEqual(width(), 392) // ⅓ (wraps)
        XCTAssertTrue(ws.perform(.cycleColumnWidth))
        XCTAssertEqual(width(), 588)
        XCTAssertTrue(ws.perform(.cycleColumnWidthBackward))
        XCTAssertEqual(width(), 392)
        XCTAssertTrue(ws.perform(.cycleColumnWidthBackward))
        XCTAssertEqual(width(), 784)
        XCTAssertEqual(frames(ws)[2]!.maxX - frames(ws)[1]!.minX, 1188)
    }

    func testTheLastTileChangesItsOwnShareThroughTheSplitBeforeIt() {
        var ws = make(2, focused: 1)
        ws.perform(.cycleColumnWidth)
        XCTAssertEqual(frames(ws)[2]?.width, 784, "⅔ for the tile in focus")
        XCTAssertEqual(frames(ws)[1]?.width, 392)
    }

    func testThreeColumnsStartAtAThirdAndCycleFromThere() {
        var ws = make(3, columns: 3, focused: 0)
        XCTAssertEqual(frames(ws)[1]?.width, 388)
        ws.perform(.cycleColumnWidth)
        XCTAssertEqual(frames(ws)[1]?.width, 588, "½ of what is left after the gap")
        XCTAssertEqual(frames(ws)[2]?.width, 288, "The other two share the rest")
    }

    func testCyclingATileInTheMiddleOfTheSpiralChangesItsOwnSplit() {
        var ws = make(4, focused: 1) // Tile 1 over (2 | 3): its own split is the row split
        let before = frames(ws)
        XCTAssertTrue(ws.perform(.cycleColumnWidth))
        let after = frames(ws)
        XCTAssertEqual(before[1]?.width, after[1]?.width)
        XCTAssertGreaterThan(after[2]!.height, before[2]!.height, "⅔ of the height")
        XCTAssertEqual(before[3], frames(make(4))[3])
        XCTAssertEqual(TiledLayout.frames(in: ws.viewport, count: 4, columns: 2, gap: 12, ratios: [0, 2.0 / 3, 0]), placed(ws))
    }

    func testCyclingDoesNothingWithOneTile() {
        var ws = make(1)
        XCTAssertFalse(ws.perform(.cycleColumnWidth))
        XCTAssertNil(ws.tiledRatios)
    }

    func testRatiosStartOverWhenTheWindowCountChanges() {
        var set = WorkspaceSet(viewport: viewport)
        set.active.layoutOverride = .tiled
        set.insert(1, widthIndex: 1, focus: true)
        set.insert(2, widthIndex: 1, focus: true)
        set.active.strip.focus(1)
        set.active.perform(.cycleColumnWidth)
        XCTAssertEqual(frames(set.active)[1]?.width, 784)
        set.insert(3, widthIndex: 1, focus: true)
        XCTAssertEqual(placed(set.active), expected(set.active))
        set.remove(3)
        XCTAssertEqual(frames(set.active)[1]?.width, 784, "Same count again: they are still stored")
    }

    // MARK: Width: resizing with the mouse

    func testResizingAColumnMovesItsSplit() {
        var ws = make(2)
        XCTAssertTrue(ws.setColumnWidthFromResize(1, to: 784))
        XCTAssertEqual(frames(ws)[1]?.width, 784)
        XCTAssertEqual(frames(ws)[2]?.width, 392)
        XCTAssertTrue(ws.setColumnWidthFromResize(2, to: 500), "The second part: the first gets the rest")
        XCTAssertEqual(frames(ws)[2]?.width, 500)
        XCTAssertEqual(frames(ws)[1]?.width, 676)
        XCTAssertFalse(ws.setColumnWidthFromResize(2, to: 500), "Already so")
    }

    func testResizingATileInsideAStackedPairChangesTheSplitThatSizesIt() {
        var ws = make(5) // [0][1 over (2 | (3 over 4))]
        XCTAssertTrue(ws.setColumnWidthFromResize(3, to: 200)) // Tile 2 is the first part of the side-by-side split (2 | …)
        XCTAssertEqual(frames(ws)[3]!.width, 200, accuracy: 2)
        XCTAssertTrue(ws.setColumnWidthFromResize(2, to: 300)) // Tile 1 sits in the second part of the first split
        XCTAssertEqual(frames(ws)[2]!.width, 300, accuracy: 2)
        XCTAssertEqual(frames(ws)[1]?.minX, 12)
    }

    func testResizeIsClampedAndSomethingAloneSnapsBack() {
        var ws = make(2)
        ws.setColumnWidthFromResize(1, to: 5000)
        XCTAssertTrue((100...1100).contains(frames(ws)[1]!.width))
        ws.setColumnWidthFromResize(1, to: 1)
        XCTAssertTrue((100...1100).contains(frames(ws)[1]!.width))
        var alone = make(1)
        XCTAssertFalse(alone.setColumnWidthFromResize(1, to: 300))
        var unknown = make(2)
        XCTAssertFalse(unknown.setColumnWidthFromResize(9, to: 300))
    }

    func testResizeOnTheStripIsTheCustomWidth() {
        var ws = make(2, layout: .scrolling)
        XCTAssertTrue(ws.setColumnWidthFromResize(1, to: 700))
        XCTAssertEqual(ws.width(ofColumn: 0), 700)
        XCTAssertEqual(ws.width(ofColumn: 1), 588)
    }

    // MARK: Columns

    func testCycleTiledColumnsSwitchesBetweenTwoAndThreeAndStartsRatiosOver() {
        var ws = make(4, columns: 2)
        ws.perform(.cycleColumnWidth)
        XCTAssertNotNil(ws.tiledRatios)
        XCTAssertTrue(ws.perform(.cycleTiledColumns))
        XCTAssertEqual(ws.tiledColumns, 3)
        XCTAssertEqual(ws.tiledColumnsOverride, 3)
        XCTAssertNil(ws.tiledRatios)
        XCTAssertEqual(placed(ws), expected(ws))
        XCTAssertEqual(frames(ws)[3], CGRect(x: 812, y: 52, width: 388, height: 382))
        ws.cycleTiledColumns()
        XCTAssertEqual(ws.tiledColumns, 2)
    }

    func testCycleTiledColumnsStillSetsTheCountWhileScrolling() {
        var ws = make(3, layout: nil)
        let before = ws.strip
        XCTAssertTrue(ws.perform(.cycleTiledColumns))
        XCTAssertEqual(ws.tiledColumns, 3)
        XCTAssertEqual(ws.layout, .scrolling)
        XCTAssertEqual(ws.strip, before)
        ws.toggleLayout()
        XCTAssertEqual(frames(ws)[3], CGRect(x: 812, y: 52, width: 388, height: 776))
    }

    // MARK: Switching layouts

    func testToggleSetsTheOverrideAndFlips() {
        var ws = make(3, layout: nil)
        XCTAssertNil(ws.layoutOverride)
        XCTAssertTrue(ws.perform(.toggleLayout))
        XCTAssertEqual(ws.layoutOverride, .tiled)
        ws.toggleLayout()
        XCTAssertEqual(ws.layoutOverride, .scrolling)
    }

    func testGoingTiledMakesOneColumnPerWindowButKeepsTabsAndFocus() {
        var ws = workspace([
            Column(windows: [1], widthIndex: 0),
            Column(windows: [2, 3, 4], focusedRow: 1, widthIndex: 2, customWidth: 700),
            Column(windows: [5, 6], widthIndex: 1, isTabbed: true),
            Column(windows: [7], widthIndex: 1),
        ], focused: 1, layout: nil)
        ws.toggleLayout()
        XCTAssertEqual(layout(ws.strip), [[1], [2], [3], [4], [5, 6], [7]])
        XCTAssertEqual(ws.strip.focusedWindow, 3)
        XCTAssertTrue(ws.strip.columns[4].isTabbed)
        XCTAssertFalse(ws.strip.columns[2].isTabbed)
        // Each exploded column keeps the stack's width choice.
        for index in 1...3 { XCTAssertEqual(ws.strip.columns[index].widthIndex, 2) }
        XCTAssertEqual(ws.strip.columns[0].widthIndex, 0)
        XCTAssertEqual(ws.placements().filter { $0.visibility == .visible }.count, 6, "7 windows, one of them a hidden tab")
        XCTAssertEqual(ws.placements().filter { $0.visibility == .hiddenTab }.count, 1)
        XCTAssertEqual(ws.scrollOffset, 0)
    }

    func testGoingBackToScrollingGivesEveryColumnTheDefaultWidth() {
        var ws = workspace([
            Column(windows: [1], widthIndex: 3),
            Column(windows: [2], widthIndex: 1, isFullWidth: true),
            Column(windows: [3], widthIndex: 1, customWidth: 300),
            Column(windows: [4], widthIndex: 0),
        ], focused: 3)
        ws.toggleLayout()
        XCTAssertEqual(ws.layout, .scrolling)
        for column in ws.strip.columns {
            XCTAssertEqual(column.widthIndex, 1)
            XCTAssertFalse(column.isFullWidth)
            XCTAssertNil(column.customWidth)
        }
        XCTAssertEqual(ws.strip.focusedWindow, 4)
        XCTAssertEqual(layout(ws.strip), [[1], [2], [3], [4]])
        XCTAssertGreaterThan(ws.scrollOffset, 0, "Four half-width columns don't fit, so the focused one is scrolled into view")
        XCTAssertEqual(visibility(ws)[4], .visible)
    }

    func testAZoomIsForgottenWhenReturningToScrolling() {
        var ws = make(2)
        ws.perform(.toggleFullWidth)
        ws.toggleLayout()
        ws.toggleLayout()
        XCTAssertNil(ws.zoomedWindow)
    }

    func testThereAndBackKeepsTheOrderAndTheFocus() {
        var ws = workspace([
            Column(windows: [1], widthIndex: 1), Column(windows: [2, 3], widthIndex: 1),
            Column(windows: [4, 5], widthIndex: 1, isTabbed: true), Column(windows: [6], widthIndex: 1),
        ], focused: 2, layout: nil)
        let order = ws.strip.windows
        let focus = ws.strip.focusedWindow
        ws.toggleLayout()
        XCTAssertEqual(ws.strip.windows, order)
        XCTAssertEqual(ws.strip.focusedWindow, focus)
        ws.toggleLayout()
        XCTAssertEqual(ws.strip.windows, order)
        XCTAssertEqual(ws.strip.focusedWindow, focus)
        XCTAssertEqual(layout(ws.strip), [[1], [2], [3], [4, 5], [6]])
    }

    func testScrollingPlacementsAreUnchanged() {
        let ws = make(3, layout: nil)
        XCTAssertEqual(ws.layout, .scrolling)
        XCTAssertEqual(ws.width(ofColumn: 0), 588)
        XCTAssertEqual(frames(ws)[2]?.width, 588)
        XCTAssertEqual(frames(ws)[2]?.minX, 612)
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

    // MARK: Dropping windows

    func testADropOnATiledWorkspaceHighlightsTheTileItWouldTake() {
        let ws = make(3)
        let tiles = expected(ws)
        XCTAssertEqual(ws.insertionFrame(at: 0, thickness: 4), tiles[0])
        XCTAssertEqual(ws.insertionFrame(at: 2, thickness: 4), tiles[2])
        XCTAssertEqual(ws.insertionFrame(at: 3, thickness: 4), tiles[2], "Past the end: the last tile")
    }

    func testTheDropIndexGoesByTilePositions() {
        let ws = make(3)
        XCTAssertEqual(ws.dropIndex(atX: 50), 0)
        XCTAssertEqual(ws.dropIndex(atX: 400), 1)
        XCTAssertEqual(ws.dropIndex(atX: 1150), 3)
    }

    func testTheColumnFrameOfATiledWindowIsItsTile() {
        let ws = make(3)
        XCTAssertEqual(ws.columnFrame(containing: 2), expected(ws)[1])
    }

    // MARK: Persistence

    func testSnapshotKeepsLayoutColumnsAndRatios() throws {
        var set = WorkspaceSet(viewport: viewport)
        set.active.strip.insert(1, widthIndex: 1, at: 0)
        set.active.strip.insert(2, widthIndex: 1, at: 1)
        set.edit(0) {
            $0.toggleLayout()
            $0.cycleTiledColumns()
            $0.perform(.cycleColumnWidth)
        }
        set.edit(2) { $0.layoutOverride = .scrolling }
        set.edit(3) { $0.tiledColumnsOverride = 2 }
        let snapshot = StripSnapshot(workspaces: set, userFloating: [], userTiled: [], bootTime: Date(timeIntervalSince1970: 0))
        let data = try JSONEncoder().encode(snapshot)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\"tiledColumns\""))
        let decoded = try JSONDecoder().decode(StripSnapshot.self, from: data)
        XCTAssertEqual(decoded, snapshot)

        let restored = decoded.restoreWorkspaces(windows: [1, 2], widthIndex: 1, presetCount: 4)
        XCTAssertEqual(Array(restored.layouts.prefix(3)), [.tiled, nil, .scrolling])
        XCTAssertEqual(restored.tiledColumns, [3, nil, nil, 2, nil, nil, nil, nil, nil])
        XCTAssertNotNil(restored.tiledRatios[0])
        XCTAssertNil(restored.tiledRatios[1])

        var rebuilt = WorkspaceSet(viewport: viewport)
        rebuilt.restore(strips: restored.strips, activeIndex: restored.active, layouts: restored.layouts,
                        tiledColumns: restored.tiledColumns, tiledRatios: restored.tiledRatios)
        XCTAssertEqual(rebuilt.workspaces[0].layoutOverride, .tiled)
        XCTAssertEqual(rebuilt.workspaces[0].tiledColumnsOverride, 3)
        XCTAssertEqual(rebuilt.workspaces[0].tiledRatios, set.workspaces[0].tiledRatios)
        XCTAssertEqual(frames(rebuilt.workspaces[0]), frames(set.workspaces[0]))
        XCTAssertNil(rebuilt.workspaces[1].layoutOverride)
        XCTAssertNil(rebuilt.workspaces[1].tiledColumnsOverride)
        XCTAssertNil(rebuilt.workspaces[1].tiledRatios)
        XCTAssertEqual(rebuilt.workspaces[2].layoutOverride, .scrolling)
        XCTAssertEqual(rebuilt.workspaces[3].tiledColumnsOverride, 2)
    }

    func testEachDisplayKeepsItsOwnLayouts() throws {
        var main = WorkspaceSet(viewport: viewport)
        main.active.strip.insert(1, widthIndex: 1, at: 0)
        main.edit(0) { $0.toggleLayout(); $0.cycleTiledColumns() }
        var side = WorkspaceSet(viewport: viewport)
        side.active.strip.insert(2, widthIndex: 1, at: 0)
        let snapshot = StripSnapshot(displays: [("main", main), ("side", side)], userFloating: [], userTiled: [], bootTime: Date(timeIntervalSince1970: 0))
        let decoded = try JSONDecoder().decode(StripSnapshot.self, from: JSONEncoder().encode(snapshot))
        let restored = decoded.restoreDisplays(windows: [(1, "main"), (2, "side")], displays: ["main", "side"], widthIndex: 1, presetCount: 4)
        XCTAssertEqual(restored["main"]!.layouts[0], .tiled)
        XCTAssertEqual(restored["main"]!.tiledColumns[0], 3)
        XCTAssertNil(restored["side"]!.layouts[0])
        XCTAssertNil(restored["side"]!.tiledColumns[0])
    }

    func testSnapshotsWithoutTheNewFieldsStillLoad() throws {
        let tiled = """
        {"columns":[{"windows":[1],"focusedRow":0,"widthIndex":1,"isFullWidth":false}],\
        "workspaces":[{"columns":[{"windows":[1],"focusedRow":0,"widthIndex":1,"isFullWidth":false}],"layout":"tiled"}],\
        "userFloating":[],"userTiled":[],"bootTime":0}
        """
        let decoded = try JSONDecoder().decode(StripSnapshot.self, from: Data(tiled.utf8))
        let restored = decoded.restoreWorkspaces(windows: [1], widthIndex: 1, presetCount: 4)
        XCTAssertEqual(restored.layouts, [.tiled])
        XCTAssertEqual(restored.tiledColumns, [nil])
        XCTAssertNil(restored.tiledRatios[0])
        let older = """
        {"columns":[{"windows":[1],"focusedRow":0,"widthIndex":1,"isFullWidth":false}],\
        "workspaces":[{"columns":[{"windows":[1],"focusedRow":0,"widthIndex":1,"isFullWidth":false}]}],\
        "userFloating":[],"userTiled":[],"bootTime":0}
        """
        let oldRestored = try JSONDecoder().decode(StripSnapshot.self, from: Data(older.utf8)).restoreWorkspaces(windows: [1], widthIndex: 1, presetCount: 4)
        XCTAssertEqual(oldRestored.layouts, [nil])
    }

    // MARK: The shortcuts

    func testToggleLayoutIsAWorkspaceLevelActionWithItsOwnShortcut() {
        XCTAssertNil(Action.toggleLayout.workspaceCommand)
        XCTAssertEqual(Action.toggleLayout.group, .workspaces)
        XCTAssertEqual(Keymap.defaults[.toggleLayout], KeyCombo(KeyCode.t, [.control, .option]))
        XCTAssertEqual(Keymap.defaults.filter { $0.value == KeyCombo(KeyCode.t, [.control, .option]) }.map(\.key), [.toggleLayout])
        XCTAssertEqual(Action(rawValue: "toggleLayout"), .toggleLayout)
        XCTAssertEqual(Action(rawValue: "toggleTiling"), .toggleTiling)
        XCTAssertEqual(Keymap.defaults[.toggleTiling], KeyCombo(KeyCode.t, [.control, .option, .shift]))
    }

    func testCycleTiledColumnsIsLastInTheEnumHasATitleAndAFreeSafeShortcut() {
        XCTAssertEqual(Action.allCases.last, .cycleTiledColumns)
        XCTAssertEqual(Action(rawValue: "cycleTiledColumns"), .cycleTiledColumns)
        XCTAssertEqual(Action.cycleTiledColumns.group, .workspaces)
        XCTAssertNil(Action.cycleTiledColumns.workspaceCommand)
        let combo = KeyCombo(KeyCode.g, [.control, .option])
        XCTAssertEqual(Keymap.defaults[.cycleTiledColumns], combo)
        XCTAssertEqual(combo.description, "⌃⌥G")
        XCTAssertEqual(Keymap.defaults.filter { $0.value == combo }.map(\.key), [.cycleTiledColumns])
        XCTAssertEqual(ShortcutPolicy.evaluate(combo), .ok)
        XCTAssertEqual(Keymap().action(for: combo), .cycleTiledColumns)
    }

    func testWindowMovesKeepTheirActionNamesAndTakeTheWindowWording() {
        XCTAssertEqual(Action(rawValue: "moveColumnToWorkspace3"), .moveColumnToWorkspace3)
        XCTAssertEqual(Action(rawValue: "moveColumnToNextWorkspace"), .moveColumnToNextWorkspace)
        XCTAssertEqual(Action.moveColumnToWorkspace3.workspaceCommand?.movesWindow, true)
        XCTAssertEqual(Action.moveColumnToDisplayLeft.displayCommand?.movesColumn, true)
    }
}

/// The strip operations the tiled conversions use.
final class StripConversionTests: XCTestCase {
    private func layout(_ strip: Strip) -> [[WindowID]] { strip.columns.map(\.windows) }

    func testExplodeStacksSplitsStacksOnlyAndKeepsFocusOnTheSameWindow() {
        var strip = Strip(columns: [Column(windows: [1, 2], focusedRow: 1, widthIndex: 2), Column(windows: [3, 4], widthIndex: 1, isTabbed: true),
                                    Column(windows: [5], widthIndex: 1)], focusedColumnIndex: 0)
        XCTAssertTrue(strip.explodeStacks())
        XCTAssertEqual(layout(strip), [[1], [2], [3, 4], [5]])
        XCTAssertEqual(strip.focusedWindow, 2)
        XCTAssertEqual(strip.focusedColumnIndex, 1)
        XCTAssertEqual(strip.columns[1].widthIndex, 2)
        XCTAssertFalse(strip.explodeStacks())
    }

    func testSwapColumnsMovesFocusWithTheFocusedOne() {
        var strip = Strip(columns: (1...3).map { Column(windows: [WindowID($0)], widthIndex: 1) }, focusedColumnIndex: 0)
        XCTAssertTrue(strip.swapColumns(0, 2))
        XCTAssertEqual(layout(strip), [[3], [2], [1]])
        XCTAssertEqual(strip.focusedWindow, 1)
        XCTAssertFalse(strip.swapColumns(1, 1))
        XCTAssertFalse(strip.swapColumns(0, 5))
        strip.swapColumns(0, 1) // Neither is focused (1 is at index 2)
        XCTAssertEqual(strip.focusedWindow, 1)
    }

    func testFocusColumnAtKeepsTheRow() {
        var strip = Strip(columns: [Column(windows: [1], widthIndex: 1), Column(windows: [2, 3], focusedRow: 1, widthIndex: 1)])
        XCTAssertTrue(strip.focusColumn(at: 1))
        XCTAssertEqual(strip.focusedWindow, 3)
        XCTAssertFalse(strip.focusColumn(at: 1))
        XCTAssertFalse(strip.focusColumn(at: 5))
    }

    func testRemoveFocusedWindowTakesOnlyThatWindow() {
        var strip = Strip(columns: [Column(windows: [1], widthIndex: 3), Column(windows: [2, 3], widthIndex: 2)], focusedColumnIndex: 1)
        let taken = strip.removeFocusedWindow(widthIndex: 1)!
        XCTAssertEqual(taken.windows, [2])
        XCTAssertEqual(taken.widthIndex, 1)
        XCTAssertEqual(layout(strip), [[1], [3]])
        XCTAssertEqual(strip.columns[1].widthIndex, 2)
        strip.focus(1)
        let alone = strip.removeFocusedWindow(widthIndex: 1)!
        XCTAssertEqual(alone.widthIndex, 3, "Alone in its column: the column goes along")
        XCTAssertEqual(layout(strip), [[3]])
        var empty = Strip()
        XCTAssertNil(empty.removeFocusedWindow(widthIndex: 1))
    }

    func testResetWidthsDropsCustomAndFullWidths() {
        var strip = Strip(columns: [Column(windows: [1], widthIndex: 3, isFullWidth: true), Column(windows: [2], widthIndex: 1, customWidth: 400)])
        strip.resetWidths(to: 1)
        XCTAssertEqual(strip.columns, [Column(windows: [1], widthIndex: 1), Column(windows: [2], widthIndex: 1)])
    }
}
