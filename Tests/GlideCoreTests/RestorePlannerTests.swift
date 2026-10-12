import XCTest
@testable import GlideCore

final class RestorePlannerTests: XCTestCase {
    private let viewport = CGRect(x: 0, y: 40, width: 1200, height: 800)

    func testVisibleWindowsKeepTheirFrames() {
        let frame = CGRect(x: 100, y: 100, width: 400, height: 300)
        let result = RestorePlanner.restoredFrames(for: [(1, frame)], in: viewport)
        XCTAssertEqual(result[1], frame)
    }

    func testMostlyVisibleWindowIsNudgedInside() {
        let frame = CGRect(x: 1000, y: 100, width: 400, height: 300)
        let result = RestorePlanner.restoredFrames(for: [(1, frame)], in: viewport)
        XCTAssertEqual(result[1], CGRect(x: 1200 - 12 - 400, y: 100, width: 400, height: 300))
    }

    func testParkedFullHeightWindowsShrinkAndStagger() {
        let parked = [
            (WindowID(1), CGRect(x: -596, y: 52, width: 600, height: 776)),
            (WindowID(2), CGRect(x: 1196, y: 52, width: 600, height: 776)),
        ]
        let result = RestorePlanner.restoredFrames(for: parked, in: viewport)
        XCTAssertEqual(result[1], CGRect(x: 12, y: 52, width: 600, height: 660))
        XCTAssertEqual(result[2], CGRect(x: 40, y: 80, width: 600, height: 660))
        for frame in result.values {
            XCTAssertTrue(viewport.contains(frame))
        }
    }

    func testSmallParkedWindowsCascadeDiagonally() {
        let parked = (1...3).map { (WindowID($0), CGRect(x: 1196, y: 52, width: 400, height: 300)) }
        let result = RestorePlanner.restoredFrames(for: parked, in: viewport)
        XCTAssertEqual(result[1]?.origin, CGPoint(x: 12, y: 52))
        XCTAssertEqual(result[2]?.origin, CGPoint(x: 40, y: 80))
        XCTAssertEqual(result[3]?.origin, CGPoint(x: 68, y: 108))
    }

    func testOversizedWindowShrinksToFit() {
        let frame = CGRect(x: -2000, y: 0, width: 3000, height: 2000)
        let result = RestorePlanner.restoredFrames(for: [(1, frame)], in: viewport)
        XCTAssertEqual(result[1], CGRect(x: 12, y: 52, width: 1000, height: 660))
    }
}
