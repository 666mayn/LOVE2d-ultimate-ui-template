# cursor/

Drop ONE image here (.png, .jpg, .bmp or .tga) and it becomes the mouse cursor for the whole app.
Nested folders are fine. Several images? The first one by path (alphabetical) wins.
No image here = the normal system cursor.

* Big images are shrunk to `config.cursorSize` (default 32 px, longest side). Small ones are used as they are.
* The "hot spot" (the exact pixel that clicks) is `config.cursorHotspot` = `{ 0.5, 0.5 }`, as fractions of the
  image: `{ 0, 0 }` = top-left corner (a classic arrow), `{ 0.5, 0.5 }` = the middle.
* `config.cursor = false` turns it off. Change the file, then restart the game.
