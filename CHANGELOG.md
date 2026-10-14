# Changelog

What's new in each version of Glide for Mac. Glide shows the new entries once after it updates, and each release's notes on GitHub come from here, so write for people using Glide. Add an entry for every change worth knowing about under the next version before tagging it.

## 0.3.0 — 2026-10-14

### New

- **Every display is tiled.** Each display has its own strip and its own nine workspaces. Shortcuts act on the display with the focused window, or the one under the pointer. ⌃⌥⌘←/→ move focus to the display on that side, and ⌃⌥⌘⇧←/→ send the focused column there. New windows join the display they open on.
- **Drag a window where you want it.** Drop it on a tab bar and it becomes a tab there; drop it on another window and it stacks into that window's column; drop it on another display and it joins that display's strip. A floating window dropped on a tile joins the tiles. Anywhere else, it snaps back as before.
- **The mouse wheel glides the strip.** Tilt the wheel (or use a thumb wheel) to move along the strip, or hold ⌃⌥ while scrolling. Choose when tilting does this under Settings › Horizontal mouse wheel: Always, With ⌃⌥, or Off.
- **Apps reopen where you keep them.** Glide remembers each app's display, workspace, column width and place on the strip, and opens its new windows there. Turn it off, or forget every place, in Settings.
- **Focus ring thickness**, from 1 to 12 points, in Settings › Appearance.

## 0.2.1 — 2026-10-14

### New

- **What's new.** After an update, Glide shows what changed. Find it again in the menu bar under **What’s New**.

## 0.2.0 — 2026-10-14

### New

- **Glide keeps itself up to date.** It checks for a new version once a day and offers it, or installs it for you if you turn that on in Settings › Updates. **Check for Updates…** in the menu checks right away. Every update is signed and notarized by Apple.
- **Glide is open source**, under the MIT license: [github.com/QuackByte/glide](https://github.com/QuackByte/glide).

## 0.1.1 — 2026-10-13

### Fixes

- Quitting and reopening Chrome, T3 Code or another Chromium or Electron app left focus on the previous window, and the new window sat off screen. It's now focused and scrolled into view.

## 0.1.0 — 2026-10-13

The first release of Glide for Mac.

- **Columns on a scrolling strip**: ⅓, ½, ⅔ and full widths, stacks, and tabbed columns, with a shortcut for everything.
- **Nine workspaces**, an overview with live previews, three-finger swipes, a focus ring, app rules, and a watchdog that puts your windows back if Glide crashes.
