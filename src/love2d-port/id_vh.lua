-- ID_VH.lua
-- Video High-level routines - ported from ID_VH.C
-- Draws pics, sprites, proportional strings, manages double buffering

local bit = require("bit")
local band, bor, lshift, rshift = bit.band, bit.bor, bit.lshift, bit.rshift

local id_vl = require("id_vl")
local gfx   = require("gfxv_wl6")

local id_vh = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------
id_vh.WHITE        = 15
id_vh.BLACK        = 0
id_vh.FIRSTCOLOR   = 1
id_vh.SECONDCOLOR  = 12
id_vh.F_WHITE      = 15
id_vh.F_BLACK      = 0
id_vh.F_FIRSTCOLOR = 1
id_vh.F_SECONDCOLOR = 12
id_vh.MAXSHIFTS    = 1

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
id_vh.pictable   = nil   -- Set from id_ca after loading STRUCTPIC
id_vh.fontcolor  = 0
id_vh.backcolor  = 15
id_vh.fontnumber = 0
id_vh.px         = 0
id_vh.py         = 0

-- Latch pics array
id_vh.latchpics = {}
for i = 0, gfx.NUMLATCHPICS_LUMP_END or 99 do
    id_vh.latchpics[i] = 0
end
id_vh.freelatch = 0

-- The game palette (used by VW_FadeIn/Out)
id_vh.gamepal = {}
for i = 0, 767 do
    id_vh.gamepal[i] = 0
end

---------------------------------------------------------------------------
-- Double buffer management (simplified for Love2D)
---------------------------------------------------------------------------

function id_vh.VW_InitDoubleBuffer()
    -- No-op for Love2D (we use a single screenbuf)
end

function id_vh.VW_MarkUpdateBlock(x1, y1, x2, y2)
    -- No-op (we update the full screen each frame)
    return 1
end

function id_vh.VW_UpdateScreen()
    id_vl.VL_UpdateScreen()
end

---------------------------------------------------------------------------
-- VW_ aliases (from ID_VH.H)
---------------------------------------------------------------------------

id_vh.VW_Startup       = id_vl.VL_Startup
id_vh.VW_Shutdown      = id_vl.VL_Shutdown
id_vh.VW_SetCRTC       = id_vl.VL_SetCRTC
id_vh.VW_SetScreen     = id_vl.VL_SetScreen
id_vh.VW_Bar           = id_vl.VL_Bar
id_vh.VW_Plot          = id_vl.VL_Plot
id_vh.VW_SetSplitScreen = id_vl.VL_SetSplitScreen
id_vh.VW_SetLineWidth  = id_vl.VL_SetLineWidth
id_vh.VW_ColorBorder   = id_vl.VL_ColorBorder
id_vh.VW_WaitVBL       = id_vl.VL_WaitVBL
id_vh.VW_ScreenToScreen = id_vl.VL_ScreenToScreen

function id_vh.VW_Hlin(x1, x2, y, c)
    id_vl.VL_Hlin(x1, y, x2 - x1 + 1, c)
end

function id_vh.VW_Vlin(y1, y2, x, c)
    id_vl.VL_Vlin(x, y1, y2 - y1 + 1, c)
end

function id_vh.VW_FadeIn()
    id_vl.VL_FadeIn(0, 255, id_vh.gamepal, 30)
end

function id_vh.VW_FadeOut()
    id_vl.VL_FadeOut(0, 255, 0, 0, 0, 30)
end

function id_vh.VH_SetDefaultColors()
    -- Set the game palette from the first graphic chunk
    -- (gamepal is loaded elsewhere)
end

---------------------------------------------------------------------------
-- Pic drawing
---------------------------------------------------------------------------

function id_vh.VH_DrawPic(x, y, chunknum)
    -- x is in tile units (8-pixel blocks), y is in pixels (for VWB) or tiles
    local id_ca = require("id_ca")
    local data = id_ca.grsegs[chunknum]
    if not data then return end

    local pt = id_ca.pictable[chunknum - gfx.STARTPICS]
    if not pt then return end

    local width = pt.width
    local height = pt.height

    -- Convert pixel x to screen coordinates (x is already pixel in VWB_DrawPic)
    id_vl.VL_MemToScreen(data, width, height, x, y)
end

function id_vh.VWB_DrawPic(x, y, chunknum)
    local id_ca = require("id_ca")

    -- Make sure the chunk is cached
    if not id_ca.grsegs[chunknum] then
        id_ca.CA_CacheGrChunk(chunknum)
    end

    local data = id_ca.grsegs[chunknum]
    if not data then return end

    local pt = id_ca.pictable[chunknum - gfx.STARTPICS]
    if not pt then return end

    id_vl.VL_MemToScreen(data, pt.width, pt.height, x, y)
end

function id_vh.VWB_DrawMPic(x, y, chunknum)
    local id_ca = require("id_ca")

    if not id_ca.grsegs[chunknum] then
        id_ca.CA_CacheGrChunk(chunknum)
    end

    local data = id_ca.grsegs[chunknum]
    if not data then return end

    local pt = id_ca.pictable[chunknum - gfx.STARTPICS]
    if not pt then return end

    id_vl.VL_MaskedToScreen(data, pt.width, pt.height, x, y)
end

function id_vh.VWB_Bar(x, y, width, height, color)
    id_vl.VL_Bar(x, y, width, height, color)
end

function id_vh.VWB_Plot(x, y, color)
    id_vl.VL_Plot(x, y, color)
end

function id_vh.VWB_Hlin(x1, x2, y, color)
    id_vl.VL_Hlin(x1, y, x2 - x1 + 1, color)
end

function id_vh.VWB_Vlin(y1, y2, x, color)
    id_vl.VL_Vlin(x, y1, y2 - y1 + 1, color)
end

---------------------------------------------------------------------------
-- Proportional string drawing
---------------------------------------------------------------------------

function id_vh.VWB_DrawPropString(str)
    local id_ca = require("id_ca")

    -- Get font data
    local fontchunk = gfx.STARTFONT + id_vh.fontnumber
    if not id_ca.grsegs[fontchunk] then
        id_ca.CA_CacheGrChunk(fontchunk)
    end
    local fontdata = id_ca.grsegs[fontchunk]
    if not fontdata then return end

    -- Parse font struct: height (int16), location[256] (int16 each), width[256] (byte each)
    local fontheight = fontdata[1] + fontdata[2] * 256
    if fontheight >= 32768 then fontheight = fontheight - 65536 end

    -- location: 256 entries of int16, starting at byte index 3 (1-indexed)
    -- width: 256 entries of byte, starting at byte index 3 + 512

    local function get_location(ch)
        local idx = 3 + ch * 2
        local lo = fontdata[idx] or 0
        local hi = fontdata[idx + 1] or 0
        local v = lo + hi * 256
        if v >= 32768 then v = v - 65536 end
        return v
    end

    local function get_width(ch)
        return fontdata[3 + 512 + ch] or 0
    end

    local px = id_vh.px
    local py = id_vh.py
    local fc = id_vh.fontcolor
    local bc = id_vh.backcolor

    for ci = 1, #str do
        local ch = string.byte(str, ci)
        local w = get_width(ch)
        local loc = get_location(ch)

        if w > 0 and loc >= 0 then
            -- Draw character column by column
            for col = 0, w - 1 do
                for row = 0, fontheight - 1 do
                    local src_idx = loc + row * w + col + 1  -- 1-indexed
                    local pixel = fontdata[src_idx] or 0
                    local sx = px + col
                    local sy = py + row
                    if sx >= 0 and sx < 320 and sy >= 0 and sy < 200 then
                        if pixel ~= 0 then
                            id_vl.screenbuf[sy * 320 + sx] = fc
                        elseif bc ~= 255 then
                            -- Draw background unless bc == 255 (transparent)
                            id_vl.screenbuf[sy * 320 + sx] = bc
                        end
                    end
                end
            end
        end

        px = px + w
    end

    id_vh.px = px
end

function id_vh.VWB_DrawMPropString(str)
    -- Same as DrawPropString but masked (no background)
    local saved_bc = id_vh.backcolor
    id_vh.backcolor = 255  -- transparent
    id_vh.VWB_DrawPropString(str)
    id_vh.backcolor = saved_bc
end

function id_vh.VW_MeasurePropString(str)
    local id_ca = require("id_ca")
    local fontchunk = gfx.STARTFONT + id_vh.fontnumber
    if not id_ca.grsegs[fontchunk] then
        id_ca.CA_CacheGrChunk(fontchunk)
    end
    local fontdata = id_ca.grsegs[fontchunk]
    if not fontdata then return 0, 0 end

    local fontheight = fontdata[1] + fontdata[2] * 256
    if fontheight >= 32768 then fontheight = fontheight - 65536 end

    local totalw = 0
    for ci = 1, #str do
        local ch = string.byte(str, ci)
        local w = fontdata[3 + 512 + ch] or 0
        totalw = totalw + w
    end

    return totalw, fontheight
end

---------------------------------------------------------------------------
-- Tile drawing
---------------------------------------------------------------------------

function id_vh.VWB_DrawTile8(x, y, tile)
    local id_ca = require("id_ca")
    local tile8data = id_ca.grsegs[gfx.STARTTILE8]
    if not tile8data then return end

    -- Each tile8 is 64 bytes (8x8 pixels in planar format)
    local base = tile * 64
    local src = {}
    for i = 1, 64 do
        src[i] = tile8data[base + i] or 0
    end

    -- Draw using tile8 string method (single char)
    id_vl.VL_DrawTile8String(string.char(tile), tile8data, x, y)
end

---------------------------------------------------------------------------
-- Latch operations
---------------------------------------------------------------------------

function id_vh.LatchDrawChar(x, y, p)
    id_vl.VL_LatchToScreen(id_vh.latchpics[0] + p * 16, 2, 8, x, y)
end

function id_vh.LatchDrawTile(x, y, p)
    id_vl.VL_LatchToScreen(id_vh.latchpics[1] + p * 64, 4, 16, x, y)
end

function id_vh.LatchDrawPic(x, y, picnum)
    local id_ca = require("id_ca")
    local pt = id_ca.pictable[picnum - gfx.STARTPICS]
    if not pt then return end

    local width = math.floor(pt.width / 4)  -- planar byte width
    local height = pt.height

    -- x is in tile units (8 pixels each -> 2 planar bytes)
    x = x * 8
    id_vl.VL_LatchToScreen(id_vh.latchpics[2 + picnum - gfx.LATCHPICS_LUMP_START],
        width, height, x, y)
end

---------------------------------------------------------------------------
-- FizzleFade
---------------------------------------------------------------------------

function id_vh.FizzleFade(source, dest, width, height, frames, abortable)
    local id_in = require("id_in")
    local id_sd = require("id_sd")

    -- Proper LFSR-based pixel reveal (from original Wolf3D)
    -- The LFSR generates a maximal-length sequence covering all pixels
    -- Uses a 17-bit LFSR: feedback polynomial x^17 + x^14 + 1
    -- This covers 2^17 - 1 = 131071 values, enough for 320*200 = 64000 pixels

    -- We have a source buffer (the new frame) already in screenbuf.
    -- We need to copy from a saved "new" buffer to the display one pixel at a time.
    -- Since Love2D uses a single buffer, we save the target image and reveal it
    -- over the current (faded) screen.

    -- Save the target pixels
    local target = {}
    for i = 0, width * height - 1 do
        target[i] = id_vl.screenbuf[i] or 0
    end

    -- If we have a "source" page saved, restore it as the base
    -- (In practice, the screenbuf is already set to the new image, so we
    --  first fill with black or the old content, then reveal target pixels)
    -- For simplicity: fill visible area with black, then reveal target
    for i = 0, width * height - 1 do
        id_vl.screenbuf[i] = 0
    end

    local rndval = 1
    local pixcount = width * height
    local pixels_per_frame = math.ceil(pixcount / frames)
    local frame = 0
    local total_revealed = 0

    while frame < frames and total_revealed < pixcount do
        local this_frame = 0
        while this_frame < pixels_per_frame do
            -- Extract x (low 9 bits) and y (bits 9..16, 8 bits)
            local x = band(rndval, 0x1FF)
            local y = band(rshift(rndval, 9), 0xFF)

            -- Advance LFSR (17-bit, taps at 17 and 14: XOR with 0x00012000)
            local carry = band(rndval, 1)
            rndval = rshift(rndval, 1)
            if carry ~= 0 then
                rndval = bxor(rndval, 0x00012000)
            end

            if x < width and y < height then
                local idx = y * width + x
                id_vl.screenbuf[idx] = target[idx]
                this_frame = this_frame + 1
                total_revealed = total_revealed + 1
            end

            -- LFSR cycle complete
            if rndval == 1 then
                -- Fill any remaining pixels
                for i = 0, pixcount - 1 do
                    id_vl.screenbuf[i] = target[i]
                end
                total_revealed = pixcount
                break
            end
        end

        id_vl.VL_UpdateScreen()
        frame = frame + 1

        id_in.IN_ProcessEvents()
        if abortable and (id_in.LastScan ~= 0) then
            -- Finish revealing all pixels
            for i = 0, pixcount - 1 do
                id_vl.screenbuf[i] = target[i]
            end
            id_vl.VL_UpdateScreen()
            return true
        end

        -- Small delay to make the effect visible
        love.timer.sleep(1 / 70)
    end

    -- Ensure final state is fully drawn
    for i = 0, pixcount - 1 do
        id_vl.screenbuf[i] = target[i]
    end
    id_vl.VL_UpdateScreen()
    return false
end

---------------------------------------------------------------------------
-- LoadLatchMem - load latch-plane graphics
---------------------------------------------------------------------------

function id_vh.LoadLatchMem()
    local id_ca = require("id_ca")
    local id_mm = require("id_mm")

    local destoff = 0

    -- Cache fonts (STARTFONT..STARTFONT+1)
    for i = gfx.STARTFONT, gfx.STARTFONT + gfx.NUMFONT - 1 do
        id_ca.CA_CacheGrChunk(i)
        id_mm.MM_SetLock(id_ca.grsegs[i], true)
    end

    -- Cache tile8s
    id_ca.CA_CacheGrChunk(gfx.STARTTILE8)
    if id_ca.grsegs[gfx.STARTTILE8] then
        local tile8data = id_ca.grsegs[gfx.STARTTILE8]
        id_vh.latchpics[0] = destoff
        id_vl.VL_MemToLatch(tile8data, 8 * gfx.NUMTILE8, 8, destoff)
        destoff = destoff + gfx.NUMTILE8 * 16  -- 16 planar bytes per 8x8 tile
    end

    -- Latch pics
    id_vh.latchpics[1] = destoff  -- tile16 base (unused for WL6)

    -- Cache and latch all LATCHPICS
    for i = gfx.LATCHPICS_LUMP_START, gfx.LATCHPICS_LUMP_END do
        id_ca.CA_CacheGrChunk(i)
        local data = id_ca.grsegs[i]
        if data then
            local pt = id_ca.pictable[i - gfx.STARTPICS]
            if pt then
                id_vh.latchpics[2 + i - gfx.LATCHPICS_LUMP_START] = destoff
                id_vl.VL_MemToLatch(data, pt.width, pt.height, destoff)
                destoff = destoff + math.floor((pt.width + 3) / 4) * pt.height
            end
        end
    end

    id_vh.freelatch = destoff
end

return id_vh
