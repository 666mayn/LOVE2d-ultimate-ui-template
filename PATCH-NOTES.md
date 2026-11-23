# PATCH NOTES

Project: LOVE2d Ultimate UI Template
Status: every menu is editable in the F11 editor, and the export workflow (always-on keys, cut screen, save toast, shared-background export) is confirmed working by the author in real LOVE (`love . --sandbox`).

This file is the running record of what changed and why, so work can pick up where it left off.

---

## Patch: nested font folders, project-wide font, per-element fonts

**Headline:** fonts can now live in nested folders, and there are **3 new font families** to choose from (`fibberish`,
`pixeloid_sans`, `playersansmono`, alongside the existing `boldpixels`). Pick a font **per UI element** with the new FONT row in
the F11 editor, or switch the **entire project at once** with `config.font` / `UI.configure{ font = ... }`. It is entirely up to
the user: mix per-element fonts, set per-element-type roles, or change everything in one line. New screenshot added to the top of
the README (`reference_screenshots/ui_editor_font_editor.png`).

**Problem:** fonts moved into sub-folders (`fonts/font_boldpixels/boldpixels.ttf`, ...) but `fonts.lua` only looked at the top
level of `fonts/`, so none of them were found, and there was no way to choose a font per element type.

**New behaviour**

* **Recursive scan.** Every `.ttf` / `.otf` anywhere under `fonts/` (6 levels deep) is registered. Fonts are rasterized lazily
  per (font, size), so many families cost nothing until used. `UI.fonts.list()` shows every usable name.
* **Names.** A font is addressed by family folder (`"pixeloid_sans"`, `font_` prefix optional), file name (with or without
  `.ttf`) or path inside `fonts/`, case-insensitive. A family name resolves to its main file (the one named like the folder,
  else a Regular/Classic file, else the shortest name).
* **1. Whole project:** `config.font = "boldpixels"` (or `UI.configure{ font = ... }`, `UI.fonts.setDefault(...)`).
* **2. Per element type:** `config.fontRoles = { button = ..., title = ..., hint = ..., stat = ..., ... }`. Roles:
  `title`, `subtitle` (-> title), `button`, `row` (-> button), `hint`, `stat`, `hud` (-> stat), `body`.
* **3. One element:** `font = "name"` on a widget, stack item or stats row in a `ui/*.lua` screen (and in `ui/page_texts.lua`
  for the hand-coded pages). It survives the editor's export (`font` / `role` are kept and sorted next to `fontSize`).
* **Resolution order:** element `font` > role > project font > first font found > LOVE built-in. Unknown names warn once and fall back.
* **API:** `fonts.get(size, role_or_name, explicitName)` (`UI.ui.getFont` is the same function), `fonts.list()`, `fonts.resolve(name)`,
  `fonts.setDefault(name)`, `fonts.setRole(role, name)`. `helpers.drawScaledButton` / `drawPoppedButton` take an optional trailing `fontName`.
* **Startup check** (`checks.lua`) now scans nested folders and warns when `config.font` or any `config.fontRoles` entry names a font that is not there.

| File | Change |
| --- | --- |
| `ultimate_ui/fonts.lua` | Rewritten: recursive registry, name resolution, roles, lazy per-font size cache. |
| `ultimate_ui/config.lua` | `font` docs, new `fontRoles`. |
| `ultimate_ui/ui/widgets.lua` | `font` / `role` on widgets, items and stats rows; text-page overrides accept `font`. |
| `ultimate_ui/ui/helpers.lua` | Buttons use the `button` role + optional per-button font. |
| `ultimate_ui/ui/{settings,keyboard,controller,other_settings,texture_filter}_menu.lua`, `loading_screen.lua`, `hud.lua`, `intro_sequence.lua`, `main.lua` | Titles / hints / rows / stats / HUD draw through roles. |
| `ultimate_ui/sandbox/{editor,serialize}.lua` | Selection box uses the element's real font; export keeps `font` / `role`. |
| `ultimate_ui/checks.lua`, `ultimate_ui/fonts/README.md`, `ultimate_ui/ui/page_texts.lua` | Updated for the above. |

**Verification:** run in a stubbed-LOVE harness (no real LOVE available here) against the real folder tree: name resolution for
every spelling, project font, roles, per-element override, bad-name fallback, and every menu page + HUD + loading screen
drawing with the chosen fonts. **Not run in real LOVE.**

**F11 editor: FONT row.** The edit panel now has `FONT  [<] name [>]` under COLOR. Click `<` / `>` (or the name), or press
Left/Right (Up/Down) while FONT is focused (Tab goes TEXT -> COLOR -> FONT). It steps through `default` (the element's role /
project font) and every font under `fonts/`, wraps around, and the name is drawn in the font it picks. The change shows live,
survives restarts like text/color edits (saved in the save folder, dropped if the file changed underneath), `Del` resets it,
and Ctrl+E exports `font = "..."` into the screen file (or into `page_texts.lua` for the hand-coded pages).
Files: `ultimate_ui/sandbox/editor.lua`.

**Vertical centering per font.** Button / row text was placed with `y + (height - fontSize) / 2`, which assumes the font's line
box is exactly `fontSize` tall. It isn't: each family has its own ascent / descent and cap height, so fibberish sat high,
Pixeloid low, PlayerSansMono lowest. `fonts.capCenter(font)` now measures where the middle of a capital "H" really is
(`love.font.newRasterizer` glyph bearing + the font's ascent; falls back to the middle of the line box if that fails), and
`fonts.textY(boxY, boxH, font)` / `helpers.textY(boxY, boxH)` return the y that centers capitals in a box. Used by
`drawScaledButton` (every button in every menu) and the label / value text of the Keyboard, Controller, Other and Textures rows.
Measured shift at 36px in a 60px button: boldpixels +2, fibberish +6, Pixeloid -4, PlayerSansMono -2 (pixels, + = down),
so each family is corrected by its own amount, and any font you add is handled automatically.
Last-mile tweak: `config.fontNudge = { fibberish = 0.05 }` (fraction of font size, + = down).
The editor's FONT preview now shrinks the name to fit its box (PlayerSansMono used to spill over the counter) and is centered the same way.
Files: `fonts.lua`, `ui/helpers.lua`, `ui/{keyboard,controller,other_settings,texture_filter}_menu.lua`, `config.lua`, `sandbox/editor.lua`.
Verified with FreeType-backed stub metrics, not in real LOVE.

**Not covered:** the editor sets a font per element only (not per role; use `config.fontRoles`); the font size list is shared by
all fonts, so bitmap-style fonts (PlayerSansMono) may want their own sizes. The FONT row was run in the stubbed harness only.

---

## Patch: exports fixed + polished (always-on keys, cut screen, save toast), shared background in plain `love .`

**Problem:** exporting appeared to do nothing, and the background seen in the sandbox never showed in plain `love .`.

**Causes found**

1. **Export keys only worked in F11 edit mode.** `editor.keypressed` returned immediately when edit mode was off, so
   `Ctrl+E` / `Ctrl+Shift+E` went to the game. This was the main reason "nothing saves".
2. **Row edits on unopened pages were dropped.** Text-page rows are created lazily on first draw, so `Ctrl+Shift+E`
   skipped saved edits for any page not opened this session and overwrote `page_texts.lua` without them.
3. **The background was sandbox-only.** The test background was mirrored into the shared background at runtime only;
   exports never wrote it anywhere plain `love .` reads, and `config.menuBackground` is `nil`.
4. **Mac:** only Ctrl counted, not Cmd.
5. **Silent failures:** a write that fell back to the save folder, or failed, was easy to miss (the last log line
   overwrote the reason).

**Fix / new behaviour**

* **Export is always ready.** `Ctrl+E` (page on screen) and `Ctrl+Shift+E` (all pages) work in or out of F11 edit mode;
  `Cmd` works like `Ctrl` on macOS. Every other editor key still needs edit mode.
* **Cut screen.** The export is deferred until a black frame is on screen, then runs: black screen with a small white
  `exporting . . .` (dots cycle 1 / 2 / 3), in the template font, held briefly after the write finishes.
* **Save toast.** Top-center banner after every export, about 3.5 s: green `SAVED  N files  >  exports/ultimate_ui/`,
  amber if it fell back to the save folder, red with the reason if it failed or nothing was editable.
* **Shared background export.** New `ui/menu_background.lua` (`{ image, blur, dim }` or `return nil`), written by both
  export keys and read by `background.shared()` when `config.menuBackground` is nil. It ships pointing at the bundled
  image, so plain `love .` shows the background. `config.menuBackground` still wins.
* **Unopened pages are exported.** `page_texts.lua` now keeps row edits for pages not drawn yet (installed file first,
  then saved editor edits on top).
* **Diagnostics.** Each write step records its real error; a failure shows as a red toast and everything is appended to
  `ultimate_ui_export_log.txt` in the save folder (F9), including the path tried and any `RESTART:` reason.
* **Auto-reload guard.** The file watcher is paused during an export and re-baselined afterwards, so the export cannot
  trigger a restart that wipes the toast.
* **Editor crash guard.** The export runs in a protected call; an error shows as `EXPORT CRASHED: ...` instead of
  taking the sandbox down.

| File | Change |
| --- | --- |
| `ultimate_ui/sandbox/editor.lua` | Always-on export keys (+ Cmd), deferred export job + cut screen (`startExport`, `update`, `drawCut`), save-toast notifier, write diagnostics and log, lazy-row fix, `menu_background.lua` export. |
| `ultimate_ui/sandbox/init.lua` | Calls `editor.update()` / `editor.drawCut()`, wires the notifier, pauses + re-baselines the watcher around exports, logs restart reasons, passes the save toast to the overlay. |
| `ultimate_ui/sandbox/overlay.lua` | Draws the top-center save toast. |
| `ultimate_ui/ui/menu_background.lua` | **New.** Shared background data file (see above). |
| `ultimate_ui/ui/background.lua` | `background.shared()` falls back to `ui/menu_background.lua`; turning the background off in the editor beats the file. |
| `ultimate_ui/ui/widgets.lua` | New `widgets.pageTexts()` (the installed `page_texts.lua`). |
| `ultimate_ui/config.lua`, `ultimate_ui/background/README.md` | Notes for the new fallback. |
| `README.md`, `PATCH-NOTES.md` | All screenshots moved to the top; new "Edit every menu, export in one keypress" section. |

**Verification:** the author ran it in real LOVE and confirmed exports now write, the cut screen and toast appear, and
the exported files (`main_menu`, `pause_menu`, `hud_screen`, `page_texts`, `menu_background`) are correct. The lazy-row
fix, the background fallback in plain mode and the deferred-export flow were also checked in a stubbed-LOVE harness.

**Not yet covered:** `checks.lua` does not validate `ui/menu_background.lua` (a wrong image path there will not warn at
startup). The cause of an auto-reload seen right after exporting was not pinned down; the guard above should prevent it,
and any restart reason is now in `ultimate_ui_export_log.txt`.

---

## Patch: every page's text is editable in the F11 editor

**Problem:** the F11 editor only worked on the main menu, pause menu and HUD. Settings, Keyboard, Controller,
Other, Textures and the loading screen draw themselves in code, so their titles and buttons could not be selected.

**Fix:** those pages keep their layout and logic, but their strings are now data. A new `widgets.textPage{...}`
gives a page `page.label("title")`, `page.item(<stable row key>, <default text>)`, `page.rgb(...)` and
`page.report(items, w, h, uiScale)`. The page reads every text through it and reports the boxes it drew, which is all
the editor needs to select, retype and recolor them exactly like a widget screen.

1. **Editable now:** the title and hint line of every page, every button / row label (Settings categories, keybind
   and controller action rows, Other settings rows, texture-filter and CRT rows, RESET / BACK buttons) and the
   loading screen's title. `{config.title}`-style bindings work in all of them.
2. **Export.** These pages cannot be replaced by a generated file (their layout is code), so Ctrl+E on one of them
   writes **one** file for all of them: `exports/ultimate_ui/ui/page_texts.lua`, listing only what differs from the
   code. Ctrl+Shift+E writes it too, once. Install it like any other export; `ui/page_texts.lua` is read at startup by
   `widgets.textPage`, **with or without the sandbox** (a missing file or a file with an error means no overrides).
   A placeholder `ui/page_texts.lua` (`return {}`) ships with usage notes.
3. **Stable row keys.** Row edits are keyed by action name (`rows#back`, `rows#filter:Sharp (Nearest)`), not position,
   so they follow their row if rows are added or reordered. Saved sandbox edits also work for rows the page creates later
   (`def.pending`).
4. **Loading screen.** Edit mode freezes its timer (`loading_screen.holdWhile`, wired in the sandbox only) so the title can
   be clicked. The `label` the game passes to `loading_screen.start` is still used until the title is edited.
5. **Background / dim keys** (B, `[` `]`, `-` `=`) say "use the main menu" on text pages: they use the shared menu background.

**Not editable (by design):** values that change at runtime (`UNBOUND`, `ACTIVE`, `PRESS A KEY...`, `PRESS A BUTTON...`,
the FPS counter, the version watermark) and the loading bar.

| File | Change |
| --- | --- |
| `ultimate_ui/ui/widgets.lua` | New `widgets.textPage`, `widgets.defaults`, `widgets.resolveText`; loads `ui/page_texts.lua`. |
| `ultimate_ui/ui/page_texts.lua` | **New.** Placeholder + usage notes (`return {}`). |
| `ultimate_ui/ui/settings_menu.lua`, `keyboard_menu.lua`, `controller_menu.lua`, `other_settings_menu.lua`, `texture_filter_menu.lua`, `loading_screen.lua` | Texts read through a text page; draw reports its boxes. Layout, clicks, input handling unchanged. |
| `ultimate_ui/sandbox/editor.lua` | Row `key` support, lazy rows re-apply saved edits, `page_texts.lua` export, hints. |
| `ultimate_ui/loading_screen.lua`, `ultimate_ui/sandbox/init.lua` | `holdWhile` hook; sandbox holds loading while editing. |
| `ultimate_ui/sandbox/README.md`, `README.md` | Docs. |

**Verification:** no LOVE here, so this was run in a stubbed-LOVE harness (real files, Lua runtime). Passed: all six pages draw
exactly the same text as before; for every one of the 47 selectable items on those pages, clicking it selects it, typing
replaces its text, and the next frame draws the new text; export writes a `page_texts.lua` with only the changed entries
(text and color); a fresh start with that file installed shows the edits with no editor; a fresh sandbox start re-applies saved
edits (including lazily created rows); a stale saved edit loses to an installed file; the main menu still edits as before.
**Please run `love . --sandbox`, press F11 and click through Settings / Keyboard / Controller / Other / Textures
and F7 (loading) to confirm, then Ctrl+Shift+E and install the export.**

---

## Patch: button-click + loading-screen sounds (drop-in `ui` / `loading` files)

1. **Menu buttons play a click sound.** `menu_input.lua` plays the UI sound for every button activation: mouse click on
   a button, Enter, gamepad A, and Esc / B / Start for "back". Clicking empty space, moving the cursor, right-clicking and
   Esc on the main menu (nothing to go back to) are silent. It goes through `audio.playSFX`, so the SFX volume row applies.
2. **The loading screen plays a sound and lasts exactly as long as it.** `main.lua` starts `loading.ogg` from the
   loading screen's `onStart`, stops it in `onFinish`, and passes `sounds.loadingDuration(1.0)` as the screen's duration
   (1.0 s if there is no loading sound). The sandbox's F7 preview uses the same rule (3 s fallback), and jumping screens
   in the sandbox cuts a half-played loading sound.
3. **Drag-and-drop replacement.** `ultimate_ui/sounds/` holds `example_ui.ogg` and `example_loading.ogg`. Dropping a file
   named `ui.*` or `loading.*` there (`.ogg`, `.mp3` or `.wav`, any letter case) replaces the matching example, with no code or
   config. Priority per slot: yours before the example, then `.ogg`, `.mp3`, `.wav`. Nothing found = silence, and the
   template still runs with no sounds at all.
4. **Startup check.** `checks.lua` warns if the sound in use will not decode, or if a `ui.*` / `loading.*` file has an
   extension that is never picked up (e.g. `loading.flac`).

**New / changed files**

| File | Change |
| --- | --- |
| `ultimate_ui/ui_sounds.lua` | **New.** Finds the files, `playUI()`, `playLoading()`, `stopLoading()`, `loadingDuration(fallback)`, `path(slot)`, `refresh()`. Also reachable as `UI.sounds`. |
| `ultimate_ui/sounds/README.md` | **New.** The drop-in instructions, next to the files. |
| `ultimate_ui/audio.lua` | `playSFX` now returns the playing Source (was nothing). New `getSFXDuration(path)` and `clearSFXCache()`. Existing callers are unaffected. |
| `ultimate_ui/menu_input.lua` | Plays the UI sound on button activation / back (see 1). |
| `ultimate_ui/init.lua` | Registers `UI.sounds`; `UI.init()` scans the sounds folder. |
| `ultimate_ui/checks.lua` | New "sounds" check. |
| `ultimate_ui/sandbox/init.lua`, `sandbox/screens.lua` | F7 preview length follows the sound; screen jumps stop the loading sound. |
| `main.lua` | `onStart` / `onFinish` / `onPlay` wiring for the loading sound and duration. |
| `README.md` | New "Sounds" section, module table row, layout and startup-check lines. |

**Behaviour to know about**

* The loading screen's length is the **whole file's** length, including any silence at the end. `example_loading.ogg`
  has about 0.7 s of near-silence at the end, so the bar holds a moment after the sound has faded. Trim the tail of your file if that matters.
* The folder is scanned once at startup (`UI.init()`). Swap a file, then restart (F5 in the sandbox).
* `loading_screen.lua` itself is unchanged and still knows nothing about sound; the wiring lives in `main.lua`, so a game that
  copies `ultimate_ui/` and wires its own loading screen can pass `UI.sounds.loadingDuration()` the same way.
* The bundled example sounds: confirm you may redistribute them before publishing, as with the background image.
* In a fused / packaged build the folder is inside the archive, so swap files **before** building.

**Verification:** there was no LOVE in my environment, so this was checked with a stubbed LOVE harness (real files on disk,
sound lengths from `ffprobe`) rather than a real run. 25 checks passed: example files are picked by default; `ui.wav` and
`Loading.MP3` override them; `.ogg` beats `.mp3`; an empty or missing `sounds/` folder is silent with the fallback duration
and no crash; the loading screen's length equals the sound's length (2.584 s for the example); the sound stops on finish;
the click plays on a button hit, Enter, gamepad A and Esc-in-a-sub-screen but not on empty clicks, cursor moves, right-click
or Esc on the main menu; SFX volume is respected; the startup check flags `loading.flac` and an undecodable `ui.mp3`.
**Please run `love . --sandbox` once and confirm you hear the click and the loading sound, and that F7 matches.**

---

## Patch: new reference screenshots, cleaner main.lua + nested `ultimate_ui/`

1. **Improved reference screenshots, and fixed the main README to use them.** `reference_screenshots/` now holds
   exactly these eight images: `ui_editor_open`, `ui_editor_open_2`, `ui_editor_closed_2`,
   `ui_editor_keyboard_binds`, `ui_editor_controller_binds`, `ui_editor_other_settings`,
   `ui_editor_texture_settings_crt_off`, `ui_editor_texture_settings_crt_on`. The README's Screenshots section
   was rewritten as four two-column rows that reference only those files (the old `open_3`, `open_4_*`, `open_6`
   and `open_7` links are gone). The folder layout in the README now lists `reference_screenshots/`.
2. **`main.lua` makes explicit calls, and everything is nested under `ultimate_ui/` for easy integration.**
   `main.lua` talks to the library only through `local UI = require("ultimate_ui")` (`UI.init()`,
   `UI.configure{...}`, `UI.ui`, `UI.state`, `UI.input`, ...) and is the reference for hooking up the draw,
   keyboard, mouse and gamepad callbacks. The whole library lives in the one `ultimate_ui/` folder, so a game
   copies that single folder in with nothing to merge and nothing in its project root to collide with.
3. **Sandbox overlay fix.** The F1 help panel and the bottom-left strip could disappear on every screen. The
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

