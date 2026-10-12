import XCTest
@testable import GlideCore

final class SwipeTrackerTests: XCTestCase {
    private func fingers(_ count: Int, x: Double, y: Double = 0.5) -> [Touch] {
        (0..<count).map { Touch(x: x + Double($0) * 0.05, y: y) }
    }

    func testHorizontalThreeFingerSwipe() {
        var tracker = SwipeTracker()
        XCTAssertEqual(tracker.update(touches: fingers(3, x: 0.5), at: 0), [])
        XCTAssertEqual(tracker.update(touches: fingers(3, x: 0.505), at: 0.01), [], "Below threshold")
        let began = tracker.update(touches: fingers(3, x: 0.48), at: 0.02)
        XCTAssertEqual(began.first, .began)
        XCTAssertEqual(began.count, 2)
        if case let .changed(dx) = began[1] { XCTAssertEqual(dx, -0.02, accuracy: 1e-9) } else { XCTFail() }
        XCTAssertTrue(tracker.isSwiping)

        let moved = tracker.update(touches: fingers(3, x: 0.40), at: 0.06)
        if case let .changed(dx) = moved.first { XCTAssertEqual(dx, -0.08, accuracy: 1e-9) } else { XCTFail() }

        let ended = tracker.update(touches: [], at: 0.07)
        guard case let .ended(velocity) = ended.first else { return XCTFail("Expected end") }
        XCTAssertEqual(velocity, -2.0, accuracy: 1e-6, "0.08 widths in 40 ms")
        XCTAssertFalse(tracker.isSwiping)
    }

    func testFingersLandingOneAtATimeStillSwipe() {
        var tracker = SwipeTracker()
        XCTAssertEqual(tracker.update(touches: fingers(1, x: 0.5), at: 0), [])
        XCTAssertEqual(tracker.update(touches: fingers(2, x: 0.5), at: 0.01), [])
        XCTAssertEqual(tracker.update(touches: fingers(3, x: 0.5), at: 0.02), [])
        XCTAssertEqual(tracker.update(touches: fingers(3, x: 0.45), at: 0.03).first, .began)
    }

    func testFourFingersLockOutUntilLifted() {
        var tracker = SwipeTracker()
        _ = tracker.update(touches: fingers(3, x: 0.5), at: 0)
        _ = tracker.update(touches: fingers(4, x: 0.5), at: 0.01)
        _ = tracker.update(touches: fingers(3, x: 0.5), at: 0.02)
        XCTAssertEqual(tracker.update(touches: fingers(3, x: 0.3), at: 0.03), [], "macOS's four-finger swipe, not ours")
        _ = tracker.update(touches: [], at: 0.04)
        _ = tracker.update(touches: fingers(3, x: 0.5), at: 0.05)
        XCTAssertEqual(tracker.update(touches: fingers(3, x: 0.45), at: 0.06).first, .began)
    }

    func testVerticalSwipeIsLeftToTheSystem() {
        var tracker = SwipeTracker()
        _ = tracker.update(touches: fingers(3, x: 0.5, y: 0.5), at: 0)
        XCTAssertEqual(tracker.update(touches: fingers(3, x: 0.5, y: 0.6), at: 0.02), [])
        XCTAssertEqual(tracker.update(touches: fingers(3, x: 0.2, y: 0.6), at: 0.04), [], "Locked until fingers lift")
        _ = tracker.update(touches: [], at: 0.05)
        _ = tracker.update(touches: fingers(3, x: 0.5), at: 0.06)
        XCTAssertEqual(tracker.update(touches: fingers(3, x: 0.45), at: 0.07).first, .began)
    }

    func testOtherFingerCountsAreIgnored() {
        var tracker = SwipeTracker()
        _ = tracker.update(touches: fingers(2, x: 0.5), at: 0)
        XCTAssertEqual(tracker.update(touches: fingers(2, x: 0.2), at: 0.05), [])
        _ = tracker.update(touches: fingers(4, x: 0.5), at: 0.1)
        XCTAssertEqual(tracker.update(touches: fingers(4, x: 0.2), at: 0.15), [])
    }

    func testLiftingOneFingerEndsAndLocksUntilAllLift() {
        var tracker = SwipeTracker()
        _ = tracker.update(touches: fingers(3, x: 0.5), at: 0)
        _ = tracker.update(touches: fingers(3, x: 0.45), at: 0.01)
        XCTAssertEqual(tracker.update(touches: fingers(2, x: 0.45), at: 0.02).count, 1)
        _ = tracker.update(touches: fingers(3, x: 0.45), at: 0.03)
        XCTAssertEqual(tracker.update(touches: fingers(3, x: 0.30), at: 0.04), [], "Still locked")
    }

    func testPausedFingersReleaseWithoutVelocity() {
        var tracker = SwipeTracker()
        _ = tracker.update(touches: fingers(3, x: 0.5), at: 0)
        _ = tracker.update(touches: fingers(3, x: 0.4), at: 0.01)
        _ = tracker.update(touches: fingers(3, x: 0.4), at: 0.30)
        XCTAssertEqual(tracker.update(touches: [], at: 0.31), [.ended(velocity: 0)])
    }
}

final class GestureScrollTests: XCTestCase {
    private let viewport = CGRect(x: 0, y: 40, width: 1212, height: 800)

    /// Five ½ columns (588 wide, 600 apart); the usable width shows exactly two.
    private func workspace(focused: Int = 0) -> Workspace {
        let columns = (1...5).map { Column(windows: [WindowID($0)], widthIndex: 1) }
        return Workspace(strip: Strip(columns: columns, focusedColumnIndex: focused), viewport: viewport)
    }

    func testScrollFollowsFingersInsideBounds() {
        var ws = workspace()
        ws.scroll(by: 250)
        XCTAssertEqual(ws.scrollOffset, 250)
        XCTAssertEqual(ws.scrollBounds, 0...1800)
    }

    func testRubberBandPastTheEnds() {
        var ws = workspace()
        ws.scroll(by: -300)
        XCTAssertEqual(ws.scrollOffset, -100, "A third of the movement")
        ws.scroll(by: -3000)
        XCTAssertEqual(ws.scrollOffset, -297, "At most a quarter of the screen")
    }

    func testSnapToNearestColumnEdge() {
        let ws = workspace()
        XCTAssertEqual(ws.snappedOffset(near: 250), 0)
        XCTAssertEqual(ws.snappedOffset(near: 350), 600)
        XCTAssertEqual(ws.snappedOffset(near: 5000), 1800)
        XCTAssertEqual(ws.snappedOffset(near: -400), 0)
    }

    func testSettleKeepsFocusWhenStillVisible() {
        var ws = workspace(focused: 1)
        ws.scroll(by: 500)
        XCTAssertFalse(ws.settleSwipe(projectedOffset: ws.scrollOffset))
        XCTAssertEqual(ws.scrollOffset, 600)
        XCTAssertEqual(ws.strip.focusedWindow, 2)
    }

    func testSettleMovesFocusOntoScreen() {
        var ws = workspace(focused: 0)
        ws.scroll(by: 1000)
        XCTAssertTrue(ws.settleSwipe(projectedOffset: 1250))
        XCTAssertEqual(ws.scrollOffset, 1200)
        XCTAssertEqual(ws.strip.focusedWindow, 3, "Columns 3 and 4 are on screen; 3 is nearest the middle when tied")
        let focused = ws.placements().first { $0.window == 3 }!
        XCTAssertEqual(focused.visibility, .visible)
    }

    func testSettleSpringsBackFromOverscroll() {
        var ws = workspace(focused: 4)
        ws.ensureFocusedVisible()
        XCTAssertEqual(ws.scrollOffset, 1800)
        ws.scroll(by: 600)
        XCTAssertGreaterThan(ws.scrollOffset, 1800)
        ws.settleSwipe(projectedOffset: ws.scrollOffset)
        XCTAssertEqual(ws.scrollOffset, 1800)
    }

    func testShortStripStaysPut() {
        let columns = [Column(windows: [1], widthIndex: 1)]
        var ws = Workspace(strip: Strip(columns: columns), viewport: viewport)
        ws.scroll(by: 400)
        ws.settleSwipe(projectedOffset: 900)
        XCTAssertEqual(ws.scrollOffset, 0)
    }
}
