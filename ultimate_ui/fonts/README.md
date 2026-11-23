# ultimate_ui/fonts/

Drop `.ttf` / `.otf` files in here -- **nested folders are fine** (`fonts/font_boldpixels/boldpixels.ttf`,
`fonts/my_pack/ui/thing.otf`, ...). Every font file anywhere under this folder is registered automatically,
and nothing is loaded until something actually uses it.

`UI.fonts.list()` returns every font with the name you can use for it.

## Naming a font

All of these work (case does not matter) anywhere a font name is accepted:

| Name | Picks |
| --- | --- |
| `"boldpixels"` / `"font_boldpixels"` | the family (folder name, `font_` prefix optional) -> its main file |
| `"pixeloid_sans"` | `PixeloidSans.ttf` (the file named like the folder wins; then a Regular/Classic file; then the shortest name) |
| `"PixeloidSans-Bold"` / `"PixeloidSans-Bold.ttf"` | one exact file |
| `"font_pixeloid_sans/PixeloidSans-Bold.ttf"` | a path inside `fonts/` |

## Using fonts

1. **The whole project at once** -- `config.lua`: `font = "boldpixels"` (or `UI.configure{ font = "boldpixels" }`).
   Menus, HUD and the sandbox overlay all follow. No `font` set = the first font found.
2. **One kind of element** -- `config.lua`: `fontRoles = { button = "pixeloid_sans", title = "boldpixels" }`.
   Roles: `title`, `subtitle` (-> title), `button`, `row` (keybind / settings rows, -> button), `hint`, `stat`,
   `hud` (-> stat), `body`. A role you do not list uses the project font.
3. **One single element** -- put `font = "fibberish"` on a widget or stack item in its `ui/*.lua` file:
   `{ text = "E X I T", action = "exit", font = "fibberish" }`. It beats the role and the project font.
   For the hand-coded pages (Settings, Keyboard, ...) add `font = "..."` to the entry in `ui/page_texts.lua`.
4. **From code** -- `UI.fonts.setDefault("name")`, `UI.fonts.setRole("button", "name")`, and
   `love.graphics.setFont(UI.ui.getFont(24, "button"))` / `getFont(24, nil, "fibberish")` for your own text.

5. **Every font at once (override)** -- in the sandbox editor press **Shift+F** (nothing selected) to step the whole project
   through every font, then **Ctrl+E** to export it as `ui/all_fonts.lua`. While that file names a font, ALL text uses it, beating
   element fonts and roles; `return nil` turns it off. From code: `UI.fonts.setUniform("name")` (`nil` = back to the file,
   `false` = off).

Most specific wins: element `font` > role > project font > first font found > LOVE's built-in font.
The all-fonts override (5) beats all of that while it is on. An unknown name prints one warning (console + sandbox log) and falls back instead of crashing.

* Pixel fonts look best at the sizes in `ultimate_ui/fonts.lua` (`availableFontSizes`); edit that list for yours.
  Bitmap-style fonts (PlayerSansMono 8x8 / 8x13, ...) are crispest at multiples of their native size.
* Text is centered in buttons and rows by measuring each font's capital letters, so any font lines up on its own. If one still
  looks a hair high or low, nudge it: `fontNudge = { fibberish = 0.05 }` in `config.lua` (fraction of the font size, + = down).
* After swapping fonts in the folder, restart (F5 in the sandbox).

**Licensing:** each family keeps its own license file next to it. Keep the license of every font you ship, and delete
the folders (with their licenses) of fonts you do not use. BoldPixels is CC BY-SA 4.0.
