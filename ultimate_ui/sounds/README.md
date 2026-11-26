# ultimate_ui/sounds/

Three sounds are wired in. Drop your own files in this folder to replace them, with no code changes.

| Drop in a file named | Plays when | Bundled example it replaces |
| --- | --- | --- |
| `ui.ogg` (or `.mp3` / `.wav`) | a menu button is activated: mouse click, Enter, gamepad A, and Esc / B for "back" | `example_ui.ogg` |
| `loading.ogg` (or `.mp3` / `.wav`) | the loading screen starts (after PLAY) | `example_loading.ogg` |
| `intro.ogg` (or `.mp3` / `.wav`) | the startup intro video starts; it is cut off when the intro ends or is skipped | `example_intro.ogg` |

* **The loading screen lasts exactly as long as the loading sound.** A 4 s `loading.mp3` gives a 4 s loading screen;
  a 1.5 s one gives 1.5 s. With no loading sound at all it falls back to 1 s. Trim any silence off the end of your
  file, because silence counts as length.
* **Yours wins.** If `loading.*` exists it is used instead of `example_loading.ogg`; same for `ui.*` and `example_ui.ogg`.
  You can delete the two examples whenever you like.
* **Formats:** `.ogg`, `.mp3`, `.wav`. If the same name exists in several formats, `.ogg` is used first, then `.mp3`, then `.wav`.
  File names are not case-sensitive (`Loading.MP3` works). Anything else (`.flac`, `.m4a`, ...) is ignored, with a warning at startup.
* **Volume:** both sounds follow Settings -> Other -> SFX volume.
* **Skipping the intro** (any key, click or gamepad button) plays the `ui` click sound and stops the intro sound.
* **Clicking empty space, or moving the cursor, is silent.** Only activating a button plays the click.
* After swapping a file, restart (F5 in the sandbox). The folder is scanned once at startup.
* No sounds here at all is fine: the template just stays silent.

**In your own code**

```lua
local UI = require("ultimate_ui")
UI.sounds.playUI()                         -- the click sound, e.g. for your own buttons
UI.sounds.playLoading()                    -- start the loading sound
UI.sounds.stopLoading()
UI.sounds.playIntro()                      -- the intro sound (main.lua starts / stops it with the intro video)
UI.sounds.stopIntro()
loading_screen.start("level2", UI.sounds.loadingDuration(1.0), "LOADING...")   -- screen as long as the sound
UI.sounds.path("loading")                  -- the file in use, or nil
```

`main.lua` shows the loading-screen wiring (`onStart` / `onFinish` / the PLAY button). The click sound needs no wiring:
`menu_input.lua` plays it for every menu.

**Licensing:** only ship sounds you have the right to redistribute. Confirm or replace the bundled examples before publishing.
