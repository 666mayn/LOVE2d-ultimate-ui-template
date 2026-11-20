# fonts/

Drop **any** `.ttf` or `.otf` file in here, with any name, and the whole template uses it
(menus, HUD, and the sandbox/editor overlay). No code changes.

* Several fonts in this folder? The first one (alphabetical) is used. To choose, set
`font = "myfont.ttf"` in `config.lua` (the file name inside `fonts/`).
* No usable font here? LÖVE's built-in font is used, so the template still runs.
* Pixel fonts look best at the sizes in `fonts.lua` (`availableFontSizes`); edit that list for yours.
* After swapping a font, restart (F5 in the sandbox).

**Licensing:** the bundled BoldPixels is CC BY-SA 4.0 (see `INCLUDED\_FONT\_LICENSE.txt`). If you replace it,
delete that font and its license file, and keep the license of whatever you add.

