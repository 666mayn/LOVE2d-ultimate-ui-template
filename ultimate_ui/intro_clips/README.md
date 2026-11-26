# intro_clips/

Drop .ogv videos here (nested folders are fine) and they play back to back on startup, in path order
(name them intro1.ogv, intro2.ogv ... to control the order). LÖVE 11 only plays Ogg Theora video.
No .ogv here = no intro.

While the intro plays, the game builds its menus behind it (fonts, blurred background, ...), so the first
menu appears without a hitch. Any key press, mouse click or gamepad button skips the intro; the remaining
set-up then finishes in one go.

Settings (ultimate_ui/config.lua): `introVideos` (nil or {} = use this folder; a list of paths = use exactly those;
false = no intro) and `introSkipHint` (show "Press any key to skip"; off by default).
