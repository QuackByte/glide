import AppKit
import GlideCore

/// The menu bar icon and its menu, rebuilt each time it opens.
final class StatusMenu: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private unowned let controller: AppController

    init(controller: AppController) {
        self.controller = controller
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        refreshIcon()
    }

    func refreshIcon() {
        guard let button = statusItem.button else { return }
        let problems = !controller.hotkeys.problems.isEmpty
        let symbol: String
        if !controller.isTrusted || problems {
            symbol = "exclamationmark.triangle"
        } else if controller.windowManager.isEnabled {
            symbol = "rectangle.split.3x1.fill"
        } else {
            symbol = "rectangle.split.3x1"
        }
        let manager = controller.windowManager
        if manager.isEnabled {
            let entries = manager.workspaceSummary.map { WorkspaceIndicator.Entry(number: $0.number, isActive: $0.isActive) }
            button.image = WorkspaceIndicator.menuBarImage(symbol: symbol, entries: entries)
        } else {
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Glide")
        }
        button.setAccessibilityLabel(manager.isEnabled ? String(localized: "Glide, workspace \(manager.activeWorkspaceNumber)") : "Glide")
        button.toolTip = manager.isEnabled ? String(localized: "Glide: workspace \(manager.activeWorkspaceNumber)") : String(localized: "Glide: paused")
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let manager = controller.windowManager
        let keymap = controller.shortcuts.keymap
        let problems = controller.hotkeys.problems

        if !controller.isTrusted {
            menu.addItem(item("Grant Accessibility Access…", #selector(grantAccess)))
            menu.addItem(.separator())
        }

        let toggle = item("Enable Tiling", #selector(toggleTiling), combo: keymap.combo(for: .toggleTiling))
        toggle.state = manager.isEnabled ? .on : .off
        menu.addItem(toggle)

        if manager.isEnabled {
            let windows = String(localized: "\(manager.tiledWindowCount) windows")
            let columns = String(localized: "\(manager.columnCount) columns")
            var summary = String(localized: "\(windows) in \(columns)")
            if manager.floatingWindowCount > 0 {
                let floating = String(localized: "\(manager.floatingWindowCount) floating")
                summary = String(localized: "\(summary), \(floating)")
            }
            menu.addItem(disabled(summary))

            menu.addItem(.separator())
            menu.addItem(NSMenuItem.sectionHeader(title: String(localized: "Workspaces")))
            for entry in manager.workspaceSummary {
                let action = Action(rawValue: "focusWorkspace\(entry.number)")
                let windows = String(localized: "\(entry.windowCount) windows")
                let switchItem = item("Workspace \(entry.number) — \(windows)", #selector(performAction(_:)), combo: action.flatMap(keymap.combo(for:)))
                switchItem.representedObject = action?.rawValue
                switchItem.state = entry.isActive ? .on : .off
                menu.addItem(switchItem)
            }
        }

        if !problems.isEmpty {
            menu.addItem(.separator())
            let count = problems.count
            let warning = item("⚠︎ \(count) shortcuts unavailable…", #selector(openSettings))
            warning.toolTip = String(localized: "Open Settings to choose other shortcuts.")
            menu.addItem(warning)
            for action in Action.allCases {
                guard let problem = problems[action], let combo = keymap.combo(for: action) else { continue }
                menu.addItem(disabled("    \(action.title) \(combo): \(problem.message)"))
            }
        }

        menu.addItem(.separator())
        let shortcutsItem = NSMenuItem(title: String(localized: "Shortcuts"), action: nil, keyEquivalent: "")
        shortcutsItem.submenu = shortcutsMenu(keymap: keymap, problems: problems)
        menu.addItem(shortcutsItem)
        menu.addItem(item("What’s New", #selector(showWhatsNew)))
        menu.addItem(item("Check for Updates…", #selector(checkForUpdates)))
        menu.addItem(item("Report a Problem…", #selector(reportProblem)))
        menu.addItem(item("Settings…", #selector(openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(item("Quit Glide", #selector(quit), key: "q"))
    }

    private func shortcutsMenu(keymap: Keymap, problems: [Action: HotkeyCenter.Problem]) -> NSMenu {
        let menu = NSMenu()
        let showAll = item("Show All Shortcuts", #selector(performAction(_:)), combo: keymap.combo(for: .showShortcuts))
        showAll.representedObject = Action.showShortcuts.rawValue
        menu.addItem(showAll)
        for group in Action.Group.allCases {
            if !menu.items.isEmpty { menu.addItem(.separator()) }
            menu.addItem(NSMenuItem.sectionHeader(title: group.title))
            for action in Action.allCases where action.group == group {
                let combo = keymap.combo(for: action)
                let entry = item(verbatim: action.title, #selector(performAction(_:)), combo: combo)
                entry.representedObject = action.rawValue
                if let problem = problems[action] {
                    entry.title += "  ⚠︎"
                    entry.toolTip = problem.message
                } else if combo == nil {
                    entry.toolTip = String(localized: "No shortcut")
                }
                menu.addItem(entry)
            }
        }
        return menu
    }

    private func item(_ title: LocalizedStringResource, _ action: Selector, key: String = "", combo: KeyCombo? = nil) -> NSMenuItem {
        item(verbatim: String(localized: title), action, key: key, combo: combo)
    }

    private func item(verbatim title: String, _ action: Selector, key: String = "", combo: KeyCombo? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        if let combo {
            if let equivalent = combo.menuKeyEquivalent {
                item.keyEquivalent = equivalent
                item.keyEquivalentModifierMask = combo.modifiers.eventFlags
            } else {
                item.title += "    \(combo)"
            }
        }
        return item
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func toggleTiling() { controller.setTiling(!controller.windowManager.isEnabled) }
    @objc private func grantAccess() { controller.showOnboarding() }
    @objc private func openSettings() { controller.showSettings() }
    @objc private func checkForUpdates() { controller.updates.checkForUpdates() }
    @objc private func showWhatsNew() { controller.showWhatsNew() }
    @objc private func reportProblem() { controller.reportProblem() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func performAction(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let action = Action(rawValue: raw) else { return }
        // Let the menu close and focus return to the previous app first.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [controller] in controller.perform(action) }
    }
}
