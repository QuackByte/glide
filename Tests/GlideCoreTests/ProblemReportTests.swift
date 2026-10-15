import XCTest
@testable import GlideCore

final class ProblemReportTests: XCTestCase {
    private let system = ProblemReport.System(version: "0.4.0", build: "6", macOS: "27.0", model: "Mac15,6", architecture: "arm64", displays: 2)

    func testTitlesAreRemovedAndTheRestStays() {
        let log = """
            moved Safari#31 "Secret plans — Safari" to display 2: [*Safari#31]
            window title: "Inbox (3)" changed
            windowTitle="Bank" ok
            scroll 600
            """
        XCTAssertEqual(ProblemReport.withoutTitles(log), """
            moved Safari#31 "…" to display 2: [*Safari#31]
            window title: "…" changed
            windowTitle="…" ok
            scroll 600
            """)
    }

    func testLayoutLinesAreUntouched() {
        let line = "[Ghostty#2208] [*Safari#31 Safari#40] scroll 600"
        XCTAssertEqual(ProblemReport.withoutTitles(line), line)
    }

    func testFileNameUsesDateAndTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 9, minute: 30))!
        XCTAssertEqual(ProblemReport.fileName(for: date, calendar: calendar), "Glide-Report-2026-10-15-0930.zip")
    }

    func testSystemText() {
        XCTAssertEqual(system.text, "Glide 0.4.0 (build 6)\nmacOS 27.0\nMac15,6 (arm64)\n2 displays")
    }

    func testIssueURLCarriesTheSystemAndTheZipName() throws {
        let url = try XCTUnwrap(ProblemReport.issueURL(repository: "QuackByte/glide", system: system, zipName: "Glide-Report-x.zip"))
        XCTAssertEqual(url.host, "github.com")
        XCTAssertEqual(url.path, "/QuackByte/glide/issues/new")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let body = try XCTUnwrap(items.first { $0.name == "body" }?.value)
        XCTAssertTrue(body.contains("Glide 0.4.0 (build 6) · macOS 27.0 · Mac15,6 (arm64) · 2 displays"))
        XCTAssertTrue(body.contains("`Glide-Report-x.zip`"))
        XCTAssertNotNil(items.first { $0.name == "title" })
    }
}
