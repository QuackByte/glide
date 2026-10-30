# Glide

A scrolling window manager for macOS. Windows are laid out as columns on an endless horizontal strip; you glide left and right through them with the keyboard or the trackpad instead of juggling overlapping windows.

Keyboard-first: every action has a default shortcut out of the box, and every shortcut can be rebound.

Status: early development. There's also [Glide for Windows](https://github.com/QuackByte/glide-windows); [quackbyte.dev/glide](https://quackbyte.dev/glide/#platforms) shows what each one does.

## How it works

- Each standard window is a **column** on the strip. New windows open to the right of the focused column and take focus.
- Columns use preset widths (⅓, ½, ⅔, full; change them under **Settings › General › Column widths**, as percentages) and fill the screen height, minus a gap (12 pt by default). New columns open at the preset nearest ½. A column can stack several windows vertically.
- **Resize with the mouse:** drag a tiled window's edge and its column keeps the new width; the strip reflows around it. ⌃⌥R / ⌃⌥⇧R then step to the next preset in that direction. **Drag a window** (rather than its edge) onto a tab bar and it becomes a tab there; onto another window and it stacks into that window's column; onto another display and it joins that display's strip. While you drag, an outline in the focus ring color shows the column it would join, or a bar where it would land on another display. Dropped anywhere else, it snaps back into its slot. A floating window dropped on a tile joins the tiles.
- **Tiled layout:** ⌃⌥T switches the current workspace between the scrolling strip and a tiled layout, where every window fits on screen and nothing scrolls. Each workspace on each display keeps its own layout, even after a restart. **Settings › General › Layout** sets the layout of workspaces you haven't switched by hand, and applies at once. [Details below.](#tiled-layout)
- Glide keeps the focused column fully on screen, scrolling the strip as little as possible. macOS doesn't let windows sit entirely off screen, so columns scrolled out of view are parked as 4 pt slivers at the left and right screen edges.
- A column can also be **tabbed** (⌃⌥W): it shows one window at full height under a tab bar, and the others wait as tabs. ⌃⌥↑/↓ switch tabs, ⌃⌥⇧↑/↓ reorder them, clicking a tab selects it, and consume/expel (⌃⌥[ / ⌃⌥]) adds or removes tabs. Tabs can be windows of different apps. macOS won't let a window go fully off screen, so hidden tabs wait in the bottom-right corner with a point showing.
- Dialogs, sheets, panels, popovers, full-screen windows and fixed-size windows float: Glide leaves them alone. You can float or tile any window by hand.
- **Full screen stays full screen.** A tiled window that goes full screen (the green button, a video, a game) keeps its place in the strip but is left alone: no focus ring, dimming or tab bar over it, and the horizontal wheel and three-finger swipes on its display reach it instead of gliding the strip (⌃⌥ + wheel still glides). When it leaves full screen, it goes back to its column.
- **Scratchpad:** ⌃⌥⇧S turns the focused window (a terminal, notes, a chat) into the scratchpad and hides it. ⌃⌥S brings it out, floating in the middle of the focused display, and hides it again. Switching to it with ⌘-Tab or the Dock brings it out too. ⌃⌥⇧S on the scratchpad tiles it again.
- **App rules** (Settings › App Rules): per app, always float, always tile, or let Glide decide, plus the width and workspace its new windows open with. A new window sent to another workspace by a rule takes you there. Float and tile apply at once to open windows; width and workspace apply to new ones. System Settings floats out of the box. ⌃⌥V on a single window still wins over its app's rule.
- Closing, minimizing or hiding a window removes it from the strip. A minimized window, or one whose app was hidden, returns to the spot it left: same workspace, same width, and back into its stack or tabs if they're still there.
- **Workspaces:** nine of them, each its own strip with its own scroll position. ⌃⌥1…9 switch workspaces and ⌃⌥⇧1…9 send the focused window to one: just that window, as a column of its own right of the workspace's focused column (keeping the column's width if it was alone in it, else the default width), while you stay where you are. ⌃⌥PgUp/PgDn (fn⌃⌥↑/↓ on a laptop) step to the previous or next workspace, and adding ⇧ sends the focused window there. The menu bar icon shows the active workspace's number, and the menu lists the occupied ones. Inactive workspaces' windows wait in the bottom-right corner like hidden tabs, since macOS Spaces can't be driven reliably from outside. Focusing a window on another workspace (⌘-Tab, the Dock, a notification) switches to it. New windows open on the active workspace.
- **Displays:** every display is tiled, each with its own strip and its own nine workspaces. Shortcuts act on the focused display: the one with the focused window, else the one under the pointer. ⌃⌥⌘←/→ move focus to the display on that side, and ⌃⌥⌘⇧←/→ send the focused column there. New windows join the display they open on; drag a tiled window onto another display to move it there. A column scrolled toward a neighbouring display waits hidden instead of peeking onto it, and hidden windows wait in whichever bottom corner faces away from other displays. If a display goes away, its windows move to the main one, workspace by workspace.
- **Workspace indicator:** the menu bar shows the numbers of the workspaces in use, with the active one filled in. Switching workspaces, or sending a window to one, also shows the numbers briefly near the bottom of the screen (turn it off under **Settings › Appearance**).
- **Overview (⌃⌥O):** a zoomed-out view of every workspace in use, one row each, with columns, stacks and tabs drawn to scale. Arrow keys or the pointer select a window; Return or a click goes to it, switching workspace if needed; Esc or a click on the background closes it. Start typing to filter by app name and window title (every word must match, case and accents ignored); the arrows then step through the matches, ⌫ edits the filter and Esc clears it. With **Screen Recording** access the tiles show live window previews (ScreenCaptureKit renders parked and hidden windows in full); without it they show app icons. Allow it from the button in the overview.
- **Focus follows the mouse** (off by default, **Settings › General**): resting the pointer on a tiled window focuses it. Only windows fully on screen and in front count, so the strip never scrolls under the pointer, and floating windows, menus and the Dock keep it.
- Layout changes slide into place in about 120 ms (ease-out). Turn this off under **Settings › Animate window movement**.
- A **focus ring** outlines the focused window (your accent color, or any color you pick). Optionally, Glide **dims every other window**. Both are click-through overlay windows stacked just above and just below the focused window, since macOS doesn't let one app restyle another's windows. They hide while a floating window or Glide's own Settings has focus. The ring and tab bars disappear while windows slide and fade back in once they settle: each app redraws a moved window on its own schedule, so an overlay moved alongside would drift away from it.
- Set the **gap** between windows (0–40 pt), the ring color, and the dimming amount under **Settings › Appearance**. Changes apply immediately.
- Glide remembers the layout (column order, stacks, widths, each workspace's scrolling or tiled layout with its tiled column count and splits, and windows you floated or tiled by hand) when you quit it or turn tiling off. Windows that are still open come back exactly as they were. After the Mac restarts, window IDs are new, so Glide finds windows again by their app and title as they open, for 10 minutes after it starts: each goes back to its workspace, width and stack, next to whichever of its old neighbours are back.
- Turning tiling off (or quitting Glide) moves every window to a sensible spot on screen, so nothing stays parked at the edges.
- **Crash recovery:** Glide runs a small watchdog (a second copy of itself started with `--watchdog`). If Glide exits without quitting cleanly, whether it crashed or was force quit, the watchdog brings every parked or hidden window back on screen. After a real crash (macOS wrote a crash report) it also relaunches Glide, at most once a minute, and Glide re-tiles from the saved layout.

## Tiled layout

⌃⌥T switches the current workspace between the scrolling strip and a tiled layout, where every window fits on screen and nothing scrolls. Windows are tiled in order, like a dwindle or spiral layout: one window fills the screen, two share it as columns, and from the third on the last column splits again, top and bottom, then left and right, alternating. With two columns (the default) that gives `[1][2]`, `[1][2 over 3]`, `[1][2 over (3 | 4)]`…; with three, `[1][2][3]`, `[1][2][3 over 4]`, `[1][2][3 over (4 | 5)]`…. ⌃⌥G switches the workspace between 2 and 3 columns. **Settings › General › Tiled columns** sets how many columns workspaces you haven't switched by hand use: Automatic (3 on ultrawide displays, at least twice as wide as tall, and 2 elsewhere), 2 or 3.

- **Order**: tiles follow the strip's columns left to right. Switching to tiled gives every window of a stack its own column (a tabbed column stays one tile, with its tab bar on top); switching back gives every column the default width. The order and focus survive both ways. A new window becomes the next tile after the focused one, and a window dropped onto another's column becomes the next tile too.
- **⌃⌥ + arrows** focus the tile next to the focused one in that direction, and **⌃⌥⇧ + arrows** swap it with that neighbour. ⌃⌥Home / End focus the first / last tile. ⌃⌥[ and ⌃⌥] and ⌃⌥C do nothing, and neither do the trackpad swipe or the mouse wheel.
- **⌃⌥R** steps the split between the focused tile and the rest through ⅓, ½ and ⅔ (the last tile changes the split before it). Dragging a tile's edge moves the same split; a tile with no split to move snaps back. The splits start over when a window opens or closes.
- **⌃⌥F** zooms the workspace: every tile fills the screen, stacked, with the focused one on top, until you press it again. Since only one window shows, the arrows go in order instead of by direction: ⌃⌥→ and ⌃⌥↑ focus the next window (a tab group's tabs one by one), ⌃⌥← and ⌃⌥↓ the one before, wrapping around at the ends, and with ⇧ they move the focused tile one place. New windows open zoomed too, and only the focused tab group shows its tab bar. ⌃⌥R and dragging an edge do nothing while zoomed.
- Windows with a minimum width that doesn't fit their tile get that width, overlapping their neighbour if they have to.
- Each workspace's column count and splits are remembered with its layout.

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
| Back to the previously focused window (again to come back) | ⌃⌥` |
| Move column left / right | ⌃⌥⇧← / ⌃⌥⇧→ |
| Move window up / down (within a column, or reorder tabs) | ⌃⌥⇧↑ / ⌃⌥⇧↓ |
| Consume or expel window left / right | ⌃⌥[ / ⌃⌥] |
| Cycle column width (⅓ → ½ → ⅔ → full); tiled: the split | ⌃⌥R (⌃⌥⇧R cycles backward) |
| Toggle full width; tiled: zoom every tile | ⌃⌥F |
| Toggle tabbed column | ⌃⌥W |
| Switch the workspace between scrolling and tiled | ⌃⌥T |
| Switch the tiled workspace between 2 and 3 columns | ⌃⌥G |
| Center focused column | ⌃⌥C |
| Even out the columns on screen so they share it equally; tiled: reset the splits | ⌃⌥E |
| Switch to workspace 1…9 | ⌃⌥1 … ⌃⌥9 |
| Send focused window to workspace 1…9 | ⌃⌥⇧1 … ⌃⌥⇧9 |
| Previous / next workspace | ⌃⌥PgUp / ⌃⌥PgDn (fn⌃⌥↑ / fn⌃⌥↓ on laptops) |
| Send window to previous / next workspace | ⌃⌥⇧PgUp / ⌃⌥⇧PgDn |
| Back to the last workspace (again to come back) | ⌃⌥⇥ |
| Focus display left / right | ⌃⌥⌘← / ⌃⌥⌘→ |
| Send column to display left / right | ⌃⌥⌘⇧← / ⌃⌥⌘⇧→ |
| Overview | ⌃⌥O |
| Show every shortcut | ⌃⌥/ |
| Toggle floating for the focused window | ⌃⌥V |
| Show or hide the scratchpad | ⌃⌥S |
| Make the focused window the scratchpad (on the scratchpad: tile it again) | ⌃⌥⇧S |
| Enable or disable tiling | ⌃⌥⇧T |

**Consume or expel** works like niri: a window alone in its column joins the bottom of the neighbouring column on that side. A window in a stack leaves its column and gets a new column on that side.

### Why these keys

- **One modifier pair for everything.** ⌃⌥ is the "Glide" chord, and adding ⇧ turns *focus* into *move*: ⌃⌥→ goes right, ⌃⌥⇧→ takes the window with you. That's the same split niri and PaperWM use with their Mod key, and both hands stay on the arrows.
- **Arrows, not letters, for direction.** Arrows need no vim knowledge, work on every keyboard layout, and are where your hand already is for navigation.
- **They don't steal text editing.** ⌥←/→ (word), ⌘←/→ (line), their ⇧ variants (selection), and ⌃A/E are untouched. Glide never binds a single modifier with an arrow.
- **They don't touch macOS.** ⌃←/→ (switch Spaces), ⌃↑/↓ (Mission Control / App Exposé), ⌘Space / ⌥⌘Space (Spotlight), ⌃Space / ⌃⌥Space (input sources), and the Globe-key window tiling shortcuts (🌐⌃ + arrows and friends) are all left alone. Glide also reads the system's enabled shortcuts at launch and flags any collision.
- **Mnemonic letters** for the rest: **R**esize, **F**ull, **C**enter, **T**iled, **G**rid of columns, **O**verview (niri's key too). ⌃⌥T switches the layout and sits one ⇧ away from ⌃⌥⇧T, which turns tiling off. Tabs use ⌃⌥W like niri. Floating uses ⌃⌥V, the same key niri uses. **[** and **]** point at the side the window goes to.
- **Workspaces on the number row.** ⌃⌥ + digit leaves ⌃1…9 (macOS "Switch to Desktop N") and AeroSpace's ⌥1…9 alone.
- **Other window managers.** AeroSpace's defaults use ⌥ alone (⌥H/J/K/L, ⌥1…), so the two don't collide. Raycast ships no window shortcuts by default. Rectangle-style apps default to ⌃⌥ + arrows/letters; if you still run one, rebind one of them (Glide is meant to replace them).
- **Terminal caveat:** in a terminal with "Option as Meta", ⌃⌥ letters are Emacs C-M- chords (C-M-f, C-M-r, …). If you live in Emacs, rebind those in Settings.

## Changing shortcuts

**Settings › Shortcuts › Glide modifier** switches every default from ⌃⌥ to ⌥ alone, as AeroSpace and similar apps use (⌥→ focuses right, ⌥⇧→ moves, ⌥⌘→ goes to the next display, and the mouse wheel follows too). It's easier to press, but ⌥ + arrows then stop jumping by word in text fields, and ⌥ + letters and digits stop typing characters like é, ñ or ©. Shortcuts you changed by hand stay as they are, and win over a new default on the same keys. The choice is saved under the `glideModifier` key. **Direction keys** next to it swaps the arrows of the focus and move shortcuts for H J K L, as in vim (display shortcuts keep the arrows); it's saved under `directionKeys`.

Open **Settings…** from the menu bar icon, click a shortcut and press the new combo. Esc cancels; ⌫ removes the shortcut. Shortcuts must include ⌃, ⌥ or ⌘ (F-keys may stand alone). Glide warns when a combo would shadow a text-editing or macOS shortcut. Assigning a combo that another Glide action uses moves it. Shortcuts are saved in `UserDefaults` (`dev.quackbyte.glide`, key `shortcuts`, overrides only), and **Restore Defaults** clears them.

If a shortcut can't be registered, the menu bar icon turns into a warning triangle. The menu and the Settings row then name the shortcut and the reason. macOS has no public API to see every other app's shortcuts: Glide detects collisions with enabled macOS shortcuts, but not with an app that grabs keys through an event tap or registers the same combo after Glide starts.

## Command line and URLs

Every action can also run from a terminal or a link, for scripts, Raycast, Alfred, Stream Deck or Shortcuts. **Settings › General › Command line tool** copies the command that links Glide's executable as `glide` in `/usr/local/bin`:

```sh
glide focus-column-left
glide focus-workspace 3      # same as focus-workspace-3
glide toggle-overview
glide list                   # every command and what it does
open -g glide://focus-workspace-3
```

Command names are the actions in kebab case. Glide has to be running; the command hands the action to it and exits (64 for an unknown command, 69 if Glide isn't running).

## Install and permissions

Requires macOS 27 or later (Glide follows the current Xcode 27 project defaults).

1. Download the [latest release](https://github.com/QuackByte/glide/releases/latest) (or from [quackbyte.dev/glide](https://quackbyte.dev/glide/)), unzip it and move **Glide.app** to Applications. Or build from source (below).
2. Launch Glide. It lives in the menu bar (no Dock icon). Turn on **Settings › Open at login** to start it with your Mac.
3. Grant **Accessibility** access when asked: **System Settings › Privacy & Security › Accessibility**, turn on Glide. Glide notices the grant within a second and starts tiling without a relaunch. If the permission is revoked later, Glide stops and asks again.

Glide uses Accessibility only to read window positions and move, resize and focus windows. Screen Recording is optional and only used to draw window previews in the overview.

## Report a Problem

**Report a Problem…** in the menu bar menu (or under **Settings › General**) puts Glide's recent log, settings and layout in a zip, with window titles taken out, shows it in Finder, and opens a new GitHub issue for you to describe what happened and attach the zip. Nothing is sent by itself.

## Languages

Glide is in English, Spanish, French, German, Japanese, Simplified Chinese, Korean and Brazilian Portuguese, following the language order in **System Settings › General › Language & Region**. What's New is translated too: `CHANGELOG.md` is the English source and `changelog/CHANGELOG.<code>.md` holds each translation, and a release not yet translated shows in English.

Translations live in the two String Catalogs, `Sources/Glide/Localizable.xcstrings` and `Sources/GlideCore/Localizable.xcstrings`. `LocalizationTests` fails if a string is missing in any language or changes its placeholders, and `ChangelogTranslationTests` fails if a translated changelog's releases, sections, entries or links differ from `CHANGELOG.md`'s.

## Updates

Glide updates itself with [Sparkle](https://sparkle-project.org). Once a day it reads `appcast.xml` from this repository's latest release, and offers a newer version (or installs it, with **Settings › Updates › Download and install updates automatically**). Every update is notarized by Apple and EdDSA-signed; Glide checks the signature against the public key in `Sources/Glide/Info.plist` before installing. **Check for Updates…** in the menu checks right away. That request is Glide's only network access, and it sends nothing but the request itself.

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

### Releasing

Push a tag like `v0.2.0` on `main`. `.github/workflows/ci-release.yml` builds, signs with the Developer ID, notarizes, and publishes a release with `Glide-<version>-macOS.zip` and the `appcast.xml` that existing copies update from. It uses:

- QuackByte organization secrets shared with this repository: `APPLE_API_KEY_ID`, `APPLE_API_ISSUER` and `APPLE_API_KEY_P8` (base64; App Store Connect API key, for notarization), and `MAC_CSC_LINK` and `MAC_CSC_KEY_PASSWORD` (the Developer ID Application certificate as base64 .p12, and its password).
- Repository secret `SPARKLE_PRIVATE_KEY`: Sparkle's EdDSA private key, kept in the maintainer's login keychain under the account `dev.quackbyte.glide`. Export it with Sparkle's `generate_keys --account dev.quackbyte.glide -x <file>`. If it's lost, existing copies can't verify updates any more, so keep a backup.

Debug logging of the strip after every action: `log stream --level debug --predicate 'subsystem == "dev.quackbyte.glide"'`.

## License

MIT
