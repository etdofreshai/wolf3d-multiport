-- WL_PLAY.lua
-- Play loop - ported from WL_PLAY.C
-- Handles the main gameplay loop, controls, actors

local wl_def = require("wl_def")
local id_in  = require("id_in")
local id_sd  = require("id_sd")

local wl_play = {}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
wl_play.playstate   = wl_def.ex_stillplaying
wl_play.madenoise   = false

-- Actor lists
wl_play.objlist     = {}  -- [1..MAXACTORS]
wl_play.new_obj     = nil
wl_play.obj         = nil
wl_play.player      = nil
wl_play.lastobj     = nil
wl_play.objfreelist = nil
wl_play.killerobj   = nil

-- Static objects
wl_play.statobjlist = {}
wl_play.laststatobj = nil

-- Control state
wl_play.controlx    = 0
wl_play.controly    = 0
wl_play.buttonstate = {}
wl_play.buttonheld  = {}

wl_play.singlestep  = false
wl_play.godmode     = false
wl_play.noclip      = false
wl_play.extravbls   = 0

wl_play.demorecord  = false
wl_play.demoplayback = false
wl_play.demoptr     = nil
wl_play.lastdemoptr = nil
wl_play.demobuffer  = nil

for i = 0, wl_def.NUMBUTTONS - 1 do
    wl_play.buttonstate[i] = false
    wl_play.buttonheld[i] = false
end

-- Initialize actor list
for i = 1, wl_def.MAXACTORS do
    wl_play.objlist[i] = wl_def.new_objtype()
end

-- Initialize static object list
for i = 1, wl_def.MAXSTATS do
    wl_play.statobjlist[i] = wl_def.new_statobj()
end

---------------------------------------------------------------------------
-- InitActorList
---------------------------------------------------------------------------

function wl_play.InitActorList()
    -- Reset all actors
    for i = 1, wl_def.MAXACTORS do
        wl_play.objlist[i] = wl_def.new_objtype()
    end

    -- Player is always actor 1
    wl_play.player = wl_play.objlist[1]
    wl_play.player.active = wl_def.ac_yes
    wl_play.player.obclass = wl_def.playerobj

    wl_play.lastobj = wl_play.player
    wl_play.objfreelist = nil

    -- Build free list from actors 2..MAXACTORS
    for i = 2, wl_def.MAXACTORS do
        wl_play.objlist[i].next = wl_play.objfreelist
        wl_play.objfreelist = wl_play.objlist[i]
    end
end

---------------------------------------------------------------------------
-- GetNewActor
---------------------------------------------------------------------------

function wl_play.GetNewActor()
    if not wl_play.objfreelist then
        print("GetNewActor: no free actors!")
        return nil
    end

    wl_play.new_obj = wl_play.objfreelist
    wl_play.objfreelist = wl_play.new_obj.next

    -- Reset the actor
    local saved_next = wl_play.new_obj.next
    for k, v in pairs(wl_def.new_objtype()) do
        wl_play.new_obj[k] = v
    end

    -- Link into active list
    if wl_play.lastobj then
        wl_play.lastobj.next = wl_play.new_obj
    end
    wl_play.new_obj.prev = wl_play.lastobj
    wl_play.new_obj.next = nil
    wl_play.lastobj = wl_play.new_obj

    return wl_play.new_obj
end

---------------------------------------------------------------------------
-- RemoveObj
---------------------------------------------------------------------------

function wl_play.RemoveObj(gone)
    if gone == wl_play.player then
        print("RemoveObj: tried to remove player!")
        return
    end

    -- Unlink from active list
    if gone.prev then
        gone.prev.next = gone.next
    end
    if gone.next then
        gone.next.prev = gone.prev
    end
    if gone == wl_play.lastobj then
        wl_play.lastobj = gone.prev
    end

    -- Add to free list
    gone.next = wl_play.objfreelist
    wl_play.objfreelist = gone
end

---------------------------------------------------------------------------
-- PollControls (stub)
---------------------------------------------------------------------------

function wl_play.PollControls()
    local wl_main = require("wl_main")

    wl_play.controlx = 0
    wl_play.controly = 0

    -- Read keyboard
    local info = id_in.IN_ReadControl(1)

    if info.button0 then wl_play.buttonstate[wl_def.bt_attack] = true end
    if info.button1 then wl_play.buttonstate[wl_def.bt_strafe] = true end

    -- Movement from keyboard
    if info.xaxis ~= 0 then
        wl_play.controlx = wl_play.controlx + info.xaxis * 100
    end
    if info.yaxis ~= 0 then
        wl_play.controly = wl_play.controly + info.yaxis * 100
    end
end

---------------------------------------------------------------------------
-- PlayLoop (stub)
---------------------------------------------------------------------------

function wl_play.PlayLoop()
    -- This is the main gameplay tick
    -- Would process all actors, player movement, rendering, etc.
end

---------------------------------------------------------------------------
-- Palette effects (stubs)
---------------------------------------------------------------------------

function wl_play.InitRedShifts()
    -- Would precompute red-shifted palettes for damage flash
end

function wl_play.FinishPaletteShifts()
    -- Restore normal palette
end

function wl_play.StartDamageFlash(damage)
    -- Start red flash effect
end

function wl_play.StartBonusFlash()
    -- Start yellow bonus flash
end

function wl_play.CenterWindow(w, h)
    id_us = require("id_us")
    id_us.US_CenterWindow(w, h)
end

function wl_play.StopMusic()
    id_sd.SD_MusicOff()
end

function wl_play.StartMusic()
    -- Would start level-appropriate music
end

return wl_play
