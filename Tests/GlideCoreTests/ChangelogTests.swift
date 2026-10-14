import XCTest
@testable import GlideCore

final class ChangelogTests: XCTestCase {
    private let sample = """
        # Changelog

        Intro text that isn't a release.

        - Not an entry either.

        ## 0.8.0 — 2026-11-02

        A paragraph about this release.

        ### New

        - **Bold** first entry,
          wrapped onto a second line.
        - Second entry.

        ### Fixes

        - A fix.

        ## v0.7.0 — 2026-10-14

        ### New

        - Updates.

        ## 0.6
        - Old summary entry.
        """

    private func version(_ string: String) -> Changelog.Version { Changelog.Version(string)! }

    func testParsesReleasesSectionsAndEntries() {
        let log = Changelog(markdown: sample)
        XCTAssertEqual(log.releases.map(\.version.description), ["0.8.0", "0.7.0", "0.6.0"])

        let latest = log.releases[0]
        XCTAssertEqual(latest.date, "2026-11-02")
        XCTAssertEqual(latest.summary, ["A paragraph about this release."])
        XCTAssertEqual(latest.sections.map(\.title), ["New", "Fixes"])
        XCTAssertEqual(latest.sections[0].entries, ["**Bold** first entry, wrapped onto a second line.", "Second entry."])

        XCTAssertNil(log.releases[2].date)
        XCTAssertEqual(log.releases[2].summary, ["Old summary entry."])
    }

    func testSinceListsUnseenReleasesUpToTheCurrentOne() {
        let log = Changelog(markdown: sample)
        XCTAssertEqual(log.since(version("0.6.0"), current: version("0.8.0")).map(\.version.description), ["0.8.0", "0.7.0"])
        XCTAssertEqual(log.since(version("0.6"), current: version("0.7.0")).map(\.version.description), ["0.7.0"])
        XCTAssertEqual(log.since(version("0.8.0"), current: version("0.8.0")), [])
    }

    func testWithoutAPreviousVersionOnlyTheCurrentReleaseShows() {
        let log = Changelog(markdown: sample)
        XCTAssertEqual(log.since(nil, current: version("0.7.0")).map(\.version.description), ["0.7.0"])
        XCTAssertEqual(log.since(nil, current: version("0.9.0")), [])
    }

    func testVersions() {
        XCTAssertNil(Changelog.Version("1"))
        XCTAssertNil(Changelog.Version("1.2.3.4"))
        XCTAssertNil(Changelog.Version("1.x"))
        XCTAssertEqual(version("1.2"), version("1.2.0"))
        XCTAssertLessThan(version("0.9.9"), version("0.10.0"))
    }

    /// CHANGELOG.md at the repository root parses, newest first, with entries in every release.
    func testTheRepositoryChangelogParses() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let log = Changelog(markdown: try String(contentsOf: root.appendingPathComponent("CHANGELOG.md"), encoding: .utf8))
        XCTAssertFalse(log.releases.isEmpty)
        for release in log.releases {
            XCTAssertFalse(release.summary.isEmpty && release.sections.isEmpty, "\(release.version) has no entries")
        }
        XCTAssertEqual(log.releases.map(\.version), log.releases.map(\.version).sorted(by: >))
    }
}
