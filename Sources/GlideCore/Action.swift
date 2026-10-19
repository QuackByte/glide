import Foundation

/// Everything a shortcut can trigger. Raw values are persisted; do not rename them.
public enum Action: String, CaseIterable, Codable, Sendable {
    case focusColumnLeft
    case focusColumnRight
    case focusWindowUp
    case focusWindowDown
    case focusFirstColumn
    case focusLastColumn
    case moveColumnLeft
    case moveColumnRight
    case moveWindowUp
    case moveWindowDown
    case consumeOrExpelLeft
    case consumeOrExpelRight
    case cycleColumnWidth
    case cycleColumnWidthBackward
    case toggleFullWidth
    case toggleTabbed
    case centerColumn
    case focusPreviousWorkspace
    case focusNextWorkspace
    case moveColumnToPreviousWorkspace
    case moveColumnToNextWorkspace
    case focusWorkspace1
    case focusWorkspace2
    case focusWorkspace3
    case focusWorkspace4
    case focusWorkspace5
    case focusWorkspace6
    case focusWorkspace7
    case focusWorkspace8
    case focusWorkspace9
    case moveColumnToWorkspace1
    case moveColumnToWorkspace2
    case moveColumnToWorkspace3
    case moveColumnToWorkspace4
    case moveColumnToWorkspace5
    case moveColumnToWorkspace6
    case moveColumnToWorkspace7
    case moveColumnToWorkspace8
    case moveColumnToWorkspace9
    case focusDisplayLeft
    case focusDisplayRight
    case moveColumnToDisplayLeft
    case moveColumnToDisplayRight
    case toggleOverview
    case showShortcuts
    case toggleFloating
    case toggleTiling
    case toggleLayout
    case cycleTiledColumns

    public enum Group: String, CaseIterable, Sendable {
        case focus = "Focus"
        case move = "Move"
        case column = "Columns"
        case workspaces = "Workspaces"
        case displays = "Displays"
        case general = "General"

        /// The group name in the user's language. The raw value stays the English name.
        public var title: String {
            switch self {
            case .focus: String(localized: "Focus", bundle: #bundle)
            case .move: String(localized: "Move", bundle: #bundle)
            case .column: String(localized: "Columns", bundle: #bundle)
            case .workspaces: String(localized: "Workspaces", bundle: #bundle)
            case .displays: String(localized: "Displays", bundle: #bundle)
            case .general: String(localized: "General", bundle: #bundle)
            }
        }
    }

    /// The title in the user's language. The English text is the catalog key.
    public var title: String {
        if let command = workspaceCommand, case .index(let index) = command.target {
            return command.movesWindow
                ? String(localized: "Move Window to Workspace \(index + 1)", bundle: #bundle)
                : String(localized: "Focus Workspace \(index + 1)", bundle: #bundle)
        }
        return switch self {
        case .focusColumnLeft: String(localized: "Focus Column Left", bundle: #bundle)
        case .focusColumnRight: String(localized: "Focus Column Right", bundle: #bundle)
        case .focusWindowUp: String(localized: "Focus Window Up", bundle: #bundle)
        case .focusWindowDown: String(localized: "Focus Window Down", bundle: #bundle)
        case .focusFirstColumn: String(localized: "Focus First Column", bundle: #bundle)
        case .focusLastColumn: String(localized: "Focus Last Column", bundle: #bundle)
        case .moveColumnLeft: String(localized: "Move Column Left", bundle: #bundle)
        case .moveColumnRight: String(localized: "Move Column Right", bundle: #bundle)
        case .moveWindowUp: String(localized: "Move Window Up", bundle: #bundle)
        case .moveWindowDown: String(localized: "Move Window Down", bundle: #bundle)
        case .consumeOrExpelLeft: String(localized: "Consume or Expel Window Left", bundle: #bundle)
        case .consumeOrExpelRight: String(localized: "Consume or Expel Window Right", bundle: #bundle)
        case .cycleColumnWidth: String(localized: "Cycle Column Width", bundle: #bundle)
        case .cycleColumnWidthBackward: String(localized: "Cycle Column Width Backward", bundle: #bundle)
        case .toggleFullWidth: String(localized: "Toggle Full Width", bundle: #bundle)
        case .toggleTabbed: String(localized: "Toggle Tabbed Column", bundle: #bundle)
        case .centerColumn: String(localized: "Center Column", bundle: #bundle)
        case .focusPreviousWorkspace: String(localized: "Focus Previous Workspace", bundle: #bundle)
        case .focusNextWorkspace: String(localized: "Focus Next Workspace", bundle: #bundle)
        case .moveColumnToPreviousWorkspace: String(localized: "Move Window to Previous Workspace", bundle: #bundle)
        case .moveColumnToNextWorkspace: String(localized: "Move Window to Next Workspace", bundle: #bundle)
        case .focusDisplayLeft: String(localized: "Focus Display Left", bundle: #bundle)
        case .focusDisplayRight: String(localized: "Focus Display Right", bundle: #bundle)
        case .moveColumnToDisplayLeft: String(localized: "Move Column to Display Left", bundle: #bundle)
        case .moveColumnToDisplayRight: String(localized: "Move Column to Display Right", bundle: #bundle)
        case .toggleOverview: String(localized: "Show or Hide Overview", bundle: #bundle)
        case .showShortcuts: String(localized: "Show Shortcuts", bundle: #bundle)
        case .toggleFloating: String(localized: "Toggle Floating", bundle: #bundle)
        case .toggleTiling: String(localized: "Enable or Disable Tiling", bundle: #bundle)
        case .toggleLayout: String(localized: "Switch Between Scrolling and Tiled", bundle: #bundle)
        case .cycleTiledColumns: String(localized: "Switch Between 2 and 3 Columns", bundle: #bundle)
        // Handled above.
        case .focusWorkspace1, .focusWorkspace2, .focusWorkspace3, .focusWorkspace4, .focusWorkspace5,
             .focusWorkspace6, .focusWorkspace7, .focusWorkspace8, .focusWorkspace9,
             .moveColumnToWorkspace1, .moveColumnToWorkspace2, .moveColumnToWorkspace3, .moveColumnToWorkspace4,
             .moveColumnToWorkspace5, .moveColumnToWorkspace6, .moveColumnToWorkspace7, .moveColumnToWorkspace8,
             .moveColumnToWorkspace9: ""
        }
    }

    public var group: Group {
        switch self {
        case .focusColumnLeft, .focusColumnRight, .focusWindowUp, .focusWindowDown, .focusFirstColumn, .focusLastColumn:
            .focus
        case .moveColumnLeft, .moveColumnRight, .moveWindowUp, .moveWindowDown, .consumeOrExpelLeft, .consumeOrExpelRight:
            .move
        case .cycleColumnWidth, .cycleColumnWidthBackward, .toggleFullWidth, .toggleTabbed, .centerColumn:
            .column
        case .focusDisplayLeft, .focusDisplayRight, .moveColumnToDisplayLeft, .moveColumnToDisplayRight:
            .displays
        case .toggleOverview, .showShortcuts, .toggleFloating, .toggleTiling:
            .general
        default:
            .workspaces
        }
    }

    /// Where a workspace action goes, and whether it sends the focused window there (else it just switches).
    public var workspaceCommand: (target: WorkspaceTarget, movesWindow: Bool)? {
        switch self {
        case .focusPreviousWorkspace: (.previous, false)
        case .focusNextWorkspace: (.next, false)
        case .moveColumnToPreviousWorkspace: (.previous, true)
        case .moveColumnToNextWorkspace: (.next, true)
        case .focusWorkspace1: (.index(0), false)
        case .focusWorkspace2: (.index(1), false)
        case .focusWorkspace3: (.index(2), false)
        case .focusWorkspace4: (.index(3), false)
        case .focusWorkspace5: (.index(4), false)
        case .focusWorkspace6: (.index(5), false)
        case .focusWorkspace7: (.index(6), false)
        case .focusWorkspace8: (.index(7), false)
        case .focusWorkspace9: (.index(8), false)
        case .moveColumnToWorkspace1: (.index(0), true)
        case .moveColumnToWorkspace2: (.index(1), true)
        case .moveColumnToWorkspace3: (.index(2), true)
        case .moveColumnToWorkspace4: (.index(3), true)
        case .moveColumnToWorkspace5: (.index(4), true)
        case .moveColumnToWorkspace6: (.index(5), true)
        case .moveColumnToWorkspace7: (.index(6), true)
        case .moveColumnToWorkspace8: (.index(7), true)
        case .moveColumnToWorkspace9: (.index(8), true)
        default: nil
        }
    }
}

extension Action {
    /// For display actions: which way (-1 left, +1 right), and whether the focused column goes along.
    public var displayCommand: (direction: Int, movesColumn: Bool)? {
        switch self {
        case .focusDisplayLeft: (-1, false)
        case .focusDisplayRight: (1, false)
        case .moveColumnToDisplayLeft: (-1, true)
        case .moveColumnToDisplayRight: (1, true)
        default: nil
        }
    }
}

public enum WorkspaceTarget: Equatable, Sendable {
    /// Zero-based: workspace 1 is index 0.
    case index(Int)
    case previous
    case next
}
