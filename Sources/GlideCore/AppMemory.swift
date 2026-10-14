import CoreGraphics

/// Where an app's window was on the strip, so it opens there again.
public struct RememberedPlace: Codable, Equatable, Sendable {
    /// The ID of the display it was on; nil in places remembered before Glide tiled every display.
    public var display: String?
    public var workspace: Int
    public var widthIndex: Int
    public var isFullWidth: Bool
    public var customWidth: CGFloat?
    /// The app whose column was just left of this one. nil means it was the first column.
    public var leftNeighbour: String?

    public init(display: String? = nil, workspace: Int, widthIndex: Int, isFullWidth: Bool, customWidth: CGFloat?, leftNeighbour: String?) {
        self.display = display
        self.workspace = workspace
        self.widthIndex = widthIndex
        self.isFullWidth = isFullWidth
        self.customWidth = customWidth
        self.leftNeighbour = leftNeighbour
    }
}

/// The last place of every app that had a tiled window, keyed by bundle ID.
public struct AppMemory: Codable, Equatable, Sendable {
    public private(set) var places: [String: RememberedPlace] = [:]

    public init() {}

    public func place(for bundleID: String) -> RememberedPlace? { places[bundleID] }

    /// Replaces the places of the given apps. Returns true if anything changed.
    @discardableResult
    public mutating func update(_ newPlaces: [String: RememberedPlace]) -> Bool {
        var changed = false
        for (bundleID, place) in newPlaces where places[bundleID] != place {
            places[bundleID] = place
            changed = true
        }
        return changed
    }

    public mutating func forgetAll() {
        places = [:]
    }
}

extension Strip {
    /// The column index a remembered window goes to: right of its old left neighbour's column,
    /// or first when it had none. nil when that app has no column here, so the default applies.
    public func columnIndex(rightOf leftNeighbour: String?, bundleID: (WindowID) -> String?) -> Int? {
        guard let leftNeighbour else { return 0 }
        guard let index = columns.firstIndex(where: { column in column.windows.contains { bundleID($0) == leftNeighbour } }) else { return nil }
        return index + 1
    }
}

extension WorkspaceSet {
    /// The place of each app with a tiled window, for remembering. `bundleID` names a window's app;
    /// `display` is the ID of the display these workspaces are on.
    public func rememberedPlaces(display: String? = nil, bundleID: (WindowID) -> String?) -> [String: RememberedPlace] {
        var places: [String: RememberedPlace] = [:]
        for (index, workspace) in workspaces.enumerated() {
            let columns = workspace.strip.columns
            for (columnIndex, column) in columns.enumerated() {
                let leftNeighbour = columnIndex > 0 ? bundleID(columns[columnIndex - 1].windows[0]) : nil
                for window in column.windows {
                    guard let app = bundleID(window) else { continue }
                    places[app] = RememberedPlace(
                        display: display, workspace: index, widthIndex: column.widthIndex, isFullWidth: column.isFullWidth,
                        customWidth: column.customWidth, leftNeighbour: leftNeighbour
                    )
                }
            }
        }
        return places
    }
}
