-- ultimate_ui/ui/page_texts.lua  (the hand-coded pages' texts)
-- Exported from the sandbox editor on 2026-11-21 23:42.
--
-- DROP-IN: copy this file over ultimate_ui/ui/page_texts.lua in your project and restart. The Settings,
-- Keyboard, Controller, Other, Textures and Loading pages read it at startup and show these
-- texts / colors instead of the ones in their code. Only what you changed is listed.
--
-- Layout: [page id]["title" | "hint" | "rows#<row key>"] = { text = "...", color = ... }
-- Edit it by hand, or tweak it again in the editor (love . --sandbox, F11, Ctrl+E).

return {
    controllerMenu = {
        ["rows#back"] = {
            text = "TEST BACK",
        },
        ["rows#placeholder_action"] = {
            text = "TEST ACTION",
        },
        ["rows#placeholder_backward"] = {
            text = "TEST DOWN",
        },
        ["rows#placeholder_forward"] = {
            text = "TEST UP",
        },
        ["rows#placeholder_jump"] = {
            text = "TEST JUMP",
        },
        ["rows#placeholder_left"] = {
            text = "TEST LEFT",
        },
        ["rows#placeholder_right"] = {
            text = "TEST RIGHT",
        },
        ["rows#placeholder_sprint"] = {
            text = "TEST SPRINT",
        },
        ["rows#reset"] = {
            text = "TEST RETURN TO DEFAULTS",
        },
    },
    keyboardMenu = {
        ["rows#back"] = {
            text = "TEST BACK",
        },
        ["rows#placeholder_action"] = {
            text = "TEST E",
        },
        ["rows#placeholder_backward"] = {
            text = "TEST S",
        },
        ["rows#placeholder_forward"] = {
            text = "TEST W",
        },
        ["rows#placeholder_jump"] = {
            text = "TEST SPACE",
        },
        ["rows#placeholder_left"] = {
            text = "TEST A",
        },
        ["rows#placeholder_right"] = {
            text = "TEST D",
        },
        ["rows#placeholder_sprint"] = {
            text = "TEST SHIFT",
        },
        ["rows#reset"] = {
            text = "TEST RETURN TO DEFAULTS",
        },
    },
    otherSettingsMenu = {
        ["rows#back"] = {
            text = "TEST BACK",
        },
        ["rows#fullscreen"] = {
            text = "TEST FULLSCREEN",
        },
        ["rows#music_volume"] = {
            text = "TEST GLOBAL VOL",
        },
        ["rows#reset"] = {
            text = "TEST RETURN TO DEFAULTS",
        },
        ["rows#screen_shake"] = {
            text = "TEST SCREEN SHAKE",
        },
        ["rows#sfx_volume"] = {
            text = "TEST SFX",
        },
        ["rows#show_fps"] = {
            text = "TEST SHOW FPS",
        },
    },
    settingsMenu = {
        ["rows#back"] = {
            text = "TEST BACK",
        },
        ["rows#controller"] = {
            text = "TEST CONTROLLER",
        },
        ["rows#keyboard"] = {
            text = "TEST KEYBOARD",
        },
        ["rows#other_settings"] = {
            text = "TEST OTHER",
        },
        ["rows#texture_filter"] = {
            text = "TEST TEXTURES",
        },
    },
}
