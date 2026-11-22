# UI Sandbox

A development harness for this template. It lets you build and test menus
**without playing through your game to reach them**: jump to any screen, drive
the menus with a fake gamepad, check other window sizes, and have the game
restart itself (and land back on the same screen) every time you save a file.

```
love . --sandbox            # from the project root
ultimate_ui\sandbox\run.bat  # same thing, from anywhere on Windows (needs love.exe on your PATH)
ultimate_ui/sandbox/run.sh   # same thing on Linux / macOS (needs `love` on your PATH)
set UI_SANDBOX=1 && love .  # same thing, via environment variable (cmd)
```

(The two run scripts assume `ultimate_ui/` sits in the project root. If you put it deeper,
use `love . --sandbox` from the project root.)

Plain `love .` runs the demo exactly as before. The sandbox only switches on
with the flag, and it wraps the game's `love.*` callbacks from the outside, so
none of the UI modules know it exists.

## The edit loop

1. `love . --sandbox`, press **F1**, press **4** to jump to the Keyboard menu.
2. Edit `ultimate_ui/ui/keyboard_menu.lua` in your editor and save.
3. The sandbox notices, restarts, and puts you back on the Keyboard menu.

Manual restart is **F5**. Auto-reload is on by default and toggled with **F6**.

## Hotkeys

All of these live in `ultimate_ui/sandbox/config.lua`, so you can rebind them.

| Key | What it does |
|-----|--------------|
| **F1** or `` ` `` | Help / state panel (cursor row, window size, rebind status, ...) |
| **1**-**8** *(panel open)* | Jump to: main, pause, settings, keyboard, controller, other, texture filter, in-game |
| **F2** | Cycle window sizes (1280x720, 1920x1080, 4:3, ultrawide, 640x360 minimum) |
| **F3** | Virtual gamepad: arrows = D-pad, Z/X/C/V = A/B/X/Y, Q/E = bumpers, Enter = Start |
| **F4** | On-screen event log (keys, clicks, pad presses, and the template's own `debuglog` lines) |
| **F5** | Restart, reloading all code, and return to the same screen |
| **F6** | Auto-reload on file save, on/off |
| **F7** | Preview the loading screen for 3 seconds |
| **F8** | Wipe saved settings (keybinds, controller, other, texture filter). Press twice. |
| **F9** | Open the save folder |
| **F10** | Hide / show the sandbox overlay |
| **F11** | Widget editor on/off (see below) |
| **F12** | Screenshot (without the overlay) into the save folder. Handy for your README. |

Sub-screens are opened the way a player would reach them: jumping to Keyboard
from the main menu stacks main > settings > keyboard, so Esc / B walks back
out through the real parents. Jump to "in-game" first and then to Keyboard
to test the same screen as opened from the pause menu.

While a keyboard rebind is waiting for a key, the sandbox ignores every key
(F-keys included), so you can bind them like any other key.

## Widget editor (F11)

Edit what a screen says and what color it is, then export it as a **drop-in replacement**. **Every page** is
editable: titles, buttons, row labels and hint lines on the main menu, pause menu, Settings, Keyboard,
Controller, Other, Textures and the loading screen, plus the in-game HUD (game title + stats side panel).
It works **in the game too**: press F11 while playing to edit the HUD, press Esc to pause and edit the pause menu.
Its hints appear bottom-left, next to the F1 hint.

Two kinds of page, one editor: the main menu, pause menu and HUD are *widget screens* (their layout is data,
so an export is the whole page file). The other pages keep their layout in code and describe only their
**texts** as data (`widgets.textPage`), so their export is **one file for all of them**, `ui/page_texts.lua`
(see below). You click and type the same way on both. Not editable: values that change at runtime
(`UNBOUND`, `ACTIVE`, `PRESS A KEY...`, the FPS counter) and the loading bar.

Edit mode **holds the loading screen open** (its timer freezes), so you have time to click its title.
Open it with **F7** (loading preview), or Ctrl+click PLAY.

| Action | How |
|--------|-----|
| Select a title / button | Click it (outlines show what's selectable) |
| Change its text | Just type. Backspace deletes, Ctrl+V pastes |
| Change its color | **Tab** to the COLOR field and type `#RRGGBB` or `rainbow`, or click a swatch |
| Reset it | **Del** |
| Deselect | **Esc** (while something is selected) |
| Pause / walk the menu | With nothing selected, **Esc**, the arrow keys and **Enter** still go to the game, so you can pause, move through the pause menu and resume without leaving edit mode |
| Press a button (use the game) | **Ctrl+click**: clicks the real PLAY / RESUME / EXIT TO MENU instead of selecting it |
| Export this page | **Ctrl+E** writes `exports/ultimate_ui/ui/main_menu.lua` (the page's own project path, under `exports/`). On Settings / Keyboard / Controller / Other / Textures / Loading it writes `exports/ultimate_ui/ui/page_texts.lua` instead |
| Export all pages | **Ctrl+Shift+E** writes every page, edits included (`page_texts.lua` once, for all the text pages) |
| Test background | **On by default** in the sandbox (blur 8, dim 30%; change `defaultBackground` in `ultimate_ui/sandbox/config.lua`, or set it to `nil` for none). **B** (nothing selected) cycles the images in `ultimate_ui/background/`, then off |
| Blur | **[** / **]** less / more (0 = sharp, 10 = heaviest, default 8) |
| Dim | **-** / **=** less / more of the menu's black overlay |
| Leave edit mode | **F11** |

### Export -> install -> integrate

1. Edit, then **Ctrl+E** (one page) or **Ctrl+Shift+E** (all pages).
2. Drag `exports/ultimate_ui` onto the project root and choose Replace (see [`exports/README.md`](../exports/README.md)).
3. The `ultimate_ui/ui/` files are now your custom pages; take them into your build.

An export of a widget screen is the whole screen file, so nothing else has to change.

`page_texts.lua` lists **only what you changed** on the hand-coded pages, as
`[page id]["title" | "hint" | "rows#<row key>"] = { text = "...", color = ... }` (a row key is an action name such as
`back`), and the pages read it at startup. It replaces the placeholder `ultimate_ui/ui/page_texts.lua`, which is
also where you can write the same entries by hand. Row keys are action names, not positions, so an edit keeps
following its row if you add or reorder rows. In text, `{config.title}` stays live;
`showIf = "config.subtitle"` hides a widget while that value is empty.

While something is selected, typed keys go to the editor (so number keys don't jump screens);
press Esc first to use the F1 jump keys. In edit mode every other key and plain click stays with the editor
(only Esc / arrows / Enter with nothing selected, and Ctrl+click, reach the game).

The test background / dim are only exported if you chose them yourself (B, [ ], - =); otherwise the page
keeps what its file says. If you did pick a background, ship the `ultimate_ui/background/` folder with your game.
Plain `love .` (no `--sandbox`) never shows the test background.

Edits are remembered in the save folder (`ultimate_ui_sandbox_edits.txt`), so they survive auto-reload and
restarts. Each saved edit also remembers what the file said when you made it: if the file changes
underneath (you installed an export, or edited it by hand), that edit is dropped and the file wins.
Export writes into the project's `exports/` folder (created if missing); if that isn't
possible (e.g. running from a `.love` file) it falls back to the save folder and tells you where.
`exports/` is ignored by the file watcher, so exporting never restarts the game.

## Things worth testing with it

- **Scaling:** F2 through every size. Layouts are built on `uiScale = height / 1080`.
- **Gamepad navigation and rebinding** without a controller (F3).
- **Both parents of a sub-screen** (opened from main vs. from pause).
- **Fresh-install behaviour:** F8 resets saved settings so you see first-run defaults.
- **Texture filter** switching live on the demo checkerboard.

## Using it in your own game

The sandbox ships inside the library folder (`ultimate_ui/sandbox/`) and is hooked up by
three lines at the bottom of `main.lua`:

```lua
local UI = require("ultimate_ui")
-- ...
if UI.hasSandbox() and UI.sandbox.requested(arg) then
    UI.sandbox.attach()
end
```

Copy `ultimate_ui/` into your game (anywhere), add those lines, and it works there too.
Nothing else is needed: the sandbox finds the library modules relative to itself.

**Optional: leave the sandbox out of release builds.** It does nothing unless
launched with `--sandbox`, so shipping it is harmless, but players don't need it.
Delete `ultimate_ui/sandbox/` and `UI.hasSandbox()` returns false, so no other edits
are needed.

## Limits

- Auto-reload needs LÖVE to run the project from a folder (`love .`), not a
  `.love` file or a fused build.
- The F1 panel's `uiScale` mirrors the formula in `main.lua`'s `updateUIScale()`.
  If you change that formula, change it in `sandbox/init.lua` too.
- The virtual gamepad stands in for buttons only. Analog sticks aren't simulated.
- Button hit-boxes aren't drawn: each menu keeps its layout private, and the
  sandbox deliberately doesn't reach into them.
- Save data and screenshots go to LÖVE's save folder for your `t.identity`
  (F9 opens it). `ultimate_ui_sandbox_session.txt` there is what remembers your screen.
