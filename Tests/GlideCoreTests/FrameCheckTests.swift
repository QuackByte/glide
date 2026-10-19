import CoreGraphics
import XCTest
@testable import GlideCore

final class FrameCheckTests: XCTestCase {
    let target = CGRect(x: 1034, y: 12, width: 1010, height: 700)

    func testExactAndNearbyOriginsAreFine() {
        XCTAssertFalse(FrameCheck.missedOrigin(target: target, actual: target))
        XCTAssertFalse(FrameCheck.missedOrigin(target: target, actual: target.offsetBy(dx: 2, dy: -2)))
    }

    func testAWindowLeftWhereItWasMissed() {
        XCTAssertTrue(FrameCheck.missedOrigin(target: target, actual: CGRect(x: 1417, y: 12, width: 1010, height: 700)))
        XCTAssertTrue(FrameCheck.missedOrigin(target: target, actual: target.offsetBy(dx: 0, dy: 5)))
    }

    func testARefusedSizeIsNotAMissedOrigin() {
        XCTAssertFalse(FrameCheck.missedOrigin(target: target, actual: CGRect(x: 1034, y: 12, width: 1200, height: 700)))
    }
}
