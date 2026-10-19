import XCTest
@testable import GlideCore

final class WorkspaceSetTests: XCTestCase {
    private let viewport = CGRect(x: 0, y: 40, width: 1212, height: 800)

    /// Workspace 1 holds windows 1, 2 and 3 (focus on 2); the rest are empty.
    private func set() -> WorkspaceSet {
        var set = WorkspaceSet(viewport: viewport)
        for window: WindowID in [1, 2, 3] { set.active.strip.insert(window, widthIndex: 1, at: set.active.strip.columns.count) }
        set.active.strip.focus(2)
        return set
    }

    func testStartsWithNineEmptyWorkspacesAndTheFirstActive() {
        let set = WorkspaceSet(viewport: viewport)
        XCTAssertEqual(set.workspaces.count, 9)
        XCTAssertEqual(set.activeIndex, 0)
        XCTAssertEqual(set.occupied, [])
    }

    func testActivate() {
        var set = set()
        XCTAssertFalse(set.activate(0), "Already active")
        XCTAssertFalse(set.activate(9), "Out of range")
        XCTAssertTrue(set.activate(4))
        XCTAssertEqual(set.activeIndex, 4)
        XCTAssertTrue(set.active.strip.isEmpty)
        XCTAssertEqual(set.workspaces[0].strip.windows, [1, 2, 3], "Other workspaces keep their windows")
    }

    func testResolvePreviousAndNextStopAtTheEnds() {
        var set = set()
        XCTAssertNil(set.resolve(.previous))
        XCTAssertEqual(set.resolve(.next), 1)
        set.activate(8)
        XCTAssertNil(set.resolve(.next))
        XCTAssertEqual(set.resolve(.index(2)), 2)
        XCTAssertNil(set.resolve(.index(9)))
    }

    func testMoveFocusedWindowKeepsTheActiveWorkspace() {
        var set = set()
        XCTAssertTrue(set.moveFocusedWindow(to: 2))
        XCTAssertEqual(set.activeIndex, 0)
        XCTAssertEqual(set.active.strip.windows, [1, 3])
        XCTAssertEqual(set.active.strip.focusedWindow, 1, "Focus falls to the left neighbour")
        XCTAssertEqual(set.workspaces[2].strip.windows, [2])
        XCTAssertEqual(set.workspaces[2].strip.focusedWindow, 2)
        XCTAssertEqual(set.occupied, [0, 2])
        XCTAssertFalse(set.moveFocusedWindow(to: 0), "Same workspace")
    }

    func testAWindowAloneInItsColumnKeepsTheColumnsWidth() {
        var set = WorkspaceSet(viewport: viewport)
        set.active.strip = Strip(columns: [Column(windows: [1], widthIndex: 2), Column(windows: [2], widthIndex: 1)])
        XCTAssertTrue(set.moveFocusedWindow(to: 1))
        XCTAssertEqual(set.workspaces[1].strip.columns, [Column(windows: [1], widthIndex: 2)])
        XCTAssertEqual(set.active.strip.columns.map(\.windows), [[2]])
    }

    func testOnlyTheFocusedWindowLeavesItsStack() {
        var set = WorkspaceSet(viewport: viewport)
        set.active.strip = Strip(columns: [Column(windows: [1, 2, 3], focusedRow: 1, widthIndex: 2)])
        XCTAssertTrue(set.moveFocusedWindow(to: 4))
        XCTAssertEqual(set.activeIndex, 0)
        XCTAssertEqual(set.active.strip.columns.map(\.windows), [[1, 3]])
        XCTAssertEqual(set.active.strip.columns[0].widthIndex, 2)
        XCTAssertEqual(set.active.strip.focusedWindow, 3, "The next window in the stack")
        // On its own in a new column, with the default width.
        XCTAssertEqual(set.workspaces[4].strip.columns, [Column(windows: [2], widthIndex: set.settings.defaultWidthIndex)])
        XCTAssertEqual(set.workspaces[4].strip.focusedWindow, 2)
        XCTAssertEqual(set.index(of: 2), 4)
    }

    func testAWindowTakenFromATabbedColumnLeavesTheOtherTabs() {
        var set = WorkspaceSet(viewport: viewport)
        set.active.strip = Strip(columns: [Column(windows: [1, 2], focusedRow: 1, widthIndex: 1, isTabbed: true)])
        set.moveFocusedWindow(to: 1)
        XCTAssertEqual(set.active.strip.columns.map(\.windows), [[1]])
        XCTAssertTrue(set.active.strip.columns[0].isTabbed)
        XCTAssertEqual(set.workspaces[1].strip.columns.map(\.windows), [[2]])
        XCTAssertFalse(set.workspaces[1].strip.columns[0].isTabbed)
        XCTAssertTrue(set.moveFocusedWindow(to: 2))
        XCTAssertTrue(set.active.strip.isEmpty)
        XCTAssertFalse(set.moveFocusedWindow(to: 3), "Nothing left to move")
    }

    func testAMovedWindowTakesItsLearnedMinimumWidth() {
        var set = set()
        set.active.minimumWidths[2] = 700
        set.moveFocusedWindow(to: 1)
        XCTAssertNil(set.active.minimumWidths[2])
        XCTAssertEqual(set.workspaces[1].minimumWidths[2], 700)
    }

    func testMovedWindowLandsRightOfTheTargetsFocusedColumn() {
        var set = set()
        set.activate(1)
        set.active.strip.insert(10, widthIndex: 1)
        set.active.strip.insert(11, widthIndex: 1)
        set.active.strip.focus(10)
        set.activate(0)
        set.moveFocusedWindow(to: 1)
        XCTAssertEqual(set.workspaces[1].strip.windows, [10, 2, 11])
    }

    func testRemoveFindsTheWindowOnAnyWorkspace() {
        var set = set()
        set.moveFocusedWindow(to: 5)
        XCTAssertEqual(set.index(of: 2), 5)
        XCTAssertEqual(set.remove(2), 5)
        XCTAssertNil(set.index(of: 2))
        XCTAssertNil(set.remove(2))
    }

    func testViewportAndSettingsApplyToEveryWorkspace() {
        var set = set()
        set.viewport = CGRect(x: 0, y: 0, width: 800, height: 600)
        set.settings.gap = 20
        XCTAssertTrue(set.workspaces.allSatisfy { $0.viewport.width == 800 && $0.settings.gap == 20 })
    }

    func testSnapshotRestoresEveryWorkspace() throws {
        var set = set()
        set.moveFocusedWindow(to: 3)
        set.activate(3)
        let snapshot = StripSnapshot(workspaces: set, userFloating: [], userTiled: [], bootTime: Date(timeIntervalSince1970: 0))
        let decoded = try JSONDecoder().decode(StripSnapshot.self, from: JSONEncoder().encode(snapshot))
        XCTAssertEqual(decoded.allWindows, [1, 3, 2])

        // Window 3 has closed and window 7 is new: it joins the active workspace.
        let restored = decoded.restoreWorkspaces(windows: [1, 2, 7], widthIndex: 1, presetCount: 4)
        XCTAssertEqual(restored.active, 3)
        XCTAssertEqual(restored.strips[0].windows, [1])
        XCTAssertEqual(restored.strips[3].windows, [2, 7])
        XCTAssertEqual(restored.strips[3].focusedWindow, 2)

        var rebuilt = WorkspaceSet(viewport: viewport)
        rebuilt.restore(strips: restored.strips, activeIndex: restored.active)
        XCTAssertEqual(rebuilt.activeIndex, 3)
        XCTAssertEqual(rebuilt.allWindows, [1, 2, 7])
    }

    func testSnapshotsFromBeforeWorkspacesRestoreIntoTheFirst() {
        let strip = Strip(columns: [Column(windows: [1], widthIndex: 1), Column(windows: [2], widthIndex: 0)])
        let snapshot = StripSnapshot(strip: strip, userFloating: [], userTiled: [], bootTime: Date(timeIntervalSince1970: 0))
        let restored = snapshot.restoreWorkspaces(windows: [1, 2], widthIndex: 1, presetCount: 4)
        XCTAssertEqual(restored.active, 0)
        XCTAssertEqual(restored.strips.count, 1)
        XCTAssertEqual(restored.strips[0].windows, [1, 2])
    }

    func testWorkspaceActionsAndDefaults() {
        XCTAssertEqual(Action.focusWorkspace3.workspaceCommand?.target, .index(2))
        XCTAssertEqual(Action.moveColumnToWorkspace9.workspaceCommand?.movesWindow, true)
        XCTAssertEqual(Action.focusNextWorkspace.workspaceCommand?.target, .next)
        XCTAssertNil(Action.focusColumnLeft.workspaceCommand)
        XCTAssertEqual(Action.allCases.filter { $0.group == .workspaces }.count, 24)
        XCTAssertEqual(Keymap.defaults[.focusWorkspace1], KeyCombo(18, [.control, .option]))
        XCTAssertEqual(Keymap.defaults[.moveColumnToWorkspace9], KeyCombo(25, [.control, .option, .shift]))
        XCTAssertEqual(Set(Keymap.defaults.values).count, Keymap.defaults.count, "No two actions share a default")
    }
}

final class DepartureTests: XCTestCase {
    private let viewport = CGRect(x: 0, y: 40, width: 1212, height: 800)

    private func set() -> WorkspaceSet {
        var set = WorkspaceSet(viewport: viewport)
        set.active.strip = Strip(columns: [
            Column(windows: [1], widthIndex: 1),
            Column(windows: [2], widthIndex: 2, isFullWidth: true),
            Column(windows: [3, 4], widthIndex: 1, isTabbed: true),
        ])
        return set
    }

    func testHiddenWindowReturnsToItsSlotWithItsWidth() {
        var set = set()
        let departure = set.departure(of: 2)!
        set.remove(2)
        XCTAssertEqual(set.rejoin(2, from: departure, focus: false), 0)
        XCTAssertEqual(set.active.strip.columns.map(\.windows), [[1], [2], [3, 4]])
        XCTAssertEqual(set.active.strip.columns[1].widthIndex, 2)
        XCTAssertTrue(set.active.strip.columns[1].isFullWidth)
    }

    func testFirstColumnReturnsFirst() {
        var set = set()
        let departure = set.departure(of: 1)!
        set.remove(1)
        set.rejoin(1, from: departure, focus: true)
        XCTAssertEqual(set.active.strip.columns.map(\.windows), [[1], [2], [3, 4]])
        XCTAssertEqual(set.active.strip.focusedWindow, 1)
    }

    func testTabReturnsToItsTabs() {
        var set = set()
        let departure = set.departure(of: 4)!
        set.remove(4)
        set.rejoin(4, from: departure, focus: true)
        XCTAssertEqual(set.active.strip.columns[2].windows, [3, 4])
        XCTAssertTrue(set.active.strip.columns[2].isTabbed)
        XCTAssertEqual(set.active.strip.focusedWindow, 4)
    }

    func testReturnsToItsOwnWorkspace() {
        var set = set()
        set.moveFocusedWindow(to: 4)
        let departure = set.departure(of: 1)!
        set.remove(1)
        XCTAssertEqual(set.rejoin(1, from: departure, focus: false), 4)
        XCTAssertEqual(set.workspaces[4].strip.windows, [1])
        XCTAssertEqual(set.activeIndex, 0)
    }

    func testFallsBackWhenTheNeighbourIsGone() {
        var set = set()
        let departure = set.departure(of: 3)!
        set.remove(3)
        set.remove(4)
        set.remove(2)
        set.rejoin(3, from: departure, focus: false)
        XCTAssertEqual(set.active.strip.windows, [1, 3], "Lands right of the focused column")
    }
}
