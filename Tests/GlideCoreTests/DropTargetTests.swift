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
}
