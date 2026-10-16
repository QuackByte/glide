import XCTest
@testable import GlideCore

/// The What's New window shows `changelog/CHANGELOG.<code>.md` in the app's language. These check
/// how a translation is merged with the English changelog, and that every translation in the source
/// tree says the same as `CHANGELOG.md`.
final class ChangelogTranslationTests: XCTestCase {
    private func version(_ string: String) -> Changelog.Version { Changelog.Version(string)! }

    // MARK: Merging

    private let english = Changelog(markdown: """
        # Changelog

        ## 1.2.0 — 2026-10-14

        ### New

        - English 1.2.0

        ## 1.1.0 — 2026-09-01

        ### Fixed

        - English 1.1.0

        ## 1.0.0 — 2026-08-01

        - English 1.0.0
        """)

    private let translation = Changelog(markdown: """
        ## 1.1.0 — 2026-09-01

        ### Corregido

        - Español 1.1.0

        ## 0.5.0 — 2026-01-01

        - Solo en español
        """)

    func testTranslatedReleaseWins() {
        let merged = english.localized(with: translation)
        XCTAssertEqual(merged.releases[1].sections.first?.title, "Corregido")
        XCTAssertEqual(merged.releases[1].sections.first?.entries, ["Español 1.1.0"])
    }

    func testUntranslatedReleasesStayEnglish() {
        let merged = english.localized(with: translation)
        XCTAssertEqual(merged.releases[0], english.releases[0])
        XCTAssertEqual(merged.releases[2], english.releases[2])
    }

    func testOrderAndVersionsComeFromEnglish() {
        let merged = english.localized(with: translation)
        XCTAssertEqual(merged.releases.map(\.version), [version("1.2.0"), version("1.1.0"), version("1.0.0")])
    }

    func testNoTranslationIsEnglish() {
        XCTAssertEqual(english.localized(with: nil), english)
        XCTAssertEqual(english.localized(with: Changelog(markdown: "")), english)
    }

    func testVersionSelectionIsUnchangedByTranslation() {
        let merged = english.localized(with: translation)
        XCTAssertEqual(merged.since(version("1.0.0"), current: version("1.2.0")).map(\.version),
                       english.since(version("1.0.0"), current: version("1.2.0")).map(\.version))
    }

    // MARK: Translations in the source tree

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private static let languages = ["es", "fr", "de", "ja", "zh-Hans", "ko", "pt-BR"]

    private func load(_ path: String) throws -> Changelog {
        Changelog(markdown: try String(contentsOf: Self.root.appendingPathComponent(path), encoding: .utf8))
    }

    private func links(_ release: Changelog.Release) -> Set<String> {
        let text = (release.summary + release.sections.flatMap(\.entries)).joined(separator: "\n")
        let regex = try! NSRegularExpression(pattern: #"https?://[^\s)>\]]+"#)
        return Set(regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).map {
            String(text[Range($0.range, in: text)!])
        })
    }

    func testEveryTranslationExists() {
        for code in Self.languages {
            let path = Self.root.appendingPathComponent("changelog/CHANGELOG.\(code).md").path
            XCTAssertTrue(FileManager.default.fileExists(atPath: path), "changelog/CHANGELOG.\(code).md is missing")
        }
    }

    func testTranslationsMatchTheEnglishChangelog() throws {
        let english = try load("CHANGELOG.md")
        XCTAssertFalse(english.releases.isEmpty)
        for code in Self.languages {
            let file = "changelog/CHANGELOG.\(code).md"
            guard FileManager.default.fileExists(atPath: Self.root.appendingPathComponent(file).path) else { continue }
            let translated = try load(file)

            XCTAssertEqual(translated.releases.map { "\($0.version) \($0.date ?? "no date")" },
                           english.releases.map { "\($0.version) \($0.date ?? "no date")" },
                           "\(file): release headings (version and date) differ from CHANGELOG.md's")

            for (en, tr) in zip(english.releases, translated.releases) where en.version == tr.version {
                let where_ = "\(file), \(en.version)"
                XCTAssertEqual(tr.summary.count, en.summary.count,
                               "\(where_): \(tr.summary.count) summary paragraphs, CHANGELOG.md has \(en.summary.count)")
                XCTAssertEqual(tr.sections.count, en.sections.count,
                               "\(where_): \(tr.sections.count) sections, CHANGELOG.md has \(en.sections.count)")
                for (index, (enSection, trSection)) in zip(en.sections, tr.sections).enumerated() {
                    XCTAssertEqual(trSection.entries.count, enSection.entries.count,
                                   "\(where_), section \(index + 1) “\(trSection.title)” (“\(enSection.title)” in English): \(trSection.entries.count) entries, CHANGELOG.md has \(enSection.entries.count)")
                }
                let missing = links(en).subtracting(links(tr)), extra = links(tr).subtracting(links(en))
                XCTAssertTrue(missing.isEmpty, "\(where_): links missing from the translation: \(missing.sorted())")
                XCTAssertTrue(extra.isEmpty, "\(where_): links not in CHANGELOG.md: \(extra.sorted())")
            }
        }
    }
}
