import XCTest
@testable import GlideCore

final class RestartPlanTests: XCTestCase {
    private let viewport = CGRect(x: 0, y: 40, width: 1212, height: 800)

    /// Before the restart: workspace 1 holds [1] [2 over 3] [4], workspace 2 holds [5]. Windows 1
    /// and 4 are Safari, 2 and 3 Terminal, 5 Notes.
    private func plan() -> RestartPlan {
        var set = WorkspaceSet(viewport: viewport)
        set.active.strip = Strip(columns: [Column(windows: [1], widthIndex: 0), Column(windows: [2, 3], widthIndex: 2),
                                           Column(windows: [4], widthIndex: 1, isFullWidth: true)])
        set.activate(1)
        set.active.strip = Strip(columns: [Column(windows: [5], widthIndex: 1)])
        set.activate(0)
        set.active.layoutOverride = .tiled
        var snapshot = StripSnapshot(displays: [("main", set)], userFloating: [], userTiled: [], bootTime: Date(timeIntervalSince1970: 0))
        snapshot.identities = [
            WindowIdentity(window: 1, bundleID: "safari", title: "News"),
            WindowIdentity(window: 2, bundleID: "terminal", title: "zsh"),
            WindowIdentity(window: 3, bundleID: "terminal", title: "vim"),
            WindowIdentity(window: 4, bundleID: "safari", title: "Docs"),
            WindowIdentity(window: 5, bundleID: "notes", title: "Notes"),
        ]
        return RestartPlan(snapshot: snapshot, mainDisplay: "main")!
    }

    func testMatchesByTitleThenOrderAndFindsNeighbours() {
        var plan = plan()
        XCTAssertEqual(plan.layouts["main"]?.layouts.first, .tiled)

        // Docs opens first: its old left neighbours aren't back yet, so it goes first.
        let docs = plan.claim(104, bundleID: "safari", title: "Docs")
        XCTAssertEqual(docs?.display, "main")
        XCTAssertEqual(docs?.departure.workspace, 0)
        XCTAssertNil(docs?.departure.leftNeighbour)
        XCTAssertEqual(docs?.departure.isFullWidth, true)

        // A Terminal window whose title changed takes the first Terminal place.
        let shell = plan.claim(102, bundleID: "terminal", title: "ssh")
        XCTAssertNil(shell?.departure.sibling)
        XCTAssertEqual(shell?.departure.widthIndex, 2)

        let editor = plan.claim(103, bundleID: "terminal", title: "vim")
        XCTAssertEqual(editor?.departure.sibling, 102, "Back in its stack")

        let news = plan.claim(101, bundleID: "safari", title: "Anything")
        XCTAssertNil(news?.departure.leftNeighbour, "It was the first column")

        let notes = plan.claim(105, bundleID: "notes", title: "Notes")
        XCTAssertEqual(notes?.departure.workspace, 1)
        XCTAssertTrue(plan.isEmpty)
        XCTAssertNil(plan.claim(106, bundleID: "notes", title: "Notes"), "Each place is handed out once")
    }

    func testLeftNeighbourIsTheNearestOneBack() {
        var plan = plan()
        _ = plan.claim(101, bundleID: "safari", title: "News")
        XCTAssertEqual(plan.claim(104, bundleID: "safari", title: "Docs")?.departure.leftNeighbour, 101,
                       "The Terminal column between them isn't back")
        _ = plan.claim(102, bundleID: "terminal", title: "zsh")
        XCTAssertNil(plan.claim(200, bundleID: "mail", title: "Inbox"), "Unknown apps aren't placed")
    }

    func testRebuildsTheLayoutWithRejoin() {
        var plan = plan()
        var set = WorkspaceSet(viewport: viewport)
        for (window, bundle, title) in [(104 as WindowID, "safari", "Docs"), (102, "terminal", "zsh"), (101, "safari", "News"), (103, "terminal", "vim")] {
            let place = plan.claim(window, bundleID: bundle, title: title)!
            set.rejoin(window, from: place.departure, focus: false)
        }
        XCTAssertEqual(set.active.strip.columns.map(\.windows), [[101], [102, 103], [104]])
    }

    func testNeedsIdentities() {
        let snapshot = StripSnapshot(strip: Strip(columns: [Column(windows: [1], widthIndex: 1)]), userFloating: [], userTiled: [], bootTime: Date())
        XCTAssertNil(RestartPlan(snapshot: snapshot, mainDisplay: "main"))
    }
}
