-- conf.lua
function love.conf(t)
    t.identity = "love2d-ui-template"   -- save-folder name: change this per game!
    t.version = "11.5"
    t.window.title = "LOVE2D UI Template"
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = true
    t.window.minwidth = 640
    t.window.minheight = 360
    t.window.vsync = 1
end
