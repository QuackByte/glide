import XCTest
@testable import GlideCore

final class StripTests: XCTestCase {
    private func strip(_ columns: [[WindowID]], focused: Int = 0) -> Strip {
        Strip(columns: columns.map { Column(windows: $0, widthIndex: 1) }, focusedColumnIndex: focused)
    }

    private func layout(_ strip: Strip) -> [[WindowID]] { strip.columns.map(\.windows) }

    func testInsertGoesRightOfFocusedColumnAndTakesFocus() {
        var s = Strip()
        s.insert(1, widthIndex: 1)
        s.insert(2, widthIndex: 1)
        s.focus(1)
        s.insert(3, widthIndex: 1)
        XCTAssertEqual(layout(s), [[1], [3], [2]])
        XCTAssertEqual(s.focusedWindow, 3)
    }

    func testInsertWithoutFocusKeepsFocusedWindow() {
        var s = strip([[1], [2]], focused: 1)
        s.insert(3, widthIndex: 1, at: 0, focus: false)
        XCTAssertEqual(layout(s), [[3], [1], [2]])
        XCTAssertEqual(s.focusedWindow, 2)
    }

    func testInsertIgnoresDuplicates() {
        var s = strip([[1]])
        s.insert(1, widthIndex: 1)
        XCTAssertEqual(layout(s), [[1]])
    }

    func testRemovingFocusedColumnFocusesLeftNeighbour() {
        var s = strip([[1], [2], [3]], focused: 1)
        XCTAssertTrue(s.remove(2))
        XCTAssertEqual(s.focusedWindow, 1)
    }

    func testRemovingFirstFocusedColumnFocusesNewFirst() {
        var s = strip([[1], [2]], focused: 0)
        s.remove(1)
        XCTAssertEqual(s.focusedWindow, 2)
    }

    func testRemovingColumnLeftOfFocusKeepsFocusedWindow() {
        var s = strip([[1], [2], [3]], focused: 2)
        s.remove(1)
        XCTAssertEqual(s.focusedWindow, 3)
    }

    func testRemovingLastWindowEmptiesStrip() {
        var s = strip([[1]])
        s.remove(1)
        XCTAssertTrue(s.isEmpty)
        XCTAssertNil(s.focusedWindow)
        XCTAssertFalse(s.remove(1))
    }

    func testRemovingWindowFromStackKeepsColumn() {
        var s = Strip(columns: [Column(windows: [1, 2, 3], focusedRow: 2, widthIndex: 1)])
        s.remove(3)
        XCTAssertEqual(layout(s), [[1, 2]])
        XCTAssertEqual(s.focusedWindow, 2)
        s.remove(1)
        XCTAssertEqual(s.focusedWindow, 2)
    }

    func testFocusColumnStopsAtEnds() {
        var s = strip([[1], [2]])
        XCTAssertFalse(s.focusColumn(.left))
        XCTAssertTrue(s.focusColumn(.right))
        XCTAssertEqual(s.focusedWindow, 2)
        XCTAssertFalse(s.focusColumn(.right))
    }

    func testFocusFirstAndLast() {
        var s = strip([[1], [2], [3]], focused: 1)
        XCTAssertTrue(s.focusLastColumn())
        XCTAssertEqual(s.focusedWindow, 3)
        XCTAssertFalse(s.focusLastColumn())
        XCTAssertTrue(s.focusFirstColumn())
        XCTAssertEqual(s.focusedWindow, 1)
    }

    func testFocusWindowWithinColumn() {
        var s = strip([[1, 2]])
        XCTAssertFalse(s.focusWindow(.up))
        XCTAssertTrue(s.focusWindow(.down))
        XCTAssertEqual(s.focusedWindow, 2)
        XCTAssertFalse(s.focusWindow(.down))
    }

    func testFocusByWindow() {
        var s = strip([[1], [2, 3]])
        XCTAssertTrue(s.focus(3))
        XCTAssertEqual(s.focusedColumnIndex, 1)
        XCTAssertEqual(s.focusedWindow, 3)
        XCTAssertFalse(s.focus(3))
        XCTAssertFalse(s.focus(99))
    }

    func testMoveColumnSwapsAndKeepsFocus() {
        var s = strip([[1], [2], [3]], focused: 0)
        XCTAssertFalse(s.moveColumn(.left))
        XCTAssertTrue(s.moveColumn(.right))
        XCTAssertEqual(layout(s), [[2], [1], [3]])
        XCTAssertEqual(s.focusedColumnIndex, 1)
        XCTAssertEqual(s.focusedWindow, 1)
    }

    func testMoveWindowWithinColumn() {
        var s = strip([[1, 2, 3]])
        XCTAssertTrue(s.moveWindow(.down))
        XCTAssertEqual(layout(s), [[2, 1, 3]])
        XCTAssertEqual(s.focusedWindow, 1)
        XCTAssertTrue(s.moveWindow(.up))
        XCTAssertFalse(s.moveWindow(.up))
    }

    func testConsumeIntoLeftColumn() {
        var s = strip([[1], [2], [3]], focused: 1)
        XCTAssertTrue(s.consumeOrExpel(.left))
        XCTAssertEqual(layout(s), [[1, 2], [3]])
        XCTAssertEqual(s.focusedColumnIndex, 0)
        XCTAssertEqual(s.focusedWindow, 2)
    }

    func testConsumeIntoRightColumn() {
        var s = strip([[1], [2], [3]], focused: 1)
        XCTAssertTrue(s.consumeOrExpel(.right))
        XCTAssertEqual(layout(s), [[1], [3, 2]])
        XCTAssertEqual(s.focusedColumnIndex, 1)
        XCTAssertEqual(s.focusedWindow, 2)
    }

    func testConsumeAtEdgeDoesNothing() {
        var s = strip([[1], [2]], focused: 0)
        XCTAssertFalse(s.consumeOrExpel(.left))
        XCTAssertEqual(layout(s), [[1], [2]])
    }

    func testExpelLeftAndRight() {
        var s = Strip(columns: [Column(windows: [1], widthIndex: 1), Column(windows: [2, 3], focusedRow: 1, widthIndex: 2)], focusedColumnIndex: 1)
        XCTAssertTrue(s.consumeOrExpel(.left))
        XCTAssertEqual(layout(s), [[1], [3], [2]])
        XCTAssertEqual(s.focusedWindow, 3)
        XCTAssertEqual(s.columns[1].widthIndex, 2, "Expelled column keeps the source width")

        var t = Strip(columns: [Column(windows: [2, 3], widthIndex: 1)])
        XCTAssertTrue(t.consumeOrExpel(.right))
        XCTAssertEqual(layout(t), [[3], [2]])
        XCTAssertEqual(t.focusedWindow, 2)
    }

    func testCycleWidthWrapsBothWays() {
        var s = strip([[1]])
        s.cycleWidth(presetCount: 4)
        XCTAssertEqual(s.columns[0].widthIndex, 2)
        s.cycleWidth(presetCount: 4)
        s.cycleWidth(presetCount: 4)
        XCTAssertEqual(s.columns[0].widthIndex, 0)
        s.cycleWidth(presetCount: 4, forward: false)
        XCTAssertEqual(s.columns[0].widthIndex, 3)
    }

    func testCycleWidthLeavesFullWidthAtStoredPreset() {
        var s = strip([[1]])
        s.toggleFullWidth()
        XCTAssertTrue(s.columns[0].isFullWidth)
        s.cycleWidth(presetCount: 4)
        XCTAssertFalse(s.columns[0].isFullWidth)
        XCTAssertEqual(s.columns[0].widthIndex, 1)
    }

    func testEmptyStripActionsAreNoOps() {
        var s = Strip()
        XCTAssertFalse(s.focusColumn(.right))
        XCTAssertFalse(s.focusWindow(.down))
        XCTAssertFalse(s.moveColumn(.left))
        XCTAssertFalse(s.moveWindow(.up))
        XCTAssertFalse(s.consumeOrExpel(.left))
        XCTAssertFalse(s.cycleWidth(presetCount: 4))
        XCTAssertFalse(s.toggleFullWidth())
        XCTAssertFalse(s.focusFirstColumn())
    }
}
