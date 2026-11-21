# PATCH NOTES

Project: LOVE2d Ultimate UI Template
Status: shared menu background confirmed working by the author in the sandbox (`love . --sandbox`).

This file is the running record of what changed and why, so work can pick up where it left off.

---

## Patch: drop-in `ultimate_ui/` library + shared menu background

### 1. Restructure into a self-contained library

The whole UI system now lives in one folder, `ultimate_ui/`, so it can be copied into any LÖVE
project without colliding with the project's own `input.lua`, `audio.lua`, `config.lua` or `ui/`.
`main.lua` and `conf.lua` stay at the repo root as the demo only.

- **Single entry point:** `ultimate_ui/init.lua`, used as `local UI = require("ultimate_ui")`.
- **Lazy loading:** modules load on first use (`UI.ui`, `UI.state`, `UI.input`, `UI.audio`, `UI.fonts`,
  `UI.keybinds`, `UI.controller`, `UI.menu_input`, `UI.other_settings`, `UI.textures`, `UI.crt`,
  `UI.loading`, `UI.intro`, `UI.widgets`, `UI.log`, `UI.sandbox`). File names also work
  (`UI.ui_state`, `UI.crt_manager`, ...).
- **`UI.init()`:** initialises every stateful module in the right order (texture filter first).
- **`UI.configure{...}`:** overrides `config.lua` values from game code.
- **`UI.path(sub)`:** path of a file inside the folder, from the game root.
- **Relocatable:** every file finds its siblings relative to its own module name
  (`local ROOT = (...):match(...)`), so the folder can be renamed or moved without edits.
- **No globals:** nothing is installed in the global namespace.
- **Moved under `ultimate_ui/`:** `ui/`, `sandbox/`, `fonts/`, `background/`, `crt_filters/` and all
  top-level modules (git sees these as renames).
- **`sandbox/` is dev-only:** delete it before shipping; `main.lua` skips it automatically
  (`UI.hasSandbox()`).
- **`main.lua` rewritten:** it now uses the single UI entry point and is the reference for hooking up
  the draw / keyboard / mouse / gamepad callbacks.
- **Docs:** README rewritten (quick start, module table, folder layout); the sandbox, fonts,
  background and exports READMEs were updated for the new paths.

### 2. Shared menu background (new feature)

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

- `image` is a path from the game root, scaled to cover the screen.
- `blur` runs from 0 (sharp) to 10.
- `dim` is the black overlay alpha (0..1) drawn over the picture on every page.
- The default is `nil` (none), so projects that don't set it look exactly as before.

Pages that draw it: main, pause, settings, keyboard, controller, other, texture and the loading screen.
On the loading screen the picture carries through PLAY, loading and into the game. With no shared
background it is solid black as before.

### 3. How it works (files touched for the background)

| File | Change |
| --- | --- |
| `ultimate_ui/config.lua` | New `menuBackground = nil` field, documented. |
| `ultimate_ui/ui/background.lua` | Added `background.shared()` (reads `config.menuBackground`) and `background.setShared(spec)`. |
| `ultimate_ui/ui/helpers.lua` | Added `helpers.drawMenuBackdrop(w, h, fallbackDim)`: draws the shared background, then the black dim. With a shared background the dim is its `dim`, otherwise `fallbackDim`. Requires `ui.background`. |
| `ui/pause_menu.lua`, `settings_menu.lua`, `keyboard_menu.lua`, `controller_menu.lua`, `other_settings_menu.lua`, `texture_filter_menu.lua` | The hard-coded `0,0,0,180/255` overlay was replaced by `helpers.drawMenuBackdrop(w, h, 180/255)`. |
| `ui/loading_screen.lua` | Solid black replaced by `helpers.drawMenuBackdrop(w, h, 1)`. |
| `ui/widgets.lua` | A screen's own `background` still wins. Otherwise `widgets.draw` falls back to the shared background and uses its `dim`. Header docs updated. |
| `sandbox/editor.lua` | New `mirrorShared(def, cleared)` copies the screen's background, blur and dim into the shared background. It is called from `seen`, `cycleBackground`, `changeBlur` and `changeDim`. The default test background is skipped if a shared one is already set. Added `editor.seenAll()`. |
| `sandbox/init.lua` | `love.draw` wrapper calls `editor.seenAll()` first, so every widget page's saved edits and the test background apply before the first frame. This keeps the background in place when you land directly on Settings or Pause. |
| `ultimate_ui/background/README.md` | New "One background for every menu page" section. |

### 4. Behaviour to know about

- **Dim:** a page that inherits the shared background uses the shared `dim`, not its own. A page that
  sets its own `background` keeps its own `dim`. This is intentional so every page looks the same.
- **Custom pages:** a user's own hand-drawn screen gets the background only if it calls
  `helpers.drawMenuBackdrop(w, h, fallbackDim)` or is built with `ui/widgets.lua`.
- **Sandbox:** the F11 editor's background (`B`), blur (`[` `]`) and dim (`-` `=`) choices are mirrored
  into the shared background, so all pages follow. Explicitly turning the background off clears it.
- **Exports:** exported page files are unchanged. They use the pristine values from the file, so the
  sandbox test background never leaks into a drop-in page.
- **Image file:** the path must point to a file the game ships. The bundled
  `test_background_16x9.png` is a placeholder; confirm or replace its license before publishing.
- **Verification:** my edits were reviewed by reading only; there was no LÖVE in my environment. The
  author has since run it in the sandbox and confirmed it works.

### 5. Suggested commit message

```
Restructure into a drop-in ultimate_ui/ library with one entry point

Move the whole UI system into a single self-contained ultimate_ui/
folder so it can be copied into any LÖVE project without colliding
with the project's own input.lua / audio.lua / config.lua / ui/.
main.lua and conf.lua stay at the root as the demo only.

Library structure
- New ultimate_ui/init.lua is the single entry point:
  local UI = require("ultimate_ui"). Modules load lazily on first use
  (UI.ui, UI.state, UI.input, UI.audio, UI.fonts, UI.keybinds,
  UI.controller, UI.crt, UI.textures, UI.widgets, ...).
- UI.init() sets up every module in the correct order; UI.configure{}
  overrides config.lua values from game code; UI.path() resolves paths
  inside the folder.
- Every file finds its siblings relative to its own module name, so the
  folder can be renamed or moved without editing anything. Nothing is
  placed in the global namespace.
- ui/, sandbox/, fonts/, background/, crt_filters/ and all top-level
  modules moved under ultimate_ui/ (git tracks these as renames).
- sandbox/ is dev-only and can be deleted before shipping; the main
  file skips it automatically if it is missing.

Demo + docs
- main.lua rewritten to use the single UI entry point and now serves as
  the reference for wiring draw / keyboard / mouse / gamepad callbacks.
- README rewritten with a quick-start guide, module table and folder
  layout; sandbox, fonts, background and exports READMEs updated for
  the new paths.

Shared menu background (new feature)
- config.menuBackground = { image, blur, dim } is one background drawn
  by every menu page (main, pause, settings, keyboard, controller,
  other, texture) and the loading screen. Before, only widget screens
  could show a background, so it vanished after the main menu.
- helpers.drawMenuBackdrop() draws it plus a shared dim; widgets.draw
  falls back to it when a screen has no background of its own (a
  per-screen background still overrides it).
- Sandbox: the default test background and the F11 editor's background
  / blur / dim choices are mirrored into the shared background, and all
  widget pages are applied at startup. Exports are unchanged, so the
  test background never leaks into a drop-in page.
- Defaults to nil, so projects that don't set it look as before.
```

### 6. Git state at the time of writing

- Branch `main`, remote `origin` = `https://github.com/666mayn/LOVE2d-ultimate-ui-template.git`.
- The restructure was not yet committed. `git status` showed 50 renames and 56 files changed in total.
- Suggested flow: `git checkout -b <branch>`, `git add -A`, commit, `git push -u origin <branch>`, then
  open a pull request on GitHub and merge.

### 7. Possible follow-ups

- A console warning at startup if `menuBackground.image` cannot be found.
- A short "shared background" section in the main README.
- Optional: a per-page `dim` override while a shared background is active.
