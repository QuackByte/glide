import XCTest
@testable import GlideCore

final class WheelRoutingTests: XCTestCase {
    func testTiltingFollowsTheSetting() {
        XCTAssertTrue(WheelRouting.movesStrip(horizontal: true, chordHeld: false, mode: .always))
        XCTAssertFalse(WheelRouting.movesStrip(horizontal: true, chordHeld: false, mode: .withModifier))
        XCTAssertTrue(WheelRouting.movesStrip(horizontal: true, chordHeld: true, mode: .withModifier))
        XCTAssertFalse(WheelRouting.movesStrip(horizontal: true, chordHeld: false, mode: .off))
        XCTAssertFalse(WheelRouting.movesStrip(horizontal: true, chordHeld: true, mode: .off))
    }

    func testVerticalWheelOnlyMovesTheStripWithTheChord() {
        for mode in HorizontalWheelMode.allCases {
            XCTAssertFalse(WheelRouting.movesStrip(horizontal: false, chordHeld: false, mode: mode))
            XCTAssertTrue(WheelRouting.movesStrip(horizontal: false, chordHeld: true, mode: mode), "⌃⌥ + wheel works in \(mode)")
        }
    }
}
