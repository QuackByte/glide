/// CHANGELOG.md, read for the What's New window: "## 1.2.0 — 2026-10-14" starts a release,
/// "### New" a section, and "- " an entry. Text before the first release is ignored.
public struct Changelog: Equatable, Sendable {
    public struct Version: Comparable, Hashable, Sendable, CustomStringConvertible {
        public let major: Int, minor: Int, patch: Int

        /// "1.2.3", "v1.2" (patch 0); nil for anything else.
        public init?(_ string: some StringProtocol) {
            let parts = string.drop(while: { $0 == "v" }).split(separator: ".", omittingEmptySubsequences: false)
            guard (2...3).contains(parts.count) else { return nil }
            let numbers = parts.compactMap { Int($0) }
            guard numbers.count == parts.count, numbers.allSatisfy({ $0 >= 0 }) else { return nil }
            major = numbers[0]
            minor = numbers[1]
            patch = numbers.count > 2 ? numbers[2] : 0
        }

        public var description: String { "\(major).\(minor).\(patch)" }

        public static func < (a: Version, b: Version) -> Bool {
            (a.major, a.minor, a.patch) < (b.major, b.minor, b.patch)
        }
    }

    public struct Section: Equatable, Sendable {
        public var title: String
        public var entries: [String]
    }

    /// A release. `date` is "2026-10-14" when the heading has one; `summary` holds paragraphs and
    /// entries that aren't in a section.
    public struct Release: Equatable, Sendable {
        public var version: Version
        public var date: String?
        public var summary: [String] = []
        public var sections: [Section] = []
    }

    /// Newest first, as written.
    public let releases: [Release]

    public init(releases: [Release]) {
        self.releases = releases
    }

    public init(markdown: String) {
        var releases: [Release] = []
        var release: Release?

        for raw in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = Self.trimmed(raw)
            if line.hasPrefix("## ") {
                let words = line.dropFirst(3).split(whereSeparator: \.isWhitespace)
                guard let first = words.first, let version = Version(first) else { continue }
                if let release { releases.append(release) }
                let date = words.dropFirst().first { $0.count == 10 && $0.allSatisfy { $0.isNumber || $0 == "-" } }
                release = Release(version: version, date: date.map(String.init))
            } else if release == nil {
                continue
            } else if line.hasPrefix("### ") {
                release!.sections.append(Section(title: Self.trimmed(line.dropFirst(4)), entries: []))
            } else if line.hasPrefix("- ") {
                let entry = Self.trimmed(line.dropFirst(2))
                if release!.sections.isEmpty {
                    release!.summary.append(entry)
                } else {
                    release!.sections[release!.sections.count - 1].entries.append(entry)
                }
            } else if !line.isEmpty {
                // A wrapped entry or a paragraph.
                if let last = release!.sections.indices.last {
                    if !release!.sections[last].entries.isEmpty {
                        release!.sections[last].entries[release!.sections[last].entries.count - 1] += " " + line
                    }
                } else {
                    release!.summary.append(line)
                }
            }
        }
        if let release { releases.append(release) }
        self.releases = releases.map { release in
            var release = release
            release.sections.removeAll { $0.entries.isEmpty }
            return release
        }
    }

    /// This changelog with each release replaced by the same version from `translation` when it has
    /// one. Releases the translation lacks stay as they are, so they appear in English until translated.
    /// The versions, and their order, come only from this changelog.
    public func localized(with translation: Changelog?) -> Changelog {
        guard let translation else { return self }
        let translated = Dictionary(translation.releases.map { ($0.version, $0) }, uniquingKeysWith: { first, _ in first })
        return Changelog(releases: releases.map { translated[$0.version] ?? $0 })
    }

    /// The releases someone who last saw `seen` hasn't seen, up to and including `current`,
    /// newest first. With no `seen`, just the current one.
    public func since(_ seen: Version?, current: Version) -> [Release] {
        releases.filter { release in
            guard release.version <= current else { return false }
            guard let seen else { return release.version == current }
            return release.version > seen
        }
    }

    private static func trimmed(_ text: some StringProtocol) -> String {
        String(text.drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
    }
}
