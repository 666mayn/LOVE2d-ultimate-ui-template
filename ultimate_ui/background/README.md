# ultimate_ui/background/

Drop **any** `.png` / `.jpg` here, with any name, any size (images are scaled to cover the screen).

* **In the sandbox editor (F11):** press **B** with nothing selected to cycle through every image in
this folder behind the current page (then off). **\[** / **]** change the blur (0 sharp ... 10 heaviest),
**-** / **=** change the dark dim.
* **Default test background:** `love . --sandbox` starts pages with the first image found here (blur 8,
dim 30%) so you can judge text over art. Tune or turn it off in `ultimate_ui/sandbox/config.lua`
(`defaultBackground`). Plain `love .` never shows it.
* **Exporting:** a background is written into an export only if you picked it yourself in the editor
(`background = { image = "ultimate_ui/background/<file>", blur = N }` in `exports/ultimate_ui/ui/<page>.lua`). Ship this
folder with your game, or at least the images you chose.
* **One background for every menu page:** set `menuBackground = { image = "ultimate_ui/background/<file>", blur = 8, dim = 0.3 }`
in `ultimate_ui/config.lua` (or `UI.configure{ menuBackground = {...} }`). Main, pause, settings, keyboard, controller, other,
texture and the loading screen all draw it, so it never drops out between pages. `dim` is the black overlay over it on every
page. In the sandbox the test background / your B, [ ], - = choices in the editor are mirrored into this, so all pages follow.
A widget screen that sets its own `background` still overrides it for that page.
* **In your own screens:** `background = { image = UI.path("background/your_image.png"), blur = 8 }` (or the plain path `"ultimate_ui/background/your_image.png"`, from the game root) on any
widget screen (see `ultimate_ui/ui/widgets.lua`).

**Licensing:** only commit art you have the right to redistribute. The included test image is a
placeholder (see `LICENSE.md` / `README.txt` here): replace it, or confirm its license, before publishing.

