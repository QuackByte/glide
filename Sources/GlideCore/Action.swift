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
    case centerColumn
    case toggleFloating
    case toggleTiling

    public enum Group: String, CaseIterable, Sendable {
        case focus = "Focus"
        case move = "Move"
        case column = "Columns"
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
        case .centerColumn: "Center Column"
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
        case .cycleColumnWidth, .cycleColumnWidthBackward, .toggleFullWidth, .centerColumn:
            .column
        case .toggleFloating, .toggleTiling:
            .general
        }
    }
}
