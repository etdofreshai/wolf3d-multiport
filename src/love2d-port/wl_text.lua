-- WL_TEXT.lua
-- Text display routines - ported from WL_TEXT.C
-- Handles help text, end-game text screens, ordering info

local bit = require("bit")
local band, bor, lshift, rshift = bit.band, bit.bor, bit.lshift, bit.rshift

local id_vl = require("id_vl")
local id_vh = require("id_vh")
local id_in = require("id_in")
local id_sd = require("id_sd")
local id_us = require("id_us")
local id_ca = require("id_ca")
local gfx   = require("gfxv_wl6")
local wl_def = require("wl_def")

local wl_text = {}

---------------------------------------------------------------------------
-- Text page rendering constants
---------------------------------------------------------------------------
local BACKCOLOR   = 0x11
local WORDLIMIT   = 80
local FONTHEIGHT  = 10
local TOPMARGIN   = 16
local BOTTOMMARGIN = 32
local LEFTMARGIN  = 36
local RIGHTMARGIN = 36
local PICMARGIN   = 8
local TEXTROWS    = 16
local SPESSION    = 0

---------------------------------------------------------------------------
-- RipToEOL - skip past end of line in text data
---------------------------------------------------------------------------

local function RipToEOL(text, pos)
    while pos <= #text do
        local ch = string.byte(text, pos)
        if ch == 10 or ch == 13 then  -- newline
            return pos + 1
        end
        pos = pos + 1
    end
    return pos
end

---------------------------------------------------------------------------
-- ParseNumber - read a number from text
---------------------------------------------------------------------------

local function ParseNumber(text, pos)
    local num = 0
    while pos <= #text do
        local ch = string.byte(text, pos)
        if ch >= 48 and ch <= 57 then  -- '0'-'9'
            num = num * 10 + (ch - 48)
            pos = pos + 1
        else
            break
        end
    end
    return num, pos
end

---------------------------------------------------------------------------
-- ShowArticle - display a multi-page text article
---------------------------------------------------------------------------

function wl_text.ShowArticle(text)
    if not text or #text == 0 then return end

    -- Clear screen and set up for text rendering
    id_vl.VL_Bar(0, 0, 320, 200, BACKCOLOR)

    id_vh.fontnumber = 0
    id_vh.fontcolor = 0x0f
    id_vh.backcolor = BACKCOLOR

    local pos = 1
    local row = 0
    local col = LEFTMARGIN

    id_vh.px = col
    id_vh.py = TOPMARGIN

    while pos <= #text do
        local ch = string.byte(text, pos)
        pos = pos + 1

        if ch == 94 then  -- '^' command character
            if pos <= #text then
                local cmd = string.byte(text, pos)
                pos = pos + 1

                if cmd == 80 or cmd == 112 then  -- 'P'/'p' - new page
                    id_vh.VW_UpdateScreen()
                    id_in.IN_Ack()
                    id_vl.VL_Bar(0, 0, 320, 200, BACKCOLOR)
                    row = 0
                    col = LEFTMARGIN
                    id_vh.px = col
                    id_vh.py = TOPMARGIN
                elseif cmd == 69 or cmd == 101 then  -- 'E'/'e' - end
                    break
                elseif cmd == 67 or cmd == 99 then  -- 'C'/'c' - center
                    -- Read number for centering
                    local num
                    num, pos = ParseNumber(text, pos)
                    pos = RipToEOL(text, pos)
                elseif cmd == 71 or cmd == 103 then  -- 'G'/'g' - graphic
                    local num
                    num, pos = ParseNumber(text, pos)
                    pos = RipToEOL(text, pos)
                    -- Would draw a graphic here
                end
            end
        elseif ch == 10 or ch == 13 then  -- newline
            row = row + 1
            col = LEFTMARGIN
            id_vh.px = col
            id_vh.py = TOPMARGIN + row * FONTHEIGHT
            if id_vh.py > 200 - BOTTOMMARGIN then
                -- Auto page-break
                id_vh.VW_UpdateScreen()
                id_in.IN_Ack()
                id_vl.VL_Bar(0, 0, 320, 200, BACKCOLOR)
                row = 0
                id_vh.px = LEFTMARGIN
                id_vh.py = TOPMARGIN
            end
        else
            -- Regular character
            local charstr = string.char(ch)
            id_vh.VWB_DrawPropString(charstr)
            col = id_vh.px
        end
    end

    id_vh.VW_UpdateScreen()
    id_in.IN_Ack()
end

---------------------------------------------------------------------------
-- HelpScreens
---------------------------------------------------------------------------

function wl_text.HelpScreens()
    -- Load and display help text article
    -- In the original, this loads T_HELPART from GAMEMAPS
    -- We show a simple help screen

    id_vl.VL_Bar(0, 0, 320, 200, BACKCOLOR)
    id_vh.fontnumber = 1
    id_vh.fontcolor = 0x0f
    id_vh.backcolor = BACKCOLOR

    id_vh.px = 60
    id_vh.py = 30
    id_vh.VWB_DrawPropString("Wolfenstein 3-D Help")

    id_vh.px = 30
    id_vh.py = 60
    id_vh.VWB_DrawPropString("Arrows - Move/Turn")
    id_vh.px = 30; id_vh.py = 75
    id_vh.VWB_DrawPropString("Ctrl - Fire")
    id_vh.px = 30; id_vh.py = 90
    id_vh.VWB_DrawPropString("Alt - Strafe")
    id_vh.px = 30; id_vh.py = 105
    id_vh.VWB_DrawPropString("Shift - Run")
    id_vh.px = 30; id_vh.py = 120
    id_vh.VWB_DrawPropString("Space - Open Doors/Use")
    id_vh.px = 30; id_vh.py = 135
    id_vh.VWB_DrawPropString("1-4 - Select Weapon")
    id_vh.px = 30; id_vh.py = 155
    id_vh.VWB_DrawPropString("Esc - Menu")

    id_vh.VW_UpdateScreen()
    id_vh.VW_FadeIn()
    id_in.IN_Ack()
    id_vh.VW_FadeOut()
end

---------------------------------------------------------------------------
-- OrderingInfo
---------------------------------------------------------------------------

function wl_text.OrderingInfo()
    id_vl.VL_Bar(0, 0, 320, 200, BACKCOLOR)
    id_vh.fontnumber = 1
    id_vh.fontcolor = 0x0f
    id_vh.backcolor = BACKCOLOR

    id_vh.px = 40
    id_vh.py = 60
    id_vh.VWB_DrawPropString("Wolfenstein 3-D")
    id_vh.px = 40; id_vh.py = 80
    id_vh.VWB_DrawPropString("by id Software")
    id_vh.px = 40; id_vh.py = 100
    id_vh.VWB_DrawPropString("(C) 1992 id Software")

    id_vh.VW_UpdateScreen()
    id_vh.VW_FadeIn()
    id_in.IN_Ack()
    id_vh.VW_FadeOut()
end

---------------------------------------------------------------------------
-- EndText - end-of-episode text screens
---------------------------------------------------------------------------

function wl_text.EndText()
    local wl_main = require("wl_main")

    -- Would load episode-specific end text
    -- For now, show a generic end screen

    id_vl.VL_Bar(0, 0, 320, 200, BACKCOLOR)
    id_vh.fontnumber = 1
    id_vh.fontcolor = 0x0f
    id_vh.backcolor = BACKCOLOR

    id_vh.px = 40; id_vh.py = 60
    id_vh.VWB_DrawPropString("Episode " .. tostring(wl_main.gamestate.episode + 1) .. " Complete!")
    id_vh.px = 40; id_vh.py = 90
    id_vh.VWB_DrawPropString("Congratulations!")

    id_vh.VW_UpdateScreen()
    id_vh.VW_FadeIn()
    id_in.IN_UserInput(id_sd.TickBase * 10)
    id_vh.VW_FadeOut()
end

return wl_text
