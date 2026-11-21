# PATCH NOTES

Project: LOVE2d Ultimate UI Template
Status: shared menu background confirmed working by the author in the sandbox (`love . --sandbox`).

This file is the running record of what changed and why, so work can pick up where it left off.

---

## Patch: demo game, new reference screenshots, cleaner main.lua + nested `ultimate_ui/`

1. **Added the SoBlock demo game, in its own repository** (SOBLOCK-REPO-URL). It contains the SoBlock installer
   (`SoBlockSetup.exe`), a professional `README.md` and a MaynGames 2026 `LICENSE.md`. SoBlock is a polished,
   playable block-stacking game that runs an early build of the template, so people can see the UI and the
   editing tool inside a real game. The license states it is for experiencing the editing tool only, and is
   NOT for redistribution, resale or use in other projects (the template and its editor are for that). It is
   kept out of this repo so clones of the template stay small. The README links to it.
2. **Improved reference screenshots, and fixed the main README to use them.** `reference_screenshots/` now holds
   exactly these eight images: `ui_editor_open`, `ui_editor_open_2`, `ui_editor_closed_2`,
   `ui_editor_keyboard_binds`, `ui_editor_controller_binds`, `ui_editor_other_settings`,
   `ui_editor_texture_settings_crt_off`, `ui_editor_texture_settings_crt_on`. The README's Screenshots section
   was rewritten as four two-column rows that reference only those files (the old `open_3`, `open_4_*`, `open_6`
   and `open_7` links are gone). The README also gained a "Demo game: SoBlock" section and the folder layout
   lists `reference_screenshots/`.
3. **`main.lua` makes explicit calls, and everything is nested under `ultimate_ui/` for easy integration.**
   `main.lua` talks to the library only through `local UI = require("ultimate_ui")` (`UI.init()`,
   `UI.configure{...}`, `UI.ui`, `UI.state`, `UI.input`, ...) and is the reference for hooking up the draw,
   keyboard, mouse and gamepad callbacks. The whole library lives in the one `ultimate_ui/` folder, so a game
   copies that single folder in with nothing to merge and nothing in its project root to collide with.
4. **Sandbox overlay fix.** The F1 help panel and the bottom-left strip could disappear on every screen. The
   sandbox saved its "hide overlay" (F10) state and restored it on each launch, and all versions share one save
   folder. Now `hidden` is never restored, and pressing F1 un-hides the overlay and opens the panel
   (`ultimate_ui/sandbox/init.lua`).

**Files touched:** `reference_screenshots/*`, `README.md`, `PATCH-NOTES.md`,
`main.lua`, `ultimate_ui/sandbox/init.lua`.

**Not verified in real LOVE:** the sandbox fix was checked only with a stubbed LOVE harness (the strip draws
on the main menu and in the game state). Please run `love . --sandbox`, press F10 to hide, quit, relaunch, and
confirm the strip and F1 panel are back.

---

## Patch: pause + in-game editing fix (sandbox editor)

**Problem (in the play state):** with the editor on (F11) the sandbox swallowed every key and click, including
Esc and the pause-menu buttons, and the pause menu and HUD were hand-drawn, so the editor could not see them
("this page isn't widget-based"). Result: Esc did nothing, an opened pause menu could not be resumed or left,
and text / color editing did nothing in the game.

**Fix**

* **Pause menu is a widget screen** (`ui/pause_menu.lua`, id `pauseMenu`): title and buttons can be edited
and exported like the main menu. Buttons are now 400x60 (same as the main menu) instead of 260x50.
* **In-game HUD is a widget screen** (new `ui/hud_screen.lua`, id `hud`, `static = true`): the game title and
the stats side panel can be edited (text, color) in the game and exported. New `widgets` support: a `stats`
widget (rows fed by the game via `widgets.setData`) and a `static` screen flag (no backdrop, no pop-in).
* **New `ui.drawHUD(stats, w, h, uiScale)`** draws title + stats from that screen; `main.lua` uses it.
`drawGameTitle` / `drawSidePanel` stay for projects that draw their own HUD.
* **Edit mode no longer traps you:** with nothing selected, Esc / arrows / Enter reach the game (pause, walk
the pause menu, resume); **Ctrl+click** presses the real button. Esc while something is selected still
just deselects.
* The HUD is not editable while a non-widget menu (Settings, ...) covers it, and has no background / dim.

**Files touched:** `main.lua`, `ultimate_ui/ui/{widgets,hud,hud_screen(new),pause_menu,init}.lua`,
`ultimate_ui/sandbox/{editor,init}.lua`, sandbox + exports READMEs.

**Not verified:** written without a LOVE runtime (nothing here has been run). Please check in
`love . --sandbox`: play -> F11 -> click the title / a stat row and change text and color; Esc opens the pause
menu with edit mode on; Ctrl+click RESUME; Ctrl+click EXIT TO MENU; Ctrl+Shift+E exports `hud_screen.lua`.

---

## Patch: placeholder game canvas (1920x1080, 16:9)

The demo "game" in `main.lua` was a small coloured checkerboard square (sized for the game the
template was first made for). It is now a proper full-canvas placeholder.

* **Fixed canvas:** the world is drawn into one `GAME_W x GAME_H` = 1920x1080 canvas (16:9, a normal 1080p
canvas). Both numbers are constants at the top of the "YOUR GAME" block in `main.lua`.
* **Fit to window:** the canvas is scaled to the largest size that keeps 16:9 and centred, with bars
on the sides or top when the window is not 16:9 (try F2 in the sandbox: 1024x768, 800x600, ultrawide).
* **Placeholder drawing:** a black-and-grey checkerboard fills the whole canvas: 120 px squares,
exactly 16 x 9 of them. Shades are `BLACK = 0.04` and `GREY = 0.30`.
* **Movement:** the bound movement keys now scroll the board (400 px/s, 800 with sprint) so input is still
visible. JUMPS and TIME still count as before.
* **Texture filter:** the canvas is made with `texture_filter_manager.newCanvas`, so Settings -> Textures
(Sharp / Smooth / Hybrid) changes how the canvas is scaled to the window, live. It is most visible when the
window is not 1920x1080.
* **CRT filters:** the canvas is drawn inside the CRT pass like everything else; the world is rendered with
`push("all")` / `pop()` so the CRT canvas is restored afterwards.
* **HUD:** the side panel gained a `CANVAS 1920x1080` row. Menus and HUD are unchanged: they are laid out at
the window size with `uiScale`, not on the 1920x1080 canvas.
* **Files touched:** `main.lua` (demo block only), `README.md` (one sentence).

Not verified: written without a LOVE runtime. Check that the board fills the window at 1920x1080, that bars
appear at 1024x768, and that Smooth vs Sharp visibly changes the canvas edges at 1280x720.

---

## Patch: startup checks + warning logger + console output

Adds a self-check that runs at startup and reports setup mistakes as WARNING lines in the console,
instead of the menus quietly looking wrong.

### What it checks (`ultimate_ui/checks.lua`)

|Check|Warns when|
|-|-|
|Menu background|`config.menuBackground` has no image, the file is not found (lists the images that are in `background/`), the file cannot be decoded, or `blur` / `dim` are out of range|
|Fonts|no `.ttf` / `.otf` in `fonts/` (falls back to LOVE's built-in font), the folder is missing, or `config.font` names a file that is not there|
|Screen filters|`crt_filters/` has no `.lua` files, none of the filters listed in `crt_manager.lua` exist, one listed filter file is missing, or a filter file exists that `crt_manager.lua` does not list|
|Intro videos|a path in `config.introVideos` is missing, or is not `.ogv` (LOVE 11 only plays Ogg Theora)|
|Save folder|the save folder cannot be written to, so settings would not persist|
|LOVE version|the running LOVE is not 11.x|
|Sandbox|`sandbox/` is still inside a fused (packaged) build|

An info line (not a warning) is printed when several fonts are present and `config.font` is not set.
The run ends with `startup checks: all OK` or `startup checks: N warning(s)`.

### Logger (`ultimate_ui/debuglog.lua`)

* New `debuglog.warn(fmt, ...)`, `debuglog.warnOnce(key, fmt, ...)` and the list `debuglog.warnings`.
* `warn` goes through `debuglog.log`, so the sandbox's on-screen log (F4) picks warnings up automatically.
* stdout is set to unbuffered, so lines appear immediately in a console, even right before a crash.
* Existing failure messages now use `warn`: background image load failure, audio load failure,
intro video load failure, CRT filter load / init failure. The background warning used to be a bare `print`.

### Console

Output uses `print()`, so it shows in the LOVE console build (`lovec.exe`), with `t.console = true` in
`conf.lua` (Windows; added as `false` with a comment), or in a terminal on Linux / macOS.

### Files touched

`checks.lua` (new), `debuglog.lua`, `init.lua` (`UI.checks`, called at the end of `UI.init()`),
`config.lua` (`startupChecks = true`), `ui/background.lua`, `audio.lua`, `intro_sequence.lua`,
`crt_manager.lua`, `conf.lua`, `README.md` (new "Startup checks & console output" section).

### Not verified

Written without a LOVE runtime available, so it has not been run. Please run `love . --sandbox` once
normally, then try each case: rename the background image, empty `fonts/`, empty `crt_filters/`.

---

## Patch: drop-in `ultimate_ui/` library + shared menu background

### 1\. Restructure into a self-contained library

The whole UI system now lives in one folder, `ultimate_ui/`, so it can be copied into any LÖVE
project without colliding with the project's own `input.lua`, `audio.lua`, `config.lua` or `ui/`.
`main.lua` and `conf.lua` stay at the repo root as the demo only.

* **Single entry point:** `ultimate_ui/init.lua`, used as `local UI = require("ultimate_ui")`.
* **Lazy loading:** modules load on first use (`UI.ui`, `UI.state`, `UI.input`, `UI.audio`, `UI.fonts`,
`UI.keybinds`, `UI.controller`, `UI.menu_input`, `UI.other_settings`, `UI.textures`, `UI.crt`,
`UI.loading`, `UI.intro`, `UI.widgets`, `UI.log`, `UI.sandbox`). File names also work
(`UI.ui_state`, `UI.crt_manager`, ...).
* **`UI.init()`:** initialises every stateful module in the right order (texture filter first).
* **`UI.configure{...}`:** overrides `config.lua` values from game code.
* **`UI.path(sub)`:** path of a file inside the folder, from the game root.
* **Relocatable:** every file finds its siblings relative to its own module name
(`local ROOT = (...):match(...)`), so the folder can be renamed or moved without edits.
* **No globals:** nothing is installed in the global namespace.
* **Moved under `ultimate_ui/`:** `ui/`, `sandbox/`, `fonts/`, `background/`, `crt_filters/` and all
top-level modules (git sees these as renames).
* **`sandbox/` is dev-only:** delete it before shipping; `main.lua` skips it automatically
(`UI.hasSandbox()`).
* **`main.lua` rewritten:** it now uses the single UI entry point and is the reference for hooking up
the draw / keyboard / mouse / gamepad callbacks.
* **Docs:** README rewritten (quick start, module table, folder layout); the sandbox, fonts,
background and exports READMEs were updated for the new paths.

### 2\. Shared menu background (new feature)

**Problem:** only widget-based screens (the main menu) could draw a background. Pause, settings,
keyboard, controller, other and texture were hand-drawn with a flat 70% black overlay, so the picture
vanished as soon as you left the main menu.

**Fix:** one background shared by every menu page.

```lua
-- ultimate_ui/config.lua
menuBackground = { image = "ultimate_ui/background/my_image.png", blur = 8, dim = 0.3 },
-- or from game code:
UI.configure{ menuBackground = { image = UI.path("background/my_image.png"), blur = 8, dim = 0.3 } }
```

* `image` is a path from the game root, scaled to cover the screen.
* `blur` runs from 0 (sharp) to 10.
* `dim` is the black overlay alpha (0..1) drawn over the picture on every page.
* The default is `nil` (none), so projects that don't set it look exactly as before.

Pages that draw it: main, pause, settings, keyboard, controller, other, texture and the loading screen.
On the loading screen the picture carries through PLAY, loading and into the game. With no shared
background it is solid black as before.

### 3\. How it works (files touched for the background)

|File|Change|
|-|-|
|`ultimate_ui/config.lua`|New `menuBackground = nil` field, documented.|
|`ultimate_ui/ui/background.lua`|Added `background.shared()` (reads `config.menuBackground`) and `background.setShared(spec)`.|
|`ultimate_ui/ui/helpers.lua`|Added `helpers.drawMenuBackdrop(w, h, fallbackDim)`: draws the shared background, then the black dim. With a shared background the dim is its `dim`, otherwise `fallbackDim`. Requires `ui.background`.|
|`ui/pause_menu.lua`, `settings_menu.lua`, `keyboard_menu.lua`, `controller_menu.lua`, `other_settings_menu.lua`, `texture_filter_menu.lua`|The hard-coded `0,0,0,180/255` overlay was replaced by `helpers.drawMenuBackdrop(w, h, 180/255)`.|
|`ui/loading_screen.lua`|Solid black replaced by `helpers.drawMenuBackdrop(w, h, 1)`.|
|`ui/widgets.lua`|A screen's own `background` still wins. Otherwise `widgets.draw` falls back to the shared background and uses its `dim`. Header docs updated.|
|`sandbox/editor.lua`|New `mirrorShared(def, cleared)` copies the screen's background, blur and dim into the shared background. It is called from `seen`, `cycleBackground`, `changeBlur` and `changeDim`. The default test background is skipped if a shared one is already set. Added `editor.seenAll()`.|
|`sandbox/init.lua`|`love.draw` wrapper calls `editor.seenAll()` first, so every widget page's saved edits and the test background apply before the first frame. This keeps the background in place when you land directly on Settings or Pause.|
|`ultimate_ui/background/README.md`|New "One background for every menu page" section.|

### 4\. Behaviour to know about

* **Dim:** a page that inherits the shared background uses the shared `dim`, not its own. A page that
sets its own `background` keeps its own `dim`. This is intentional so every page looks the same.
* **Custom pages:** a user's own hand-drawn screen gets the background only if it calls
`helpers.drawMenuBackdrop(w, h, fallbackDim)` or is built with `ui/widgets.lua`.
* **Sandbox:** the F11 editor's background (`B`), blur (`[` `]`) and dim (`-` `=`) choices are mirrored
into the shared background, so all pages follow. Explicitly turning the background off clears it.
* **Exports:** exported page files are unchanged. They use the pristine values from the file, so the
sandbox test background never leaks into a drop-in page.
* **Image file:** the path must point to a file the game ships. The bundled
`test_background_16x9.png` is a placeholder; confirm or replace its license before publishing.
* **Verification:** my edits were reviewed by reading only; there was no LÖVE in my environment. The
author has since run it in the sandbox and confirmed it works.

### 5\. What shipped

Both parts (the `ultimate_ui/` restructure and the shared menu background) are already committed and
pushed to `main`. The history on GitHub is the source of truth for the exact commit messages; this file
only summarises the changes above.

### 6\. Git state

* Branch `main`, remote `origin` = `https://github.com/666mayn/LOVE2d-ultimate-ui-template.git`.
* `PATCH-NOTES.md` was added in commit `ed4e5fc` ("Added PATCH-NOTES.md that will be updated per
iteration"). Add a new dated patch section above this one for each iteration and commit it with the
change it describes.

### 7\. Possible follow-ups

* A console warning at startup if `menuBackground.image` cannot be found.
* A short "shared background" section in the main README.
* Optional: a per-page `dim` override while a shared background is active.

