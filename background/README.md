# background/

Drop **any** `.png` / `.jpg` here, with any name, any size (images are scaled to cover the screen).

* **In the sandbox editor (F11):** press **B** with nothing selected to cycle through every image in
this folder behind the current page (then off). **\[** / **]** change the blur (0 sharp ... 10 heaviest),
**-** / **=** change the dark dim.
* **Default test background:** `love . --sandbox` starts pages with the first image found here (blur 8,
dim 30%) so you can judge text over art. Tune or turn it off in `sandbox/config.lua`
(`defaultBackground`). Plain `love .` never shows it.
* **Exporting:** a background is written into an export only if you picked it yourself in the editor
(`background = { image = "background/<file>", blur = N }` in `exports/ui/<page>.lua`). Ship this
folder with your game, or at least the images you chose.
* **In your own screens:** `background = { image = "background/your\\\_image.png", blur = 8 }` on any
widget screen (see `ui/widgets.lua`).

**Licensing:** only commit art you have the right to redistribute. The included test image is a
placeholder (see `LICENSE.md` / `README.txt` here): replace it, or confirm its license, before publishing.

