-- main.lua
-- Love2D entry point for Wolfenstein 3-D port
-- Wires up Love2D callbacks to the game engine modules

-- Set up the asset search path so WL6 files can be found
local source_path = love.filesystem.getSource()
print("Love2D source path: " .. source_path)

-- Try to find assets relative to the port directory
-- The assets should be at ../../assets/ relative to this file
local possible_paths = {
    source_path .. "/../../assets",
    source_path .. "/../../../assets",
    source_path .. "/assets",
    source_path,
}

-- Normalize path separators for Windows
for i, p in ipairs(possible_paths) do
    possible_paths[i] = p:gsub("\\", "/")
end

local found_assets = false
for _, full in ipairs(possible_paths) do
    local ok = love.filesystem.mount(full, "", true)
    if ok then
        local info = love.filesystem.getInfo("VSWAP.WL6")
        if info then
            print("Found game assets at: " .. full)
            found_assets = true
            break
        end
        -- Also try lowercase
        info = love.filesystem.getInfo("vswap.wl6")
        if info then
            print("Found game assets (lowercase) at: " .. full)
            found_assets = true
            break
        end
    end
end

-- Verify assets are available
local required_files = {"VSWAP.WL6", "VGAHEAD.WL6", "VGAGRAPH.WL6", "VGADICT.WL6",
                        "MAPHEAD.WL6", "GAMEMAPS.WL6", "AUDIOHED.WL6", "AUDIOT.WL6"}
local missing = {}
for _, f in ipairs(required_files) do
    if not love.filesystem.getInfo(f) then
        table.insert(missing, f)
    end
end

if #missing > 0 then
    print("WARNING: Missing game data files: " .. table.concat(missing, ", "))
    print("Please place WL6 data files in the assets directory or the game directory.")
end

---------------------------------------------------------------------------
-- Load game modules
---------------------------------------------------------------------------
local id_vl   = require("id_vl")
local id_in   = require("id_in")
local id_sd   = require("id_sd")
local id_vh   = require("id_vh")
local wl_main = require("wl_main")

---------------------------------------------------------------------------
-- Game state
---------------------------------------------------------------------------
local game_initialized = false
local game_error = nil
local game_coroutine = nil

---------------------------------------------------------------------------
-- love.load - called once at startup
---------------------------------------------------------------------------
function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Check if assets are available
    if #missing > 0 then
        game_error = "Missing game data files:\n" .. table.concat(missing, "\n") ..
            "\n\nPlace WL6 files in the assets/ directory."
        return
    end

    -- Initialize the game in a coroutine so blocking operations
    -- (like IN_Ack, VL_FadeIn) can yield back to the Love2D event loop
    game_coroutine = coroutine.create(function()
        local ok, err = pcall(function()
            wl_main.InitGame()
            game_initialized = true
            wl_main.DemoLoop()
        end)
        if not ok then
            game_error = "Game error: " .. tostring(err)
            print(game_error)
        end
    end)
end

---------------------------------------------------------------------------
-- love.update - called every frame
---------------------------------------------------------------------------
function love.update(dt)
    if game_error then return end

    -- Update TimeCount
    id_sd.SD_TimeCountUpdate()

    -- Resume the game coroutine
    if game_coroutine and coroutine.status(game_coroutine) ~= "dead" then
        local ok, err = coroutine.resume(game_coroutine)
        if not ok then
            game_error = "Coroutine error: " .. tostring(err)
            print(game_error)
        end
    end
end

---------------------------------------------------------------------------
-- love.draw - called every frame to render
---------------------------------------------------------------------------
function love.draw()
    if game_error then
        love.graphics.setColor(1, 0.3, 0.3, 1)
        love.graphics.printf(game_error, 20, 20, love.graphics.getWidth() - 40)
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    -- Present the Wolf3D framebuffer
    id_vl.VL_Present()
end

---------------------------------------------------------------------------
-- Input callbacks - forward to id_in
---------------------------------------------------------------------------
function love.keypressed(key, scancode, isrepeat)
    id_in.keypressed(key, scancode, isrepeat)
end

function love.keyreleased(key, scancode)
    id_in.keyreleased(key, scancode)
end

function love.mousemoved(x, y, dx, dy)
    id_in.mousemoved(x, y, dx, dy)
end

function love.mousepressed(x, y, button)
    id_in.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    id_in.mousereleased(x, y, button)
end

---------------------------------------------------------------------------
-- Window resize handling
---------------------------------------------------------------------------
function love.resize(w, h)
    -- Nothing special needed - VL_Present handles scaling
end

---------------------------------------------------------------------------
-- Quit handler
---------------------------------------------------------------------------
function love.quit()
    if game_initialized then
        wl_main.ShutdownId()
    end
    return false  -- Allow quit
end
