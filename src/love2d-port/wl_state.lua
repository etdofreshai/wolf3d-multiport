-- WL_STATE.lua
-- Actor state machine - ported from WL_STATE.C
-- Handles movement, AI decisions, collision, line of sight

local bit = require("bit")
local band, bor, bxor, lshift, rshift = bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift

local wl_def = require("wl_def")
local id_us  = require("id_us")

local wl_state = {}

---------------------------------------------------------------------------
-- Direction tables
---------------------------------------------------------------------------
wl_state.opposite = {
    [wl_def.dir_east]      = wl_def.dir_west,
    [wl_def.dir_northeast] = wl_def.dir_southwest,
    [wl_def.dir_north]     = wl_def.dir_south,
    [wl_def.dir_northwest] = wl_def.dir_southeast,
    [wl_def.dir_west]      = wl_def.dir_east,
    [wl_def.dir_southwest] = wl_def.dir_northeast,
    [wl_def.dir_south]     = wl_def.dir_north,
    [wl_def.dir_southeast] = wl_def.dir_northwest,
    [wl_def.dir_nodir]     = wl_def.dir_nodir,
}

-- diagonal[dir1][dir2] -> combined diagonal direction
wl_state.diagonal = {}
for i = 0, 8 do
    wl_state.diagonal[i] = {}
    for j = 0, 8 do
        wl_state.diagonal[i][j] = wl_def.dir_nodir
    end
end
-- east + north = northeast, etc.
wl_state.diagonal[wl_def.dir_east][wl_def.dir_north] = wl_def.dir_northeast
wl_state.diagonal[wl_def.dir_east][wl_def.dir_south] = wl_def.dir_southeast
wl_state.diagonal[wl_def.dir_north][wl_def.dir_east] = wl_def.dir_northeast
wl_state.diagonal[wl_def.dir_north][wl_def.dir_west] = wl_def.dir_northwest
wl_state.diagonal[wl_def.dir_west][wl_def.dir_north] = wl_def.dir_northwest
wl_state.diagonal[wl_def.dir_west][wl_def.dir_south] = wl_def.dir_southwest
wl_state.diagonal[wl_def.dir_south][wl_def.dir_east] = wl_def.dir_southeast
wl_state.diagonal[wl_def.dir_south][wl_def.dir_west] = wl_def.dir_southwest

---------------------------------------------------------------------------
-- SpawnNewObj
---------------------------------------------------------------------------

function wl_state.SpawnNewObj(tilex, tiley, state)
    local wl_play = require("wl_play")
    local wl_main = require("wl_main")

    local obj = wl_play.GetNewActor()
    if not obj then return nil end

    obj.state = state
    if state and state.tictime and state.tictime > 0 then
        obj.ticcount = id_us.US_RndT() % state.tictime
    else
        obj.ticcount = 0
    end

    obj.tilex = tilex
    obj.tiley = tiley
    obj.x = lshift(tilex, wl_def.TILESHIFT) + math.floor(wl_def.TILEGLOBAL / 2)
    obj.y = lshift(tiley, wl_def.TILESHIFT) + math.floor(wl_def.TILEGLOBAL / 2)
    obj.dir = wl_def.dir_nodir

    wl_main.actorat[tilex][tiley] = obj

    -- Set area number from map
    local wl_game = require("wl_game")
    local id_ca = require("id_ca")
    if id_ca.mapsegs and id_ca.mapsegs[1] and wl_main.farmapylookup[tiley + 1] then
        local map_idx = wl_main.farmapylookup[tiley + 1] + tilex + 1
        local area_val = id_ca.mapsegs[1][map_idx]
        if area_val then
            obj.areanumber = area_val - wl_def.AREATILE
        end
    end

    return obj
end

---------------------------------------------------------------------------
-- NewState
---------------------------------------------------------------------------

function wl_state.NewState(ob, state)
    ob.state = state
    ob.ticcount = state and state.tictime or 0
end

---------------------------------------------------------------------------
-- TryWalk
---------------------------------------------------------------------------

function wl_state.TryWalk(ob)
    local wl_main = require("wl_main")
    local wl_act1 = require("wl_act1")
    local id_ca   = require("id_ca")

    local doornum = -1

    local function CHECKDIAG(x, y)
        if x < 0 or x >= wl_def.MAPSIZE or y < 0 or y >= wl_def.MAPSIZE then return false end
        local temp = wl_main.actorat[x][y]
        if temp then
            if type(temp) == "number" then
                if temp < 256 then return false end
            else
                if band(temp.flags or 0, wl_def.FL_SHOOTABLE) ~= 0 then return false end
            end
        end
        return true
    end

    local function CHECKSIDE(x, y)
        if x < 0 or x >= wl_def.MAPSIZE or y < 0 or y >= wl_def.MAPSIZE then return false end
        local temp = wl_main.actorat[x][y]
        if temp then
            if type(temp) == "number" then
                if temp < 128 then return false end
                if temp < 256 then
                    doornum = band(temp, 63)
                end
            else
                if band(temp.flags or 0, wl_def.FL_SHOOTABLE) ~= 0 then return false end
            end
        end
        return true
    end

    if ob.obclass == wl_def.inertobj then
        -- Inert objects just move without collision checks
        if ob.dir == wl_def.dir_north then ob.tiley = ob.tiley - 1
        elseif ob.dir == wl_def.dir_northeast then ob.tilex = ob.tilex + 1; ob.tiley = ob.tiley - 1
        elseif ob.dir == wl_def.dir_east then ob.tilex = ob.tilex + 1
        elseif ob.dir == wl_def.dir_southeast then ob.tilex = ob.tilex + 1; ob.tiley = ob.tiley + 1
        elseif ob.dir == wl_def.dir_south then ob.tiley = ob.tiley + 1
        elseif ob.dir == wl_def.dir_southwest then ob.tilex = ob.tilex - 1; ob.tiley = ob.tiley + 1
        elseif ob.dir == wl_def.dir_west then ob.tilex = ob.tilex - 1
        elseif ob.dir == wl_def.dir_northwest then ob.tilex = ob.tilex - 1; ob.tiley = ob.tiley - 1
        end
    else
        local is_dog_or_fake = (ob.obclass == wl_def.dogobj or ob.obclass == wl_def.fakeobj)

        if ob.dir == wl_def.dir_north then
            if is_dog_or_fake then
                if not CHECKDIAG(ob.tilex, ob.tiley - 1) then return false end
            else
                if not CHECKSIDE(ob.tilex, ob.tiley - 1) then return false end
            end
            ob.tiley = ob.tiley - 1
        elseif ob.dir == wl_def.dir_northeast then
            if not CHECKDIAG(ob.tilex + 1, ob.tiley - 1) then return false end
            if not CHECKDIAG(ob.tilex + 1, ob.tiley) then return false end
            if not CHECKDIAG(ob.tilex, ob.tiley - 1) then return false end
            ob.tilex = ob.tilex + 1
            ob.tiley = ob.tiley - 1
        elseif ob.dir == wl_def.dir_east then
            if is_dog_or_fake then
                if not CHECKDIAG(ob.tilex + 1, ob.tiley) then return false end
            else
                if not CHECKSIDE(ob.tilex + 1, ob.tiley) then return false end
            end
            ob.tilex = ob.tilex + 1
        elseif ob.dir == wl_def.dir_southeast then
            if not CHECKDIAG(ob.tilex + 1, ob.tiley + 1) then return false end
            if not CHECKDIAG(ob.tilex + 1, ob.tiley) then return false end
            if not CHECKDIAG(ob.tilex, ob.tiley + 1) then return false end
            ob.tilex = ob.tilex + 1
            ob.tiley = ob.tiley + 1
        elseif ob.dir == wl_def.dir_south then
            if is_dog_or_fake then
                if not CHECKDIAG(ob.tilex, ob.tiley + 1) then return false end
            else
                if not CHECKSIDE(ob.tilex, ob.tiley + 1) then return false end
            end
            ob.tiley = ob.tiley + 1
        elseif ob.dir == wl_def.dir_southwest then
            if not CHECKDIAG(ob.tilex - 1, ob.tiley + 1) then return false end
            if not CHECKDIAG(ob.tilex - 1, ob.tiley) then return false end
            if not CHECKDIAG(ob.tilex, ob.tiley + 1) then return false end
            ob.tilex = ob.tilex - 1
            ob.tiley = ob.tiley + 1
        elseif ob.dir == wl_def.dir_west then
            if is_dog_or_fake then
                if not CHECKDIAG(ob.tilex - 1, ob.tiley) then return false end
            else
                if not CHECKSIDE(ob.tilex - 1, ob.tiley) then return false end
            end
            ob.tilex = ob.tilex - 1
        elseif ob.dir == wl_def.dir_northwest then
            if not CHECKDIAG(ob.tilex - 1, ob.tiley - 1) then return false end
            if not CHECKDIAG(ob.tilex - 1, ob.tiley) then return false end
            if not CHECKDIAG(ob.tilex, ob.tiley - 1) then return false end
            ob.tilex = ob.tilex - 1
            ob.tiley = ob.tiley - 1
        elseif ob.dir == wl_def.dir_nodir then
            return false
        end
    end

    if doornum ~= -1 then
        wl_act1.OpenDoor(doornum)
        ob.distance = -doornum - 1
        return true
    end

    -- Set area number
    if id_ca.mapsegs and id_ca.mapsegs[1] and wl_main.farmapylookup[ob.tiley + 1] then
        local map_idx = wl_main.farmapylookup[ob.tiley + 1] + ob.tilex + 1
        local area_val = id_ca.mapsegs[1][map_idx]
        if area_val then
            ob.areanumber = area_val - wl_def.AREATILE
        end
    end

    ob.distance = wl_def.TILEGLOBAL
    return true
end

---------------------------------------------------------------------------
-- SelectDodgeDir
---------------------------------------------------------------------------

function wl_state.SelectDodgeDir(ob)
    local wl_play = require("wl_play")

    local turnaround
    if band(ob.flags, wl_def.FL_FIRSTATTACK) ~= 0 then
        turnaround = wl_def.dir_nodir
        ob.flags = band(ob.flags, bxor(wl_def.FL_FIRSTATTACK, 0xFF))
    else
        turnaround = wl_state.opposite[ob.dir] or wl_def.dir_nodir
    end

    local deltax = wl_play.player.tilex - ob.tilex
    local deltay = wl_play.player.tiley - ob.tiley

    local dirtry = {}

    if deltax > 0 then
        dirtry[2] = wl_def.dir_east
        dirtry[4] = wl_def.dir_west
    else
        dirtry[2] = wl_def.dir_west
        dirtry[4] = wl_def.dir_east
    end

    if deltay > 0 then
        dirtry[3] = wl_def.dir_south
        dirtry[5] = wl_def.dir_north
    else
        dirtry[3] = wl_def.dir_north
        dirtry[5] = wl_def.dir_south
    end

    -- Randomize for dodging
    if math.abs(deltax) > math.abs(deltay) then
        dirtry[2], dirtry[3] = dirtry[3], dirtry[2]
        dirtry[4], dirtry[5] = dirtry[5], dirtry[4]
    end

    if id_us.US_RndT() < 128 then
        dirtry[2], dirtry[3] = dirtry[3], dirtry[2]
        dirtry[4], dirtry[5] = dirtry[5], dirtry[4]
    end

    dirtry[1] = wl_state.diagonal[dirtry[2] or wl_def.dir_nodir][dirtry[3] or wl_def.dir_nodir] or wl_def.dir_nodir

    for i = 1, 5 do
        if dirtry[i] ~= wl_def.dir_nodir and dirtry[i] ~= turnaround then
            ob.dir = dirtry[i]
            if wl_state.TryWalk(ob) then return end
        end
    end

    if turnaround ~= wl_def.dir_nodir then
        ob.dir = turnaround
        if wl_state.TryWalk(ob) then return end
    end

    ob.dir = wl_def.dir_nodir
end

---------------------------------------------------------------------------
-- SelectChaseDir
---------------------------------------------------------------------------

function wl_state.SelectChaseDir(ob)
    local wl_play = require("wl_play")

    local olddir = ob.dir
    local turnaround = wl_state.opposite[olddir] or wl_def.dir_nodir

    local deltax = wl_play.player.tilex - ob.tilex
    local deltay = wl_play.player.tiley - ob.tiley

    local d = { [1] = wl_def.dir_nodir, [2] = wl_def.dir_nodir }

    if deltax > 0 then d[1] = wl_def.dir_east
    elseif deltax < 0 then d[1] = wl_def.dir_west end
    if deltay > 0 then d[2] = wl_def.dir_south
    elseif deltay < 0 then d[2] = wl_def.dir_north end

    if math.abs(deltay) > math.abs(deltax) then
        d[1], d[2] = d[2], d[1]
    end

    if d[1] == turnaround then d[1] = wl_def.dir_nodir end
    if d[2] == turnaround then d[2] = wl_def.dir_nodir end

    if d[1] ~= wl_def.dir_nodir then
        ob.dir = d[1]
        if wl_state.TryWalk(ob) then return end
    end

    if d[2] ~= wl_def.dir_nodir then
        ob.dir = d[2]
        if wl_state.TryWalk(ob) then return end
    end

    if olddir ~= wl_def.dir_nodir then
        ob.dir = olddir
        if wl_state.TryWalk(ob) then return end
    end

    if id_us.US_RndT() > 128 then
        for tdir = wl_def.dir_north, wl_def.dir_west do
            if tdir ~= turnaround then
                ob.dir = tdir
                if wl_state.TryWalk(ob) then return end
            end
        end
    else
        for tdir = wl_def.dir_west, wl_def.dir_north, -1 do
            if tdir ~= turnaround then
                ob.dir = tdir
                if wl_state.TryWalk(ob) then return end
            end
        end
    end

    if turnaround ~= wl_def.dir_nodir then
        ob.dir = turnaround
        if ob.dir ~= wl_def.dir_nodir then
            if wl_state.TryWalk(ob) then return end
        end
    end

    ob.dir = wl_def.dir_nodir
end

---------------------------------------------------------------------------
-- SelectRunDir - run away from player
---------------------------------------------------------------------------

function wl_state.SelectRunDir(ob)
    local wl_play = require("wl_play")

    local deltax = wl_play.player.tilex - ob.tilex
    local deltay = wl_play.player.tiley - ob.tiley

    local d = {}
    if deltax < 0 then d[1] = wl_def.dir_east else d[1] = wl_def.dir_west end
    if deltay < 0 then d[2] = wl_def.dir_south else d[2] = wl_def.dir_north end

    if math.abs(deltay) > math.abs(deltax) then
        d[1], d[2] = d[2], d[1]
    end

    ob.dir = d[1]
    if wl_state.TryWalk(ob) then return end

    ob.dir = d[2]
    if wl_state.TryWalk(ob) then return end

    if id_us.US_RndT() > 128 then
        for tdir = wl_def.dir_north, wl_def.dir_west do
            ob.dir = tdir
            if wl_state.TryWalk(ob) then return end
        end
    else
        for tdir = wl_def.dir_west, wl_def.dir_north, -1 do
            ob.dir = tdir
            if wl_state.TryWalk(ob) then return end
        end
    end

    ob.dir = wl_def.dir_nodir
end

---------------------------------------------------------------------------
-- MoveObj
---------------------------------------------------------------------------

function wl_state.MoveObj(ob, move)
    local wl_play = require("wl_play")
    local wl_game = require("wl_game")
    local wl_agent = require("wl_agent")

    if ob.dir == wl_def.dir_north then ob.y = ob.y - move
    elseif ob.dir == wl_def.dir_northeast then ob.x = ob.x + move; ob.y = ob.y - move
    elseif ob.dir == wl_def.dir_east then ob.x = ob.x + move
    elseif ob.dir == wl_def.dir_southeast then ob.x = ob.x + move; ob.y = ob.y + move
    elseif ob.dir == wl_def.dir_south then ob.y = ob.y + move
    elseif ob.dir == wl_def.dir_southwest then ob.x = ob.x - move; ob.y = ob.y + move
    elseif ob.dir == wl_def.dir_west then ob.x = ob.x - move
    elseif ob.dir == wl_def.dir_northwest then ob.x = ob.x - move; ob.y = ob.y - move
    elseif ob.dir == wl_def.dir_nodir then return
    end

    -- Check player collision
    if wl_game.areabyplayer[ob.areanumber] then
        local deltax = ob.x - wl_play.player.x
        if deltax > -wl_def.MINACTORDIST and deltax < wl_def.MINACTORDIST then
            local deltay = ob.y - wl_play.player.y
            if deltay > -wl_def.MINACTORDIST and deltay < wl_def.MINACTORDIST then
                -- Ghost/spectre damages player
                local wl_main = require("wl_main")
                if ob.obclass == wl_def.ghostobj or ob.obclass == wl_def.spectreobj then
                    wl_agent.TakeDamage(wl_main.tics * 2, ob)
                end

                -- Back up
                if ob.dir == wl_def.dir_north then ob.y = ob.y + move
                elseif ob.dir == wl_def.dir_northeast then ob.x = ob.x - move; ob.y = ob.y + move
                elseif ob.dir == wl_def.dir_east then ob.x = ob.x - move
                elseif ob.dir == wl_def.dir_southeast then ob.x = ob.x - move; ob.y = ob.y - move
                elseif ob.dir == wl_def.dir_south then ob.y = ob.y - move
                elseif ob.dir == wl_def.dir_southwest then ob.x = ob.x + move; ob.y = ob.y - move
                elseif ob.dir == wl_def.dir_west then ob.x = ob.x + move
                elseif ob.dir == wl_def.dir_northwest then ob.x = ob.x + move; ob.y = ob.y + move
                end
                return
            end
        end
    end

    ob.distance = ob.distance - move
end

---------------------------------------------------------------------------
-- CheckLine - check line of sight between ob and player
---------------------------------------------------------------------------

function wl_state.CheckLine(ob)
    local wl_play = require("wl_play")
    local wl_main = require("wl_main")

    local x1 = ob.tilex
    local y1 = ob.tiley
    local x2 = wl_play.player.tilex
    local y2 = wl_play.player.tiley

    local deltax = x2 - x1
    local deltay = y2 - y1

    local steps = math.max(math.abs(deltax), math.abs(deltay))
    if steps == 0 then return true end

    local xstep, ystep
    if deltax > 0 then xstep = 1
    elseif deltax < 0 then xstep = -1
    else xstep = 0 end
    if deltay > 0 then ystep = 1
    elseif deltay < 0 then ystep = -1
    else ystep = 0 end

    -- Bresenham-style LOS check
    local partial
    if math.abs(deltax) > math.abs(deltay) then
        -- X-major
        local err = math.abs(deltay) * 2 - math.abs(deltax)
        local cx, cy = x1, y1
        for i = 1, math.abs(deltax) do
            cx = cx + xstep
            if err >= 0 then
                cy = cy + ystep
                err = err - math.abs(deltax) * 2
            end
            err = err + math.abs(deltay) * 2

            if cx >= 0 and cx < wl_def.MAPSIZE and cy >= 0 and cy < wl_def.MAPSIZE then
                local tile = wl_main.tilemap[cx][cy]
                if tile ~= 0 then
                    if band(tile, 0x80) == 0 then return false end  -- solid wall
                    -- door: check if open enough
                end
            end
        end
    else
        -- Y-major
        local err = math.abs(deltax) * 2 - math.abs(deltay)
        local cx, cy = x1, y1
        for i = 1, math.abs(deltay) do
            cy = cy + ystep
            if err >= 0 then
                cx = cx + xstep
                err = err - math.abs(deltay) * 2
            end
            err = err + math.abs(deltax) * 2

            if cx >= 0 and cx < wl_def.MAPSIZE and cy >= 0 and cy < wl_def.MAPSIZE then
                local tile = wl_main.tilemap[cx][cy]
                if tile ~= 0 then
                    if band(tile, 0x80) == 0 then return false end
                end
            end
        end
    end

    return true
end

---------------------------------------------------------------------------
-- FirstSighting - called when enemy first spots player
---------------------------------------------------------------------------

function wl_state.FirstSighting(ob)
    local wl_play = require("wl_play")
    local id_sd   = require("id_sd")

    ob.flags = bor(ob.flags, bor(wl_def.FL_ATTACKMODE, wl_def.FL_FIRSTATTACK))

    -- Play alert sound based on enemy type
    -- (simplified - would normally play specific sounds per enemy)

    wl_state.SelectDodgeDir(ob)

    if ob.obclass == wl_def.guardobj then
        -- Switch to chase state would happen via state machine
    end

    ob.active = wl_def.ac_yes
end

---------------------------------------------------------------------------
-- SightPlayer - check if ob can see the player
---------------------------------------------------------------------------

function wl_state.SightPlayer(ob)
    local wl_play = require("wl_play")
    local wl_game = require("wl_game")

    if not wl_play.player then return false end

    -- Only check if in connected area
    if not wl_game.areabyplayer[ob.areanumber] then
        return false
    end

    -- Check if we have line of sight
    if wl_state.CheckLine(ob) then
        return true
    end

    return false
end

---------------------------------------------------------------------------
-- CheckSight - periodically called to check if enemy can see player
---------------------------------------------------------------------------

function wl_state.CheckSight(ob)
    local wl_play = require("wl_play")
    local wl_game = require("wl_game")

    if not wl_play.player then return false end

    -- Random delay on checking
    if id_us.US_RndT() > 128 then return false end

    if not wl_game.areabyplayer[ob.areanumber] then
        return false
    end

    if wl_state.CheckLine(ob) then
        return true
    end

    return false
end

---------------------------------------------------------------------------
-- KillActor
---------------------------------------------------------------------------

function wl_state.KillActor(ob)
    local wl_main = require("wl_main")
    local wl_play = require("wl_play")

    ob.hitpoints = 0
    ob.flags = band(ob.flags, bxor(bor(wl_def.FL_SHOOTABLE, wl_def.FL_ATTACKMODE), 0xFF))

    wl_main.actorat[ob.tilex][ob.tiley] = nil

    wl_main.gamestate.killcount = wl_main.gamestate.killcount + 1
end

---------------------------------------------------------------------------
-- DamageActor
---------------------------------------------------------------------------

function wl_state.DamageActor(ob, damage)
    ob.hitpoints = ob.hitpoints - damage
    if ob.hitpoints <= 0 then
        wl_state.KillActor(ob)
    else
        -- React to damage
        if band(ob.flags, wl_def.FL_ATTACKMODE) == 0 then
            wl_state.FirstSighting(ob)
        end
    end
end

return wl_state
