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
    case toggleFloating
    case toggleTiling

    public enum Group: String, CaseIterable, Sendable {
        case focus = "Focus"
        case move = "Move"
        case column = "Columns"
        case workspaces = "Workspaces"
        case displays = "Displays"
        case general = "General"
    }

    public var title: String {
        switch self {
        case .focusColumnLeft: "Focus Column Left"
        case .focusColumnRight: "Focus Column Right"
        case .focusWindowUp: "Focus Window Up"
        case .focusWindowDown: "Focus Window Down"
        case .focusFirstColumn: "Focus First Column"
        case .focusLastColumn: "Focus Last Column"
        case .moveColumnLeft: "Move Column Left"
        case .moveColumnRight: "Move Column Right"
        case .moveWindowUp: "Move Window Up"
        case .moveWindowDown: "Move Window Down"
        case .consumeOrExpelLeft: "Consume or Expel Window Left"
        case .consumeOrExpelRight: "Consume or Expel Window Right"
        case .cycleColumnWidth: "Cycle Column Width"
        case .cycleColumnWidthBackward: "Cycle Column Width Backward"
        case .toggleFullWidth: "Toggle Full Width"
        case .toggleTabbed: "Toggle Tabbed Column"
        case .centerColumn: "Center Column"
        case .focusPreviousWorkspace: "Focus Previous Workspace"
        case .focusNextWorkspace: "Focus Next Workspace"
        case .moveColumnToPreviousWorkspace: "Move Column to Previous Workspace"
        case .moveColumnToNextWorkspace: "Move Column to Next Workspace"
        case .focusWorkspace1: "Focus Workspace 1"
        case .focusWorkspace2: "Focus Workspace 2"
        case .focusWorkspace3: "Focus Workspace 3"
        case .focusWorkspace4: "Focus Workspace 4"
        case .focusWorkspace5: "Focus Workspace 5"
        case .focusWorkspace6: "Focus Workspace 6"
        case .focusWorkspace7: "Focus Workspace 7"
        case .focusWorkspace8: "Focus Workspace 8"
        case .focusWorkspace9: "Focus Workspace 9"
        case .moveColumnToWorkspace1: "Move Column to Workspace 1"
        case .moveColumnToWorkspace2: "Move Column to Workspace 2"
        case .moveColumnToWorkspace3: "Move Column to Workspace 3"
        case .moveColumnToWorkspace4: "Move Column to Workspace 4"
        case .moveColumnToWorkspace5: "Move Column to Workspace 5"
        case .moveColumnToWorkspace6: "Move Column to Workspace 6"
        case .moveColumnToWorkspace7: "Move Column to Workspace 7"
        case .moveColumnToWorkspace8: "Move Column to Workspace 8"
        case .moveColumnToWorkspace9: "Move Column to Workspace 9"
        case .focusDisplayLeft: "Focus Display Left"
        case .focusDisplayRight: "Focus Display Right"
        case .moveColumnToDisplayLeft: "Move Column to Display Left"
        case .moveColumnToDisplayRight: "Move Column to Display Right"
        case .toggleOverview: "Show or Hide Overview"
        case .toggleFloating: "Toggle Floating"
        case .toggleTiling: "Enable or Disable Tiling"
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
        case .toggleOverview, .toggleFloating, .toggleTiling:
            .general
        default:
            .workspaces
        }
    }

    /// Where a workspace action goes, and whether it takes the focused column along.
    public var workspaceCommand: (target: WorkspaceTarget, movesColumn: Bool)? {
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
