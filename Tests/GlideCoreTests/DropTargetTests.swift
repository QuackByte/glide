import XCTest
@testable import GlideCore

final class DropTargetTests: XCTestCase {
    /// Two half-width columns; the second is tabbed with windows 2 and 3, so its tab bar is at the top.
    private func workspace() -> Workspace {
        let strip = Strip(columns: [
            Column(windows: [1], widthIndex: 1),
            Column(windows: [2, 3], widthIndex: 1, isTabbed: true),
        ])
        return Workspace(strip: strip, viewport: CGRect(x: 0, y: 0, width: 1000, height: 800))
    }

    func testDroppingOnAWindowTargetsIt() {
        let ws = workspace()
        XCTAssertEqual(ws.dropTarget(at: CGPoint(x: 100, y: 400), dragging: 9), 1)
    }

    func testDroppingOnATabBarTargetsItsActiveTab() {
        let ws = workspace()
        XCTAssertEqual(ws.dropTarget(at: CGPoint(x: 700, y: 20), dragging: 9), 2)
    }

    func testTheDraggedWindowIsNeverItsOwnTarget() {
        let ws = workspace()
        XCTAssertNil(ws.dropTarget(at: CGPoint(x: 100, y: 400), dragging: 1))
    }

    func testDroppingOnEmptySpaceHasNoTarget() {
        let ws = workspace()
        XCTAssertNil(ws.dropTarget(at: CGPoint(x: 500, y: 400), dragging: 9), "The gap between columns")
    }

    func testHighlightCoversTheTargetColumn() {
        let ws = workspace()
        // The first column: its one window, inside the gaps.
        XCTAssertEqual(ws.columnFrame(containing: 1), CGRect(x: 12, y: 12, width: 482, height: 776))
        // The tabbed column: its tab bar and the active tab under it.
        XCTAssertEqual(ws.columnFrame(containing: 2), CGRect(x: 506, y: 12, width: 482, height: 776))
        XCTAssertNil(ws.columnFrame(containing: 9))
    }

    func testInsertionBarSitsInTheGap() {
        let ws = workspace()
        // Between the two columns: the gap runs from 494 to 506.
        XCTAssertEqual(ws.insertionFrame(at: 1).midX, 500)
        // Before the first column and after the last, kept on screen.
        XCTAssertEqual(ws.insertionFrame(at: 0).midX, 6)
        XCTAssertEqual(ws.insertionFrame(at: 2).midX, 994)
    }
}

