# exports/

Pages exported from the sandbox editor land here, **in the same folder layout as the project**:

```
exports/
  ultimate_ui/
    ui/
      main_menu.lua    <- replaces  ultimate_ui/ui/main_menu.lua
```

(If you keep the library somewhere else, say `libs/ultimate_ui/`, the exports mirror that
path instead: `exports/libs/ultimate_ui/ui/main_menu.lua`.)

## The workflow

1. `love . --sandbox`, press **F11** (edit mode), click a title or button, change its text / color.
2. Export:
   - **Ctrl+E** exports the page you're looking at.
   - **Ctrl+Shift+E** exports **all** pages in one go (a complete set).
3. **Install:** drag the `exports/ultimate_ui` folder onto the project root and choose *Replace*
   (or copy a single file over the one it names). The sandbox restarts by itself.
4. Your `ultimate_ui/ui/` files are now your custom pages -- take them into your own build.

Every export is a **whole screen file, not a fragment**. It keeps providing the functions
`ultimate_ui/ui/init.lua` and `menu_input.lua` already call, so nothing else has to change.

## Good to know

- Exports are plain Lua data. Edit them by hand, or open the page in the editor again.
- Re-exporting overwrites the file in `exports/`. Installed pages in `ultimate_ui/ui/` are never touched until you copy them.
- Once you install an export, the editor notices the root file changed and drops its older edits for that
  page ("the file wins"), so what you see is what's in the file.
- `{config.title}` in a text stays **live** (it follows `ultimate_ui/config.lua`); type over it to make it fixed text.
- The sandbox's test background and dim are **not** written into an export unless you picked them
  yourself (**B**, **[ ]**, **- =**). If you did, ship the `ultimate_ui/background/` folder with your game.
- Only pages built from `ui/widgets.lua` are exported (the main menu so far).
- If the project folder can't be written (running from a `.love`), exports go to the save folder (**F9**) and the
  on-screen message says so.
