###### ***# LOVE2d Ultimate UI Template***

###### 

###### ***A LÖVE (Love2D) UI and editing tool template by \*\*MaynGames\*\*.***

###### 

###### ***## Credits \& Licensing***

###### 

###### ***\* \*\*UI Template \& Display Filters (`crt\_filter.lua`, `crt\_filter2.lua`, `crt\_filter3.lua`, etc.):\*\* Created by \*\*MaynGames\*\* (Copyright © 2026 MaynGames) and released under the \*\*MIT License\*\* (see `LICENSE`).***

###### ***\* \*\*Font — `BoldPixels` (`boldpixels.ttf`, v1.6):\*\* Created by \*\*YukiPixels\*\* (2024) — \[https://yukipixels.itch.io/boldpixels](https://yukipixels.itch.io/boldpixels). Licensed under \*\*Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)\*\*. Please credit YukiPixels and keep the license / `CREDITS.md` notice when shipping this font. \*(If you replace the font, remove the bundled font and its license file as noted in `fonts/README.md`.)\****

###### ***\* \*\*Placeholder Background — `Free Pixel Art Forest`:\*\* Artwork created by \*\*Eder Muniz\*\*. Permitted for personal and commercial use, modification, and use across multiple games with credit to Eder Muniz (see `background/LICENSE.md`, `background/README.txt`, and `background/README.md`). Note that this test image is a placeholder—replace it or confirm its license before publishing your final game.***





# LÖVE2D Menu \& Settings Template

A drop-in, **zero-dependency** UI starter for any [LÖVE](https://love2d.org) (11.x) game:
main menu, pause menu, settings with **rebindable keyboard + gamepad controls**, an
"other settings" screen, a texture-filter switcher with optional CRT / LCD screen filters, a loading screen, a HUD helper, and an
optional intro-video player. Pure Lua + LÖVE, no libraries.

Run it as-is (`love .`) to see a tiny demo: move a checkerboard square with the bound keys,
press Esc to pause, and change everything from the settings screens.

## Quick Start Guide

**1. Run it.** Install [LÖVE](https://love2d.org) 11.x, then from the project folder:

```
love .              # the demo, exactly as players see it
love . --sandbox    # the same, plus the UI editor and dev tools
```

**2. Make it yours (no code needed).**

* Drop any `.ttf` / `.otf` into `fonts/` and any `.png` / `.jpg` into `background/`. Any file names work.
* In `love . --sandbox`, press **F1** for the help panel and **1-8** to jump to any screen.

**3. Edit a page in the editor.**

1. Press **F11** (edit mode) and click a title or button.
2. Type to change the text; **Tab** switches to the color (`#RRGGBB` or `rainbow`).
3. **B** picks a background, **\[ ]** blur, **- =** dim (with nothing selected).

**4. Export, install, integrate.**

1. **Ctrl+E** exports the page you're on; **Ctrl+Shift+E** exports all pages. They land in
`exports/`, in the same folders as the project (for example `exports/ui/main\\\_menu.lua`).
2. Drag the `exports/ui` folder onto the project root and choose **Replace**. The sandbox restarts
by itself, and your root `ui/` files are now your custom pages.
3. Take those root files into your own build. Nothing else has to change.

More: [`sandbox/README.md`](sandbox/README.md) (editor + hotkeys), [`exports/README.md`](exports/README.md),
[`fonts/README.md`](fonts/README.md), [`background/README.md`](background/README.md).

## Layout

```
main.lua                    demo wiring (replace the "YOUR GAME" block with your game)
conf.lua                    window + save-folder name (change `t.identity`!)
config.lua                  title, version, and fields the settings rows write into
ui\\\_state.lua                which screen is open + cursor positions + pulse clock
menu\\\_input.lua              keyboard / mouse / gamepad navigation for every menu
keybinds.lua                rebindable keyboard actions (placeholder\\\_\\\* examples)
controller.lua              rebindable gamepad actions (placeholder\\\_\\\* examples)
input.lua                   optional: one call checks keyboard AND gamepad
other\\\_settings.lua          data-driven cycle rows (volumes, shake, FPS, fullscreen)
texture\\\_filter\\\_manager.lua  Sharp / Smooth / Hybrid texture filtering, live + saved
crt\\\_manager.lua             optional full-screen shader filters (CRT, LCD, ...), live + saved
crt\\\_filters/                one file per screen filter; each lists its own settings rows
audio.lua                   tiny volume-aware audio helper (tolerates missing files)
loading\\\_screen.lua          timed loading-state machine
intro\\\_sequence.lua          optional startup .ogv videos
fonts.lua  fonts/           pre-sized font cache; uses any .ttf/.otf dropped in fonts/ (falls back to LÖVE's font)
debuglog.lua                print-based logger
ui/                         all drawing code, one file per screen
ui/widgets.lua              widget data model + renderer (main menu uses it; the editor will too)
sandbox/                    optional dev tools (jump to any screen, fake gamepad, auto-reload, widget editor)
exports/                    pages exported from the sandbox editor (drag exports/ui onto the project root to install)
background/                 test / game-art backgrounds (blurred behind a screen via ui/background.lua)
```

## Developing the UI:

`love . --sandbox` runs the demo with dev tooling on top: press **F1** for a panel, then
**1-8** to jump straight to any screen, **F3** for a keyboard-driven fake gamepad, **F2** to
cycle window sizes, and edit any `.lua` file to have the game restart on the same screen.
Full details in [`sandbox/README.md`](sandbox/README.md). Optional: leave `sandbox/` out of release builds.

## Using it in your game

1. Copy the files into your project (or start from this repo).
2. **Config:** edit `config.lua` (title, version) and `conf.lua` (`t.identity`).
3. **Controls:** edit the `ACTIONS` lists in `keybinds.lua` and `controller.lua`.
Use the same `id`s in both so `input.isDown("your\\\_action")` works for either device.
The menus rebuild themselves from those lists.
4. **Settings rows:** add entries to `ROW\\\_DEFS` in `other\\\_settings.lua`. A row is a label, a list
of options, and either a `configRef`/`configField` to write to or a `setter` function.
5. **Textures:** create images with `texture\\\_filter\\\_manager.newImage(...)` (or `.track(img)`) so
the Texture Filter setting updates them live.
6. **Your game:** replace the "YOUR GAME" block in `main.lua`. The hooks you care about are
`menu\\\_input.configure{ onPlay, onResume, onExitToMenu, onExit }`.

### Extending

* **New main/pause button:** add a label + action in `ui/main\\\_menu.lua` (or `ui/pause\\\_menu.lua`),
then handle the action in `menu\\\_input.lua`.
* **New settings category:** add it to `CATEGORIES` in `ui/settings\\\_menu.lua`, copy
`ui/other\\\_settings\\\_menu.lua` as the screen, add its flag/cursor to `ui\\\_state.lua`, and register
it in `ui/init.lua` and `menu\\\_input.lua`'s `SCREENS` list.
* **New texture filter mode:** one line in `defs` in `texture\\\_filter\\\_manager.lua`.
* **New screen filter:** drop a module in `crt\\\_filters/` and add one line to `defs` in
`crt\\\_manager.lua`. A filter provides `init`, `update(dt)`, `apply`, `endApply` and an optional
`settings` table (`{ id, label, defaultIndex, apply(value), options = {{ label, value }, ...} }`).
Its settings show up as rows in Settings -> Textures automatically, saved per filter.
The three included filters (Classic CRT, Neon Arcade, Handheld LCD) are working examples.
The default is Off; change `DEFAULT\\\_ID` in `crt\\\_manager.lua` to ship with one on.

### Controls (menus)

Up/Down + Enter, mouse click, or D-pad + A. Esc / B go back; Esc / Start pause in-game.
Click a bind to rebind it (Esc / Start cancels). Binding a key already in use swaps the two.

## Notes

* Saved settings go in LÖVE's save directory (`keybinds.txt`, `controller.txt`,
`other\\\_settings.txt`, `texture\\\_filter\\\_choice.txt`, `crt\\\_filter\\\_choice.txt`).
* Screen filters bend or pixelate the picture, but mouse hit-boxes stay on the unfiltered layout.
Test strong curvature before shipping it on a mouse-driven UI. A filter that fails to load is
skipped, never fatal.
* Sizes are laid out against a 1080p reference and scale with window height.
* **Fonts and backgrounds are interchangeable:** any `.ttf` / `.otf` in `fonts/` and any `.png` / `.jpg` in
`background/` works, under any file name (see the README in each folder). The bundled `fonts/boldpixels.ttf`
is only the demo font (CC BY-SA 4.0, credit YukiPixels; see `fonts/FONT\\\_LICENSE.txt`); delete it and drop
in your own.

## Vision / Roadmap

The goal is an all-in-one "ultimate" UI template for LÖVE2D that ships with a **visual
drag-and-drop sandbox editor** able to **export Lua UI code**, and to become the go-to
LÖVE2D UI starter.

* \[x] Menus, rebindable keyboard + gamepad controls, settings, screen filters, loading screen
* \[x] Dev sandbox (`love . --sandbox`): jump to any screen, fake gamepad, auto-reload
* \[x] Widget data model prototype (`ui/widgets.lua`), main menu migrated
* \[ ] Widget model: more widget types (slider, toggle, panel, image)
* \[ ] Migrate the remaining screens to the widget model
* \[x] Editor, first slice (F11): select widgets, edit text + color, blurred test background + dim, export pages to `exports/` as drop-in replacements for `ui/` files
* \[ ] Editor: drag to move, resize, anchors, add / delete widgets, undo
* \[ ] Docs, screenshots, example games

Contributions and ideas are welcome.

## License

Code: MIT, see [`LICENSE`](LICENSE). The bundled font `fonts/boldpixels.ttf` is separate:
CC BY-SA 4.0 by YukiPixels, see `fonts/FONT\\\_LICENSE.txt`. Replace it with your own font in `fonts/`
if you want a fully MIT game.

