-- WL_SCALE.lua
-- Scaling routines - ported from WL_SCALE.C
-- Handles scaled wall/sprite column drawing (compiled scalers replaced with lookup tables)

local bit = require("bit")
local band, bor, lshift, rshift = bit.band, bit.bor, bit.lshift, bit.rshift

local wl_def = require("wl_def")
local id_vl  = require("id_vl")
local id_pm  = require("id_pm")

local wl_scale = {}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
wl_scale.scaledirectory   = {}   -- [0..MAXSCALEHEIGHT] -> {width={}, codeofs={}}
wl_scale.maxscale         = 0
wl_scale.maxscaleshl2     = 0
wl_scale.stepbytwo        = 0
wl_scale.insetupscaling   = false

-- ScaleLine globals
wl_scale.slinex       = 0
wl_scale.slinewidth   = 0
wl_scale.linecmds     = nil   -- table of uint16 command words
wl_scale.linescale    = nil   -- pointer to a t_compscale entry
wl_scale.shape_base   = nil   -- byte table for current shape

---------------------------------------------------------------------------
-- SetupScaling - build lookup tables
---------------------------------------------------------------------------

function wl_scale.SetupScaling(maxscaleheight)
    local wl_main = require("wl_main")

    wl_scale.insetupscaling = true

    maxscaleheight = math.floor(maxscaleheight / 2)
    wl_scale.maxscale = maxscaleheight - 1
    wl_scale.maxscaleshl2 = lshift(wl_scale.maxscale, 2)

    -- Clear old entries
    wl_scale.scaledirectory = {}

    wl_scale.stepbytwo = math.floor(wl_main.viewheight / 2)

    local i = 1
    while i <= maxscaleheight do
        local height = i * 2
        local step = math.floor(lshift(height, 16) / 64)
        local fix = 0
        local toppix = math.floor((wl_main.viewheight - height) / 2)

        local sc = { width = {}, codeofs = {} }

        for src = 0, 64 do
            local startpix = rshift(fix, 16)
            fix = fix + step
            local endpix = rshift(fix, 16)

            if endpix > startpix then
                sc.width[src] = endpix - startpix
            else
                sc.width[src] = 0
            end
            sc.codeofs[src] = startpix + toppix
        end

        wl_scale.scaledirectory[i] = sc

        if i >= wl_scale.stepbytwo then
            wl_scale.scaledirectory[i + 1] = sc
            wl_scale.scaledirectory[i + 2] = sc
            i = i + 3
        else
            i = i + 1
        end
    end

    wl_scale.scaledirectory[0] = wl_scale.scaledirectory[1]

    wl_scale.insetupscaling = false
end

---------------------------------------------------------------------------
-- GetSpritePageBytes - load a sprite page as byte table
---------------------------------------------------------------------------

local function GetSpritePageBytes(shapenum)
    local pagenum = id_pm.PMSpriteStart + shapenum
    local page = id_pm.PM_GetPage(pagenum)
    if not page then return nil end
    local bytes = {}
    for i = 1, #page do
        bytes[i] = string.byte(page, i)
    end
    return bytes
end

---------------------------------------------------------------------------
-- Read uint16 from byte table (little-endian, 1-indexed)
---------------------------------------------------------------------------

local function read_u16(bytes, offset)
    -- offset is 0-based byte offset; bytes is 1-indexed
    local lo = bytes[offset + 1] or 0
    local hi = bytes[offset + 2] or 0
    return lo + hi * 256
end

---------------------------------------------------------------------------
-- ScaleLine - draw a single column of a sprite
---------------------------------------------------------------------------

function wl_scale.ScaleLine()
    local wl_main = require("wl_main")

    local comptable = wl_scale.linescale
    local cmds = wl_scale.linecmds
    local shape_base = wl_scale.shape_base

    if not comptable or not cmds or not shape_base then return end

    local screenofs = wl_main.screenofs
    local yofs = math.floor(screenofs / wl_def.SCREENWIDTH)
    local xofs = (screenofs % wl_def.SCREENWIDTH) * 4
    local viewh = wl_main.viewheight

    -- Process command list: [end_ofs, src_offset, start_ofs] repeating, 0 terminates
    local ci = 1
    while ci <= #cmds and cmds[ci] ~= 0 do
        local end_ofs   = cmds[ci]
        local src_offset = cmds[ci + 1]
        local start_ofs  = cmds[ci + 2]
        ci = ci + 3

        local texel_start = math.floor(start_ofs / 2)
        local texel_end   = math.floor(end_ofs / 2)

        if texel_start > 64 then texel_start = 64 end
        if texel_end > 64 then texel_end = 64 end

        for texel = texel_start, texel_end - 1 do
            local width_pix = comptable.width[texel] or 0
            local screen_y_start = comptable.codeofs[texel] or 0

            if width_pix > 0 then
                -- Get source pixel color
                local color = shape_base[src_offset + texel + 1] or 0

                if color ~= 0 then
                    for dy = 0, width_pix - 1 do
                        local sy = screen_y_start + dy
                        if sy >= 0 and sy < viewh then
                            local screen_y = sy + yofs
                            if screen_y >= 0 and screen_y < 200 then
                                for x = wl_scale.slinex, wl_scale.slinex + wl_scale.slinewidth - 1 do
                                    local screenx = x + xofs
                                    if screenx >= 0 and screenx < 320 then
                                        id_vl.screenbuf[screen_y * 320 + screenx] = color
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- ParseShapeCommands - extract command list from shape data at given offset
---------------------------------------------------------------------------

local function ParseShapeCommands(shape_bytes, cmd_offset)
    local cmds = {}
    local i = cmd_offset
    while true do
        local val = read_u16(shape_bytes, i)
        cmds[#cmds + 1] = val
        if val == 0 then break end
        i = i + 2
        cmds[#cmds + 1] = read_u16(shape_bytes, i)
        i = i + 2
        cmds[#cmds + 1] = read_u16(shape_bytes, i)
        i = i + 2
    end
    return cmds
end

---------------------------------------------------------------------------
-- ScaleShape - draw a compiled shape at [height] pixels high
---------------------------------------------------------------------------

function wl_scale.ScaleShape(xcenter, shapenum, height)
    local wl_main = require("wl_main")

    local shape = GetSpritePageBytes(shapenum)
    if not shape then return end

    local scale = rshift(height, 3)
    if scale == 0 or scale > wl_scale.maxscale then return end

    local comptable = wl_scale.scaledirectory[scale]
    if not comptable then return end

    wl_scale.linescale = comptable
    wl_scale.shape_base = shape

    -- Parse shape header: leftpix (uint16), rightpix (uint16), then dataofs[]
    local leftpix = read_u16(shape, 0)
    local rightpix = read_u16(shape, 2)

    local vieww = wl_main.viewwidth
    local wallheight = wl_main.wallheight

    -- Scale to the left (from pixel 31 to leftpix)
    local srcx = 32
    wl_scale.slinex = xcenter
    local stopx = leftpix

    -- dataofs starts at byte 4; dataofs[31-stopx] is at byte 4 + (31-stopx)*2
    local cmdptr_base = 4
    local cmdptr_idx = 31 - stopx  -- index into dataofs

    srcx = srcx - 1
    while srcx >= stopx and wl_scale.slinex > 0 do
        local dofs = read_u16(shape, cmdptr_base + cmdptr_idx * 2)
        wl_scale.linecmds = ParseShapeCommands(shape, dofs)
        cmdptr_idx = cmdptr_idx - 1

        local sw = comptable.width[srcx] or 0
        wl_scale.slinewidth = sw
        if sw ~= 0 then
            if sw == 1 then
                wl_scale.slinex = wl_scale.slinex - 1
                if wl_scale.slinex < vieww then
                    if (wallheight[wl_scale.slinex] or 0) < height then
                        wl_scale.ScaleLine()
                    end
                end
            else
                -- Multi-pixel lines
                if wl_scale.slinex > vieww then
                    wl_scale.slinex = wl_scale.slinex - sw
                    wl_scale.slinewidth = vieww - wl_scale.slinex
                    if wl_scale.slinewidth >= 1 then
                        wl_scale.ScaleLine()
                    end
                else
                    if sw > wl_scale.slinex then
                        sw = wl_scale.slinex
                        wl_scale.slinewidth = sw
                    end
                    wl_scale.slinex = wl_scale.slinex - sw
                    wl_scale.ScaleLine()
                end
            end
        end

        srcx = srcx - 1
    end

    -- Scale to the right
    wl_scale.slinex = xcenter
    stopx = rightpix

    if leftpix < 31 then
        srcx = 31
        cmdptr_idx = 32 - leftpix
    else
        srcx = leftpix - 1
        cmdptr_idx = 0
    end
    wl_scale.slinewidth = 0

    srcx = srcx + 1
    while srcx <= stopx and wl_scale.slinex + wl_scale.slinewidth < vieww do
        wl_scale.slinex = wl_scale.slinex + wl_scale.slinewidth

        local dofs = read_u16(shape, cmdptr_base + cmdptr_idx * 2)
        wl_scale.linecmds = ParseShapeCommands(shape, dofs)
        cmdptr_idx = cmdptr_idx + 1

        local sw = comptable.width[srcx] or 0
        wl_scale.slinewidth = sw
        if sw ~= 0 then
            if sw == 1 then
                if wl_scale.slinex >= 0 and (wallheight[wl_scale.slinex] or 0) < height then
                    wl_scale.ScaleLine()
                end
            else
                -- Multi-pixel lines
                if wl_scale.slinex < 0 then
                    if sw <= -wl_scale.slinex then
                        srcx = srcx + 1
                        goto continue_right
                    end
                    wl_scale.slinewidth = sw + wl_scale.slinex
                    wl_scale.slinex = 0
                else
                    if wl_scale.slinex + sw > vieww then
                        wl_scale.slinewidth = vieww - wl_scale.slinex
                    end
                end
                wl_scale.ScaleLine()
            end
        end

        srcx = srcx + 1
        ::continue_right::
    end
end

---------------------------------------------------------------------------
-- SimpleScaleShape - no wall clipping, height in pixels
---------------------------------------------------------------------------

function wl_scale.SimpleScaleShape(xcenter, shapenum, height)
    local wl_main = require("wl_main")

    local shape = GetSpritePageBytes(shapenum)
    if not shape then return end

    local scale = rshift(height, 1)
    if scale == 0 or scale > wl_scale.maxscale then return end

    local comptable = wl_scale.scaledirectory[scale]
    if not comptable then return end

    wl_scale.linescale = comptable
    wl_scale.shape_base = shape

    local leftpix = read_u16(shape, 0)
    local rightpix = read_u16(shape, 2)
    local cmdptr_base = 4

    -- Scale to the left
    local srcx = 32
    wl_scale.slinex = xcenter
    local stopx = leftpix
    local cmdptr_idx = 31 - stopx

    srcx = srcx - 1
    while srcx >= stopx do
        local dofs = read_u16(shape, cmdptr_base + cmdptr_idx * 2)
        wl_scale.linecmds = ParseShapeCommands(shape, dofs)
        cmdptr_idx = cmdptr_idx - 1

        local sw = comptable.width[srcx] or 0
        wl_scale.slinewidth = sw
        if sw ~= 0 then
            wl_scale.slinex = wl_scale.slinex - sw
            wl_scale.ScaleLine()
        end

        srcx = srcx - 1
    end

    -- Scale to the right
    wl_scale.slinex = xcenter
    stopx = rightpix

    if leftpix < 31 then
        srcx = 31
        cmdptr_idx = 32 - leftpix
    else
        srcx = leftpix - 1
        cmdptr_idx = 0
    end
    wl_scale.slinewidth = 0

    srcx = srcx + 1
    while srcx <= stopx do
        local dofs = read_u16(shape, cmdptr_base + cmdptr_idx * 2)
        wl_scale.linecmds = ParseShapeCommands(shape, dofs)
        cmdptr_idx = cmdptr_idx + 1

        local sw = comptable.width[srcx] or 0
        wl_scale.slinewidth = sw
        if sw ~= 0 then
            wl_scale.ScaleLine()
            wl_scale.slinex = wl_scale.slinex + sw
        end

        srcx = srcx + 1
    end
end

return wl_scale
