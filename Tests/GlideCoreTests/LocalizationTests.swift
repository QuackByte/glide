import XCTest
@testable import GlideCore

/// Glide is in Spanish when macOS prefers it. These check that the String Catalogs are complete,
/// and that every action title reaches the screen translated.
final class LocalizationTests: XCTestCase {
    private static let sources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Sources")

    private static let catalogs = ["Glide", "GlideCore"]

    private struct Entry {
        let key: String
        /// The English text for each plural form, or the single text under "other".
        let english: [String: String]
        let spanish: [String: String]
    }

    private func entries(in module: String) throws -> [Entry] {
        let url = Self.sources.appendingPathComponent("\(module)/Localizable.xcstrings")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        XCTAssertEqual(json?["sourceLanguage"] as? String, "en")
        let strings = try XCTUnwrap(json?["strings"] as? [String: [String: Any]])
        return strings.map { key, value in
            let localizations = value["localizations"] as? [String: [String: Any]] ?? [:]
            return Entry(key: key,
                         english: Self.forms(localizations["en"]) ?? ["other": key],
                         spanish: Self.forms(localizations["es"]) ?? [:])
        }
    }

    /// Plural variations by category, or a single value as "other". Only "translated" counts.
    private static func forms(_ localization: [String: Any]?) -> [String: String]? {
        guard let localization else { return nil }
        func text(_ node: Any?) -> String? {
            guard let unit = (node as? [String: Any])?["stringUnit"] as? [String: Any],
                  unit["state"] as? String == "translated" else { return nil }
            return unit["value"] as? String
        }
        if let value = text(localization) { return ["other": value] }
        guard let plural = (localization["variations"] as? [String: Any])?["plural"] as? [String: Any] else { return nil }
        return plural.compactMapValues(text)
    }

    /// The format specifiers in a string, sorted, with positions removed: "%1$@" is "%@".
    private func specifiers(_ text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: #"%(?:\d+\$)?(?:lld|ld|d|@|f|s)"#)
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).map {
            String(text[Range($0.range, in: text)!]).replacingOccurrences(of: #"\d+\$"#, with: "", options: .regularExpression)
        }.sorted()
    }

    func testCatalogsAreNotEmpty() throws {
        for module in Self.catalogs { XCTAssertFalse(try entries(in: module).isEmpty, module) }
    }

    func testEveryStringHasASpanishTranslation() throws {
        for module in Self.catalogs {
            for entry in try entries(in: module) {
                XCTAssertFalse(entry.spanish.isEmpty, "\(module): “\(entry.key)” has no translated Spanish")
                for (form, text) in entry.spanish {
                    XCTAssertFalse(text.trimmingCharacters(in: .whitespaces).isEmpty, "\(module): “\(entry.key)” (\(form)) is empty")
                }
                // Spanish needs "one" and "other" wherever English has plural forms.
                for form in entry.english.keys where entry.spanish[form] == nil && entry.spanish["other"] == nil {
                    XCTFail("\(module): “\(entry.key)” lacks the Spanish “\(form)” form")
                }
            }
        }
    }

    func testFormatSpecifiersMatchEnglish() throws {
        for module in Self.catalogs {
            for entry in try entries(in: module) {
                let expected = specifiers(entry.english["other"] ?? entry.key)
                for (form, text) in entry.spanish where entry.english.count == 1 || form == "other" || entry.english[form] != nil {
                    let reference = entry.english[form].map(specifiers) ?? expected
                    XCTAssertEqual(specifiers(text), reference, "\(module): “\(entry.key)” (\(form)) changes the placeholders")
                }
            }
        }
    }

    func testNoStaleOrDuplicateTitles() {
        // Titles are shown in lists; two actions with one title would be indistinguishable.
        let titles = Action.allCases.map(\.title)
        XCTAssertEqual(Set(titles).count, titles.count)
        XCTAssertFalse(titles.contains(""))
    }

    func testSpanishTitlesResolveInTheFramework() throws {
        guard let framework = Bundle(identifier: "dev.quackbyte.glide.core"),
              let path = framework.path(forResource: "es", ofType: "lproj"), let spanish = Bundle(path: path) else {
            throw XCTSkip("The framework's Spanish localization isn't in this build")
        }
        let english = try entries(in: "GlideCore")
        for entry in english where !entry.key.contains("%") {
            let text = spanish.localizedString(forKey: entry.key, value: "⟂", table: nil)
            XCTAssertNotEqual(text, "⟂", "“\(entry.key)” isn't in the framework's es.lproj")
        }
        // Every action title, as the code asks for it, is a key in the catalog (workspace actions
        // are templates over the number). Only checkable when the framework is showing English.
        let keys = Set(english.map(\.key))
        if framework.preferredLocalizations.first == "en" {
            for action in Action.allCases {
                let template = action.title.replacingOccurrences(of: #"\d$"#, with: "%lld", options: .regularExpression)
                XCTAssertTrue(keys.contains(template), "“\(action.title)” isn't in the catalog")
                XCTAssertNotEqual(spanish.localizedString(forKey: template, value: "⟂", table: nil), "⟂", template)
            }
        }
        for group in Action.Group.allCases {
            XCTAssertNotEqual(spanish.localizedString(forKey: group.rawValue, value: "⟂", table: nil), "⟂", group.rawValue)
        }
        XCTAssertEqual(spanish.localizedString(forKey: "Focus Column Left", value: nil, table: nil), "Enfocar columna a la izquierda")
    }
}
