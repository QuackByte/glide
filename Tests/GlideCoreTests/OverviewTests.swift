import XCTest
@testable import GlideCore

final class OverviewTests: XCTestCase {
    private let viewport = CGRect(x: 0, y: 40, width: 1212, height: 800)

    /// Workspace 1: [1] [2 3 stacked] [4]; workspace 3: [10] [11 12 tabbed]; workspace 1 active,
    /// focus on 2.
    private func spaces() -> WorkspaceSet {
        var set = WorkspaceSet(viewport: viewport)
        set.active.strip = Strip(columns: [
            Column(windows: [1], widthIndex: 1),
            Column(windows: [2, 3], widthIndex: 1),
            Column(windows: [4], widthIndex: 1),
        ], focusedColumnIndex: 1)
        set.activate(2)
        set.active.strip = Strip(columns: [
            Column(windows: [10], widthIndex: 3),
            Column(windows: [11, 12], focusedRow: 1, widthIndex: 1, isTabbed: true),
        ])
        set.activate(0)
        return set
    }

    func testRowsCoverOccupiedWorkspacesAndSelectionStartsOnFocus() {
        let overview = Overview(spaces: spaces())
        XCTAssertEqual(overview.rows.map(\.workspace), [0, 2])
        XCTAssertEqual(overview.rows[0].widths, [588, 588, 588])
        XCTAssertEqual(overview.rows[0].offsets, [0, 600, 1200])
        XCTAssertEqual(overview.selection, 2)
    }

    func testAnEmptyActiveWorkspaceStillGetsARow() {
        var set = spaces()
        set.activate(5)
        let overview = Overview(spaces: set)
        XCTAssertEqual(overview.rows.map(\.workspace), [0, 2, 5])
        XCTAssertEqual(overview.selection, 1, "Nothing to focus on 6, so the first window")
    }

    func testLeftAndRightStepThroughColumns() {
        var overview = Overview(spaces: spaces())
        XCTAssertTrue(overview.move(.right))
        XCTAssertEqual(overview.selection, 4)
        XCTAssertFalse(overview.move(.right))
        overview.move(.left)
        overview.move(.left)
        XCTAssertEqual(overview.selection, 1)
    }

    func testDownGoesThroughTheStackThenToTheNextWorkspace() {
        var overview = Overview(spaces: spaces())
        overview.move(.down)
        XCTAssertEqual(overview.selection, 3, "Within the stack")
        overview.move(.down)
        // Column 2's center is at 894; workspace 3's columns are centered at 594 (full) and 1494.
        XCTAssertEqual(overview.selection, 10)
        XCTAssertFalse(overview.move(.down))
        overview.move(.right)
        XCTAssertEqual(overview.selection, 12, "A tabbed column selects its active tab")
        XCTAssertEqual(overview.shownWindow(row: 1, column: 1), 12)
        overview.move(.up)
        XCTAssertEqual(overview.selection, 11, "Up steps through tabs")
        XCTAssertEqual(overview.shownWindow(row: 1, column: 1), 11, "The selected tab is the one shown")
        overview.move(.up)
        XCTAssertEqual(overview.selection, 4, "Nearest column on the row above")
    }

    func testMovingSkipsEmptyRows() {
        var set = spaces()
        set.activate(1)
        var overview = Overview(spaces: set)
        XCTAssertEqual(overview.rows.map(\.workspace), [0, 1, 2])
        overview.select(4)
        overview.move(.down)
        XCTAssertEqual(overview.selection, 12, "Skips empty workspace 2; the tabbed column is nearest")
    }

    func testSelectOnlyKnownWindows() {
        var overview = Overview(spaces: spaces())
        XCTAssertTrue(overview.select(12))
        XCTAssertFalse(overview.select(99))
        XCTAssertEqual(overview.selection, 12)
        XCTAssertEqual(overview.location(of: 12)?.row, 1)
    }
}
