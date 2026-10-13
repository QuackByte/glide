# Glide

A scrolling window manager for macOS. Windows are laid out as columns on an endless horizontal strip; you glide left and right through them with the keyboard or the trackpad instead of juggling overlapping windows.

Keyboard-first: every action has a default shortcut out of the box, and every shortcut can be rebound.

Status: early development (milestone 1: one display).

## How it works

- Each standard window is a **column** on the strip. New windows open to the right of the focused column and take focus.
- Columns use preset widths (⅓, ½, ⅔, full) and fill the screen height, minus a gap (12 pt by default). A column can stack several windows vertically.
- **Resize with the mouse:** drag a tiled window's edge and its column keeps the new width; the strip reflows around it. ⌃⌥R / ⌃⌥⇧R then step to the next preset in that direction. Dragging a tiled window (rather than its edge) still snaps it back into its slot.
- Glide keeps the focused column fully on screen, scrolling the strip as little as possible. macOS doesn't let windows sit entirely off screen, so columns scrolled out of view are parked as 4 pt slivers at the left and right screen edges.
- A column can also be **tabbed** (⌃⌥W): it shows one window at full height under a tab bar, and the others wait as tabs. ⌃⌥↑/↓ switch tabs, ⌃⌥⇧↑/↓ reorder them, clicking a tab selects it, and consume/expel (⌃⌥[ / ⌃⌥]) adds or removes tabs. Tabs can be windows of different apps. macOS won't let a window go fully off screen, so hidden tabs wait in the bottom-right corner with a point showing.
- Dialogs, sheets, panels, popovers, full-screen windows and fixed-size windows float: Glide leaves them alone. You can float or tile any window by hand.
- **App rules** (Settings › App Rules): per app, always float, always tile, or let Glide decide, plus the width and workspace its new windows open with. A new window sent to another workspace by a rule takes you there. Float and tile apply at once to open windows; width and workspace apply to new ones. System Settings floats out of the box. ⌃⌥V on a single window still wins over its app's rule.
- Closing, minimizing or hiding a window removes it from the strip. A minimized window, or one whose app was hidden, returns to the spot it left: same workspace, same width, and back into its stack or tabs if they're still there.
- **Workspaces:** nine of them, each its own strip with its own scroll position. ⌃⌥1…9 switch workspaces and ⌃⌥⇧1…9 send the focused column to one. ⌃⌥PgUp/PgDn (fn⌃⌥↑/↓ on a laptop) step to the previous or next workspace, and adding ⇧ takes the column along. The menu bar icon shows the active workspace's number, and the menu lists the occupied ones. Inactive workspaces' windows wait in the bottom-right corner like hidden tabs, since macOS Spaces can't be driven reliably from outside. Focusing a window on another workspace (⌘-Tab, the Dock, a notification) switches to it. New windows open on the active workspace.
- **Workspace indicator:** the menu bar shows the numbers of the workspaces in use, with the active one filled in. Switching workspaces, or sending a column to one, also shows the numbers briefly near the bottom of the screen (turn it off under **Settings › Appearance**).
- **Overview (⌃⌥O):** a zoomed-out view of every workspace in use, one row each, with columns, stacks and tabs drawn to scale. Arrow keys or the pointer select a window; Return or a click goes to it, switching workspace if needed; Esc or a click on the background closes it. Start typing to filter by app name and window title (every word must match, case and accents ignored); the arrows then step through the matches, ⌫ edits the filter and Esc clears it. With **Screen Recording** access the tiles show live window previews (ScreenCaptureKit renders parked and hidden windows in full); without it they show app icons. Allow it from the button in the overview.
- Layout changes slide into place in about 120 ms (ease-out). Turn this off under **Settings › Animate window movement**.
- A **focus ring** outlines the focused window (your accent color, or any color you pick). Optionally, Glide **dims every other window**. Both are click-through overlay windows stacked just above and just below the focused window, since macOS doesn't let one app restyle another's windows. They hide while a floating window or Glide's own Settings has focus. The ring and tab bars disappear while windows slide and fade back in once they settle: each app redraws a moved window on its own schedule, so an overlay moved alongside would drift away from it.
- Set the **gap** between windows (0–40 pt), the ring color, and the dimming amount under **Settings › Appearance**. Changes apply immediately.
- Glide remembers the layout (column order, stacks, widths, and windows you floated or tiled by hand) when you quit it or turn tiling off. Windows that are still open come back exactly as they were. The layout resets after a restart, because macOS window IDs only last until then.
- Turning tiling off (or quitting Glide) moves every window to a sensible spot on screen, so nothing stays parked at the edges.
- **Crash recovery:** Glide runs a small watchdog (a second copy of itself started with `--watchdog`). If Glide exits without quitting cleanly, whether it crashed or was force quit, the watchdog brings every parked or hidden window back on screen. After a real crash (macOS wrote a crash report) it also relaunches Glide, at most once a minute, and Glide re-tiles from the saved layout.

## Trackpad

Swipe **three fingers** left or right to scroll the strip. It follows your fingers and rubber-bands past the ends. When you let go, momentum carries it on and it settles on a column edge, keeping focus on a column that's fully on screen. Vertical three-finger swipes (Mission Control, App Exposé) still go to macOS.

macOS uses three-finger horizontal swipes to switch Spaces by default, which would fire at the same time. Set **System Settings › Trackpad › More Gestures › Swipe between full-screen apps** to **four fingers** (Settings shows a reminder while it's still on three). Turn trackpad scrolling off under **Settings › Scroll with a three-finger swipe**.

Raw finger positions come from Apple's private MultitouchSupport framework, the same source BetterTouchTool and similar tools use.

## Default shortcuts

| Action | Shortcut |
| --- | --- |
| Focus column left / right | ⌃⌥← / ⌃⌥→ |
| Focus window up / down (within a column, or switch tabs) | ⌃⌥↑ / ⌃⌥↓ |
| Focus first / last column | ⌃⌥Home / ⌃⌥End (fn⌃⌥← / fn⌃⌥→ on laptops) |
| Move column left / right | ⌃⌥⇧← / ⌃⌥⇧→ |
| Move window up / down (within a column, or reorder tabs) | ⌃⌥⇧↑ / ⌃⌥⇧↓ |
| Consume or expel window left / right | ⌃⌥[ / ⌃⌥] |
| Cycle column width (⅓ → ½ → ⅔ → full) | ⌃⌥R (⌃⌥⇧R cycles backward) |
| Toggle full width | ⌃⌥F |
| Toggle tabbed column | ⌃⌥W |
| Center focused column | ⌃⌥C |
| Switch to workspace 1…9 | ⌃⌥1 … ⌃⌥9 |
| Send focused column to workspace 1…9 | ⌃⌥⇧1 … ⌃⌥⇧9 |
| Previous / next workspace | ⌃⌥PgUp / ⌃⌥PgDn (fn⌃⌥↑ / fn⌃⌥↓ on laptops) |
| Send column to previous / next workspace | ⌃⌥⇧PgUp / ⌃⌥⇧PgDn |
| Overview | ⌃⌥O |
| Toggle floating for the focused window | ⌃⌥V |
| Enable or disable tiling | ⌃⌥⇧T |

**Consume or expel** works like niri: a window alone in its column joins the bottom of the neighbouring column on that side. A window in a stack leaves its column and gets a new column on that side.

### Why these keys

- **One modifier pair for everything.** ⌃⌥ is the "Glide" chord, and adding ⇧ turns *focus* into *move*: ⌃⌥→ goes right, ⌃⌥⇧→ takes the window with you. That's the same split niri and PaperWM use with their Mod key, and both hands stay on the arrows.
- **Arrows, not letters, for direction.** Arrows need no vim knowledge, work on every keyboard layout, and are where your hand already is for navigation.
- **They don't steal text editing.** ⌥←/→ (word), ⌘←/→ (line), their ⇧ variants (selection), and ⌃A/E are untouched. Glide never binds a single modifier with an arrow.
- **They don't touch macOS.** ⌃←/→ (switch Spaces), ⌃↑/↓ (Mission Control / App Exposé), ⌘Space / ⌥⌘Space (Spotlight), ⌃Space / ⌃⌥Space (input sources), and the Globe-key window tiling shortcuts (🌐⌃ + arrows and friends) are all left alone. Glide also reads the system's enabled shortcuts at launch and flags any collision.
- **Mnemonic letters** for the rest: **R**esize, **F**ull, **C**enter, **T**iling, **O**verview (niri's key too). Tabs use ⌃⌥W like niri; ⌃⌥T would sit one ⇧ away from turning tiling off. Floating uses ⌃⌥V, the same key niri uses. **[** and **]** point at the side the window goes to.
- **Workspaces on the number row.** ⌃⌥ + digit leaves ⌃1…9 (macOS "Switch to Desktop N") and AeroSpace's ⌥1…9 alone.
- **Other window managers.** AeroSpace's defaults use ⌥ alone (⌥H/J/K/L, ⌥1…), so the two don't collide. Raycast ships no window shortcuts by default. Rectangle-style apps default to ⌃⌥ + arrows/letters; if you still run one, rebind one of them (Glide is meant to replace them).
- **Terminal caveat:** in a terminal with "Option as Meta", ⌃⌥ letters are Emacs C-M- chords (C-M-f, C-M-r, …). If you live in Emacs, rebind those in Settings.

## Changing shortcuts

Open **Settings…** from the menu bar icon, click a shortcut and press the new combo. Esc cancels; ⌫ removes the shortcut. Shortcuts must include ⌃, ⌥ or ⌘ (F-keys may stand alone). Glide warns when a combo would shadow a text-editing or macOS shortcut. Assigning a combo that another Glide action uses moves it. Shortcuts are saved in `UserDefaults` (`dev.quackbyte.glide`, key `shortcuts`, overrides only), and **Restore Defaults** clears them.

If a shortcut can't be registered, the menu bar icon turns into a warning triangle. The menu and the Settings row then name the shortcut and the reason. macOS has no public API to see every other app's shortcuts: Glide detects collisions with enabled macOS shortcuts, but not with an app that grabs keys through an event tap or registers the same combo after Glide starts.

## Install and permissions

Requires macOS 27 or later (Glide follows the current Xcode 27 project defaults).

1. Build from source (below) or download a release once they exist.
2. Launch Glide. It lives in the menu bar (no Dock icon). Turn on **Settings › Open at login** to start it with your Mac.
3. Grant **Accessibility** access when asked: **System Settings › Privacy & Security › Accessibility**, turn on Glide. Glide notices the grant within a second and starts tiling without a relaunch. If the permission is revoked later, Glide stops and asks again.

Glide uses Accessibility only to read window positions and move, resize and focus windows. Screen Recording is optional and only used to draw window previews in the overview. It has no network code.

## Build from source

Open `Glide.xcodeproj` in Xcode and run the `Glide` scheme, or from Terminal:

```sh
xcodebuild -project Glide.xcodeproj -scheme Glide \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO test
```

The checked-in Xcode project is generated from [`project.yml`](project.yml) with XcodeGen (`xcodegen generate`). Signing is configured for bundle ID `dev.quackbyte.glide` and team `435MC3786D`, as in ClickType. Accessibility grants are tied to the code signature, so sign local builds with a stable identity (Developer ID or Apple Development) or you'll be asked again after every rebuild.

### Layout

- `Sources/GlideCore`: the pure-Swift layout engine (strip model, workspaces, column widths, scroll offset, visibility and parking rules, keymap, restore planner). It only imports CoreGraphics, has no AppKit or Accessibility code, and is fully unit-tested in `Tests/GlideCoreTests`.
- `Design/glide-icon.svg`: the app icon source. Re-render the asset catalog with `for n in 16 32 64 128 256 512 1024; do rsvg-convert -w $n -h $n Design/glide-icon.svg -o Assets.xcassets/AppIcon.appiconset/icon_$n.png; done`.
- `Sources/Glide`: the app: AX window tracking (`WindowManager`, `AXWindow`), Carbon hotkeys (`HotkeyCenter`), the menu bar item, the settings and onboarding windows.

Debug logging of the strip after every action: `log stream --level debug --predicate 'subsystem == "dev.quackbyte.glide"'`.

## License

MIT
