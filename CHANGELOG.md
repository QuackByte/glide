# Changelog

What's new in each version of Glide for Mac. Glide shows the new entries once after it updates, and each release's notes on GitHub come from here, so write for people using Glide. Add an entry for every change worth knowing about under the next version before tagging it. Glide shows these notes in the app's language: the translations live in `changelog/CHANGELOG.<code>.md`, and a new entry must be translated in every one of them before tagging (`ChangelogTranslationTests` checks that they match this file).

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
