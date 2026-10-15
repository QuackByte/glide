import Foundation

/// The text side of Report a Problem: what goes in the zip and in the pre-filled GitHub issue.
/// Nothing is sent anywhere; the user attaches the zip themselves.
public enum ProblemReport {
    /// What the issue says about the machine.
    public struct System: Equatable, Sendable {
        public var version: String, build: String, macOS: String, model: String, architecture: String
        public var displays: Int

        public init(version: String, build: String, macOS: String, model: String, architecture: String, displays: Int) {
            self.version = version
            self.build = build
            self.macOS = macOS
            self.model = model
            self.architecture = architecture
            self.displays = displays
        }

        /// One fact per line, as system.txt in the zip.
        public var text: String {
            """
            Glide \(version) (build \(build))
            macOS \(macOS)
            \(model) (\(architecture))
            \(displays) display\(displays == 1 ? "" : "s")
            """
        }
    }

    /// e.g. "Glide-Report-2026-10-15-0930.zip".
    public static func fileName(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return String(format: "Glide-Report-%04d-%02d-%02d-%02d%02d.zip", c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0)
    }

    /// A new issue on `repository` ("owner/name") with the title and body filled in.
    public static func issueURL(repository: String, system: System, zipName: String) -> URL? {
        let body = """
            **What happened?**


            **What did you expect to happen?**


            **How can it be made to happen again?**


            ---
            \(system.text.replacingOccurrences(of: "\n", with: " · "))

            Please attach `\(zipName)` from the Finder window that just opened: Glide's log and settings, with window titles taken out.
            """
        var components = URLComponents(string: "https://github.com/\(repository)/issues/new")
        components?.queryItems = [URLQueryItem(name: "title", value: "Problem: "), URLQueryItem(name: "body", value: body)]
        return components?.url
    }

    /// Glide's own log lines name windows by app and id only, so this is a safety net for anything
    /// that slips in later: a quoted string after a window id (`Safari#31 "Title"`) or after a
    /// `title:` / `title=` label has its text replaced.
    public static func withoutTitles(_ log: String) -> String {
        var result = log
        for pattern in [#"(#\d+ )["“][^"”\n]*["”]"#, #"(?i)(title\w*\s*[:=]\s*)["“][^"”\n]*["”]"#] {
            result = result.replacingOccurrences(of: pattern, with: "$1\"…\"", options: .regularExpression)
        }
        return result
    }
}
