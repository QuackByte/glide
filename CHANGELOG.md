# Changelog

What's new in each version of Glide for Mac. Glide shows the new entries once after it updates, and each release's notes on GitHub come from here, so write for people using Glide. Add an entry for every change worth knowing about under the next version before tagging it. Glide shows these notes in the app's language: the translations live in `changelog/CHANGELOG.<code>.md`, and a new entry must be translated in every one of them before tagging (`ChangelogTranslationTests` checks that they match this file).

## 0.11.0 — 2026-10-20

### New

- **Tiled layout: ⌃⌥F makes the whole workspace full screen.** Every window fills the screen, with the focused one on top, until you press ⌃⌥F again. ⌃⌥ + arrows move through the windows without leaving it, and new windows open full screen too.

## 0.10.2 — 2026-10-19

### New

- **Tiled layout: ⌃⌥↑ and ⌃⌥↓ switch tabs first.** In a tab group, they switch tabs before moving to the tile in that direction.

### Fixes

- **Tiled layout: neighbours shrink to fit an app's minimum width.** When an app has a minimum width, the tiles beside it shrink to fit instead of overlapping, and Glide says why a resize stops at that width.

## 0.10.1 — 2026-10-19

### Fixes

- **Tab groups work in the Tiled layout.** ⌃⌥[ and ⌃⌥] add a window to a tab group (a tabbed column), and a tab can be moved out into its own tile, as they already did when scrolling.

## 0.10.0 — 2026-10-19

### New

- **Tiled is now a spiral layout.** ⌃⌥T switches a workspace to a layout where every window fits on screen: one window fills it, two share it as halves, and from the third on the last column splits again, alternating top and bottom with left and right. It uses 2 columns, or 3 with the new ⌃⌥G, which is also what Glide picks on ultrawide displays. Switching back to scrolling keeps your windows in the same order.
- **Move around a tiled workspace by direction.** ⌃⌥ + arrows focus the tile next to the focused one, and ⌃⌥⇧ + arrows swap it with that neighbour. Cycling width (⌃⌥R) changes how the focused tile splits the room with the tiles after it, and ⌃⌥F zooms a tile to fill the screen until you press it again.
- **Choose how many columns tiled workspaces use** in Settings › General › Tiled columns: Automatic (3 on ultrawide displays, else 2), 2 or 3.

### Changes

- **Sending a window to another workspace moves just that window.** ⌃⌥⇧1…9 and ⌃⌥⇧PgUp/PgDn used to take the whole column along, and now only the focused window goes, as a column of its own, while you stay on the workspace you're on.

## 0.9.4 — 2026-10-19

### Fixes

- **No more gaps after closing a window.** When a window closed or left, an app that ignored part of a move (such as Proton Mail) could stay where it was, leaving a gap. Glide now checks where windows actually end up and puts them right.

## 0.9.3 — 2026-10-19

### New

- **Tiled layout.** ⌃⌥T switches the current workspace between the scrolling strip and a tiled layout, where every column shares the screen so they all fit, without scrolling. Each workspace keeps its own layout, even after Glide restarts. Cycling a column's width (⌃⌥R) gives it a bigger or smaller share, dragging its edge resizes it, and ⌃⌥F still makes it full width until you press it again.
- **Choose the layout new workspaces start with** in Settings › General › Layout: Scrolling, as before, or Tiled. Workspaces you've switched with ⌃⌥T keep their own.

## 0.9.2 — 2026-10-16

### New

- **What's New speaks your language too.** The notes Glide shows after an update, and under What's New, are now in the same language as the rest of Glide.

## 0.9.1 — 2026-10-16

### New

- **Glide speaks your language.** Glide is now in French, German, Japanese, Simplified Chinese, Korean and Brazilian Portuguese, as well as English and Spanish, and follows the language macOS prefers.

## 0.9.0 — 2026-10-15

Glide for Mac now shares version numbers with Glide for Windows.

### New

- **Every shortcut on one page.** ⌃⌥/ shows them all; press it again, press Esc or click outside to close. It's also in the menu bar menu, at the top of Shortcuts.
- **Report a Problem**, in the menu bar menu and in Settings › General. Glide puts its recent log and settings in a zip, with window titles taken out, shows it in Finder, and opens a new issue on GitHub for you to describe what happened and attach the zip. Nothing is sent by itself.
- **Glide habla español.** When macOS is in Spanish, Glide is too. What's New stays in English.

### Fixes

- **Full screen stays full screen.** A window you make full screen, or a video or game that fills the display, is no longer pulled back into its column. Glide leaves it alone, hides the focus ring, dimming and tab bar over it, and lets the horizontal wheel and three-finger swipes on that display reach it. When it leaves full screen, it goes back to its column.

## 0.4.0 — 2026-10-14

### New

- **See where a dragged window will land.** While you drag a window, an outline in the focus ring color shows the column it would join, tab bar included. Over another display, a bar shows where it would go between that display's columns. No highlight means it will snap back.

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
