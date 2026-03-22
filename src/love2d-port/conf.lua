-- conf.lua
-- Love2D configuration for Wolfenstein 3-D port

function love.conf(t)
    t.identity = "wolf3d"
    t.version = "11.4"
    t.console = true

    t.window.title = "Wolfenstein 3-D"
    t.window.width = 960
    t.window.height = 600
    t.window.resizable = true
    t.window.minwidth = 320
    t.window.minheight = 200
    t.window.vsync = 1

    t.modules.audio = true
    t.modules.data = true
    t.modules.event = true
    t.modules.font = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.joystick = true
    t.modules.keyboard = true
    t.modules.math = true
    t.modules.mouse = true
    t.modules.physics = false
    t.modules.sound = true
    t.modules.system = true
    t.modules.timer = true
    t.modules.touch = false
    t.modules.video = false
    t.modules.window = true
    t.modules.thread = true
end
