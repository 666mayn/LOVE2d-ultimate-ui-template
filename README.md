# LÖVE2D Menu & Settings Template

A drop-in, **zero-dependency** UI starter for any [LÖVE](https://love2d.org) (11.x) game:
main menu, pause menu, settings with **rebindable keyboard + gamepad controls**, an
"other settings" screen, a texture-filter switcher, a loading screen, a HUD helper, and an
optional intro-video player. Pure Lua + LÖVE, no libraries.

Run it as-is (`love .`) to see a tiny demo: move a checkerboard square with the bound keys,
press Esc to pause, and change everything from the settings screens.

## Layout

```
main.lua                    demo wiring (replace the "YOUR GAME" block with your game)
conf.lua                    window + save-folder name (change `t.identity`!)
config.lua                  title, version, and fields the settings rows write into
ui_state.lua                which screen is open + cursor positions + pulse clock
menu_input.lua              keyboard / mouse / gamepad navigation for every menu
keybinds.lua                rebindable keyboard actions (placeholder_* examples)
controller.lua              rebindable gamepad actions (placeholder_* examples)
input.lua                   optional: one call checks keyboard AND gamepad
other_settings.lua          data-driven cycle rows (volumes, shake, FPS, fullscreen)
texture_filter_manager.lua  Sharp / Smooth / Hybrid texture filtering, live + saved
audio.lua                   tiny volume-aware audio helper (tolerates missing files)
loading_screen.lua          timed loading-state machine
intro_sequence.lua          optional startup .ogv videos
fonts.lua  fonts/           pre-sized font cache (falls back to LÖVE's font if missing)
debuglog.lua                print-based logger
ui/                         all drawing code, one file per screen
sandbox/                    optional dev tools (jump to any screen, fake gamepad, auto-reload)
```

## Developing the UI: the sandbox

`love . --sandbox` runs the demo with dev tooling on top: press **F1** for a panel, then
**1-8** to jump straight to any screen, **F3** for a keyboard-driven fake gamepad, **F2** to
cycle window sizes, and edit any `.lua` file to have the game restart on the same screen.
Full details in [`sandbox/README.md`](sandbox/README.md). Optional: leave `sandbox/` out of release builds.

## Using it in your game

1. Copy the files into your project (or start from this repo).
2. **Config:** edit `config.lua` (title, version) and `conf.lua` (`t.identity`).
3. **Controls:** edit the `ACTIONS` lists in `keybinds.lua` and `controller.lua`.
   Use the same `id`s in both so `input.isDown("your_action")` works for either device.
   The menus rebuild themselves from those lists.
4. **Settings rows:** add entries to `ROW_DEFS` in `other_settings.lua`. A row is a label, a list
   of options, and either a `configRef`/`configField` to write to or a `setter` function.
5. **Textures:** create images with `texture_filter_manager.newImage(...)` (or `.track(img)`) so
   the Texture Filter setting updates them live.
6. **Your game:** replace the "YOUR GAME" block in `main.lua`. The hooks you care about are
   `menu_input.configure{ onPlay, onResume, onExitToMenu, onExit }`.

### Extending

- **New main/pause button:** add a label + action in `ui/main_menu.lua` (or `ui/pause_menu.lua`),
  then handle the action in `menu_input.lua`.
- **New settings category:** add it to `CATEGORIES` in `ui/settings_menu.lua`, copy
  `ui/other_settings_menu.lua` as the screen, add its flag/cursor to `ui_state.lua`, and register
  it in `ui/init.lua` and `menu_input.lua`'s `SCREENS` list.
- **New texture filter mode:** one line in `defs` in `texture_filter_manager.lua`.

### Controls (menus)

Up/Down + Enter, mouse click, or D-pad + A. Esc / B go back; Esc / Start pause in-game.
Click a bind to rebind it (Esc / Start cancels). Binding a key already in use swaps the two.

## Notes

- Saved settings go in LÖVE's save directory (`keybinds.txt`, `controller.txt`,
  `other_settings.txt`, `texture_filter_choice.txt`).
- Sizes are laid out against a 1080p reference and scale with window height.
- `fonts/boldpixels.ttf` is bundled for the look of the demo. Check its license before
  redistributing, or swap in a font you're free to share (change `fontPath` in `fonts.lua`).
