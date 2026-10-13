import XCTest
@testable import GlideCore

final class StripSnapshotTests: XCTestCase {
    private let boot = Date(timeIntervalSince1970: 1_000)

    private func savedStrip() -> Strip {
        Strip(columns: [
            Column(windows: [1], widthIndex: 0),
            Column(windows: [2, 3], focusedRow: 1, widthIndex: 2),
            Column(windows: [4], widthIndex: 1, isFullWidth: true),
        ], focusedColumnIndex: 1)
    }

    func testRoundTripKeepsOrderStacksWidthsAndFocus() {
        let snapshot = StripSnapshot(strip: savedStrip(), userFloating: [], userTiled: [], bootTime: boot)
        let restored = snapshot.restore(windows: [4, 3, 2, 1], widthIndex: 1, presetCount: 4)
        XCTAssertEqual(restored, savedStrip())
    }

    func testClosedWindowsDropOutAndEmptyColumnsDisappear() {
        let snapshot = StripSnapshot(strip: savedStrip(), userFloating: [], userTiled: [], bootTime: boot)
        let restored = snapshot.restore(windows: [3, 4], widthIndex: 1, presetCount: 4)
        XCTAssertEqual(restored.columns.map(\.windows), [[3], [4]])
        XCTAssertEqual(restored.columns[0].widthIndex, 2, "Column keeps its width without its first window")
        XCTAssertTrue(restored.columns[1].isFullWidth)
        XCTAssertEqual(restored.focusedWindow, 3)
    }

    func testFocusedRowFollowsTheWindowWhenAnotherCloses() {
        let snapshot = StripSnapshot(strip: savedStrip(), userFloating: [], userTiled: [], bootTime: boot)
        let restored = snapshot.restore(windows: [1, 3, 4], widthIndex: 1, presetCount: 4)
        XCTAssertEqual(restored.columns[1].windows, [3])
        XCTAssertEqual(restored.columns[1].focusedRow, 0)
    }

    func testUnknownWindowsAppendInGivenOrder() {
        let snapshot = StripSnapshot(strip: savedStrip(), userFloating: [], userTiled: [], bootTime: boot)
        let restored = snapshot.restore(windows: [9, 1, 8], widthIndex: 1, presetCount: 4)
        XCTAssertEqual(restored.columns.map(\.windows), [[1], [9], [8]])
        XCTAssertEqual(restored.columns[1].widthIndex, 1)
    }

    func testOutOfRangeWidthFallsBackToDefault() {
        let strip = Strip(columns: [Column(windows: [1], widthIndex: 7)])
        let snapshot = StripSnapshot(strip: strip, userFloating: [], userTiled: [], bootTime: boot)
        XCTAssertEqual(snapshot.restore(windows: [1], widthIndex: 1, presetCount: 4).columns[0].widthIndex, 1)
    }

    func testCodableRoundTrip() throws {
        let snapshot = StripSnapshot(strip: savedStrip(), userFloating: [7], userTiled: [8], bootTime: boot)
        let decoded = try JSONDecoder().decode(StripSnapshot.self, from: JSONEncoder().encode(snapshot))
        XCTAssertEqual(decoded, snapshot)
    }
}
