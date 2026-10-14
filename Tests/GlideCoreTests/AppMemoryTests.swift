import XCTest
@testable import GlideCore

final class AppMemoryTests: XCTestCase {
    private let apps: [WindowID: String] = [1: "com.a", 2: "com.b", 3: "com.c"]

    private func bundleID(_ window: WindowID) -> String? { apps[window] }

    func testRemembersEachAppsWorkspaceWidthAndLeftNeighbour() {
        var set = WorkspaceSet(viewport: CGRect(x: 0, y: 0, width: 1000, height: 800))
        set.insertColumn(Column(windows: [1], widthIndex: 0), workspace: 0, focus: false)
        set.insertColumn(Column(windows: [2], widthIndex: 2, isFullWidth: true), workspace: 0, focus: false)
        set.insertColumn(Column(windows: [3], widthIndex: 1), workspace: 2, focus: false)

        let places = set.rememberedPlaces(bundleID: bundleID)

        XCTAssertEqual(places["com.a"], RememberedPlace(workspace: 0, widthIndex: 0, isFullWidth: false, customWidth: nil, leftNeighbour: nil))
        XCTAssertEqual(places["com.b"], RememberedPlace(workspace: 0, widthIndex: 2, isFullWidth: true, customWidth: nil, leftNeighbour: "com.a"))
        XCTAssertEqual(places["com.c"], RememberedPlace(workspace: 2, widthIndex: 1, isFullWidth: false, customWidth: nil, leftNeighbour: nil))
    }

    func testColumnGoesRightOfItsRememberedNeighbour() {
        var strip = Strip()
        strip.insert(1, widthIndex: 1, focus: false)
        strip.insert(3, widthIndex: 1, focus: false)

        XCTAssertEqual(strip.columnIndex(rightOf: "com.a", bundleID: bundleID), 1)
        XCTAssertEqual(strip.columnIndex(rightOf: nil, bundleID: bundleID), 0, "It was first")
        XCTAssertNil(strip.columnIndex(rightOf: "com.b", bundleID: bundleID), "Its neighbour isn't open")
    }

    func testUpdateReportsOnlyRealChanges() {
        var memory = AppMemory()
        let place = RememberedPlace(workspace: 0, widthIndex: 1, isFullWidth: false, customWidth: nil, leftNeighbour: nil)
        XCTAssertTrue(memory.update(["com.a": place]))
        XCTAssertFalse(memory.update(["com.a": place]))
        XCTAssertEqual(memory.place(for: "com.a"), place)

        memory.forgetAll()
        XCTAssertNil(memory.place(for: "com.a"))
    }
}
