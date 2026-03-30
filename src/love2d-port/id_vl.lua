-- ID_VL.lua
-- Video Layer - ported from ID_VL.C (SDL3 version)
-- Uses Love2D's ImageData as a 320x200 indexed framebuffer

local bit = require("bit")
local band, bor, bxor, lshift, rshift = bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift
local ffi = require("ffi")

local id_vl = {}

---------------------------------------------------------------------------
-- Constants (from ID_VL.H)
---------------------------------------------------------------------------
id_vl.SCREENSEG    = 0xa000
id_vl.SCREENWIDTH  = 80
id_vl.MAXSCANLINES = 200
id_vl.CHARWIDTH    = 2
id_vl.TILEWIDTH    = 4

---------------------------------------------------------------------------
-- State (globals from ID_VL.C)
---------------------------------------------------------------------------
id_vl.bufferofs    = 0
id_vl.displayofs   = 0
id_vl.pelpan       = 0
id_vl.screenseg    = 0xa000
id_vl.linewidth    = 0
id_vl.ylookup      = {}  -- [0..199]
id_vl.screenfaded  = false
id_vl.bordercolor  = 0
id_vl.fastpalette  = true

-- The 320x200 8-bit indexed framebuffer (0-indexed via table, keys 0..63999)
id_vl.screenbuf = {}
-- The 768-byte palette (VGA 6-bit values 0-63). Indexed [0..767]
id_vl.palette   = {}
-- Fade workspace palettes
id_vl.palette1  = {}  -- [0..767]
id_vl.palette2  = {}  -- [0..767]

-- Latch memory (simulates VGA latch planes as linear pixel buffer)
local LATCH_MEM_SIZE = 256 * 1024
id_vl.latchmem = {}

-- Love2D rendering objects
id_vl.imageData = nil   -- love.image.newImageData(320, 200)
id_vl.image     = nil   -- love.graphics.newImage from imageData
id_vl.canvas    = nil   -- optional render target

-- Frame counter
id_vl.capture_frame = 0

---------------------------------------------------------------------------
-- Init / Shutdown
---------------------------------------------------------------------------

function id_vl.VL_Startup()
    -- Initialize the screenbuf to all zeros (palette index 0)
    for i = 0, 320 * 200 - 1 do
        id_vl.screenbuf[i] = 0
    end

    -- Initialize palette to all zeros
    for i = 0, 767 do
        id_vl.palette[i] = 0
        id_vl.palette1[i] = 0
        id_vl.palette2[i] = 0
    end

    -- Initialize latch memory
    for i = 0, LATCH_MEM_SIZE - 1 do
        id_vl.latchmem[i] = 0
    end

    -- Create Love2D image data
    id_vl.imageData = love.image.newImageData(320, 200)
    id_vl.image = love.graphics.newImage(id_vl.imageData)
    id_vl.image:setFilter("nearest", "nearest")
end

function id_vl.VL_Shutdown()
    -- Love2D handles cleanup via GC
    id_vl.imageData = nil
    id_vl.image = nil
end

---------------------------------------------------------------------------
-- VGA mode setup
---------------------------------------------------------------------------

function id_vl.VL_SetVGAPlaneMode()
    if not id_vl.imageData then
        id_vl.VL_Startup()
    end
    id_vl.VL_DePlaneVGA()
    id_vl.VL_SetLineWidth(40)
end

function id_vl.VL_SetVGAPlane()
    -- No-op
end

function id_vl.VL_SetTextMode()
    -- No-op
end

function id_vl.VL_ClearVideo(color)
    for i = 0, 320 * 200 - 1 do
        id_vl.screenbuf[i] = color
    end
    for i = 0, LATCH_MEM_SIZE - 1 do
        id_vl.latchmem[i] = color
    end
end

function id_vl.VL_DePlaneVGA()
    id_vl.VL_ClearVideo(0)
end

---------------------------------------------------------------------------
-- Line width / lookup tables
---------------------------------------------------------------------------

function id_vl.VL_SetLineWidth(width)
    id_vl.linewidth = width * 2
    local offset = 0
    for i = 0, id_vl.MAXSCANLINES - 1 do
        id_vl.ylookup[i] = offset
        offset = offset + id_vl.linewidth
    end
end

function id_vl.VL_SetSplitScreen(linenum)
    -- No-op
end

---------------------------------------------------------------------------
-- Timing
---------------------------------------------------------------------------

function id_vl.VL_WaitVBL(vbls)
    if vbls > 0 then
        -- Approximate 70Hz VBL: ~14ms per frame
        -- Yield to Love2D event loop if in a coroutine
        local co = coroutine.running()
        if co then
            for i = 1, vbls do
                coroutine.yield()
            end
        else
            love.timer.sleep(vbls * 0.014)
        end
    end
end

function id_vl.VL_SetScreen(crtc, pel)
    id_vl.displayofs = crtc
    id_vl.pelpan = pel
end

function id_vl.VL_SetCRTC(crtc)
    -- No-op
end

function id_vl.VL_VideoID()
    return 5  -- Always VGA
end

---------------------------------------------------------------------------
-- Palette operations
---------------------------------------------------------------------------

function id_vl.VL_FillPalette(red, green, blue)
    for i = 0, 255 do
        id_vl.palette[i * 3 + 0] = red
        id_vl.palette[i * 3 + 1] = green
        id_vl.palette[i * 3 + 2] = blue
    end
end

function id_vl.VL_SetColor(color, red, green, blue)
    id_vl.palette[color * 3 + 0] = red
    id_vl.palette[color * 3 + 1] = green
    id_vl.palette[color * 3 + 2] = blue
end

function id_vl.VL_GetColor(color)
    return id_vl.palette[color * 3 + 0],
           id_vl.palette[color * 3 + 1],
           id_vl.palette[color * 3 + 2]
end

function id_vl.VL_SetPalette(pal_data)
    -- pal_data is a table indexed [0..767] or a string of 768 bytes
    if type(pal_data) == "string" then
        for i = 0, 767 do
            id_vl.palette[i] = string.byte(pal_data, i + 1) or 0
        end
    else
        for i = 0, 767 do
            id_vl.palette[i] = pal_data[i] or 0
        end
    end
end

function id_vl.VL_GetPalette()
    local pal = {}
    for i = 0, 767 do
        pal[i] = id_vl.palette[i]
    end
    return pal
end

function id_vl.VL_FadeOut(start, finish, red, green, blue, steps)
    id_vl.VL_WaitVBL(1)
    -- Save current palette
    for i = 0, 767 do
        id_vl.palette1[i] = id_vl.palette[i]
        id_vl.palette2[i] = id_vl.palette[i]
    end

    -- Fade through intermediate frames
    for i = 0, steps - 1 do
        for j = start, finish do
            local orig_r = id_vl.palette1[j * 3 + 0]
            local delta_r = red - orig_r
            id_vl.palette2[j * 3 + 0] = orig_r + math.floor(delta_r * i / steps)

            local orig_g = id_vl.palette1[j * 3 + 1]
            local delta_g = green - orig_g
            id_vl.palette2[j * 3 + 1] = orig_g + math.floor(delta_g * i / steps)

            local orig_b = id_vl.palette1[j * 3 + 2]
            local delta_b = blue - orig_b
            id_vl.palette2[j * 3 + 2] = orig_b + math.floor(delta_b * i / steps)
        end

        id_vl.VL_WaitVBL(1)
        id_vl.VL_SetPalette(id_vl.palette2)
        id_vl.VL_UpdateScreen()
    end

    -- Final color
    id_vl.VL_FillPalette(red, green, blue)
    id_vl.screenfaded = true
end

function id_vl.VL_FadeIn(start, finish, pal_data, steps)
    id_vl.VL_WaitVBL(1)
    -- Save current palette
    for i = 0, 767 do
        id_vl.palette1[i] = id_vl.palette[i]
        id_vl.palette2[i] = id_vl.palette[i]
    end

    local start3 = start * 3
    local end3 = finish * 3 + 2

    -- Fade through intermediate frames
    for i = 0, steps - 1 do
        for j = start3, end3 do
            local target = pal_data[j] or 0
            local delta = target - id_vl.palette1[j]
            id_vl.palette2[j] = id_vl.palette1[j] + math.floor(delta * i / steps)
        end

        id_vl.VL_WaitVBL(1)
        id_vl.VL_SetPalette(id_vl.palette2)
        id_vl.VL_UpdateScreen()
    end

    -- Final palette
    id_vl.VL_SetPalette(pal_data)
    id_vl.screenfaded = false
end

function id_vl.VL_TestPaletteSet()
    id_vl.fastpalette = true
end

function id_vl.VL_ColorBorder(color)
    id_vl.bordercolor = color
end

---------------------------------------------------------------------------
-- Pixel operations
---------------------------------------------------------------------------

function id_vl.VL_Plot(x, y, color)
    if x >= 0 and x < 320 and y >= 0 and y < 200 then
        id_vl.screenbuf[y * 320 + x] = color
    end
end

function id_vl.VL_Hlin(x, y, width, color)
    if y >= 200 or y < 0 then return end
    if x >= 320 then return end
    if x < 0 then width = width + x; x = 0 end
    if x + width > 320 then width = 320 - x end
    if width <= 0 then return end
    local base = y * 320 + x
    for i = 0, width - 1 do
        id_vl.screenbuf[base + i] = color
    end
end

function id_vl.VL_Vlin(x, y, height, color)
    if x < 0 or x >= 320 then return end
    if y < 0 then height = height + y; y = 0 end
    if y + height > 200 then height = 200 - y end
    local idx = y * 320 + x
    for i = 0, height - 1 do
        id_vl.screenbuf[idx] = color
        idx = idx + 320
    end
end

function id_vl.VL_Bar(x, y, width, height, color)
    if x < 0 then width = width + x; x = 0 end
    if y < 0 then height = height + y; y = 0 end
    if x + width > 320 then width = 320 - x end
    if y + height > 200 then height = 200 - y end
    if width <= 0 or height <= 0 then return end

    for row = 0, height - 1 do
        local base = (y + row) * 320 + x
        for col = 0, width - 1 do
            id_vl.screenbuf[base + col] = color
        end
    end
end

---------------------------------------------------------------------------
-- Memory-to-screen blitting (planar format)
---------------------------------------------------------------------------

-- De-munges a pic that was in VGA planar format
function id_vl.VL_MungePic(source, width, height)
    -- source is a table of bytes. This function rearranges in-place
    -- from linear to plane-separated format.
    -- In the C code this function converts from linear to planar order.
    -- We implement the same transformation.
    local size = width * height
    if #source < size then return end

    local temp = {}
    for i = 1, size do
        temp[i] = source[i]
    end

    local pwidth = math.floor(width / 4)
    local idx = 1
    for plane = 0, 3 do
        for y = 0, height - 1 do
            for x = 0, pwidth - 1 do
                source[idx] = temp[y * width + x * 4 + plane + 1] or 0
                idx = idx + 1
            end
        end
    end
end

-- Draw a plane-separated block to the screenbuf
function id_vl.VL_MemToScreen(source, width, height, x, y)
    local pwidth = rshift(width, 2)
    local src_idx = 1
    local startplane = band(x, 3)

    for plane = 0, 3 do
        local curplane = band(startplane + plane, 3)
        for py = 0, height - 1 do
            for px = 0, pwidth - 1 do
                local screenx = (rshift(x, 2) + px) * 4 + curplane
                local screeny = y + py
                if screenx >= 0 and screenx < 320 and screeny >= 0 and screeny < 200 then
                    id_vl.screenbuf[screeny * 320 + screenx] = source[src_idx] or 0
                end
                src_idx = src_idx + 1
            end
        end
    end
end

-- Masked version (pixel 0 = transparent)
function id_vl.VL_MaskedToScreen(source, width, height, x, y)
    local pwidth = rshift(width, 2)
    local src_idx = 1
    local startplane = band(x, 3)

    for plane = 0, 3 do
        local curplane = band(startplane + plane, 3)
        for py = 0, height - 1 do
            for px = 0, pwidth - 1 do
                local screenx = (rshift(x, 2) + px) * 4 + curplane
                local screeny = y + py
                local val = source[src_idx] or 0
                if val ~= 0 and screenx >= 0 and screenx < 320 and screeny >= 0 and screeny < 200 then
                    id_vl.screenbuf[screeny * 320 + screenx] = val
                end
                src_idx = src_idx + 1
            end
        end
    end
end

---------------------------------------------------------------------------
-- Latch operations
---------------------------------------------------------------------------

function id_vl.VL_MemToLatch(source, width, height, dest)
    local pwidth = math.floor((width + 3) / 4)
    local linearbase = dest * 4

    -- Clear destination area
    if linearbase + width * height <= LATCH_MEM_SIZE then
        for i = 0, width * height - 1 do
            id_vl.latchmem[linearbase + i] = 0
        end
    end

    local src_idx = 1
    for plane = 0, 3 do
        for y = 0, height - 1 do
            for x = 0, pwidth - 1 do
                local px = x * 4 + plane
                local idx = linearbase + y * width + px
                if px < width and idx < LATCH_MEM_SIZE then
                    id_vl.latchmem[idx] = source[src_idx] or 0
                end
                src_idx = src_idx + 1
            end
        end
    end
end

function id_vl.VL_LatchToScreen(source, width, height, x, y)
    local pixwidth = width * 4
    local linearbase = source * 4

    -- Adjust for bufferofs
    local within_page = id_vl.bufferofs % (id_vl.SCREENWIDTH * 208)
    local buf_y = math.floor(within_page / id_vl.linewidth)
    local buf_x = (within_page % id_vl.linewidth) * 4

    x = x + buf_x
    y = y + buf_y

    for sy = 0, height - 1 do
        local screeny = y + sy
        if screeny >= 0 and screeny < 200 then
            for sx = 0, pixwidth - 1 do
                if x + sx >= 0 and x + sx < 320 then
                    local idx = linearbase + sy * pixwidth + sx
                    if idx >= 0 and idx < LATCH_MEM_SIZE then
                        id_vl.screenbuf[screeny * 320 + x + sx] = id_vl.latchmem[idx]
                    end
                end
            end
        end
    end
end

function id_vl.VL_ScreenToScreen(source, dest, width, height)
    for y = 0, height - 1 do
        local src_planar = source + y * id_vl.linewidth
        local dst_planar = dest + y * id_vl.linewidth

        local src_row = math.floor(src_planar / id_vl.linewidth)
        local src_col = src_planar % id_vl.linewidth
        local dst_row = math.floor(dst_planar / id_vl.linewidth)
        local dst_col = dst_planar % id_vl.linewidth

        local src_linear = src_row * 320 + src_col * 4
        local dst_linear = dst_row * 320 + dst_col * 4
        local pixwidth = width * 4

        if src_linear >= 0 and dst_linear >= 0 and
           src_linear + pixwidth <= 320 * 200 and
           dst_linear + pixwidth <= 320 * 200 then
            -- Copy (handle overlap with temp)
            local temp = {}
            for i = 0, pixwidth - 1 do
                temp[i] = id_vl.screenbuf[src_linear + i]
            end
            for i = 0, pixwidth - 1 do
                id_vl.screenbuf[dst_linear + i] = temp[i]
            end
        end
    end
end

---------------------------------------------------------------------------
-- String drawing
---------------------------------------------------------------------------

function id_vl.VL_DrawTile8String(str, tile8ptr, printx, printy)
    for ci = 1, #str do
        local ch = string.byte(str, ci)
        local src_base = ch * 64   -- 64 bytes per char, 0-indexed in tile8ptr

        for plane = 0, 3 do
            for row = 0, 7 do
                local screeny = printy + row
                if screeny >= 0 and screeny < 200 then
                    local src_offset = plane * 16 + row * 2
                    local x0 = printx + plane
                    local x1 = printx + plane + 4

                    if x0 >= 0 and x0 < 320 then
                        id_vl.screenbuf[screeny * 320 + x0] = tile8ptr[src_base + src_offset + 1] or 0
                    end
                    if x1 >= 0 and x1 < 320 then
                        id_vl.screenbuf[screeny * 320 + x1] = tile8ptr[src_base + src_offset + 2] or 0
                    end
                end
            end
        end

        printx = printx + 8
    end
end

function id_vl.VL_DrawLatch8String(str, tile8ptr, printx, printy)
    for ci = 1, #str do
        local ch = string.byte(str, ci)
        local planar_src = tile8ptr + lshift(ch, 4)  -- 16 planar bytes per char
        local linear_src = planar_src * 4

        for row = 0, 7 do
            local screeny = printy + row
            if screeny >= 0 and screeny < 200 then
                for col = 0, 7 do
                    local screenx = printx + col
                    if screenx >= 0 and screenx < 320 then
                        local idx = linear_src + row * 8 + col
                        if idx >= 0 and idx < LATCH_MEM_SIZE then
                            id_vl.screenbuf[screeny * 320 + screenx] = id_vl.latchmem[idx]
                        end
                    end
                end
            end
        end

        printx = printx + 8
    end
end

function id_vl.VL_SizeTile8String(str)
    return 8 * #str, 8
end

---------------------------------------------------------------------------
-- VL_UpdateScreen - convert indexed framebuffer to RGBA and present
---------------------------------------------------------------------------

function id_vl.VL_UpdateScreen()
    if not id_vl.imageData then return end

    local imgData = id_vl.imageData
    local pal = id_vl.palette
    local buf = id_vl.screenbuf

    -- Get palette shift amounts from wl_play (damage=red, bonus=white)
    local ok, wl_play = pcall(require, "wl_play")
    local red_shift = 0
    local white_shift = 0
    if ok and wl_play then
        red_shift = wl_play.palshifted_red or 0     -- 0..6 (NUMREDSHIFTS)
        white_shift = wl_play.palshifted_white or 0  -- 0..3 (NUMWHITESHIFTS)
    end

    -- Pre-compute tint amounts (in 6-bit VGA space)
    -- Red shift: boost R, reduce G and B proportionally
    local red_add = red_shift * 10       -- max ~60 in 6-bit space
    local red_sub = red_shift * 6        -- how much to reduce G/B
    -- White shift: boost all channels proportionally
    local white_add = white_shift * 8    -- max ~24 in 6-bit space

    local has_shift = (red_shift > 0 or white_shift > 0)

    -- Use FFI pointer for speed if available
    local ptr = imgData:getFFIPointer()
    if ptr then
        for y = 0, 199 do
            for x = 0, 319 do
                local idx = buf[y * 320 + x] or 0
                local pr = pal[idx * 3 + 0] or 0
                local pg = pal[idx * 3 + 1] or 0
                local pb = pal[idx * 3 + 2] or 0

                if has_shift then
                    -- Apply damage (red) shift
                    pr = pr + red_add
                    pg = pg - red_sub
                    pb = pb - red_sub
                    -- Apply bonus (white) shift
                    pr = pr + white_add
                    pg = pg + white_add
                    pb = pb + white_add
                    -- Clamp to 6-bit range
                    if pr > 63 then pr = 63 elseif pr < 0 then pr = 0 end
                    if pg > 63 then pg = 63 elseif pg < 0 then pg = 0 end
                    if pb > 63 then pb = 63 elseif pb < 0 then pb = 0 end
                end

                -- VGA palette values are 6-bit (0-63), scale to 8-bit (0-255)
                local offset = (y * 320 + x) * 4
                ptr[offset + 0] = math.floor(pr * 255 / 63)
                ptr[offset + 1] = math.floor(pg * 255 / 63)
                ptr[offset + 2] = math.floor(pb * 255 / 63)
                ptr[offset + 3] = 255
            end
        end
    else
        -- Fallback: use setPixel (slower)
        for y = 0, 199 do
            for x = 0, 319 do
                local idx = buf[y * 320 + x] or 0
                local pr = pal[idx * 3 + 0] or 0
                local pg = pal[idx * 3 + 1] or 0
                local pb = pal[idx * 3 + 2] or 0

                if has_shift then
                    pr = pr + red_add
                    pg = pg - red_sub
                    pb = pb - red_sub
                    pr = pr + white_add
                    pg = pg + white_add
                    pb = pb + white_add
                    if pr > 63 then pr = 63 elseif pr < 0 then pr = 0 end
                    if pg > 63 then pg = 63 elseif pg < 0 then pg = 0 end
                    if pb > 63 then pb = 63 elseif pb < 0 then pb = 0 end
                end

                imgData:setPixel(x, y, pr / 63, pg / 63, pb / 63, 1)
            end
        end
    end

    -- Refresh the GPU texture from the ImageData
    id_vl.image:replacePixels(imgData)

    id_vl.capture_frame = id_vl.capture_frame + 1
end

-- Called from love.draw() to actually render the image to screen
function id_vl.VL_Present()
    if not id_vl.image then return end

    -- Scale to fill window while maintaining aspect ratio
    local ww, wh = love.graphics.getDimensions()
    local sx = ww / 320
    local sy = wh / 200
    local s = math.min(sx, sy)
    local ox = math.floor((ww - 320 * s) / 2)
    local oy = math.floor((wh - 200 * s) / 2)

    love.graphics.clear(0, 0, 0, 1)
    love.graphics.draw(id_vl.image, ox, oy, 0, s, s)
end

return id_vl
