-- WL_GAME.lua
-- Game loop management - ported from WL_GAME.C
-- Handles level setup, game loop, play screen drawing

local wl_def  = require("wl_def")
local id_vl   = require("id_vl")
local id_vh   = require("id_vh")
local id_in   = require("id_in")
local id_sd   = require("id_sd")
local id_ca   = require("id_ca")
local id_us   = require("id_us")
local gfx     = require("gfxv_wl6")
local audiowl6 = require("audiowl6")

local wl_game = {}

---------------------------------------------------------------------------
-- Game state
---------------------------------------------------------------------------
wl_game.ingame    = false
wl_game.fizzlein  = false
wl_game.doornum   = 0
wl_game.demoname  = "DEMO0.WL6"

-- Pushwall state
wl_game.pwallstate = 0
wl_game.pwallx     = 0
wl_game.pwally     = 0
wl_game.pwalldir   = 0
wl_game.pwallpos   = 0

-- Door positions
wl_game.doorposition = {}
for i = 0, wl_def.MAXDOORS - 1 do
    wl_game.doorposition[i] = 0
end

-- Door objects
wl_game.doorobjlist = {}
wl_game.lastdoorobj = nil
for i = 0, wl_def.MAXDOORS - 1 do
    wl_game.doorobjlist[i] = wl_def.new_doorobj()
end

-- Area connectivity
wl_game.areaconnect = {}
wl_game.areabyplayer = {}
for i = 0, wl_def.NUMAREAS - 1 do
    wl_game.areabyplayer[i] = false
    wl_game.areaconnect[i] = {}
    for j = 0, wl_def.NUMAREAS - 1 do
        wl_game.areaconnect[i][j] = false
    end
end

-- Spear of Destiny state (unused in WL6 but defined)
wl_game.spearx = 0
wl_game.speary = 0
wl_game.spearangle = 0
wl_game.spearflag = false

---------------------------------------------------------------------------
-- SetupGameLevel
---------------------------------------------------------------------------

function wl_game.SetupGameLevel()
    local wl_main = require("wl_main")

    local mapnum = wl_main.gamestate.mapon + wl_main.gamestate.episode * 10

    -- Cache the map
    id_ca.CA_CacheMap(mapnum)

    -- Clear tilemap
    for x = 0, wl_def.MAPSIZE - 1 do
        for y = 0, wl_def.MAPSIZE - 1 do
            wl_main.tilemap[x][y] = 0
            wl_main.spotvis[x][y] = 0
            wl_main.actorat[x][y] = nil
        end
    end

    -- Reset door count
    wl_game.doornum = 0

    -- The full ScanInfoPlane would parse the map data here
    -- For now this is a stub
end

---------------------------------------------------------------------------
-- ScanInfoPlane (stub)
---------------------------------------------------------------------------

function wl_game.ScanInfoPlane()
    -- Would parse map plane 1 (info plane) for actors, items, etc.
end

---------------------------------------------------------------------------
-- DrawPlayBorder / DrawPlayScreen
---------------------------------------------------------------------------

function wl_game.DrawPlayBorder()
    local wl_main = require("wl_main")
    -- Draw the border around the play area
    id_vh.VWB_Bar(0, 0, 320, 200 - wl_def.STATUSLINES, 0x2d)
end

function wl_game.DrawPlayScreen()
    local wl_main = require("wl_main")
    wl_game.DrawPlayBorder()
    -- Would also draw status bar, etc.
end

function wl_game.DrawAllPlayBorder()
    wl_game.DrawPlayBorder()
end

function wl_game.DrawAllPlayBorderSides()
    -- stub
end

---------------------------------------------------------------------------
-- NormalScreen
---------------------------------------------------------------------------

function wl_game.NormalScreen()
    id_vl.VL_SetLineWidth(40)
end

---------------------------------------------------------------------------
-- FizzleOut
---------------------------------------------------------------------------

function wl_game.FizzleOut()
    -- Transition effect
    id_vh.VW_UpdateScreen()
end

---------------------------------------------------------------------------
-- ClearMemory
---------------------------------------------------------------------------

function wl_game.ClearMemory()
    id_sd.SD_StopDigitized()
    id_sd.SD_StopSound()
    id_sd.SD_MusicOff()
end

---------------------------------------------------------------------------
-- GameLoop (stub)
---------------------------------------------------------------------------

function wl_game.GameLoop()
    local wl_main = require("wl_main")
    -- This would be the main game loop
    -- For now, just set up the level and return
    wl_game.SetupGameLevel()
    wl_main.playstate = wl_def.ex_completed
end

---------------------------------------------------------------------------
-- PlayDemo (stub)
---------------------------------------------------------------------------

function wl_game.PlayDemo(demonumber)
    local wl_main = require("wl_main")
    -- Would play a demo recording
    wl_main.playstate = wl_def.ex_demodone
end

function wl_game.RecordDemo()
    -- stub
end

---------------------------------------------------------------------------
-- DrawHighScores
---------------------------------------------------------------------------

function wl_game.DrawHighScores()
    id_ca.CA_CacheScreen(gfx.HIGHSCORESPIC)
    -- Would draw score entries
end

return wl_game
