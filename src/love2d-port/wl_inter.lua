-- WL_INTER.lua
-- Intermission screens - ported from WL_INTER.C
-- Handles intro screens, level completion, victory, high scores

local bit = require("bit")
local band, bor, lshift, rshift = bit.band, bit.bor, bit.lshift, bit.rshift

local id_vl  = require("id_vl")
local id_vh  = require("id_vh")
local id_in  = require("id_in")
local id_sd  = require("id_sd")
local id_us  = require("id_us")
local id_ca  = require("id_ca")
local gfx    = require("gfxv_wl6")
local audiowl6 = require("audiowl6")
local wl_def = require("wl_def")

local wl_inter = {}

---------------------------------------------------------------------------
-- IntroScreen - show the signon/intro screen
---------------------------------------------------------------------------

function wl_inter.IntroScreen()
    if not id_us.NoWait then
        wl_inter.PG13()
    end
end

---------------------------------------------------------------------------
-- PG13 - show the PG-13 rating screen
---------------------------------------------------------------------------

function wl_inter.PG13()
    id_ca.CA_CacheScreen(gfx.PG13PIC)
    id_vh.VW_UpdateScreen()
    id_vh.VW_FadeIn()

    if not id_us.NoWait then
        id_in.IN_UserInput(id_sd.TickBase * 7)
    end

    id_vh.VW_FadeOut()
end

---------------------------------------------------------------------------
-- PreloadGraphics
---------------------------------------------------------------------------

function wl_inter.PreloadGraphics()
    -- Draw "Get Psyched" loading bar
    id_ca.CA_CacheGrChunk(gfx.GETPSYCHEDPIC)

    wl_inter.ClearSplitVWB()
    id_vh.VWB_DrawPic(0, 0, gfx.GETPSYCHEDPIC)

    -- Draw progress bar outline
    id_vh.VWB_Bar(34, 152, 252, 10, 0)
    id_vh.VWB_Bar(35, 153, 250, 8, wl_def.BORDERCOLOR_CONST)

    id_vh.VW_UpdateScreen()
    id_vh.VW_FadeIn()

    -- Simulate loading progress
    for i = 0, 10 do
        local width = math.floor(i * 250 / 10)
        id_vh.VWB_Bar(35, 153, width, 8, 0x37)
        id_vh.VW_UpdateScreen()
    end

    -- Done loading
    id_in.IN_UserInput(id_sd.TickBase * 1)
    id_vh.VW_FadeOut()
end

---------------------------------------------------------------------------
-- ClearSplitVWB
---------------------------------------------------------------------------

function wl_inter.ClearSplitVWB()
    id_vl.VL_Bar(0, 0, 320, 160, 0)
end

---------------------------------------------------------------------------
-- LevelCompleted - show level stats
---------------------------------------------------------------------------

function wl_inter.LevelCompleted()
    local wl_main = require("wl_main")
    local wl_menu = require("wl_menu")

    wl_menu.CacheLump(gfx.LEVELEND_LUMP_START or gfx.L_GUYPIC or 0, gfx.LEVELEND_LUMP_END or gfx.L_BJWINSPIC or 0)

    wl_inter.ClearSplitVWB()

    -- Draw a basic level-complete screen
    id_vh.VWB_Bar(0, 0, 320, 160, 0x2d)

    id_vh.fontnumber = 1
    id_vh.fontcolor = 0x0f
    id_vh.backcolor = 0x2d

    -- Display stats text
    id_vh.px = 50
    id_vh.py = 20
    id_vh.VWB_DrawPropString("Floor " .. tostring(wl_main.gamestate.mapon + 1) .. " Completed!")

    local gs = wl_main.gamestate

    id_vh.px = 50; id_vh.py = 50
    id_vh.VWB_DrawPropString("Kill Ratio: " ..
        tostring(gs.killtotal > 0 and math.floor(gs.killcount * 100 / gs.killtotal) or 0) .. "%")

    id_vh.px = 50; id_vh.py = 70
    id_vh.VWB_DrawPropString("Secret Ratio: " ..
        tostring(gs.secrettotal > 0 and math.floor(gs.secretcount * 100 / gs.secrettotal) or 0) .. "%")

    id_vh.px = 50; id_vh.py = 90
    id_vh.VWB_DrawPropString("Treasure Ratio: " ..
        tostring(gs.treasuretotal > 0 and math.floor(gs.treasurecount * 100 / gs.treasuretotal) or 0) .. "%")

    id_vh.VW_UpdateScreen()
    id_vh.VW_FadeIn()

    id_in.IN_UserInput(id_sd.TickBase * 10)

    id_vh.VW_FadeOut()
end

---------------------------------------------------------------------------
-- Victory
---------------------------------------------------------------------------

function wl_inter.Victory()
    local wl_main = require("wl_main")

    wl_inter.ClearSplitVWB()

    id_vh.VWB_Bar(0, 0, 320, 160, 0x2d)
    id_vh.fontnumber = 1
    id_vh.fontcolor = 0x0f
    id_vh.backcolor = 0x2d

    id_vh.px = 80; id_vh.py = 60
    id_vh.VWB_DrawPropString("VICTORY!")
    id_vh.px = 40; id_vh.py = 90
    id_vh.VWB_DrawPropString("You have completed the episode!")

    id_vh.VW_UpdateScreen()
    id_vh.VW_FadeIn()

    id_in.IN_UserInput(id_sd.TickBase * 15)

    id_vh.VW_FadeOut()

    wl_inter.CheckHighScore(wl_main.gamestate.score, wl_main.gamestate.mapon + 1)
end

---------------------------------------------------------------------------
-- CheckHighScore
---------------------------------------------------------------------------

function wl_inter.CheckHighScore(score, completed)
    -- Simplified high score check
    wl_inter.DrawHighScores()
    id_vh.VW_UpdateScreen()
    id_vh.VW_FadeIn()
    id_in.IN_UserInput(id_sd.TickBase * 10)
    id_vh.VW_FadeOut()
end

---------------------------------------------------------------------------
-- DrawHighScores
---------------------------------------------------------------------------

function wl_inter.DrawHighScores()
    id_ca.CA_CacheScreen(gfx.HIGHSCORESPIC)

    -- Would draw score entries on top
    id_vh.fontnumber = 1
    id_vh.fontcolor = 0x0f
    id_vh.backcolor = 0x00

    -- Default high scores
    local scores = {
        {name = "Id Software",  score = 10000, completed = 1},
        {name = "B.J.",         score = 5000,  completed = 1},
        {name = "Todd",         score = 3000,  completed = 1},
    }

    for i, entry in ipairs(scores) do
        id_vh.px = 48
        id_vh.py = 68 + (i - 1) * 16
        id_vh.VWB_DrawPropString(entry.name)
        id_vh.px = 192
        id_vh.VWB_DrawPropString(tostring(entry.score))
    end
end

---------------------------------------------------------------------------
-- FreeMusic
---------------------------------------------------------------------------

function wl_inter.FreeMusic()
    -- Free cached music data (no-op, GC handles it)
end

return wl_inter
