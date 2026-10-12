import XCTest
@testable import GlideCore

final class WorkspaceTests: XCTestCase {
    /// 1212 wide so preset maths gives whole numbers with a 12 pt gap: (1212 - 12) × ½ - 12 = 588.
    private let viewport = CGRect(x: 0, y: 40, width: 1212, height: 800)

    private func workspace(_ columns: [[WindowID]], widths: [Int]? = nil, focused: Int = 0) -> Workspace {
        let cols = columns.enumerated().map { index, windows in
            Column(windows: windows, widthIndex: widths?[index] ?? 1)
        }
        return Workspace(strip: Strip(columns: cols, focusedColumnIndex: focused), viewport: viewport)
    }

    private func frames(_ ws: Workspace) -> [WindowID: CGRect] {
        Dictionary(uniqueKeysWithValues: ws.placements().map { ($0.window, $0.frame) })
    }

    private func visibility(_ ws: Workspace) -> [WindowID: Visibility] {
        Dictionary(uniqueKeysWithValues: ws.placements().map { ($0.window, $0.visibility) })
    }

    func testPresetWidths() {
        let ws = workspace([[1], [2], [3], [4]], widths: [0, 1, 2, 3])
        XCTAssertEqual(ws.width(ofColumn: 0), 388)
        XCTAssertEqual(ws.width(ofColumn: 1), 588)
        XCTAssertEqual(ws.width(ofColumn: 2), 788)
        XCTAssertEqual(ws.width(ofColumn: 3), 1188)
    }

    func testTwoHalvesFillViewportWithGaps() {
        let f = frames(workspace([[1], [2]]))
        XCTAssertEqual(f[1], CGRect(x: 12, y: 52, width: 588, height: 776))
        XCTAssertEqual(f[2], CGRect(x: 612, y: 52, width: 588, height: 776))
        XCTAssertEqual(f[2]!.maxX + 12, viewport.maxX)
    }

    func testThreeThirdsFillViewport() {
        let ws = workspace([[1], [2], [3]], widths: [0, 0, 0])
        XCTAssertEqual(ws.contentWidth, ws.usableWidth)
        XCTAssertTrue(visibility(ws).values.allSatisfy { $0 == .visible })
    }

    func testFullWidthOverridesPreset() {
        var ws = workspace([[1]], widths: [0])
        ws.strip.toggleFullWidth()
        XCTAssertEqual(ws.width(ofColumn: 0), 1188)
    }

    func testStackedWindowsSplitHeight() {
        let f = frames(workspace([[1, 2]]))
        XCTAssertEqual(f[1], CGRect(x: 12, y: 52, width: 588, height: 382))
        XCTAssertEqual(f[2], CGRect(x: 12, y: 446, width: 588, height: 382))
    }

    func testMinimumWidthWidensColumnButNotPastViewport() {
        var ws = workspace([[1, 2]], widths: [0])
        ws.minimumWidths[2] = 500
        XCTAssertEqual(ws.width(ofColumn: 0), 500)
        ws.minimumWidths[2] = 5000
        XCTAssertEqual(ws.width(ofColumn: 0), 1188)
    }

    func testFocusRightScrollsMinimallyToRevealColumn() {
        var ws = workspace([[1], [2], [3]])
        XCTAssertTrue(ws.perform(.focusColumnRight))
        XCTAssertEqual(ws.scrollOffset, 0, "Second half column already fits")
        XCTAssertTrue(ws.perform(.focusColumnRight))
        XCTAssertEqual(ws.scrollOffset, 600, "Third column's right edge aligns with the usable area")
        let f = frames(ws)
        XCTAssertEqual(f[3]?.maxX, viewport.maxX - 12)
        XCTAssertEqual(visibility(ws)[3], .visible)
        XCTAssertEqual(visibility(ws)[2], .visible)
        XCTAssertEqual(visibility(ws)[1], .parkedLeft)
    }

    func testFocusLeftScrollsBack() {
        var ws = workspace([[1], [2], [3]], focused: 0)
        ws.perform(.focusLastColumn)
        ws.perform(.focusFirstColumn)
        XCTAssertEqual(ws.scrollOffset, 0)
        XCTAssertEqual(visibility(ws)[3], .parkedRight)
    }

    func testParkedColumnsLeaveSliverAtEdges() {
        var ws = workspace([[1], [2], [3], [4], [5]])
        ws.perform(.focusLastColumn)
        ws.perform(.focusColumnLeft)
        ws.perform(.focusColumnLeft)
        let f = frames(ws)
        let v = visibility(ws)
        XCTAssertEqual(v[1], .parkedLeft)
        XCTAssertEqual(f[1]?.maxX, viewport.minX + ws.settings.sliver)
        XCTAssertEqual(v[3], .visible)
        XCTAssertEqual(v[4], .visible)
        XCTAssertEqual(v[5], .parkedRight)
        XCTAssertEqual(f[5]?.minX, viewport.maxX - ws.settings.sliver)
    }

    func testPartiallyVisibleColumnKeepsRealPosition() {
        var ws = workspace([[1], [2], [3]], widths: [2, 2, 2])
        ws.perform(.focusColumnRight)
        // ⅔ columns: 788 wide. Focusing the second scrolls so it ends at the right edge.
        XCTAssertEqual(ws.scrollOffset, 800 + 788 - 1188)
        let v = visibility(ws)
        XCTAssertEqual(v[1], .partial)
        XCTAssertEqual(frames(ws)[1]?.minX, 12 + 0 - 400)
    }

    func testCenterColumn() {
        var ws = workspace([[1], [2], [3]], widths: [0, 0, 0], focused: 0)
        XCTAssertTrue(ws.perform(.centerColumn))
        let f = frames(ws)
        XCTAssertEqual(f[1]!.midX, viewport.midX, accuracy: 1)
        XCTAssertFalse(ws.perform(.centerColumn), "Already centered")
    }

    func testFocusedColumnAlwaysFullyVisibleAfterEveryAction() {
        var ws = workspace([[1], [2, 3], [4], [5], [6]], widths: [0, 1, 2, 3, 1])
        let actions: [Action] = [
            .focusColumnRight, .cycleColumnWidth, .focusColumnRight, .toggleFullWidth, .focusColumnRight,
            .moveColumnLeft, .focusLastColumn, .consumeOrExpelLeft, .focusWindowUp, .consumeOrExpelRight,
            .focusFirstColumn, .moveColumnRight, .moveColumnRight, .cycleColumnWidthBackward, .focusColumnLeft,
        ]
        for action in actions {
            ws.perform(action)
            let focused = ws.strip.focusedWindow!
            let placement = ws.placements().first { $0.window == focused }!
            XCTAssertEqual(placement.visibility, .visible, "after \(action)")
            XCTAssertGreaterThanOrEqual(placement.frame.minX, viewport.minX, "after \(action)")
            XCTAssertLessThanOrEqual(placement.frame.maxX, viewport.maxX, "after \(action)")
        }
    }

    func testSettleScrollRemovesTrailingSpaceAfterRemoval() {
        var ws = workspace([[1], [2], [3]])
        ws.perform(.focusLastColumn)
        XCTAssertEqual(ws.scrollOffset, 600)
        ws.strip.remove(3)
        ws.settleScroll()
        XCTAssertEqual(ws.scrollOffset, 0)
        XCTAssertTrue(visibility(ws).values.allSatisfy { $0 == .visible })
    }

    func testViewportOriginIsRespected() {
        var ws = workspace([[1]])
        ws.viewport = CGRect(x: 1512, y: 25, width: 1212, height: 800)
        XCTAssertEqual(frames(ws)[1], CGRect(x: 1524, y: 37, width: 588, height: 776))
    }

    func testNonLayoutActionsReportNoChange() {
        var ws = workspace([[1]])
        XCTAssertFalse(ws.perform(.toggleFloating))
        XCTAssertFalse(ws.perform(.toggleTiling))
    }

    func testEmptyWorkspace() {
        var ws = workspace([])
        XCTAssertEqual(ws.contentWidth, 0)
        XCTAssertTrue(ws.placements().isEmpty)
        XCTAssertFalse(ws.perform(.focusColumnRight))
        ws.settleScroll()
        XCTAssertEqual(ws.scrollOffset, 0)
    }
}
