# UI Sandbox

A development harness for this template. It lets you build and test menus
**without playing through your game to reach them**: jump to any screen, drive
the menus with a fake gamepad, check other window sizes, and have the game
restart itself (and land back on the same screen) every time you save a file.

```
love . --sandbox            # from the project root
sandbox\run.bat             # same thing, from anywhere (needs love.exe on your PATH)
set UI_SANDBOX=1 && love .  # same thing, via environment variable (cmd)
```

Plain `love .` runs the demo exactly as before. The sandbox only switches on
with the flag, and it wraps the game's `love.*` callbacks from the outside, so
none of the UI modules know it exists.

## The edit loop

1. `love . --sandbox`, press **F1**, press **4** to jump to the Keyboard menu.
2. Edit `ui/keyboard_menu.lua` in your editor and save.
3. The sandbox notices, restarts, and puts you back on the Keyboard menu.

Manual restart is **F5**. Auto-reload is on by default and toggled with **F6**.

## Hotkeys

All of these live in `sandbox/config.lua`, so you can rebind them.

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
| **F12** | Screenshot (without the overlay) into the save folder. Handy for your README. |

Sub-screens are opened the way a player would reach them: jumping to Keyboard
from the main menu stacks main > settings > keyboard, so Esc / B walks back
out through the real parents. Jump to "in-game" first and then to Keyboard
to test the same screen as opened from the pause menu.

While a keyboard rebind is waiting for a key, the sandbox ignores every key
(F-keys included), so you can bind them like any other key.

## Things worth testing with it

- **Scaling:** F2 through every size. Layouts are built on `uiScale = height / 1080`.
- **Gamepad navigation and rebinding** without a controller (F3).
- **Both parents of a sub-screen** (opened from main vs. from pause).
- **Fresh-install behaviour:** F8 resets saved settings so you see first-run defaults.
- **Texture filter** switching live on the demo checkerboard.

## Using it in your own game

The sandbox is two lines at the bottom of `main.lua`:

```lua
if love.filesystem.getInfo("sandbox/init.lua") then
    local sandbox = require("sandbox")
    if sandbox.requested(arg) then sandbox.attach() end
end
```

Copy the `sandbox/` folder and those lines into your game's root and it works
there too. It needs the template's module names (`ui_state`, `menu_input`,
`keybinds`, ...) at the project root.

**Optional: leave `sandbox/` out of release builds.** It does nothing unless
launched with `--sandbox`, so shipping it is harmless, but players don't need it.
If you delete the folder, the `getInfo` check skips the block, so no other edits
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
  (F9 opens it). `sandbox_session.txt` there is what remembers your screen.
