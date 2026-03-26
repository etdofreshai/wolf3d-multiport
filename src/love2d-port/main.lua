-- main.lua
-- Love2D entry point for Wolfenstein 3-D port
-- Wires up Love2D callbacks to the game engine modules

-- Set up the asset search path so WL6 files can be found
local source_path = love.filesystem.getSource()
local source_base = love.filesystem.getSourceBaseDirectory()
print("Love2D source path: " .. source_path)
print("Love2D source base: " .. source_base)

-- Helper: resolve a path by removing trailing slashes and collapsing "foo/.." segments
local function resolve_path(p)
    -- Normalize separators
    p = p:gsub("\\", "/")
    -- Remove trailing slash
    p = p:gsub("/$", "")
    -- Collapse /foo/.. segments repeatedly
    local changed = true
    while changed do
        local newp = p:gsub("/[^/]+/%.%.", "")
        changed = (newp ~= p)
        p = newp
    end
    return p
end

-- Strip trailing slash from source_path
local sp = source_path:gsub("[/\\]+$", "")
local sb = source_base:gsub("[/\\]+$", "")

-- Try to find assets relative to the port directory and the base directory
-- The assets should be at ../../assets/ relative to this file (src/love2d-port)
local possible_paths = {
    resolve_path(sp .. "/../../assets"),
    resolve_path(sp .. "/../../../assets"),
    resolve_path(sp .. "/assets"),
    sp,
    resolve_path(sb .. "/assets"),
    resolve_path(sb .. "/../assets"),
}

-- Normalize path separators for Windows
for i, p in ipairs(possible_paths) do
    possible_paths[i] = p:gsub("\\", "/")
end

local found_assets = false
for _, full in ipairs(possible_paths) do
    -- Try both forward and back slash versions on Windows
    local ok = love.filesystem.mount(full, "", true)
    if not ok then
        ok = love.filesystem.mount(full:gsub("/", "\\"), "", true)
    end
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
local id_us   = require("id_us")
local wl_main = require("wl_main")

---------------------------------------------------------------------------
-- Game state
---------------------------------------------------------------------------
local game_initialized = false
local game_error = nil
local game_coroutine = nil

---------------------------------------------------------------------------
-- Test/capture state (set from command line)
---------------------------------------------------------------------------
local test_sequence_enabled = false
local quit_after_ms = 0        -- 0 = disabled
local quit_after_start = nil   -- love.timer.getTime() at first update
local test_start_time = nil
local test_next_event = 1      -- 1-indexed

-- Test sequence events matching the C port timings
-- Each entry: { time_ms, love_key, is_press }
local test_events = {
    -- ~1s: Press SPACE (acknowledge signon "Press a key")
    {  1000, "space", true  },
    {  1200, "space", false },
    -- ~4s: Press SPACE (acknowledge PC-13 screen)
    {  4000, "space", true  },
    {  4200, "space", false },
    -- ~9s: Press SPACE (dismiss title, should go to menu)
    {  9000, "space", true  },
    {  9200, "space", false },
    -- ~13s: Press RETURN (select "New Game" in menu)
    { 13000, "return", true  },
    { 13200, "return", false },
    -- ~16s: Press RETURN (select episode)
    { 16000, "return", true  },
    { 16200, "return", false },
    -- ~19s: Press RETURN (select difficulty)
    { 19000, "return", true  },
    { 19200, "return", false },
}

---------------------------------------------------------------------------
-- love.load - called once at startup
---------------------------------------------------------------------------
function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Parse command-line args
    if arg then
        for i, v in ipairs(arg) do
            if v == "--capture" then
                id_vl.capture_enabled = true
            end
            if v == "--capture-limit" and arg[i+1] then
                id_vl.capture_limit = tonumber(arg[i+1])
            end
            if v == "--quit-after" and arg[i+1] then
                quit_after_ms = tonumber(arg[i+1])
            end
            if v == "--test-sequence" then
                test_sequence_enabled = true
            end
            if v == "--nowait" then
                id_us.NoWait = true
            end
        end
    end

    if id_vl.capture_enabled then
        print("Frame capture enabled (limit=" .. tostring(id_vl.capture_limit) .. ")")
        print("Capture save directory: " .. love.filesystem.getSaveDirectory())
    end
    if test_sequence_enabled then
        print("Test sequence enabled")
    end
    if quit_after_ms > 0 then
        print("Auto-quit after " .. quit_after_ms .. " ms")
    end

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

    -- Initialize timing references on first update
    local now_ms = love.timer.getTime() * 1000
    if not quit_after_start then
        quit_after_start = now_ms
    end
    if test_sequence_enabled and not test_start_time then
        test_start_time = now_ms
    end

    -- Test sequence: inject key events at specific elapsed times
    if test_sequence_enabled and test_start_time then
        local elapsed = now_ms - test_start_time
        while test_next_event <= #test_events do
            local ev = test_events[test_next_event]
            if ev[1] > elapsed then
                break
            end
            -- Inject the key event directly into id_in
            if ev[3] then
                -- key down
                id_in.keypressed(ev[2], ev[2], false)
            else
                -- key up
                id_in.keyreleased(ev[2], ev[2])
            end
            test_next_event = test_next_event + 1
        end
    end

    -- Auto-quit timer
    if quit_after_ms > 0 and quit_after_start then
        if (now_ms - quit_after_start) >= quit_after_ms then
            love.event.quit(0)
            return
        end
    end

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
