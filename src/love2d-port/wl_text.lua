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
-- ShowArticle - display a multi-page text article with full markup parsing
-- Supports ^P (page break), ^E (end), ^C (center text),
-- ^G (graphic), ^T (timed page), ^B (background color), ^L (left margin)
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
    local newpage = true
    local picx = 0
    local picy = 0
    local picw = 0
    local pich = 0
    local layoutdone = false

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
                    picx = 0; picy = 0; picw = 0; pich = 0

                elseif cmd == 69 or cmd == 101 then  -- 'E'/'e' - end
                    layoutdone = true
                    break

                elseif cmd == 67 or cmd == 99 then  -- 'C'/'c' - center text
                    -- ^Cnnn - change text color
                    local num
                    num, pos = ParseNumber(text, pos)
                    id_vh.fontcolor = num
                    pos = RipToEOL(text, pos)

                elseif cmd == 71 or cmd == 103 then  -- 'G'/'g' - graphic
                    -- ^Gnnn,x,y - draw graphic number nnn at position x,y
                    local num
                    num, pos = ParseNumber(text, pos)
                    -- Skip comma
                    if pos <= #text and string.byte(text, pos) == 44 then
                        pos = pos + 1
                    end
                    local gx
                    gx, pos = ParseNumber(text, pos)
                    if pos <= #text and string.byte(text, pos) == 44 then
                        pos = pos + 1
                    end
                    local gy
                    gy, pos = ParseNumber(text, pos)
                    pos = RipToEOL(text, pos)

                    -- Draw the graphic
                    if num > 0 then
                        id_ca.CA_CacheGrChunk(num)
                        id_vh.VWB_DrawPic(gx, gy, num)
                        -- Update pic dimensions for text wrapping
                        local pt = id_ca.pictable and id_ca.pictable[num - gfx.STARTPICS]
                        if pt then
                            picx = gx; picy = gy
                            picw = pt.width; pich = pt.height
                        end
                    end

                elseif cmd == 84 or cmd == 116 then  -- 'T'/'t' - timed page
                    -- ^Tnnn - wait nnn tics then auto-advance
                    local num
                    num, pos = ParseNumber(text, pos)
                    pos = RipToEOL(text, pos)
                    id_vh.VW_UpdateScreen()
                    id_in.IN_UserInput(num)
                    id_vl.VL_Bar(0, 0, 320, 200, BACKCOLOR)
                    row = 0; col = LEFTMARGIN
                    id_vh.px = col; id_vh.py = TOPMARGIN

                elseif cmd == 66 or cmd == 98 then  -- 'B'/'b' - background color
                    local num
                    num, pos = ParseNumber(text, pos)
                    pos = RipToEOL(text, pos)
                    BACKCOLOR = num
                    id_vh.backcolor = BACKCOLOR

                elseif cmd == 76 or cmd == 108 then  -- 'L'/'l' - left margin
                    local num
                    num, pos = ParseNumber(text, pos)
                    pos = RipToEOL(text, pos)
                    col = num
                    id_vh.px = col
                end
            end
        elseif ch == 10 or ch == 13 then  -- newline
            -- Skip \r\n pairs
            if ch == 13 and pos <= #text and string.byte(text, pos) == 10 then
                pos = pos + 1
            end
            row = row + 1
            col = LEFTMARGIN
            -- Check if we need to wrap around a graphic
            if picw > 0 and id_vh.py >= picy and id_vh.py < picy + pich then
                col = picx + picw + PICMARGIN
            end
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
                picx = 0; picy = 0; picw = 0; pich = 0
            end
        elseif ch == 9 then  -- tab
            -- Move to next 8-character tab stop
            col = math.floor((col + 64) / 64) * 64
            id_vh.px = col
        else
            -- Regular character - draw it
            local charstr = string.char(ch)
            id_vh.VWB_DrawPropString(charstr)
            col = id_vh.px

            -- Check right margin
            if col >= 320 - RIGHTMARGIN then
                row = row + 1
                col = LEFTMARGIN
                if picw > 0 and id_vh.py >= picy and id_vh.py < picy + pich then
                    col = picx + picw + PICMARGIN
                end
                id_vh.px = col
                id_vh.py = TOPMARGIN + row * FONTHEIGHT
                if id_vh.py > 200 - BOTTOMMARGIN then
                    id_vh.VW_UpdateScreen()
                    id_in.IN_Ack()
                    id_vl.VL_Bar(0, 0, 320, 200, BACKCOLOR)
                    row = 0
                    id_vh.px = LEFTMARGIN
                    id_vh.py = TOPMARGIN
                    picx = 0; picy = 0; picw = 0; pich = 0
                end
            end
        end
    end

    id_vh.VW_UpdateScreen()
    id_in.IN_Ack()
end

---------------------------------------------------------------------------
-- HelpScreens - load and display help text from game data
---------------------------------------------------------------------------

function wl_text.HelpScreens()
    local wl_menu = require("wl_menu")
    wl_menu.StartCPMusic(audiowl6.CORNER_MUS)

    -- Try to load the help article from game data (T_HELPART)
    id_ca.CA_CacheGrChunk(gfx.T_HELPART)
    local data = id_ca.grsegs[gfx.T_HELPART]

    if data and #data > 0 then
        -- Convert byte array to string
        local str = ""
        for i = 1, #data do
            if data[i] == 0 then break end
            str = str .. string.char(data[i])
        end
        if #str > 0 then
            wl_text.ShowArticle(str)
            return
        end
    end

    -- Fallback: built-in help screen
    id_vl.VL_Bar(0, 0, 320, 200, 0x11)
    id_vh.fontnumber = 1
    id_vh.fontcolor = 0x0f
    id_vh.backcolor = 0x11

    id_vh.px = 60; id_vh.py = 20
    id_vh.VWB_DrawPropString("Wolfenstein 3-D Help")

    id_vh.px = 30; id_vh.py = 50
    id_vh.VWB_DrawPropString("Arrows / WASD  - Move/Turn")
    id_vh.px = 30; id_vh.py = 65
    id_vh.VWB_DrawPropString("Ctrl           - Fire")
    id_vh.px = 30; id_vh.py = 80
    id_vh.VWB_DrawPropString("Alt            - Strafe")
    id_vh.px = 30; id_vh.py = 95
    id_vh.VWB_DrawPropString("Shift          - Run")
    id_vh.px = 30; id_vh.py = 110
    id_vh.VWB_DrawPropString("Space          - Open Doors/Use")
    id_vh.px = 30; id_vh.py = 125
    id_vh.VWB_DrawPropString("1-4            - Select Weapon")
    id_vh.px = 30; id_vh.py = 140
    id_vh.VWB_DrawPropString("Esc            - Menu")
    id_vh.px = 30; id_vh.py = 155
    id_vh.VWB_DrawPropString("F1             - Help")
    id_vh.px = 30; id_vh.py = 170
    id_vh.VWB_DrawPropString("Tab+G/N/I      - Debug cheats")

    id_vh.VW_UpdateScreen()
    id_vh.VW_FadeIn()
    id_in.IN_Ack()
    id_vh.VW_FadeOut()
end

---------------------------------------------------------------------------
-- OrderingInfo
---------------------------------------------------------------------------

function wl_text.OrderingInfo()
    id_ca.CA_CacheScreen(gfx.ORDERSCREEN)
    id_vh.VW_UpdateScreen()
    id_vh.VW_FadeIn()
    id_in.IN_Ack()
    id_vh.VW_FadeOut()
end

---------------------------------------------------------------------------
-- EndText - end-of-episode text screens
-- Loads episode-specific end text from game data
---------------------------------------------------------------------------

function wl_text.EndText()
    local wl_main = require("wl_main")
    local wl_menu = require("wl_menu")

    local episode = wl_main.gamestate.episode or 0
    local endart_chunk = gfx.T_ENDART1 + episode

    -- Try to load the end article from game data
    if endart_chunk >= gfx.T_ENDART1 and endart_chunk <= gfx.T_ENDART6 then
        id_ca.CA_CacheGrChunk(endart_chunk)
        local data = id_ca.grsegs[endart_chunk]
        if data and #data > 0 then
            local str = ""
            for i = 1, #data do
                if data[i] == 0 then break end
                str = str .. string.char(data[i])
            end
            if #str > 0 then
                wl_text.ShowArticle(str)
                return
            end
        end
    end

    -- Fallback: generic end screen
    id_vl.VL_Bar(0, 0, 320, 200, 0x11)
    id_vh.fontnumber = 1
    id_vh.fontcolor = 0x0f
    id_vh.backcolor = 0x11

    id_vh.px = 40; id_vh.py = 60
    id_vh.VWB_DrawPropString("Episode " .. tostring(episode + 1) .. " Complete!")
    id_vh.px = 40; id_vh.py = 90
    id_vh.VWB_DrawPropString("Congratulations!")

    id_vh.VW_UpdateScreen()
    id_vh.VW_FadeIn()
    id_in.IN_UserInput(id_sd.TickBase * 10)
    id_vh.VW_FadeOut()
end

return wl_text
