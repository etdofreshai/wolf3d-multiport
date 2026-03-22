-- WL_INTER.lua
-- Intermission screens - ported from WL_INTER.C
-- Handles intro screens, level completion, victory, etc.

local id_vl  = require("id_vl")
local id_vh  = require("id_vh")
local id_in  = require("id_in")
local id_sd  = require("id_sd")
local id_us  = require("id_us")
local id_ca  = require("id_ca")
local gfx    = require("gfxv_wl6")
local audiowl6 = require("audiowl6")

local wl_inter = {}

---------------------------------------------------------------------------
-- IntroScreen - show the signon/intro screen
---------------------------------------------------------------------------

function wl_inter.IntroScreen()
    -- The intro screen would be loaded from the signon data
    -- For now, just show a brief pause
    if not id_us.NoWait then
        -- Show PG13 screen
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
    id_vh.VWB_DrawPic(0, 0, gfx.GETPSYCHEDPIC)

    -- Draw progress bar
    local total = 100
    for i = 0, total do
        local x = math.floor(i * 256 / total)
        id_vh.VWB_Bar(32, 152, x, 8, wl_inter._psyched_color or 0x37)
        id_vh.VW_UpdateScreen()
    end
end

---------------------------------------------------------------------------
-- ClearSplitVWB
---------------------------------------------------------------------------

function wl_inter.ClearSplitVWB()
    id_vl.VL_Bar(0, 0, 320, 160, 0)
end

---------------------------------------------------------------------------
-- LevelCompleted
---------------------------------------------------------------------------

function wl_inter.LevelCompleted()
    -- Stub - would show level stats
end

---------------------------------------------------------------------------
-- Victory
---------------------------------------------------------------------------

function wl_inter.Victory()
    -- Stub
end

---------------------------------------------------------------------------
-- CheckHighScore
---------------------------------------------------------------------------

function wl_inter.CheckHighScore(score, other)
    id_us.US_CheckHighScore(score, other)
end

---------------------------------------------------------------------------
-- FreeMusic
---------------------------------------------------------------------------

function wl_inter.FreeMusic()
    -- Free cached music data
end

---------------------------------------------------------------------------
-- DrawHighScores
---------------------------------------------------------------------------

function wl_inter.DrawHighScores()
    id_ca.CA_CacheScreen(gfx.HIGHSCORESPIC)
    -- Would draw score entries on top
end

return wl_inter
