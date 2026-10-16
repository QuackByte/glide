import XCTest
@testable import GlideCore

/// Glide speaks every language in `languages` when macOS prefers it. These check that the String
/// Catalogs are complete in each, and that every action title reaches the screen translated.
final class LocalizationTests: XCTestCase {
    private static let sources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Sources")

    private static let catalogs = ["Glide", "GlideCore"]

    /// The translated languages: Xcode localization codes, as in the catalogs and the lproj folders.
    private static let languages = ["es", "fr", "de", "ja", "zh-Hans", "ko", "pt-BR"]

    private struct Entry {
        let key: String
        /// The English text for each plural form, or the single text under "other".
        let english: [String: String]
        /// The translated text for each language, in the same shape as `english`.
        let translations: [String: [String: String]]
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
                         translations: Dictionary(uniqueKeysWithValues: Self.languages.map {
                             ($0, Self.forms(localizations[$0]) ?? [:])
                         }))
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

    func testEveryStringIsTranslatedIntoEveryLanguage() throws {
        for module in Self.catalogs {
            for entry in try entries(in: module) {
                for language in Self.languages {
                    let translation = entry.translations[language] ?? [:]
                    XCTAssertFalse(translation.isEmpty, "\(module): “\(entry.key)” has no translated \(language)")
                    for (form, text) in translation {
                        XCTAssertFalse(text.trimmingCharacters(in: .whitespaces).isEmpty, "\(module): “\(entry.key)” (\(language) \(form)) is empty")
                    }
                    // Wherever English has plural forms, every language needs its form or a catch-all "other".
                    for form in entry.english.keys where translation[form] == nil && translation["other"] == nil {
                        XCTFail("\(module): “\(entry.key)” lacks the \(language) “\(form)” form")
                    }
                }
            }
        }
    }

    func testFormatSpecifiersMatchEnglish() throws {
        for module in Self.catalogs {
            for entry in try entries(in: module) {
                let expected = specifiers(entry.english["other"] ?? entry.key)
                for language in Self.languages {
                    for (form, text) in entry.translations[language] ?? [:] where entry.english.count == 1 || form == "other" || entry.english[form] != nil {
                        let reference = entry.english[form].map(specifiers) ?? expected
                        XCTAssertEqual(specifiers(text), reference, "\(module): “\(entry.key)” (\(language) \(form)) changes the placeholders")
                    }
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

    func testTitlesResolveInTheFramework() throws {
        guard let framework = Bundle(identifier: "dev.quackbyte.glide.core") else {
            throw XCTSkip("The framework isn't in this build")
        }
        let english = try entries(in: "GlideCore")
        // Every action title, as the code asks for it, is a key in the catalog (workspace actions
        // are templates over the number). Only checkable when the framework is showing English.
        let keys = Set(english.map(\.key))
        if framework.preferredLocalizations.first == "en" {
            for action in Action.allCases {
                let template = action.title.replacingOccurrences(of: #"\d$"#, with: "%lld", options: .regularExpression)
                XCTAssertTrue(keys.contains(template), "“\(action.title)” isn't in the catalog")
            }
        }
        for language in Self.languages {
            guard let path = framework.path(forResource: language, ofType: "lproj"), let bundle = Bundle(path: path) else {
                XCTFail("The framework's \(language) localization isn't in this build")
                continue
            }
            for entry in english where !entry.key.contains("%") {
                let text = bundle.localizedString(forKey: entry.key, value: "⟂", table: nil)
                XCTAssertNotEqual(text, "⟂", "“\(entry.key)” isn't in the framework's \(language).lproj")
            }
            if framework.preferredLocalizations.first == "en" {
                for action in Action.allCases {
                    let template = action.title.replacingOccurrences(of: #"\d$"#, with: "%lld", options: .regularExpression)
                    XCTAssertNotEqual(bundle.localizedString(forKey: template, value: "⟂", table: nil), "⟂", "\(language): \(template)")
                }
            }
            for group in Action.Group.allCases {
                XCTAssertNotEqual(bundle.localizedString(forKey: group.rawValue, value: "⟂", table: nil), "⟂", "\(language): \(group.rawValue)")
            }
            if language == "es" {
                XCTAssertEqual(bundle.localizedString(forKey: "Focus Column Left", value: nil, table: nil), "Enfocar columna a la izquierda")
            }
        }
    }
}
