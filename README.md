# Glide

A scrolling window manager for macOS. Windows are laid out as columns on an endless horizontal strip; you glide left and right through them with the keyboard or the trackpad instead of juggling overlapping windows.

Keyboard-first: every action has a default shortcut out of the box, and every shortcut can be rebound.

Status: early development (milestone 1: one display, keyboard only, no animation).

## How it works

- Each standard window is a **column** on the strip. New windows open to the right of the focused column and take focus.
- Columns use preset widths (⅓, ½, ⅔, full) and fill the screen height, minus a 12 pt gap. A column can stack several windows vertically.
- Glide keeps the focused column fully on screen, scrolling the strip as little as possible. macOS doesn't let windows sit entirely off screen, so columns scrolled out of view are parked as 4 pt slivers at the left and right screen edges.
- Dialogs, sheets, panels, popovers, full-screen windows and fixed-size windows float: Glide leaves them alone. You can float or tile any window by hand.
- Closing, minimizing or hiding a window removes it from the strip; restoring it brings it back next to the focused column.
- Turning tiling off (or quitting Glide) moves every window to a sensible spot on screen, so nothing stays parked at the edges.

## Default shortcuts

| Action | Shortcut |
| --- | --- |
| Focus column left / right | ⌃⌥← / ⌃⌥→ |
| Focus window up / down (within a column) | ⌃⌥↑ / ⌃⌥↓ |
| Focus first / last column | ⌃⌥Home / ⌃⌥End (fn⌃⌥← / fn⌃⌥→ on laptops) |
| Move column left / right | ⌃⌥⇧← / ⌃⌥⇧→ |
| Move window up / down (within a column) | ⌃⌥⇧↑ / ⌃⌥⇧↓ |
| Consume or expel window left / right | ⌃⌥[ / ⌃⌥] |
| Cycle column width (⅓ → ½ → ⅔ → full) | ⌃⌥R (⌃⌥⇧R cycles backward) |
| Toggle full width | ⌃⌥F |
| Center focused column | ⌃⌥C |
| Toggle floating for the focused window | ⌃⌥V |
| Enable or disable tiling | ⌃⌥⇧T |

**Consume or expel** works like niri: a window alone in its column joins the bottom of the neighbouring column on that side. A window in a stack leaves its column and gets a new column on that side.

### Why these keys

- **One modifier pair for everything.** ⌃⌥ is the "Glide" chord, and adding ⇧ turns *focus* into *move*: ⌃⌥→ goes right, ⌃⌥⇧→ takes the window with you. That's the same split niri and PaperWM use with their Mod key, and both hands stay on the arrows.
- **Arrows, not letters, for direction.** Arrows need no vim knowledge, work on every keyboard layout, and are where your hand already is for navigation.
- **They don't steal text editing.** ⌥←/→ (word), ⌘←/→ (line), their ⇧ variants (selection), and ⌃A/E are untouched. Glide never binds a single modifier with an arrow.
- **They don't touch macOS.** ⌃←/→ (switch Spaces), ⌃↑/↓ (Mission Control / App Exposé), ⌘Space / ⌥⌘Space (Spotlight), ⌃Space / ⌃⌥Space (input sources), and the Globe-key window tiling shortcuts (🌐⌃ + arrows and friends) are all left alone. Glide also reads the system's enabled shortcuts at launch and flags any collision.
- **Mnemonic letters** for the rest: **R**esize, **F**ull, **C**enter, **T**iling. Floating uses ⌃⌥V, the same key niri uses. **[** and **]** point at the side the window goes to.
- **Other window managers.** AeroSpace's defaults use ⌥ alone (⌥H/J/K/L, ⌥1…), so the two don't collide. Raycast ships no window shortcuts by default. Rectangle-style apps default to ⌃⌥ + arrows/letters; if you still run one, rebind one of them (Glide is meant to replace them).
- **Terminal caveat:** in a terminal with "Option as Meta", ⌃⌥ letters are Emacs C-M- chords (C-M-f, C-M-r, …). If you live in Emacs, rebind those in Settings.

## Changing shortcuts

Open **Settings…** from the menu bar icon, click a shortcut and press the new combo. Esc cancels; ⌫ removes the shortcut. Shortcuts must include ⌃, ⌥ or ⌘ (F-keys may stand alone). Glide warns when a combo would shadow a text-editing or macOS shortcut. Assigning a combo that another Glide action uses moves it. Shortcuts are saved in `UserDefaults` (`dev.quackbyte.glide`, key `shortcuts`, overrides only), and **Restore Defaults** clears them.

If a shortcut can't be registered, the menu bar icon turns into a warning triangle. The menu and the Settings row then name the shortcut and the reason. macOS has no public API to see every other app's shortcuts: Glide detects collisions with enabled macOS shortcuts, but not with an app that grabs keys through an event tap or registers the same combo after Glide starts.

## Install and permissions

Requires macOS 27 or later (Glide follows the current Xcode 27 project defaults).

1. Build from source (below) or download a release once they exist.
2. Launch Glide. It lives in the menu bar (no Dock icon).
3. Grant **Accessibility** access when asked: **System Settings › Privacy & Security › Accessibility**, turn on Glide. Glide notices the grant within a second and starts tiling without a relaunch. If the permission is revoked later, Glide stops and asks again.

Glide uses Accessibility only to read window positions and move, resize and focus windows. It has no network code.

## Build from source

Open `Glide.xcodeproj` in Xcode and run the `Glide` scheme, or from Terminal:

```sh
xcodebuild -project Glide.xcodeproj -scheme Glide \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO test
```

The checked-in Xcode project is generated from [`project.yml`](project.yml) with XcodeGen (`xcodegen generate`). Signing is configured for bundle ID `dev.quackbyte.glide` and team `435MC3786D`, as in ClickType. Accessibility grants are tied to the code signature, so sign local builds with a stable identity (Developer ID or Apple Development) or you'll be asked again after every rebuild.

### Layout

- `Sources/GlideCore`: the pure-Swift layout engine (strip model, column widths, scroll offset, visibility and parking rules, keymap, restore planner). It only imports CoreGraphics, has no AppKit or Accessibility code, and is fully unit-tested in `Tests/GlideCoreTests`.
- `Sources/Glide`: the app: AX window tracking (`WindowManager`, `AXWindow`), Carbon hotkeys (`HotkeyCenter`), the menu bar item, the settings and onboarding windows.

Debug logging of the strip after every action: `log stream --level debug --predicate 'subsystem == "dev.quackbyte.glide"'`.

## License

MIT
