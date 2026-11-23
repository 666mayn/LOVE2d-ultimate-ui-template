-- ui/all_fonts.lua
-- The "every font at once" override. While it names a font, ALL text in the UI (titles, buttons,
-- rows, hints, HUD) is drawn in that font, beating per-element fonts, roles and config.font.
-- The sandbox editor writes this file when you export (Ctrl+E / Ctrl+Shift+E) after choosing a font
-- with Shift+F; you can also edit it by hand.
--
--   font   a font name from UI.fonts.list(), e.g. "pixeloid_sans" or "PixeloidSans-Bold"
--
-- `return nil` = no override: every element keeps its own font / role font / the project font.
return nil
