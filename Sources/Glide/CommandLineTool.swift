import AppKit
import GlideCore

/// `glide <command>` in a terminal, and `glide://<command>` URLs: run any action in the Glide
/// that is running. The command line is Glide's own executable, linked as `glide` (or run with
/// `--cli`); it hands the command over with a distributed notification and exits.
enum CommandLineTool {
    static let argument = "--cli"
    static let urlScheme = "glide"
    private static let notification = Notification.Name("dev.quackbyte.glide.command")
    private static let actionKey = "action"

    /// The arguments for the command line, if this process was started as one.
    static func arguments(from arguments: [String]) -> [String]? {
        if arguments.count > 1, arguments[1] == argument { return Array(arguments.dropFirst(2)) }
        if let first = arguments.first, URL(fileURLWithPath: first).lastPathComponent == "glide" { return Array(arguments.dropFirst()) }
        return nil
    }

    /// Where the executable lives, for linking it into the PATH.
    static var executablePath: String { Bundle.main.executablePath ?? "/Applications/Glide.app/Contents/MacOS/Glide" }

    static var installCommand: String { "sudo ln -sf '\(executablePath)' /usr/local/bin/glide" }

    static func run(_ arguments: [String]) -> Never {
        switch arguments.first {
        case nil, "help", "-h", "--help":
            print(usage)
            exit(0)
        case "list":
            let width = Action.allCases.map(\.commandName.count).max() ?? 0
            for action in Action.allCases {
                print(action.commandName.padding(toLength: width + 2, withPad: " ", startingAt: 0) + action.title)
            }
            exit(0)
        default:
            // "focus-workspace 3" reads as "focus-workspace-3".
            let name = arguments.joined(separator: "-")
            guard let action = Action(commandName: name) else {
                FileHandle.standardError.write(Data("glide: unknown command “\(name)”. Run “glide list” to see them all.\n".utf8))
                exit(64)
            }
            let ownPID = ProcessInfo.processInfo.processIdentifier
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: "dev.quackbyte.glide")
                .contains { $0.processIdentifier != ownPID }
            guard running else {
                FileHandle.standardError.write(Data("glide: Glide isn't running. Open it first.\n".utf8))
                exit(69)
            }
            send(action)
            exit(0)
        }
    }

    private static let usage = """
        Usage: glide <command>

        Runs a Glide action in the Glide that is running, like its shortcut does.

          glide focus-column-left
          glide focus-workspace 3
          glide toggle-overview

        glide list    shows every command
        glide help    shows this

        URLs work too, e.g. glide://focus-workspace-3, for launchers and Shortcuts.
        """

    private static func send(_ action: Action) {
        DistributedNotificationCenter.default().postNotificationName(
            notification, object: nil, userInfo: [actionKey: action.rawValue], deliverImmediately: true)
    }

    /// In the running app: runs commands from the command line.
    static func listen(_ perform: @escaping (Action) -> Void) -> NSObjectProtocol {
        DistributedNotificationCenter.default().addObserver(forName: notification, object: nil, queue: .main) { note in
            guard let raw = note.userInfo?[actionKey] as? String, let action = Action(rawValue: raw) else { return }
            MainActor.assumeIsolated { perform(action) }
        }
    }

    /// The action in a `glide://focus-column-left` URL.
    static func action(from url: URL) -> Action? {
        guard url.scheme?.lowercased() == urlScheme else { return nil }
        let name = ([url.host ?? ""] + url.pathComponents.filter { $0 != "/" }).filter { !$0.isEmpty }.joined(separator: "-")
        return Action(commandName: name)
    }
}
