-- WL_SCALE.lua
-- Scaling routines - ported from WL_SCALE.C
-- Handles scaled wall/sprite column drawing

local wl_def = require("wl_def")

local wl_scale = {}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
wl_scale.scaledirectory     = {}  -- [0..MAXSCALEHEIGHT]
wl_scale.fullscalefarcall   = {}  -- [0..MAXSCALEHEIGHT]

---------------------------------------------------------------------------
-- SetupScaling
---------------------------------------------------------------------------

function wl_scale.SetupScaling(maxscaleheight)
    -- In the original, this built compiled scalers (self-modifying code).
    -- In our port, we precompute lookup tables for scaled column drawing.
    -- For now, this is a stub.
    for i = 0, wl_def.MAXSCALEHEIGHT do
        wl_scale.scaledirectory[i] = nil
        wl_scale.fullscalefarcall[i] = 0
    end
end

---------------------------------------------------------------------------
-- ScalePost - draw a single scaled wall column
---------------------------------------------------------------------------

function wl_scale.ScalePost(height, source, offset, x)
    local id_vl = require("id_vl")
    local wl_main = require("wl_main")

    if height <= 0 then return end

    local top_y = math.floor((200 - wl_def.STATUSLINES - height) / 2)
    if top_y < 0 then top_y = 0 end

    local bottom_y = top_y + height
    if bottom_y > 200 - wl_def.STATUSLINES then
        bottom_y = 200 - wl_def.STATUSLINES
    end

    -- Draw the column from the texture source
    if not source then return end

    local texheight = 64  -- Wall textures are 64 pixels tall
    for y = top_y, bottom_y - 1 do
        local frac = math.floor((y - top_y) * texheight / height)
        if frac >= texheight then frac = texheight - 1 end
        local pixel = source[offset + frac + 1] or 0
        if x >= 0 and x < 320 and y >= 0 and y < 200 then
            id_vl.screenbuf[y * 320 + x] = pixel
        end
    end
end

return wl_scale
