import AppKit
import GlideCore
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

final class SettingsWindowController: NSObject, NSWindowDelegate {
    private unowned let controller: AppController
    private let recorder: ShortcutRecorder
    private lazy var window: NSWindow = {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(controller: controller, recorder: recorder)))
        window.title = String(localized: "Glide Settings")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }()

    init(controller: AppController) {
        self.controller = controller
        recorder = ShortcutRecorder(controller: controller)
        super.init()
    }

    func show() {
        // A menu bar app isn't frontmost when its menu is used; ask firmly to come forward.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) { recorder.stop() }
    func windowDidResignKey(_ notification: Notification) { recorder.stop() }
}

/// Captures the next key combo pressed in the settings window. Glide's own hotkeys are
/// suspended meanwhile, otherwise pressing a current shortcut would trigger it instead.
@Observable
final class ShortcutRecorder {
    private(set) var action: Action?
    var message: String?
    @ObservationIgnored private unowned let controller: AppController
    @ObservationIgnored private var monitor: Any?

    init(controller: AppController) {
        self.controller = controller
    }

    func start(_ action: Action) {
        stop()
        self.action = action
        message = String(localized: "Press the new shortcut for “\(action.title)”. Esc cancels, ⌫ removes it.")
        controller.suspendHotkeys()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            handle(event)
            return nil
        }
    }

    func stop() {
        guard action != nil else { return }
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        action = nil
        controller.resumeHotkeys()
    }

    private func handle(_ event: NSEvent) {
        guard let action else { return }
        let modifiers = KeyModifiers(event.modifierFlags.intersection(.deviceIndependentFlagsMask))
        let keyCode = UInt32(event.keyCode)

        if modifiers.isEmpty && keyCode == KeyCode.escape {
            message = nil
            return stop()
        }
        if modifiers.isEmpty && (keyCode == KeyCode.delete || keyCode == KeyCode.forwardDelete) {
            controller.shortcuts.set(nil, for: action)
            message = String(localized: "Removed the shortcut for “\(action.title)”.")
            return stop()
        }

        let combo = KeyCombo(keyCode, modifiers)
        var notes: [String] = []
        switch ShortcutPolicy.evaluate(combo) {
        case .rejected(let reason):
            message = String(localized: "\(combo.description) can't be used: \(reason)")
            return
        case .warning(let reason):
            notes.append(String(localized: "Note: \(reason)"))
        case .ok:
            break
        }
        let displaced = controller.shortcuts.set(combo, for: action)
        if !displaced.isEmpty {
            notes.insert(String(localized: "\(combo.description) was removed from “\(displaced.map(\.title).joined(separator: "”, “"))”."), at: 0)
        }
        message = notes.isEmpty ? nil : notes.joined(separator: " ")
        stop()
    }
}

struct SettingsView: View {
    let controller: AppController
    let recorder: ShortcutRecorder

    var body: some View {
        let _ = controller.revision
        let chord = controller.shortcuts.modifier.modifiers.symbols
        VStack(alignment: .leading, spacing: 12) {
            Form {
                Section("General") {
                    Toggle("Open at login", isOn: Binding(
                        get: { controller.opensAtLogin || controller.loginItemNeedsApproval },
                        set: { controller.setOpensAtLogin($0) }
                    ))
                    if controller.loginItemNeedsApproval {
                        HStack(alignment: .firstTextBaseline) {
                            Label("macOS needs you to allow Glide under Login Items.", systemImage: "exclamationmark.triangle.fill")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Button("Login Items…") { SMAppService.openSystemSettingsLoginItems() }
                        }
                    }
                    Toggle("Tile windows", isOn: Binding(
                        get: { controller.isTilingPreferred && controller.windowManager.isEnabled },
                        set: { controller.setTiling($0) }
                    ))
                    Picker("Layout", selection: Binding(
                        get: { Appearance.defaultLayout },
                        set: { Appearance.defaultLayout = $0; controller.appearanceChanged() }
                    )) {
                        Text("Scrolling").tag(LayoutMode.scrolling)
                        Text("Tiled").tag(LayoutMode.tiled)
                    }
                    Text("Scrolling keeps columns on a strip you scroll along; tiled fits every window on screen, splitting the space in a spiral. New and untouched workspaces use this. \(controller.shortcuts.keymap.combo(for: .toggleLayout)?.description ?? String(localized: "A shortcut")) switches the current workspace.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Picker("Tiled columns", selection: Binding(
                        get: { Appearance.tiledColumns },
                        set: { Appearance.tiledColumns = $0; controller.appearanceChanged() }
                    )) {
                        Text("Automatic").tag(Int?.none)
                        Text(verbatim: "2").tag(Int?.some(2))
                        Text(verbatim: "3").tag(Int?.some(3))
                    }
                    Text("How many columns a tiled workspace uses before splitting the last one. Automatic uses 3 on ultrawide displays. \(controller.shortcuts.keymap.combo(for: .cycleTiledColumns)?.description ?? String(localized: "A shortcut")) switches the current workspace.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    WidthPresetsField(controller: controller)
                    Toggle("Animate window movement", isOn: Binding(
                        get: { WindowManager.animatesWindows },
                        set: { WindowManager.animatesWindows = $0 }
                    ))
                    Toggle("Scroll with a three-finger swipe", isOn: Binding(
                        get: { controller.isTrackpadSwipeEnabled },
                        set: { controller.isTrackpadSwipeEnabled = $0 }
                    ))
                    if controller.isTrackpadSwipeEnabled && controller.systemUsesThreeFingerSwipe {
                        HStack(alignment: .firstTextBaseline) {
                            Label("macOS also switches Spaces with three-finger swipes. Set “Swipe between full-screen apps” to four fingers.", systemImage: "exclamationmark.triangle.fill")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Button("Trackpad Settings…") {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension")!)
                            }
                        }
                    }
                    Picker("Horizontal mouse wheel", selection: Binding(
                        get: { controller.horizontalWheelMode },
                        set: { controller.horizontalWheelMode = $0 }
                    )) {
                        Text("Always").tag(HorizontalWheelMode.always)
                        Text("With \(chord)").tag(HorizontalWheelMode.withModifier)
                        Text("Off").tag(HorizontalWheelMode.off)
                    }
                    .help("Tilting the mouse wheel (or a thumb wheel) glides the strip. \(chord) with the wheel always does, whatever this is set to.")
                    Toggle("Apps reopen where you keep them", isOn: Binding(
                        get: { WindowManager.remembersApps },
                        set: { WindowManager.remembersApps = $0 }
                    ))
                    LabeledContent("Remembered places") {
                        Button("Forget") { controller.windowManager.forgetRememberedApps() }
                    }
                    LabeledContent("Something wrong?") {
                        Button("Report a Problem…") { controller.reportProblem() }
                    }
                }

                Section("Updates") {
                    Toggle("Check for updates automatically", isOn: Binding(
                        get: { controller.checksForUpdates },
                        set: { controller.checksForUpdates = $0 }
                    ))
                    Toggle("Download and install updates automatically", isOn: Binding(
                        get: { controller.installsUpdates },
                        set: { controller.installsUpdates = $0 }
                    ))
                    .disabled(!controller.checksForUpdates)
                    LabeledContent("Glide \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")") {
                        Button("Check Now") { controller.updates.checkForUpdates() }
                    }
                }

                AppearanceSection(controller: controller)

                AppRulesSection(store: controller.appRules,
                                floatCombo: controller.shortcuts.keymap.combo(for: .toggleFloating)?.description ?? String(localized: "A shortcut"))

                Section {
                    Picker("Glide modifier", selection: Binding(
                        get: { controller.shortcuts.modifier },
                        set: { recorder.stop(); controller.shortcuts.modifier = $0 }
                    )) {
                        Text("⌃⌥ Control-Option").tag(GlideModifier.controlOption)
                        Text("⌥ Option").tag(GlideModifier.option)
                    }
                    Picker("Direction keys", selection: Binding(
                        get: { controller.shortcuts.directions },
                        set: { recorder.stop(); controller.shortcuts.directions = $0 }
                    )) {
                        Text("Arrows").tag(DirectionKeys.arrows)
                        Text(verbatim: "H J K L").tag(DirectionKeys.letters)
                    }
                } header: {
                    Text("Shortcuts")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if controller.shortcuts.modifier == .option {
                            Text("Every default shortcut uses ⌥, and ⇧ to move windows. ⌥ + arrows no longer jump by word in text, and ⌥ + letters and digits no longer type special characters like é or ©. Shortcuts you changed stay as they are.")
                        } else {
                            Text("Every default shortcut uses ⌃⌥, and ⇧ to move windows. Shortcuts you changed stay as they are.")
                        }
                        if controller.shortcuts.directions == .letters {
                            Text("H, J, K and L go left, down, up and right, as in vim. Display shortcuts keep the arrows.")
                        }
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }

                ForEach(Action.Group.allCases, id: \.self) { group in
                    Section(group.title) {
                        ForEach(Action.allCases.filter { $0.group == group }, id: \.self) { action in
                            ShortcutRow(action: action, controller: controller, recorder: recorder)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack(alignment: .top) {
                Text(recorder.message ?? String(localized: "Click a shortcut to record a new one. Shortcuts work in every app."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("Restore Defaults") {
                    recorder.stop()
                    controller.shortcuts.resetAll()
                    recorder.message = String(localized: "All shortcuts restored to their defaults.")
                }
            }
        }
        .padding(20)
        .frame(width: 620, height: 780)
    }
}

/// The column widths, typed as percentages of the screen.
private struct WidthPresetsField: View {
    let controller: AppController
    @State private var text = LayoutSettings.describe(widthPresets: Appearance.widthPresets)
    @State private var isInvalid = false

    var body: some View {
        LabeledContent("Column widths") {
            HStack {
                TextField("Column widths", text: $text)
                    .labelsHidden()
                    .frame(width: 160)
                    .onSubmit(apply)
                    .onDisappear(perform: apply)
                Text(verbatim: "%")
                Button("Reset") {
                    text = LayoutSettings.describe(widthPresets: LayoutSettings.standard.widthPresets)
                    apply()
                }
                .disabled(Appearance.widthPresets == LayoutSettings.standard.widthPresets && !isInvalid)
            }
        }
        Text(isInvalid
             ? String(localized: "Type one to eight widths from 10 to 100, separated by commas.")
             : String(localized: "The widths \(controller.shortcuts.keymap.combo(for: .cycleColumnWidth)?.description ?? String(localized: "A shortcut")) steps through, as percentages of the screen. New windows open at the one nearest 50."))
            .font(.callout)
            .foregroundStyle(isInvalid ? .red : .secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func apply() {
        guard let presets = LayoutSettings.widthPresets(from: text) else {
            isInvalid = true
            return
        }
        isInvalid = false
        Appearance.widthPresets = presets
        text = LayoutSettings.describe(widthPresets: presets)
        controller.appearanceChanged()
    }
}

private struct AppRulesSection: View {
    let store: RuleStore
    let floatCombo: String

    var body: some View {
        Section {
            ForEach(store.rules.rules) { rule in
                AppRuleRow(rule: rule, store: store)
            }
            Menu("Add App…") {
                ForEach(store.appsWithoutRules, id: \.processIdentifier) { app in
                    Button(app.localizedName ?? app.bundleIdentifier ?? "App") {
                        store.set(AppRule(bundleID: app.bundleIdentifier!, appName: app.localizedName ?? app.bundleIdentifier!, mode: .float))
                    }
                }
                Divider()
                Button("Other App…") { chooseApp() }
            }
            .fixedSize()
        } header: {
            Text("App Rules")
        } footer: {
            Text("Rules apply as windows open. Float and tile take effect right away; width and workspace apply to new windows. \(floatCombo) still floats or tiles a single window.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { store.addApp(at: url) }
    }
}

private struct AppRuleRow: View {
    let rule: AppRule
    let store: RuleStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: rule.bundleID) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                Text(rule.appName)
                    .fontWeight(.medium)
                Spacer()
                Button {
                    store.remove(rule.bundleID)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .help("Remove the rule for \(rule.appName)")
            }
            HStack(spacing: 8) {
                Picker("Windows", selection: binding(\.mode)) {
                    Text("Automatic").tag(AppRule.Mode.automatic)
                    Text("Always float").tag(AppRule.Mode.float)
                    Text("Always tile").tag(AppRule.Mode.tile)
                }
                Picker("Width", selection: binding(\.widthIndex)) {
                    Text("Default width").tag(Int?.none)
                    let presets = Appearance.widthPresets
                    if presets == LayoutSettings.standard.widthPresets {
                        let names: [LocalizedStringResource] = ["⅓ width", "½ width", "⅔ width", "Full width"]
                        ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                            Text(name).tag(Int?.some(index))
                        }
                    } else {
                        ForEach(Array(presets.enumerated()), id: \.offset) { index, preset in
                            Text("\(LayoutSettings.describe(widthPresets: [preset]) + "%") width").tag(Int?.some(index))
                        }
                    }
                }
                .disabled(rule.mode == .float)
                Picker("Workspace", selection: binding(\.workspace)) {
                    Text("Any workspace").tag(Int?.none)
                    ForEach(0..<WorkspaceSet.count, id: \.self) { index in
                        Text("Workspace \(index + 1)").tag(Int?.some(index))
                    }
                }
                .disabled(rule.mode == .float)
            }
            .labelsHidden()
            .padding(.leading, 28)
        }
        .padding(.vertical, 2)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AppRule, Value>) -> Binding<Value> {
        Binding(get: { rule[keyPath: keyPath] }, set: { value in
            var updated = rule
            updated[keyPath: keyPath] = value
            store.set(updated)
        })
    }
}

private struct AppearanceSection: View {
    let controller: AppController

    var body: some View {
        let _ = controller.revision
        Section("Appearance") {
            LabeledContent("Gap between windows") {
                HStack {
                    Slider(value: binding(get: { Double(Appearance.gap) }, set: { Appearance.gap = CGFloat($0.rounded()) }),
                           in: Double(Appearance.gapRange.lowerBound)...Double(Appearance.gapRange.upperBound), step: 2)
                        .frame(width: 180)
                    Text("\(Int(Appearance.gap)) pt")
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
            }

            Toggle("Focus ring", isOn: binding(get: { Appearance.showsFocusRing }, set: { Appearance.showsFocusRing = $0 }))
            if Appearance.showsFocusRing {
                LabeledContent("Ring color") {
                    HStack {
                        if Appearance.focusRingColor != nil {
                            Button("Use Accent Color") { set { Appearance.focusRingColor = nil } }
                                .buttonStyle(.link)
                        }
                        ColorPicker("Ring color", selection: binding(
                            get: { Color(nsColor: Appearance.focusRingColor ?? .controlAccentColor) },
                            set: { Appearance.focusRingColor = NSColor($0) }
                        ), supportsOpacity: false)
                        .labelsHidden()
                    }
                }
                LabeledContent("Ring thickness") {
                    HStack {
                        Slider(value: binding(get: { Double(Appearance.focusRingWidth) }, set: { Appearance.focusRingWidth = CGFloat($0.rounded()) }),
                               in: Double(Appearance.focusRingWidthRange.lowerBound)...Double(Appearance.focusRingWidthRange.upperBound), step: 1)
                            .frame(width: 180)
                        Text("\(Int(Appearance.focusRingWidth)) pt")
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }

            Toggle("Show workspace number when switching", isOn: binding(get: { Appearance.showsWorkspaceHUD }, set: { Appearance.showsWorkspaceHUD = $0 }))

            Toggle("Dim unfocused windows", isOn: binding(get: { Appearance.dimsUnfocusedWindows }, set: { Appearance.dimsUnfocusedWindows = $0 }))
            if Appearance.dimsUnfocusedWindows {
                LabeledContent("Dimming") {
                    HStack {
                        Slider(value: binding(get: { Appearance.dimAmount }, set: { Appearance.dimAmount = $0 }),
                               in: Appearance.dimRange)
                            .frame(width: 180)
                        Text("\(Int((Appearance.dimAmount * 100).rounded()))%")
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
    }

    /// Writes the setting, then applies it to the windows on screen.
    private func binding<Value>(get: @escaping () -> Value, set: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(get: get, set: { value in self.set { set(value) } })
    }

    private func set(_ change: () -> Void) {
        change()
        controller.appearanceChanged()
    }
}

private struct ShortcutRow: View {
    let action: Action
    let controller: AppController
    let recorder: ShortcutRecorder

    var body: some View {
        let _ = controller.revision
        let combo = controller.shortcuts.keymap.combo(for: action)
        let problem = controller.hotkeys.problems[action]
        let recording = recorder.action == action

        HStack {
            Text(action.title)
            Spacer()
            if let problem {
                Label(problem.message, systemImage: "exclamationmark.triangle.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.yellow)
                    .help("\(problem.message). Choose a different shortcut.")
            }
            Button {
                recording ? recorder.stop() : recorder.start(action)
            } label: {
                Text(recording ? String(localized: "Press keys…") : combo?.description ?? String(localized: "None"))
                    .monospaced()
                    .frame(minWidth: 96)
                    .foregroundStyle(combo == nil && !recording ? .secondary : .primary)
            }
            .buttonStyle(.bordered)
            .tint(recording ? .accentColor : nil)
            Button {
                controller.shortcuts.reset(action)
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(.borderless)
            .help("Restore the default (\(controller.shortcuts.keymap.defaultCombo(for: action)?.description ?? String(localized: "none")))")
            .disabled(combo == controller.shortcuts.keymap.defaultCombo(for: action))
        }
    }
}
