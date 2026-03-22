-- WL_DRAW.lua
-- 3D rendering engine - ported from WL_DRAW.C
-- Raycasting, wall drawing, sprite rendering

local bit = require("bit")
local band, bor, lshift, rshift = bit.band, bit.bor, bit.lshift, bit.rshift

local wl_def = require("wl_def")
local id_vl  = require("id_vl")

local wl_draw = {}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
wl_draw.postsource  = nil
wl_draw.postx       = 0
wl_draw.postwidth   = 0

---------------------------------------------------------------------------
-- FixedByFrac - multiply two fixed-point numbers
---------------------------------------------------------------------------

function wl_draw.FixedByFrac(a, b)
    -- In the original, this is (a * b) >> 16
    -- But we need to handle the sign bit (bit 31) encoding
    local a_val = a
    local b_val = b

    -- Handle sign-encoded values (bit 31 = negative in original)
    local a_neg = false
    local b_neg = false

    if a_val < 0 or (type(a_val) == "number" and a_val >= 0x80000000) then
        a_neg = true
        if a_val >= 0x80000000 then
            a_val = band(a_val, 0x7FFFFFFF)
        else
            a_val = -a_val
        end
    end
    if b_val < 0 or (type(b_val) == "number" and b_val >= 0x80000000) then
        b_neg = true
        if b_val >= 0x80000000 then
            b_val = band(b_val, 0x7FFFFFFF)
        else
            b_val = -b_val
        end
    end

    local result = math.floor(a_val * b_val / 65536)

    if a_neg ~= b_neg then
        result = -result
    end

    return result
end

---------------------------------------------------------------------------
-- TransformActor (stub)
---------------------------------------------------------------------------

function wl_draw.TransformActor(ob)
    -- Transform actor coordinates to view space
    -- Sets ob.viewx, ob.viewheight, ob.transx, ob.transy
end

---------------------------------------------------------------------------
-- CalcRotate (stub)
---------------------------------------------------------------------------

function wl_draw.CalcRotate(ob)
    -- Calculate which rotation frame to use for a sprite
    return 0
end

---------------------------------------------------------------------------
-- DrawScaleds (stub)
---------------------------------------------------------------------------

function wl_draw.DrawScaleds()
    -- Draw all visible scaled sprites
end

---------------------------------------------------------------------------
-- CalcTics
---------------------------------------------------------------------------

function wl_draw.CalcTics()
    local wl_main = require("wl_main")
    local id_sd = require("id_sd")

    local newtime = id_sd.TimeCount

    wl_main.tics = newtime - wl_main.lasttimecount
    wl_main.lasttimecount = newtime

    if wl_main.tics > wl_def.MAXTICS then
        wl_main.tics = wl_def.MAXTICS
    end
    if wl_main.tics < 1 then
        wl_main.tics = 1
    end
end

---------------------------------------------------------------------------
-- ClearScreen
---------------------------------------------------------------------------

function wl_draw.ClearScreen()
    local wl_main = require("wl_main")
    -- Clear the 3D view area
    -- Top half = ceiling color, bottom half = floor color
    local vieww = wl_main.viewwidth
    local viewh = wl_main.viewheight
    local top_y = math.floor((200 - wl_def.STATUSLINES - viewh) / 2)

    -- Ceiling (color 0x1d for WL6)
    id_vl.VL_Bar(math.floor((320 - vieww) / 2), top_y, vieww, math.floor(viewh / 2), 0x19)
    -- Floor (color 0x19 for WL6)
    id_vl.VL_Bar(math.floor((320 - vieww) / 2), top_y + math.floor(viewh / 2), vieww, math.floor(viewh / 2), 0x1d)
end

---------------------------------------------------------------------------
-- ThreeDRefresh (stub)
---------------------------------------------------------------------------

function wl_draw.ThreeDRefresh()
    -- The main 3D rendering function
    -- Would do raycasting, wall drawing, sprite rendering, weapon overlay
    wl_draw.ClearScreen()
end

---------------------------------------------------------------------------
-- FixOfs
---------------------------------------------------------------------------

function wl_draw.FixOfs()
    id_vl.bufferofs = wl_def.PAGE1START
    id_vl.displayofs = wl_def.PAGE1START
end

---------------------------------------------------------------------------
-- FarScalePost (stub)
---------------------------------------------------------------------------

function wl_draw.FarScalePost()
    -- Draw a scaled wall column
end

return wl_draw
