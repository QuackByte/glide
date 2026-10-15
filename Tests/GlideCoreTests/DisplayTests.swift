import XCTest
@testable import GlideCore

final class DisplayTests: XCTestCase {
    /// A laptop with an external display to its right, top-aligned.
    private let sideBySide = [CGRect(x: 0, y: 0, width: 1440, height: 900), CGRect(x: 1440, y: 0, width: 2560, height: 1440)]

    func testNeighboursGoByHorizontalPosition() {
        // Listed right first: the order of the list doesn't matter, only where they are.
        let displays = [CGRect(x: 1440, y: 0, width: 1920, height: 1080), CGRect(x: 0, y: 0, width: 1440, height: 900),
                        CGRect(x: -1920, y: 0, width: 1920, height: 1080)]
        XCTAssertEqual(DisplayGeometry.neighbour(of: 1, direction: 1, in: displays), 0)
        XCTAssertEqual(DisplayGeometry.neighbour(of: 1, direction: -1, in: displays), 2)
        XCTAssertNil(DisplayGeometry.neighbour(of: 0, direction: 1, in: displays))
        XCTAssertNil(DisplayGeometry.neighbour(of: 2, direction: -1, in: displays))
    }

    func testShowsOnAnother() {
        XCTAssertTrue(DisplayGeometry.showsOnAnother(CGRect(x: 1400, y: 100, width: 300, height: 300), own: 0, in: sideBySide))
        XCTAssertFalse(DisplayGeometry.showsOnAnother(CGRect(x: 100, y: 100, width: 300, height: 300), own: 0, in: sideBySide))
        // Touching the shared edge isn't showing.
        XCTAssertFalse(DisplayGeometry.showsOnAnother(CGRect(x: 1140, y: 100, width: 300, height: 300), own: 0, in: sideBySide))
    }

    func testCoversDisplay() {
        XCTAssertTrue(DisplayGeometry.coversDisplay(sideBySide[0], in: sideBySide))
        XCTAssertTrue(DisplayGeometry.coversDisplay(sideBySide[1], in: sideBySide))
        // A full-width column honors the gaps and the menu bar, so it falls short of the display.
        XCTAssertFalse(DisplayGeometry.coversDisplay(CGRect(x: 12, y: 36, width: 1416, height: 852), in: sideBySide))
        // Full width but under the menu bar.
        XCTAssertFalse(DisplayGeometry.coversDisplay(CGRect(x: 0, y: 24, width: 1440, height: 876), in: sideBySide))
        // Straddling two displays isn't covering one.
        XCTAssertFalse(DisplayGeometry.coversDisplay(CGRect(x: 700, y: 0, width: 1440, height: 900), in: sideBySide))
    }

    func testCoversDisplayIgnoresWhereGlidePutTheWindow() {
        // No gap, menu bar hidden: Glide's own full-width column is the display's size.
        let placed = sideBySide[0]
        XCTAssertFalse(DisplayGeometry.coversDisplay(sideBySide[0], in: sideBySide, placed: placed))
        XCTAssertFalse(DisplayGeometry.coversDisplay(placed.offsetBy(dx: 1, dy: 1), in: sideBySide, placed: placed))
        XCTAssertTrue(DisplayGeometry.coversDisplay(sideBySide[0], in: sideBySide, placed: CGRect(x: 12, y: 36, width: 700, height: 852)))
    }

    func testHiddenCornerAvoidsTheNeighbour() {
        // The laptop's bottom-right corner faces the external display, so its windows hide bottom-left.
        XCTAssertEqual(DisplayGeometry.hiddenCorner(of: 0, in: sideBySide), .bottomLeft)
        XCTAssertEqual(DisplayGeometry.hiddenCorner(of: 1, in: sideBySide), .bottomRight)
        XCTAssertEqual(DisplayGeometry.hiddenCorner(of: 0, in: [sideBySide[0]]), .bottomRight)
    }

    func testHiddenFrameOnTheLeftLeavesAPointShowing() {
        var workspace = Workspace(viewport: CGRect(x: 0, y: 25, width: 1440, height: 875))
        workspace.hiddenCorner = .bottomLeft
        let frame = workspace.hiddenFrame(size: CGSize(width: 700, height: 500))
        XCTAssertEqual(frame.maxX, 1)
        XCTAssertEqual(frame.minY, 899)
    }

    func testDisplayContainingAFrame() {
        XCTAssertEqual(DisplayGeometry.display(containing: CGRect(x: 1300, y: 100, width: 600, height: 300), in: sideBySide), 1)
        XCTAssertEqual(DisplayGeometry.display(containing: CGRect(x: 100, y: 100, width: 600, height: 300), in: sideBySide), 0)
        XCTAssertNil(DisplayGeometry.display(containing: CGRect(x: -900, y: 100, width: 600, height: 300), in: sideBySide))
        XCTAssertEqual(DisplayGeometry.display(at: CGPoint(x: 2000, y: 50), in: sideBySide), 1)
    }

    func testDropIndexGoesBeforeTheFirstColumnPastThePoint() {
        let strip = Strip(columns: [Column(windows: [1], widthIndex: 1), Column(windows: [2], widthIndex: 1)])
        let workspace = Workspace(strip: strip, viewport: CGRect(x: 1000, y: 0, width: 1000, height: 800))
        XCTAssertEqual(workspace.dropIndex(atX: 1050), 0)
        XCTAssertEqual(workspace.dropIndex(atX: 1500), 1)
        XCTAssertEqual(workspace.dropIndex(atX: 1990), 2)
    }

    func testDisplayActionsAndDefaults() {
        XCTAssertEqual(Action.allCases.filter { $0.group == .displays }.count, 4)
        XCTAssertEqual(Action.moveColumnToDisplayLeft.displayCommand?.direction, -1)
        XCTAssertEqual(Action.focusDisplayRight.displayCommand?.movesColumn, false)
        XCTAssertNil(Action.focusColumnLeft.displayCommand)
        XCTAssertEqual(Keymap.defaults[.focusDisplayLeft]?.description, "⌃⌥⌘←")
        XCTAssertEqual(Keymap.defaults[.moveColumnToDisplayRight]?.description, "⌃⌥⇧⌘→")
    }

    func testRestoringKeepsWindowsOnTheirDisplay() {
        let displays = sideBySide.map { (frame: $0, viewport: $0.insetBy(dx: 0, dy: 20)) }
        let restored = RestorePlanner.restoredFrames(for: [
            (1, CGRect(x: 1600, y: 100, width: 800, height: 600)),
            // Hidden in the laptop's bottom-left corner, a point showing.
            (2, CGRect(x: -799, y: 899, width: 800, height: 600)),
        ], displays: displays)
        XCTAssertEqual(restored[1], CGRect(x: 1600, y: 100, width: 800, height: 600))
        XCTAssertTrue(sideBySide[0].contains(restored[2]!))
    }

    // MARK: Saved layouts

    private func set(_ columns: [[WindowID]], viewport: CGRect = CGRect(x: 0, y: 0, width: 1000, height: 800)) -> WorkspaceSet {
        var spaces = WorkspaceSet(viewport: viewport)
        spaces.restore(strips: [Strip(columns: columns.map { Column(windows: $0, widthIndex: 1) })], activeIndex: 0)
        return spaces
    }

    func testEachDisplayGetsItsOwnLayoutBack() throws {
        let snapshot = StripSnapshot(displays: [("main", set([[1], [2, 3]])), ("side", set([[4]]))], userFloating: [], userTiled: [], bootTime: Date())
        let decoded = try JSONDecoder().decode(StripSnapshot.self, from: JSONEncoder().encode(snapshot))
        let restored = decoded.restoreDisplays(windows: [(1, "main"), (2, "main"), (3, "main"), (4, "main"), (5, "side")],
                                               displays: ["main", "side"], widthIndex: 1, presetCount: 4)
        XCTAssertEqual(restored["main"]?.strips[0].columns.map(\.windows), [[1], [2, 3]])
        // Window 4 sits hidden on the main display but belongs to the side one; 5 is new there.
        XCTAssertEqual(restored["side"]?.strips[0].columns.map(\.windows), [[4], [5]])
        // An older Glide reads the main display's layout.
        XCTAssertEqual(decoded.restore(windows: [1, 2, 3], widthIndex: 1, presetCount: 4).windows, [1, 2, 3])
    }

    func testAGoneDisplayHandsItsWindowsToTheMainOne() {
        let snapshot = StripSnapshot(displays: [("main", set([[1]])), ("side", set([[4]]))], userFloating: [], userTiled: [], bootTime: Date())
        let restored = snapshot.restoreDisplays(windows: [(1, "main"), (4, "main")], displays: ["main"], widthIndex: 1, presetCount: 4)
        XCTAssertEqual(restored["main"]?.strips[0].columns.map(\.windows), [[1], [4]])
    }

    func testASnapshotFromBeforeDisplaysGoesToTheMainDisplay() {
        let snapshot = StripSnapshot(workspaces: set([[1], [2]]), userFloating: [], userTiled: [], bootTime: Date())
        let restored = snapshot.restoreDisplays(windows: [(1, "main"), (2, "side"), (3, "side")], displays: ["main", "side"], widthIndex: 1, presetCount: 4)
        XCTAssertEqual(restored["main"]?.strips[0].columns.map(\.windows), [[1], [2]])
        XCTAssertEqual(restored["side"]?.strips[0].columns.map(\.windows), [[3]])
    }

    func testRememberedPlacesKeepTheirDisplay() throws {
        let places = set([[1], [2]]).rememberedPlaces(display: "side") { "app\($0)" }
        XCTAssertEqual(places["app2"]?.display, "side")
        XCTAssertEqual(places["app2"]?.leftNeighbour, "app1")
        // Places remembered before displays were known still load.
        let old = #"{"workspace":2,"widthIndex":1,"isFullWidth":false}"#
        XCTAssertNil(try JSONDecoder().decode(RememberedPlace.self, from: Data(old.utf8)).display)
    }
}
