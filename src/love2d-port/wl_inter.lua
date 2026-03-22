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
-- Write() - draw a letter graphic at letterX, letterY
-- Used by intermission to draw large-font messages with graphic letters
---------------------------------------------------------------------------

function wl_inter.Write(x, y, ch)
    -- ch is a character code (or ASCII)
    local c = string.byte(ch) or ch
    local picnum = nil

    if c >= 65 and c <= 90 then      -- 'A'-'Z'
        picnum = gfx.L_APIC + (c - 65)
    elseif c >= 97 and c <= 122 then  -- 'a'-'z'
        picnum = gfx.L_APIC + (c - 97)
    elseif c >= 48 and c <= 57 then   -- '0'-'9'
        picnum = gfx.L_NUM0PIC + (c - 48)
    elseif c == 58 then               -- ':'
        picnum = gfx.L_COLONPIC
    elseif c == 37 then               -- '%'
        picnum = gfx.L_PERCENTPIC
    elseif c == 33 then               -- '!'
        picnum = gfx.L_EXPOINTPIC
    elseif c == 39 then               -- "'"
        picnum = gfx.L_APOSTROPHEPIC
    end

    if picnum then
        id_ca.CA_CacheGrChunk(picnum)
        id_vh.VWB_DrawPic(x, y, picnum)
    end
end

---------------------------------------------------------------------------
-- BJ_Breathe - BJ's breathing animation on intermission screens
---------------------------------------------------------------------------

function wl_inter.BJ_Breathe()
    local id_sd_local = require("id_sd")
    -- Simple breathing animation frames: alternate between GUY and GUY2
    local base_tic = id_sd_local.TimeCount
    local frame = 0

    -- Breathe for a few frames
    for i = 1, 3 do
        local pic = (i % 2 == 0) and gfx.L_GUY2PIC or gfx.L_GUYPIC
        id_ca.CA_CacheGrChunk(pic)
        id_vh.VWB_DrawPic(0, 16, pic)
        id_vh.VW_UpdateScreen()

        -- Wait ~35 ticks
        local start = id_sd_local.TimeCount
        while (id_sd_local.TimeCount - start) < 35 do
            id_in.IN_WaitAndProcessEvents()
            if id_in.LastScan ~= 0 then return true end
        end
    end
    return false
end

---------------------------------------------------------------------------
-- LevelCompleted - show level stats
---------------------------------------------------------------------------

function wl_inter.LevelCompleted()
    local wl_main = require("wl_main")
    local wl_menu = require("wl_menu")

    wl_menu.CacheLump(gfx.LEVELEND_LUMP_START, gfx.LEVELEND_LUMP_END)

    wl_menu.StartCPMusic(audiowl6.ENDLEVEL_MUS)

    wl_inter.ClearSplitVWB()

    -- Draw BJ with level stats
    id_ca.CA_CacheGrChunk(gfx.L_GUYPIC)
    id_vh.VWB_DrawPic(0, 16, gfx.L_GUYPIC)

    local gs = wl_main.gamestate

    id_vh.fontnumber = 1
    id_vh.fontcolor = 0x0f
    id_vh.backcolor = 0

    -- Floor completed header
    id_vh.px = 50; id_vh.py = 20
    id_vh.VWB_DrawPropString("Floor " .. tostring(gs.mapon % 10 + 1) .. " Completed!")

    -- Kill ratio
    local kr = gs.killtotal > 0 and math.floor(gs.killcount * 100 / gs.killtotal) or 0
    local sr = gs.secrettotal > 0 and math.floor(gs.secretcount * 100 / gs.secrettotal) or 0
    local tr = gs.treasuretotal > 0 and math.floor(gs.treasurecount * 100 / gs.treasuretotal) or 0

    -- Time
    local sec = math.floor(gs.TimeCount / 70)
    local min_val = math.floor(sec / 60)
    sec = sec % 60

    -- Draw ratios with letter graphics
    local RATIOX = 6
    local RATIOY = 14
    local TIMEX = 14
    local TIMEY = 8

    -- Kill ratio
    id_vh.px = 80; id_vh.py = 48
    id_vh.VWB_DrawPropString("Kill Ratio:  " .. tostring(kr) .. "%")

    -- Secret ratio
    id_vh.px = 80; id_vh.py = 68
    id_vh.VWB_DrawPropString("Secret Ratio:  " .. tostring(sr) .. "%")

    -- Treasure ratio
    id_vh.px = 80; id_vh.py = 88
    id_vh.VWB_DrawPropString("Treasure Ratio:  " .. tostring(tr) .. "%")

    -- Time
    id_vh.px = 80; id_vh.py = 108
    id_vh.VWB_DrawPropString("Time: " .. string.format("%d:%02d", min_val, sec))

    -- Bonuses
    local bonus = 0
    if kr == 100 then bonus = bonus + 10000 end
    if sr == 100 then bonus = bonus + 10000 end
    if tr == 100 then bonus = bonus + 10000 end
    if bonus > 0 then
        id_vh.px = 80; id_vh.py = 128
        id_vh.VWB_DrawPropString("Bonus: " .. tostring(bonus))
        gs.score = gs.score + bonus
    end

    -- Play bonus sounds for 100%
    if kr == 100 then id_sd.SD_PlaySound(audiowl6.PERCENT100SND) end
    if sr == 100 then id_sd.SD_PlaySound(audiowl6.PERCENT100SND) end
    if tr == 100 then id_sd.SD_PlaySound(audiowl6.PERCENT100SND) end

    id_vh.VW_UpdateScreen()
    id_vh.VW_FadeIn()

    -- Wait with BJ breathing animation
    local start_time = id_sd.TimeCount
    while (id_sd.TimeCount - start_time) < id_sd.TickBase * 10 do
        id_in.IN_WaitAndProcessEvents()
        if id_in.LastScan ~= 0 then
            id_in.IN_ClearKeysDown()
            break
        end
        -- BJ breathe cycle
        wl_inter.BJ_Breathe()
    end

    id_vh.VW_FadeOut()
    wl_menu.UnCacheLump(gfx.LEVELEND_LUMP_START, gfx.LEVELEND_LUMP_END)
end

---------------------------------------------------------------------------
-- Victory - full victory sequence with text and totals
---------------------------------------------------------------------------

function wl_inter.Victory()
    local wl_main = require("wl_main")
    local wl_menu = require("wl_menu")

    wl_menu.StartCPMusic(audiowl6.URAHERO_MUS)

    wl_inter.ClearSplitVWB()

    -- Draw BJ wins pic
    id_ca.CA_CacheGrChunk(gfx.L_BJWINSPIC)
    id_vh.VWB_DrawPic(0, 16, gfx.L_BJWINSPIC)

    id_vh.fontnumber = 1
    id_vh.fontcolor = 0x0f
    id_vh.backcolor = 0

    id_vh.px = 80; id_vh.py = 30
    id_vh.VWB_DrawPropString("VICTORY!")

    -- Episode totals
    local gs = wl_main.gamestate
    local total_kr = gs.killtotal > 0 and math.floor(gs.killcount * 100 / gs.killtotal) or 0
    local total_sr = gs.secrettotal > 0 and math.floor(gs.secretcount * 100 / gs.secrettotal) or 0
    local total_tr = gs.treasuretotal > 0 and math.floor(gs.treasurecount * 100 / gs.treasuretotal) or 0

    id_vh.px = 80; id_vh.py = 55
    id_vh.VWB_DrawPropString("Total Kill:     " .. tostring(total_kr) .. "%")
    id_vh.px = 80; id_vh.py = 70
    id_vh.VWB_DrawPropString("Total Secret:   " .. tostring(total_sr) .. "%")
    id_vh.px = 80; id_vh.py = 85
    id_vh.VWB_DrawPropString("Total Treasure: " .. tostring(total_tr) .. "%")

    -- Total time
    local total_sec = math.floor(gs.TimeCount / 70)
    local total_min = math.floor(total_sec / 60)
    total_sec = total_sec % 60
    id_vh.px = 80; id_vh.py = 105
    id_vh.VWB_DrawPropString("Total Time: " .. string.format("%d:%02d", total_min, total_sec))

    id_vh.px = 60; id_vh.py = 130
    id_vh.VWB_DrawPropString("You have completed Episode " .. tostring(gs.episode + 1) .. "!")

    id_vh.VW_UpdateScreen()
    id_vh.VW_FadeIn()

    id_in.IN_UserInput(id_sd.TickBase * 15)

    id_vh.VW_FadeOut()

    wl_inter.CheckHighScore(gs.score, gs.mapon + 1)
end

---------------------------------------------------------------------------
-- CheckHighScore - check and possibly insert into high score table
-- Allows name entry if the score qualifies
---------------------------------------------------------------------------

function wl_inter.CheckHighScore(score, completed)
    -- Find position in high scores
    local index = -1
    for i = 1, id_us.MaxScores do
        if score > id_us.Scores[i].score then
            index = i
            break
        end
    end

    -- Draw the high score screen
    wl_inter.DrawHighScores()

    if index > 0 then
        -- Shift scores down
        for i = id_us.MaxScores, index + 1, -1 do
            id_us.Scores[i] = id_us.Scores[i - 1]
        end
        id_us.Scores[index] = {
            name = "",
            score = score,
            completed = completed,
            episode = 0,
        }

        -- Draw highlight on the new entry
        id_vh.VW_UpdateScreen()
        id_vh.VW_FadeIn()

        -- Get name input
        id_vh.fontnumber = 1
        id_vh.fontcolor = 0x0f
        id_vh.backcolor = 0x00
        local name_y = 68 + (index - 1) * 16

        local ok, name = id_us.US_LineInput(
            48, name_y,
            "", "", true, 57, 120)

        if ok and name and #name > 0 then
            id_us.Scores[index].name = name
        else
            id_us.Scores[index].name = "Anonymous"
        end

        id_us.HighScoresDirty = true

        -- Redraw with the name
        wl_inter.DrawHighScores()
    end

    id_vh.VW_UpdateScreen()
    if index <= 0 then
        id_vh.VW_FadeIn()
    end

    id_in.IN_UserInput(id_sd.TickBase * 10)
    id_vh.VW_FadeOut()
end

---------------------------------------------------------------------------
-- DrawHighScores
---------------------------------------------------------------------------

function wl_inter.DrawHighScores()
    id_ca.CA_CacheScreen(gfx.HIGHSCORESPIC)

    id_vh.fontnumber = 1
    id_vh.fontcolor = 0x0f
    id_vh.backcolor = 0x00

    for i = 1, id_us.MaxScores do
        local entry = id_us.Scores[i]
        if entry then
            -- Name
            id_vh.px = 48
            id_vh.py = 68 + (i - 1) * 16
            id_vh.VWB_DrawPropString(entry.name or "")

            -- Score (right-justified)
            local score_str = tostring(entry.score or 0)
            local w, _ = id_vh.VW_MeasurePropString(score_str)
            id_vh.px = 250 - w
            id_vh.VWB_DrawPropString(score_str)

            -- Completed level
            id_vh.px = 264
            local comp_str = ""
            if entry.completed and entry.completed > 0 then
                comp_str = "E" .. tostring((entry.episode or 0) + 1) .. "/L" .. tostring(entry.completed)
            end
            id_vh.VWB_DrawPropString(comp_str)
        end
    end
end

---------------------------------------------------------------------------
-- FreeMusic
---------------------------------------------------------------------------

function wl_inter.FreeMusic()
    -- Free cached music data (no-op, GC handles it)
end

return wl_inter
