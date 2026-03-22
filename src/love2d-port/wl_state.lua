-- WL_STATE.lua
-- Actor state machine - ported from WL_STATE.C
-- Handles movement, AI decisions, collision, line of sight

local wl_def = require("wl_def")

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

---------------------------------------------------------------------------
-- InitHitRect
---------------------------------------------------------------------------

function wl_state.InitHitRect(ob, radius)
    -- Set up the hit rectangle for an object
    -- In the original this set up areamin/areamax for collision
end

---------------------------------------------------------------------------
-- SpawnNewObj
---------------------------------------------------------------------------

function wl_state.SpawnNewObj(tilex, tiley, state)
    local wl_play = require("wl_play")

    local obj = wl_play.GetNewActor()
    if not obj then return end

    obj.tilex = tilex
    obj.tiley = tiley
    obj.x = (tilex * 65536) + 32768  -- Center of tile
    obj.y = (tiley * 65536) + 32768
    obj.state = state
    obj.ticcount = state and state.tictime or 0

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
-- Movement and AI (stubs)
---------------------------------------------------------------------------

function wl_state.TryWalk(ob)
    return true
end

function wl_state.SelectChaseDir(ob)
end

function wl_state.SelectDodgeDir(ob)
end

function wl_state.SelectRunDir(ob)
end

function wl_state.MoveObj(ob, move)
    -- Move object along its direction
end

function wl_state.SightPlayer(ob)
    return false
end

function wl_state.KillActor(ob)
    ob.hitpoints = 0
end

function wl_state.DamageActor(ob, damage)
    ob.hitpoints = ob.hitpoints - damage
    if ob.hitpoints <= 0 then
        wl_state.KillActor(ob)
    end
end

function wl_state.CheckLine(ob)
    return true
end

function wl_state.CheckSight(ob)
    return false
end

return wl_state
