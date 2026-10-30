import XCTest
@testable import GlideCore

final class CommandNameTests: XCTestCase {
    func testCommandNames() {
        XCTAssertEqual(Action.focusColumnLeft.commandName, "focus-column-left")
        XCTAssertEqual(Action.focusWorkspace3.commandName, "focus-workspace-3")
        XCTAssertEqual(Action.moveColumnToWorkspace9.commandName, "move-column-to-workspace-9")
        XCTAssertEqual(Action.toggleOverview.commandName, "toggle-overview")
    }

    func testEveryCommandNameReadsBack() {
        let names = Action.allCases.map(\.commandName)
        XCTAssertEqual(Set(names).count, names.count)
        for action in Action.allCases {
            XCTAssertEqual(Action(commandName: action.commandName), action)
        }
    }

    func testCommandNamesIgnoreCaseAndSeparators() {
        XCTAssertEqual(Action(commandName: "Focus_Column_Left"), .focusColumnLeft)
        XCTAssertEqual(Action(commandName: "focusWorkspace3"), .focusWorkspace3)
        XCTAssertNil(Action(commandName: "focus-column"))
        XCTAssertNil(Action(commandName: ""))
    }
}
