import XCTest
@testable import GlideCore

final class FrameAnimationTests: XCTestCase {
    private let viewport = CGRect(x: 0, y: 40, width: 1200, height: 800)

    func testEaseOutEndpointsAndShape() {
        XCTAssertEqual(FrameAnimation.easeOut(0), 0)
        XCTAssertEqual(FrameAnimation.easeOut(1), 1)
        XCTAssertEqual(FrameAnimation.easeOut(2), 1, "Clamped past the end")
        XCTAssertGreaterThan(FrameAnimation.easeOut(0.5), 0.5, "Ease-out covers most distance early")
    }

    func testFrameInterpolatesOriginAndUsesTargetSize() {
        let from = CGRect(x: 0, y: 52, width: 600, height: 776)
        let to = CGRect(x: 1000, y: 52, width: 400, height: 776)
        XCTAssertEqual(FrameAnimation.frame(from: from, to: to, progress: 0), CGRect(x: 0, y: 52, width: 400, height: 776))
        XCTAssertEqual(FrameAnimation.frame(from: from, to: to, progress: 1), to)
        XCTAssertEqual(FrameAnimation.frame(from: from, to: to, progress: 0.5).minX, 875)
    }

    func testParkedToParkedJumps() {
        let parkedLeft = CGRect(x: -596, y: 52, width: 600, height: 776)
        let parkedRight = CGRect(x: 1196, y: 52, width: 600, height: 776)
        XCTAssertFalse(FrameAnimation.shouldAnimate(from: parkedLeft, to: parkedRight, in: viewport))
    }

    func testVisibleMovesAnimate() {
        let onScreen = CGRect(x: 12, y: 52, width: 600, height: 776)
        let parked = CGRect(x: 1196, y: 52, width: 600, height: 776)
        XCTAssertTrue(FrameAnimation.shouldAnimate(from: onScreen, to: parked, in: viewport))
        XCTAssertTrue(FrameAnimation.shouldAnimate(from: parked, to: onScreen, in: viewport))
    }

    func testTinyMovesJump() {
        let a = CGRect(x: 12, y: 52, width: 600, height: 776)
        XCTAssertFalse(FrameAnimation.shouldAnimate(from: a, to: a.offsetBy(dx: 1, dy: 0), in: viewport))
        XCTAssertFalse(FrameAnimation.shouldAnimate(from: a, to: CGRect(x: 12, y: 52, width: 400, height: 776), in: viewport), "Resize in place has nothing to travel")
    }
}
