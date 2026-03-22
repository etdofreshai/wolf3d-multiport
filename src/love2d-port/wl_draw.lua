-- WL_DRAW.lua
-- 3D rendering engine - ported from WL_DRAW.C and WL_DR_A.C
-- Raycasting, wall drawing, sprite rendering

local bit = require("bit")
local band, bor, bxor, lshift, rshift = bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift

local wl_def = require("wl_def")
local id_vl  = require("id_vl")
local id_pm  = require("id_pm")

local wl_draw = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------
local DOORWALL = 0  -- set at init: PMSpriteStart - 8
local ACTORSIZE = 0x4000

local DEG90  = 900
local DEG180 = 1800
local DEG270 = 2700
local DEG360 = 3600

local MAXVISABLE = 50

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
wl_draw.postsource  = nil
wl_draw.postx       = 0
wl_draw.postwidth   = 0
wl_draw.posttexture = 0
wl_draw.postpage    = nil   -- table of bytes for the current wall page

-- Ray tracing variables
wl_draw.lastside      = -1
wl_draw.lastintercept = 0
wl_draw.lasttilehit   = 0

wl_draw.focaltx = 0
wl_draw.focalty = 0
wl_draw.viewtx  = 0
wl_draw.viewty  = 0

wl_draw.midangle = 0
wl_draw.pixx     = 0

wl_draw.xpartialup   = 0
wl_draw.xpartialdown = 0
wl_draw.ypartialup   = 0
wl_draw.ypartialdown = 0

wl_draw.tilehit   = 0
wl_draw.xtile     = 0
wl_draw.ytile     = 0
wl_draw.xtilestep = 0
wl_draw.ytilestep = 0
wl_draw.xintercept = 0
wl_draw.yintercept = 0
wl_draw.xstep = 0
wl_draw.ystep = 0

-- Ceiling color table (WL6, not SPEAR)
wl_draw.vgaCeiling = {
    0x1d, 0x1d, 0x1d, 0x1d, 0x1d, 0x1d, 0x1d, 0x1d, 0x1d, 0xbf,
    0x4e, 0x4e, 0x4e, 0x1d, 0x8d, 0x4e, 0x1d, 0x2d, 0x1d, 0x8d,
    0x1d, 0x1d, 0x1d, 0x1d, 0x1d, 0x2d, 0xdd, 0x1d, 0x1d, 0x98,
    0x1d, 0x9d, 0x2d, 0xdd, 0xdd, 0x9d, 0x2d, 0x4d, 0x1d, 0xdd,
    0x7d, 0x1d, 0x2d, 0x2d, 0xdd, 0xd7, 0x1d, 0x1d, 0x1d, 0x2d,
    0x1d, 0x1d, 0x1d, 0x1d, 0xdd, 0xdd, 0x7d, 0xdd, 0xdd, 0xdd,
}

-- Weapon scale table
wl_draw.weaponscale = nil  -- set at init

---------------------------------------------------------------------------
-- FixedByFrac - multiply a 16.16 fixed-point number by a signed-magnitude fraction
---------------------------------------------------------------------------

function wl_draw.FixedByFrac(a, b)
    -- b is signed magnitude: bit 31 is sign, bits 0-30 are magnitude
    -- In Lua, we handle negative b via its high bit
    local sign = false

    -- Extract sign from b (high word bit 15)
    local b_hi = math.floor(b / 65536)
    if band(b_hi, 0x8000) ~= 0 then
        sign = true
    end

    -- Get absolute value of a and track sign
    local ua = a
    if a < 0 then
        ua = -a
        sign = not sign
    end

    -- b fraction is the low 16 bits (magnitude)
    local ub = band(b, 0xFFFF)
    if ub < 0 then ub = ub + 65536 end

    -- multiply: ua is 16.16 fixed, ub is 0.16 fraction
    local ua_lo = band(ua, 0xFFFF)
    local ua_hi = math.floor(ua / 65536)
    if ua_hi < 0 then ua_hi = ua_hi + 65536 end

    local lo = ua_lo * ub
    local hi = ua_hi * ub
    local result = hi + math.floor(lo / 65536)

    if sign then
        return -result
    else
        return result
    end
end

---------------------------------------------------------------------------
-- TransformActor
---------------------------------------------------------------------------

function wl_draw.TransformActor(ob)
    local wl_main = require("wl_main")

    local gx = ob.x - wl_main.viewx
    local gy = ob.y - wl_main.viewy

    -- calculate newx
    local gxt = wl_draw.FixedByFrac(gx, wl_main.viewcos)
    local gyt = wl_draw.FixedByFrac(gy, wl_main.viewsin)
    local nx = gxt - gyt - ACTORSIZE

    -- calculate newy
    gxt = wl_draw.FixedByFrac(gx, wl_main.viewsin)
    gyt = wl_draw.FixedByFrac(gy, wl_main.viewcos)
    local ny = gyt + gxt

    ob.transx = nx
    ob.transy = ny

    if nx < wl_def.MINDIST then
        ob.viewheight = 0
        return
    end

    ob.viewx = wl_main.centerx + math.floor(ny * wl_main.scale / nx)

    local temp = math.floor(wl_main.heightnumerator / rshift(nx, 8))
    ob.viewheight = temp
end

---------------------------------------------------------------------------
-- TransformTile
---------------------------------------------------------------------------

function wl_draw.TransformTile(tx, ty)
    local wl_main = require("wl_main")

    local gx = lshift(tx, wl_def.TILESHIFT) + 0x8000 - wl_main.viewx
    local gy = lshift(ty, wl_def.TILESHIFT) + 0x8000 - wl_main.viewy

    local gxt = wl_draw.FixedByFrac(gx, wl_main.viewcos)
    local gyt = wl_draw.FixedByFrac(gy, wl_main.viewsin)
    local nx = gxt - gyt - 0x2000

    gxt = wl_draw.FixedByFrac(gx, wl_main.viewsin)
    gyt = wl_draw.FixedByFrac(gy, wl_main.viewcos)
    local ny = gyt + gxt

    if nx < wl_def.MINDIST then
        return false, 0, 0
    end

    local dispx = wl_main.centerx + math.floor(ny * wl_main.scale / nx)
    local dispheight = math.floor(wl_main.heightnumerator / rshift(nx, 8))

    local grabbed = (nx < wl_def.TILEGLOBAL and ny > -math.floor(wl_def.TILEGLOBAL / 2) and ny < math.floor(wl_def.TILEGLOBAL / 2))

    return grabbed, dispx, dispheight
end

---------------------------------------------------------------------------
-- CalcHeight
---------------------------------------------------------------------------

function wl_draw.CalcHeight()
    local wl_main = require("wl_main")

    local gx = wl_draw.xintercept - wl_main.viewx
    local gxt = wl_draw.FixedByFrac(gx, wl_main.viewcos)

    local gy = wl_draw.yintercept - wl_main.viewy
    local gyt = wl_draw.FixedByFrac(gy, wl_main.viewsin)

    local nx = gxt - gyt

    if nx < wl_def.MINDIST then
        nx = wl_def.MINDIST
    end

    local shifted = rshift(nx, 8)
    if shifted == 0 then shifted = 1 end

    return math.floor(wl_main.heightnumerator / shifted)
end

---------------------------------------------------------------------------
-- ScalePost - draw a single scaled wall column
---------------------------------------------------------------------------

function wl_draw.ScalePost()
    local wl_main = require("wl_main")

    local source = wl_draw.postsource
    if not source then return end

    local ht = rshift(wl_main.wallheight[wl_draw.postx], 3)
    if ht <= 0 then return end

    local viewh = wl_main.viewheight
    local toprow = math.floor((viewh - ht) / 2)
    local bottomrow = toprow + ht
    local fracstep = math.floor(lshift(64, 16) / ht)
    local frac = 0

    -- Clamp if taller than view
    if ht > viewh then
        local skip = math.floor((ht - viewh) / 2)
        frac = skip * fracstep
        toprow = 0
        bottomrow = viewh
    end

    -- Calculate viewport offset
    local screenofs = wl_main.screenofs
    local yofs = math.floor(screenofs / wl_def.SCREENWIDTH)
    local xofs = (screenofs % wl_def.SCREENWIDTH) * 4

    for x = wl_draw.postx, math.min(wl_draw.postx + wl_draw.postwidth - 1, wl_main.viewwidth - 1) do
        local f = frac
        for y = toprow, bottomrow - 1 do
            local texel = band(rshift(f, 16), 63)
            local screeny = y + yofs
            local screenx = x + xofs
            if screeny >= 0 and screeny < 200 and screenx >= 0 and screenx < 320 then
                -- postsource is a table; texture offset is posttexture
                -- source is postpage indexed from posttexture + texel
                local srcidx = wl_draw.posttexture + texel + 1  -- 1-indexed
                local color = source[srcidx] or 0
                id_vl.screenbuf[screeny * 320 + screenx] = color
            end
            f = f + fracstep
        end
    end
end

function wl_draw.FarScalePost()
    wl_draw.ScalePost()
end

---------------------------------------------------------------------------
-- GetWallPage - helper to load a wall page as byte table
---------------------------------------------------------------------------

local function GetWallPage(wallpic)
    local page = id_pm.PM_GetPage(wallpic)
    if not page then return nil end
    -- Convert string to byte table (1-indexed)
    local bytes = {}
    for i = 1, #page do
        bytes[i] = string.byte(page, i)
    end
    return bytes
end

---------------------------------------------------------------------------
-- HitVertWall
---------------------------------------------------------------------------

function wl_draw.HitVertWall()
    local wl_main = require("wl_main")
    local wl_game = require("wl_game")

    local texture = band(rshift(wl_draw.yintercept, 4), 0xfc0)
    if wl_draw.xtilestep == -1 then
        texture = 0xfc0 - texture
        wl_draw.xintercept = wl_draw.xintercept + wl_def.TILEGLOBAL
    end
    wl_main.wallheight[wl_draw.pixx] = wl_draw.CalcHeight()

    if wl_draw.lastside == 1 and wl_draw.lastintercept == wl_draw.xtile and wl_draw.lasttilehit == wl_draw.tilehit then
        if texture == wl_draw.posttexture then
            -- wide scale
            wl_draw.postwidth = wl_draw.postwidth + 1
            wl_main.wallheight[wl_draw.pixx] = wl_main.wallheight[wl_draw.pixx - 1]
            return
        else
            wl_draw.ScalePost()
            wl_draw.posttexture = texture
            wl_draw.postsource = wl_draw.postpage
            wl_draw.postwidth = 1
            wl_draw.postx = wl_draw.pixx
        end
    else
        -- new wall
        if wl_draw.lastside ~= -1 then
            wl_draw.ScalePost()
        end

        wl_draw.lastside = 1
        wl_draw.lastintercept = wl_draw.xtile
        wl_draw.lasttilehit = wl_draw.tilehit
        wl_draw.postx = wl_draw.pixx
        wl_draw.postwidth = 1

        local wallpic
        if band(wl_draw.tilehit, 0x40) ~= 0 then
            -- check for adjacent doors
            local ytile_local = rshift(wl_draw.yintercept, wl_def.TILESHIFT)
            local adj_x = wl_draw.xtile - wl_draw.xtilestep
            if adj_x >= 0 and adj_x < wl_def.MAPSIZE and ytile_local >= 0 and ytile_local < wl_def.MAPSIZE then
                if band(wl_main.tilemap[adj_x][ytile_local], 0x80) ~= 0 then
                    wallpic = DOORWALL + 3
                else
                    wallpic = wl_main.vertwall[band(wl_draw.tilehit, bxor(0x40, 0xFF))]
                end
            else
                wallpic = wl_main.vertwall[band(wl_draw.tilehit, bxor(0x40, 0xFF))]
            end
        else
            wallpic = wl_main.vertwall[wl_draw.tilehit]
        end

        wl_draw.postpage = GetWallPage(wallpic or 0)
        wl_draw.posttexture = texture
        wl_draw.postsource = wl_draw.postpage
    end
end

---------------------------------------------------------------------------
-- HitHorizWall
---------------------------------------------------------------------------

function wl_draw.HitHorizWall()
    local wl_main = require("wl_main")

    local texture = band(rshift(wl_draw.xintercept, 4), 0xfc0)
    if wl_draw.ytilestep == -1 then
        wl_draw.yintercept = wl_draw.yintercept + wl_def.TILEGLOBAL
    else
        texture = 0xfc0 - texture
    end
    wl_main.wallheight[wl_draw.pixx] = wl_draw.CalcHeight()

    if wl_draw.lastside == 0 and wl_draw.lastintercept == wl_draw.ytile and wl_draw.lasttilehit == wl_draw.tilehit then
        if texture == wl_draw.posttexture then
            wl_draw.postwidth = wl_draw.postwidth + 1
            wl_main.wallheight[wl_draw.pixx] = wl_main.wallheight[wl_draw.pixx - 1]
            return
        else
            wl_draw.ScalePost()
            wl_draw.posttexture = texture
            wl_draw.postsource = wl_draw.postpage
            wl_draw.postwidth = 1
            wl_draw.postx = wl_draw.pixx
        end
    else
        if wl_draw.lastside ~= -1 then
            wl_draw.ScalePost()
        end

        wl_draw.lastside = 0
        wl_draw.lastintercept = wl_draw.ytile
        wl_draw.lasttilehit = wl_draw.tilehit
        wl_draw.postx = wl_draw.pixx
        wl_draw.postwidth = 1

        local wallpic
        if band(wl_draw.tilehit, 0x40) ~= 0 then
            local xtile_local = rshift(wl_draw.xintercept, wl_def.TILESHIFT)
            local adj_y = wl_draw.ytile - wl_draw.ytilestep
            if xtile_local >= 0 and xtile_local < wl_def.MAPSIZE and adj_y >= 0 and adj_y < wl_def.MAPSIZE then
                if band(wl_main.tilemap[xtile_local][adj_y], 0x80) ~= 0 then
                    wallpic = DOORWALL + 2
                else
                    wallpic = wl_main.horizwall[band(wl_draw.tilehit, bxor(0x40, 0xFF))]
                end
            else
                wallpic = wl_main.horizwall[band(wl_draw.tilehit, bxor(0x40, 0xFF))]
            end
        else
            wallpic = wl_main.horizwall[wl_draw.tilehit]
        end

        wl_draw.postpage = GetWallPage(wallpic or 0)
        wl_draw.posttexture = texture
        wl_draw.postsource = wl_draw.postpage
    end
end

---------------------------------------------------------------------------
-- HitHorizDoor
---------------------------------------------------------------------------

function wl_draw.HitHorizDoor()
    local wl_main = require("wl_main")
    local wl_game = require("wl_game")

    local doornum = band(wl_draw.tilehit, 0x7f)
    local texture = band(rshift(wl_draw.xintercept - (wl_game.doorposition[doornum] or 0), 4), 0xfc0)

    wl_main.wallheight[wl_draw.pixx] = wl_draw.CalcHeight()

    if wl_draw.lasttilehit == wl_draw.tilehit then
        if texture == wl_draw.posttexture then
            wl_draw.postwidth = wl_draw.postwidth + 1
            wl_main.wallheight[wl_draw.pixx] = wl_main.wallheight[wl_draw.pixx - 1]
            return
        else
            wl_draw.ScalePost()
            wl_draw.posttexture = texture
            wl_draw.postsource = wl_draw.postpage
            wl_draw.postwidth = 1
            wl_draw.postx = wl_draw.pixx
        end
    else
        if wl_draw.lastside ~= -1 then
            wl_draw.ScalePost()
        end
        wl_draw.lastside = 2
        wl_draw.lasttilehit = wl_draw.tilehit
        wl_draw.postx = wl_draw.pixx
        wl_draw.postwidth = 1

        local doorpage
        local lock = wl_game.doorobjlist[doornum] and wl_game.doorobjlist[doornum].lock or 0
        if lock == wl_def.dr_normal then
            doorpage = DOORWALL
        elseif lock == wl_def.dr_lock1 or lock == wl_def.dr_lock2 or lock == wl_def.dr_lock3 or lock == wl_def.dr_lock4 then
            doorpage = DOORWALL + 6
        elseif lock == wl_def.dr_elevator then
            doorpage = DOORWALL + 4
        else
            doorpage = DOORWALL
        end

        wl_draw.postpage = GetWallPage(doorpage)
        wl_draw.posttexture = texture
        wl_draw.postsource = wl_draw.postpage
    end
end

---------------------------------------------------------------------------
-- HitVertDoor
---------------------------------------------------------------------------

function wl_draw.HitVertDoor()
    local wl_main = require("wl_main")
    local wl_game = require("wl_game")

    local doornum = band(wl_draw.tilehit, 0x7f)
    local texture = band(rshift(wl_draw.yintercept - (wl_game.doorposition[doornum] or 0), 4), 0xfc0)

    wl_main.wallheight[wl_draw.pixx] = wl_draw.CalcHeight()

    if wl_draw.lasttilehit == wl_draw.tilehit then
        if texture == wl_draw.posttexture then
            wl_draw.postwidth = wl_draw.postwidth + 1
            wl_main.wallheight[wl_draw.pixx] = wl_main.wallheight[wl_draw.pixx - 1]
            return
        else
            wl_draw.ScalePost()
            wl_draw.posttexture = texture
            wl_draw.postsource = wl_draw.postpage
            wl_draw.postwidth = 1
            wl_draw.postx = wl_draw.pixx
        end
    else
        if wl_draw.lastside ~= -1 then
            wl_draw.ScalePost()
        end
        wl_draw.lastside = 2
        wl_draw.lasttilehit = wl_draw.tilehit
        wl_draw.postx = wl_draw.pixx
        wl_draw.postwidth = 1

        local doorpage
        local lock = wl_game.doorobjlist[doornum] and wl_game.doorobjlist[doornum].lock or 0
        if lock == wl_def.dr_normal then
            doorpage = DOORWALL
        elseif lock == wl_def.dr_lock1 or lock == wl_def.dr_lock2 or lock == wl_def.dr_lock3 or lock == wl_def.dr_lock4 then
            doorpage = DOORWALL + 6
        elseif lock == wl_def.dr_elevator then
            doorpage = DOORWALL + 4
        else
            doorpage = DOORWALL
        end

        wl_draw.postpage = GetWallPage(doorpage + 1)
        wl_draw.posttexture = texture
        wl_draw.postsource = wl_draw.postpage
    end
end

---------------------------------------------------------------------------
-- HitHorizPWall
---------------------------------------------------------------------------

function wl_draw.HitHorizPWall()
    local wl_main = require("wl_main")
    local wl_game = require("wl_game")

    local texture = band(rshift(wl_draw.xintercept, 4), 0xfc0)
    local offset = lshift(wl_game.pwallpos, 10)
    if wl_draw.ytilestep == -1 then
        wl_draw.yintercept = wl_draw.yintercept + wl_def.TILEGLOBAL - offset
    else
        texture = 0xfc0 - texture
        wl_draw.yintercept = wl_draw.yintercept + offset
    end

    wl_main.wallheight[wl_draw.pixx] = wl_draw.CalcHeight()

    if wl_draw.lasttilehit == wl_draw.tilehit then
        if texture == wl_draw.posttexture then
            wl_draw.postwidth = wl_draw.postwidth + 1
            wl_main.wallheight[wl_draw.pixx] = wl_main.wallheight[wl_draw.pixx - 1]
            return
        else
            wl_draw.ScalePost()
            wl_draw.posttexture = texture
            wl_draw.postsource = wl_draw.postpage
            wl_draw.postwidth = 1
            wl_draw.postx = wl_draw.pixx
        end
    else
        if wl_draw.lastside ~= -1 then
            wl_draw.ScalePost()
        end

        wl_draw.lasttilehit = wl_draw.tilehit
        wl_draw.postx = wl_draw.pixx
        wl_draw.postwidth = 1

        local wallpic = wl_main.horizwall[band(wl_draw.tilehit, 63)]
        wl_draw.postpage = GetWallPage(wallpic or 0)
        wl_draw.posttexture = texture
        wl_draw.postsource = wl_draw.postpage
    end
end

---------------------------------------------------------------------------
-- HitVertPWall
---------------------------------------------------------------------------

function wl_draw.HitVertPWall()
    local wl_main = require("wl_main")
    local wl_game = require("wl_game")

    local texture = band(rshift(wl_draw.yintercept, 4), 0xfc0)
    local offset = lshift(wl_game.pwallpos, 10)
    if wl_draw.xtilestep == -1 then
        wl_draw.xintercept = wl_draw.xintercept + wl_def.TILEGLOBAL - offset
        texture = 0xfc0 - texture
    else
        wl_draw.xintercept = wl_draw.xintercept + offset
    end

    wl_main.wallheight[wl_draw.pixx] = wl_draw.CalcHeight()

    if wl_draw.lasttilehit == wl_draw.tilehit then
        if texture == wl_draw.posttexture then
            wl_draw.postwidth = wl_draw.postwidth + 1
            wl_main.wallheight[wl_draw.pixx] = wl_main.wallheight[wl_draw.pixx - 1]
            return
        else
            wl_draw.ScalePost()
            wl_draw.posttexture = texture
            wl_draw.postsource = wl_draw.postpage
            wl_draw.postwidth = 1
            wl_draw.postx = wl_draw.pixx
        end
    else
        if wl_draw.lastside ~= -1 then
            wl_draw.ScalePost()
        end

        wl_draw.lasttilehit = wl_draw.tilehit
        wl_draw.postx = wl_draw.pixx
        wl_draw.postwidth = 1

        local wallpic = wl_main.vertwall[band(wl_draw.tilehit, 63)]
        wl_draw.postpage = GetWallPage(wallpic or 0)
        wl_draw.posttexture = texture
        wl_draw.postsource = wl_draw.postpage
    end
end

---------------------------------------------------------------------------
-- xpartialbyystep / ypartialbyxstep
---------------------------------------------------------------------------

local function xpartialbyystep(xpartial)
    local result = wl_draw.ystep * xpartial
    return math.floor(result / 65536)
end

local function ypartialbyxstep(ypartial)
    local result = wl_draw.xstep * ypartial
    return math.floor(result / 65536)
end

---------------------------------------------------------------------------
-- AsmRefresh - Core ray casting loop (from WL_DR_A.C)
---------------------------------------------------------------------------

function wl_draw.AsmRefresh()
    local wl_main = require("wl_main")
    local wl_game = require("wl_game")

    local tilemap = wl_main.tilemap
    local spotvis = wl_main.spotvis
    local finetangent = wl_main.finetangent
    local viewwidth = wl_main.viewwidth

    for pixx = 0, viewwidth - 1 do
        wl_draw.pixx = pixx

        local angle_ray = wl_draw.midangle + (wl_main.pixelangle[pixx] or 0)

        -- Normalize angle
        if angle_ray < 0 then angle_ray = angle_ray + wl_def.FINEANGLES end
        if angle_ray >= wl_def.FINEANGLES then angle_ray = angle_ray - wl_def.FINEANGLES end

        -- Setup based on quadrant
        local xpar, ypar
        if angle_ray < DEG90 then
            wl_draw.xtilestep = 1
            wl_draw.ytilestep = -1
            wl_draw.xstep = finetangent[DEG90 - 1 - angle_ray] or 0
            wl_draw.ystep = -(finetangent[angle_ray] or 0)
            xpar = wl_draw.xpartialup
            ypar = wl_draw.ypartialdown
        elseif angle_ray < DEG180 then
            wl_draw.xtilestep = -1
            wl_draw.ytilestep = -1
            wl_draw.xstep = -(finetangent[angle_ray - DEG90] or 0)
            wl_draw.ystep = -(finetangent[DEG180 - 1 - angle_ray] or 0)
            xpar = wl_draw.xpartialdown
            ypar = wl_draw.ypartialdown
        elseif angle_ray < DEG270 then
            wl_draw.xtilestep = -1
            wl_draw.ytilestep = 1
            wl_draw.xstep = -(finetangent[DEG270 - 1 - angle_ray] or 0)
            wl_draw.ystep = finetangent[angle_ray - DEG180] or 0
            xpar = wl_draw.xpartialdown
            ypar = wl_draw.ypartialup
        elseif angle_ray < DEG360 then
            wl_draw.xtilestep = 1
            wl_draw.ytilestep = 1
            wl_draw.xstep = finetangent[angle_ray - DEG270] or 0
            wl_draw.ystep = finetangent[DEG360 - 1 - angle_ray] or 0
            xpar = wl_draw.xpartialup
            ypar = wl_draw.ypartialup
        else
            -- Wrap around
            angle_ray = angle_ray - wl_def.FINEANGLES
            wl_draw.xtilestep = 1
            wl_draw.ytilestep = -1
            wl_draw.xstep = finetangent[DEG90 - 1 - angle_ray] or 0
            wl_draw.ystep = -(finetangent[angle_ray] or 0)
            xpar = wl_draw.xpartialup
            ypar = wl_draw.ypartialdown
        end

        -- Initialize intercepts
        wl_draw.yintercept = wl_main.viewy + xpartialbyystep(xpar)
        local xt = wl_draw.focaltx + wl_draw.xtilestep
        wl_draw.xtile = xt
        local yint_hi = math.floor(wl_draw.yintercept / 65536)

        wl_draw.xintercept = wl_main.viewx + ypartialbyxstep(ypar)
        local yt = wl_draw.focalty + wl_draw.ytilestep
        local xint_hi = math.floor(wl_draw.xintercept / 65536)

        -- Trace ray
        local hit = false
        local MAX_TRACE = 256
        local trace_count = 0

        while not hit and trace_count < MAX_TRACE do
            trace_count = trace_count + 1
            local do_vert

            -- Determine which wall face the ray reaches first
            if wl_draw.ytilestep == -1 then
                do_vert = (yint_hi > yt)
            else
                do_vert = (yint_hi < yt)
            end

            if do_vert then
                -- Check vertical wall
                if xt >= 0 and xt < wl_def.MAPSIZE and yint_hi >= 0 and yint_hi < wl_def.MAPSIZE then
                    local tile = tilemap[xt][yint_hi]
                    if tile ~= 0 then
                        wl_draw.tilehit = tile
                        if band(tile, 0x80) ~= 0 then
                            if band(tile, 0x40) ~= 0 then
                                -- Pushable wall
                                local partial = math.floor(wl_draw.ystep * wl_game.pwallpos / 64)
                                local newy = wl_draw.yintercept + partial
                                local newhi = math.floor(newy / 65536)
                                if newhi == yint_hi then
                                    wl_draw.yintercept = newy
                                    wl_draw.xintercept = xt * 65536
                                    wl_draw.HitVertPWall()
                                    hit = true
                                end
                            else
                                -- Vertical door
                                local doornum_local = band(tile, 0x7f)
                                local halfstep = math.floor(wl_draw.ystep / 2)
                                local newy = wl_draw.yintercept + halfstep
                                local newhi = math.floor(newy / 65536)
                                if newhi == math.floor(wl_draw.yintercept / 65536) then
                                    local newy_frac = band(newy, 0xFFFF)
                                    if newy_frac < 0 then newy_frac = newy_frac + 65536 end
                                    if newy_frac >= (wl_game.doorposition[doornum_local] or 0) then
                                        wl_draw.yintercept = newy
                                        wl_draw.xintercept = bor(xt * 65536, 0x8000)
                                        wl_draw.HitVertDoor()
                                        hit = true
                                    end
                                end
                            end
                        else
                            -- Solid wall
                            wl_draw.xintercept = xt * 65536
                            wl_draw.xtile = xt
                            wl_draw.yintercept = bor(band(wl_draw.yintercept, 0xFFFF), yint_hi * 65536)
                            wl_draw.ytile = yint_hi
                            wl_draw.HitVertWall()
                            hit = true
                        end
                    end
                end

                if not hit then
                    -- Mark visible and advance
                    if xt >= 0 and xt < wl_def.MAPSIZE and yint_hi >= 0 and yint_hi < wl_def.MAPSIZE then
                        spotvis[xt][yint_hi] = 1
                    end
                    xt = xt + wl_draw.xtilestep
                    wl_draw.yintercept = wl_draw.yintercept + wl_draw.ystep
                    yint_hi = math.floor(wl_draw.yintercept / 65536)
                end
            else
                -- Check horizontal wall
                local do_horiz
                if wl_draw.xtilestep == -1 then
                    do_horiz = (xint_hi > xt)
                else
                    do_horiz = (xint_hi < xt)
                end

                if do_horiz then
                    if xint_hi >= 0 and xint_hi < wl_def.MAPSIZE and yt >= 0 and yt < wl_def.MAPSIZE then
                        local tile = tilemap[xint_hi][yt]
                        if tile ~= 0 then
                            wl_draw.tilehit = tile
                            if band(tile, 0x80) ~= 0 then
                                if band(tile, 0x40) ~= 0 then
                                    -- Pushable wall
                                    local partial = math.floor(wl_draw.xstep * wl_game.pwallpos / 64)
                                    local newx = wl_draw.xintercept + partial
                                    local newhi = math.floor(newx / 65536)
                                    if newhi == xint_hi then
                                        wl_draw.xintercept = newx
                                        wl_draw.yintercept = yt * 65536
                                        wl_draw.HitHorizPWall()
                                        hit = true
                                    end
                                else
                                    -- Horizontal door
                                    local doornum_local = band(tile, 0x7f)
                                    local halfstep = math.floor(wl_draw.xstep / 2)
                                    local newx = wl_draw.xintercept + halfstep
                                    local newhi = math.floor(newx / 65536)
                                    if newhi == xint_hi then
                                        local newx_frac = band(newx, 0xFFFF)
                                        if newx_frac < 0 then newx_frac = newx_frac + 65536 end
                                        if newx_frac >= (wl_game.doorposition[doornum_local] or 0) then
                                            wl_draw.xintercept = newx
                                            wl_draw.yintercept = bor(yt * 65536, 0x8000)
                                            wl_draw.HitHorizDoor()
                                            hit = true
                                        end
                                    end
                                end
                            else
                                -- Solid wall
                                wl_draw.xintercept = bor(band(wl_draw.xintercept, 0xFFFF), xint_hi * 65536)
                                wl_draw.xtile = xint_hi
                                wl_draw.yintercept = yt * 65536
                                wl_draw.ytile = yt
                                wl_draw.HitHorizWall()
                                hit = true
                            end
                        end
                    end

                    if not hit then
                        if xint_hi >= 0 and xint_hi < wl_def.MAPSIZE and yt >= 0 and yt < wl_def.MAPSIZE then
                            spotvis[xint_hi][yt] = 1
                        end
                        yt = yt + wl_draw.ytilestep
                        wl_draw.xintercept = wl_draw.xintercept + wl_draw.xstep
                        xint_hi = math.floor(wl_draw.xintercept / 65536)
                    end
                else
                    -- Tiebreak: both at same boundary, check vertical first
                    if xt >= 0 and xt < wl_def.MAPSIZE and yint_hi >= 0 and yint_hi < wl_def.MAPSIZE then
                        local tile = tilemap[xt][yint_hi]
                        if tile ~= 0 then
                            wl_draw.tilehit = tile
                            if band(tile, 0x80) == 0 then
                                wl_draw.xintercept = xt * 65536
                                wl_draw.xtile = xt
                                wl_draw.yintercept = bor(band(wl_draw.yintercept, 0xFFFF), yint_hi * 65536)
                                wl_draw.ytile = yint_hi
                                wl_draw.HitVertWall()
                                hit = true
                            end
                        end
                    end

                    if not hit then
                        if xt >= 0 and xt < wl_def.MAPSIZE and yint_hi >= 0 and yint_hi < wl_def.MAPSIZE then
                            spotvis[xt][yint_hi] = 1
                        end
                        xt = xt + wl_draw.xtilestep
                        wl_draw.yintercept = wl_draw.yintercept + wl_draw.ystep
                        yint_hi = math.floor(wl_draw.yintercept / 65536)
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- CalcRotate
---------------------------------------------------------------------------

function wl_draw.CalcRotate(ob)
    local wl_play = require("wl_play")
    local wl_main = require("wl_main")

    local viewangle_local = wl_play.player.angle + math.floor((wl_main.centerx - ob.viewx) / 8)

    local angle
    if ob.obclass == wl_def.rocketobj or ob.obclass == wl_def.hrocketobj then
        angle = (viewangle_local - 180) - ob.angle
    else
        angle = (viewangle_local - 180) - (wl_main.dirangle[ob.dir + 1] or 0)
    end

    angle = angle + math.floor(wl_def.ANGLES / 16)
    while angle >= wl_def.ANGLES do angle = angle - wl_def.ANGLES end
    while angle < 0 do angle = angle + wl_def.ANGLES end

    if ob.state and ob.state.rotate == 2 then
        return 4 * math.floor(angle / math.floor(wl_def.ANGLES / 2))
    end

    return math.floor(angle / math.floor(wl_def.ANGLES / 8))
end

---------------------------------------------------------------------------
-- DrawScaleds - Draw all visible scaled sprites
---------------------------------------------------------------------------

function wl_draw.DrawScaleds()
    local wl_play  = require("wl_play")
    local wl_main  = require("wl_main")
    local wl_scale = require("wl_scale")
    local wl_agent = require("wl_agent")

    local vislist = {}
    local viscount = 0

    -- Place static objects
    local statobjlist = wl_play.statobjlist
    local laststatobj_idx = wl_play.laststatobj_idx or #statobjlist

    for i = 1, laststatobj_idx do
        local statptr = statobjlist[i]
        if statptr and statptr.shapenum ~= -1 then
            -- Check visibility via spotvis
            if statptr.tilex >= 0 and statptr.tilex < wl_def.MAPSIZE and
               statptr.tiley >= 0 and statptr.tiley < wl_def.MAPSIZE and
               wl_main.spotvis[statptr.tilex][statptr.tiley] ~= 0 then

                local grabbed, dispx, dispheight = wl_draw.TransformTile(statptr.tilex, statptr.tiley)

                if grabbed and band(statptr.flags, wl_def.FL_BONUS) ~= 0 then
                    wl_agent.GetBonus(statptr)
                else
                    if dispheight and dispheight > 0 then
                        viscount = viscount + 1
                        vislist[viscount] = {
                            viewx = dispx,
                            viewheight = dispheight,
                            shapenum = statptr.shapenum,
                        }
                    end
                end
            end
        end
    end

    -- Place active objects
    local obj = wl_play.player and wl_play.player.next or nil
    while obj do
        if obj.state and obj.state.shapenum and obj.state.shapenum ~= 0 then
            local shapenum = obj.state.shapenum

            -- Check 9 surrounding tiles for visibility
            local tx = obj.tilex
            local ty = obj.tiley
            local visible = false
            for dx = -1, 1 do
                for dy = -1, 1 do
                    local cx = tx + dx
                    local cy = ty + dy
                    if cx >= 0 and cx < wl_def.MAPSIZE and cy >= 0 and cy < wl_def.MAPSIZE then
                        if wl_main.spotvis[cx][cy] ~= 0 and (dx == 0 and dy == 0 or wl_main.tilemap[cx][cy] == 0) then
                            visible = true
                        end
                    end
                end
            end

            if visible then
                obj.active = wl_def.ac_yes
                wl_draw.TransformActor(obj)
                if obj.viewheight and obj.viewheight > 0 then
                    local vis_shape = shapenum
                    if vis_shape == -1 then
                        vis_shape = obj.temp1
                    end
                    if obj.state.rotate and obj.state.rotate ~= 0 then
                        vis_shape = vis_shape + wl_draw.CalcRotate(obj)
                    end
                    viscount = viscount + 1
                    vislist[viscount] = {
                        viewx = obj.viewx,
                        viewheight = obj.viewheight,
                        shapenum = vis_shape,
                    }
                    obj.flags = bor(obj.flags, wl_def.FL_VISABLE)
                end
            else
                obj.flags = band(obj.flags, bxor(wl_def.FL_VISABLE, 0xFF))
            end
        end
        obj = obj.next
    end

    if viscount == 0 then return end

    -- Sort back to front (draw farthest first)
    for i = 1, viscount do
        local least = 32000
        local farthest_idx = 1
        for j = 1, viscount do
            if vislist[j].viewheight < least then
                least = vislist[j].viewheight
                farthest_idx = j
            end
        end

        -- Draw farthest
        local v = vislist[farthest_idx]
        wl_scale.ScaleShape(v.viewx, v.shapenum, v.viewheight)
        vislist[farthest_idx].viewheight = 32000
    end
end

---------------------------------------------------------------------------
-- DrawPlayerWeapon
---------------------------------------------------------------------------

function wl_draw.DrawPlayerWeapon()
    local wl_main  = require("wl_main")
    local wl_play  = require("wl_play")
    local wl_scale = require("wl_scale")
    local id_sd    = require("id_sd")

    if not wl_draw.weaponscale then
        wl_draw.weaponscale = {
            [wl_def.wp_knife]      = wl_def.SPR_KNIFEREADY,
            [wl_def.wp_pistol]     = wl_def.SPR_PISTOLREADY,
            [wl_def.wp_machinegun] = wl_def.SPR_MACHINEGUNREADY,
            [wl_def.wp_chaingun]   = wl_def.SPR_CHAINREADY,
        }
    end

    if wl_main.gamestate.victoryflag then
        return
    end

    if wl_main.gamestate.weapon and wl_main.gamestate.weapon ~= -1 then
        local shapenum = (wl_draw.weaponscale[wl_main.gamestate.weapon] or wl_def.SPR_PISTOLREADY) + wl_main.gamestate.weaponframe
        wl_scale.SimpleScaleShape(math.floor(wl_main.viewwidth / 2), shapenum, wl_main.viewheight + 1)
    end

    if wl_play.demorecord or wl_play.demoplayback then
        wl_scale.SimpleScaleShape(math.floor(wl_main.viewwidth / 2), wl_def.SPR_DEMO, wl_main.viewheight + 1)
    end
end

---------------------------------------------------------------------------
-- CalcTics
---------------------------------------------------------------------------

function wl_draw.CalcTics()
    local wl_main = require("wl_main")
    local id_sd = require("id_sd")

    if wl_main.lasttimecount > id_sd.TimeCount then
        id_sd.TimeCount = wl_main.lasttimecount
    end

    local newtime = id_sd.TimeCount
    wl_main.tics = newtime - wl_main.lasttimecount

    if wl_main.tics < 1 then
        wl_main.tics = 1
    end

    wl_main.lasttimecount = newtime

    if wl_main.tics > wl_def.MAXTICS then
        id_sd.TimeCount = id_sd.TimeCount - (wl_main.tics - wl_def.MAXTICS)
        wl_main.tics = wl_def.MAXTICS
    end
end

---------------------------------------------------------------------------
-- VGAClearScreen
---------------------------------------------------------------------------

function wl_draw.VGAClearScreen()
    local wl_main = require("wl_main")

    local map_idx = wl_main.gamestate.episode * 10 + wl_main.gamestate.mapon
    local ceilcolor = wl_draw.vgaCeiling[map_idx + 1] or 0x1d
    local floorcolor = 0x19

    local screenofs = wl_main.screenofs
    local yofs = math.floor(screenofs / wl_def.SCREENWIDTH)
    local xofs = (screenofs % wl_def.SCREENWIDTH) * 4
    local viewh = wl_main.viewheight
    local vieww = wl_main.viewwidth

    for y = 0, math.floor(viewh / 2) - 1 do
        local screeny = y + yofs
        if screeny >= 0 and screeny < 200 then
            for x = 0, vieww - 1 do
                local screenx = x + xofs
                if screenx >= 0 and screenx < 320 then
                    id_vl.screenbuf[screeny * 320 + screenx] = ceilcolor
                end
            end
        end
    end

    for y = math.floor(viewh / 2), viewh - 1 do
        local screeny = y + yofs
        if screeny >= 0 and screeny < 200 then
            for x = 0, vieww - 1 do
                local screenx = x + xofs
                if screenx >= 0 and screenx < 320 then
                    id_vl.screenbuf[screeny * 320 + screenx] = floorcolor
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- ClearScreen
---------------------------------------------------------------------------

function wl_draw.ClearScreen()
    wl_draw.VGAClearScreen()
end

---------------------------------------------------------------------------
-- WallRefresh
---------------------------------------------------------------------------

function wl_draw.WallRefresh()
    local wl_main = require("wl_main")
    local wl_play = require("wl_play")

    local player = wl_play.player
    if not player then return end

    wl_main.viewangle = player.angle
    wl_draw.midangle = player.angle * math.floor(wl_def.FINEANGLES / wl_def.ANGLES)
    wl_main.viewsin = wl_main.sintable[player.angle] or 0
    wl_main.viewcos = wl_main.costable[player.angle] or 0
    wl_main.viewx = player.x - wl_draw.FixedByFrac(wl_main.focallength, wl_main.viewcos)
    wl_main.viewy = player.y + wl_draw.FixedByFrac(wl_main.focallength, wl_main.viewsin)

    wl_draw.focaltx = rshift(wl_main.viewx, wl_def.TILESHIFT)
    wl_draw.focalty = rshift(wl_main.viewy, wl_def.TILESHIFT)

    wl_draw.viewtx = rshift(player.x, wl_def.TILESHIFT)
    wl_draw.viewty = rshift(player.y, wl_def.TILESHIFT)

    wl_draw.xpartialdown = band(wl_main.viewx, wl_def.TILEGLOBAL - 1)
    wl_draw.xpartialup = wl_def.TILEGLOBAL - wl_draw.xpartialdown
    wl_draw.ypartialdown = band(wl_main.viewy, wl_def.TILEGLOBAL - 1)
    wl_draw.ypartialup = wl_def.TILEGLOBAL - wl_draw.ypartialdown

    wl_draw.lastside = -1
    wl_draw.AsmRefresh()
    wl_draw.ScalePost()  -- flush last post
end

---------------------------------------------------------------------------
-- ThreeDRefresh
---------------------------------------------------------------------------

function wl_draw.ThreeDRefresh()
    local wl_main = require("wl_main")

    -- Update DOORWALL from PM
    DOORWALL = id_pm.PMSpriteStart - 8

    -- Clear spotvis
    for x = 0, wl_def.MAPSIZE - 1 do
        for y = 0, wl_def.MAPSIZE - 1 do
            wl_main.spotvis[x][y] = 0
        end
    end

    id_vl.bufferofs = id_vl.bufferofs + wl_main.screenofs

    wl_draw.VGAClearScreen()
    wl_draw.WallRefresh()
    wl_draw.DrawScaleds()
    wl_draw.DrawPlayerWeapon()

    if wl_main.fizzlein then
        wl_main.fizzlein = false
        wl_main.lasttimecount = 0
        local id_sd = require("id_sd")
        id_sd.TimeCount = 0
    end

    id_vl.bufferofs = id_vl.bufferofs - wl_main.screenofs
    id_vl.displayofs = id_vl.bufferofs

    id_vl.VL_UpdateScreen()

    wl_main.frameon = wl_main.frameon + 1
end

---------------------------------------------------------------------------
-- FixOfs
---------------------------------------------------------------------------

function wl_draw.FixOfs()
    id_vl.bufferofs = wl_def.PAGE1START
    id_vl.displayofs = wl_def.PAGE1START
end

return wl_draw
