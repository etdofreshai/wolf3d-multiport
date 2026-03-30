-- WL_PLAY.lua
-- Play loop - ported from WL_PLAY.C
-- Handles the main gameplay loop, controls, actors

local bit = require("bit")
local band, bor, bxor, lshift, rshift = bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift

local wl_def = require("wl_def")
local id_in  = require("id_in")
local id_sd  = require("id_sd")
local id_vl  = require("id_vl")
local id_vh  = require("id_vh")
local audiowl6 = require("audiowl6")
local gfx    = require("gfxv_wl6")

local wl_play = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------
local BASEMOVE = 35
local RUNMOVE  = 70
local BASETURN = 35
local RUNTURN  = 70

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
wl_play.playstate    = wl_def.ex_stillplaying
wl_play.madenoise    = false

-- Actor lists
wl_play.objlist      = {}  -- [1..MAXACTORS]
wl_play.new_obj      = nil
wl_play.obj          = nil
wl_play.player       = nil
wl_play.lastobj      = nil
wl_play.objfreelist  = nil
wl_play.killerobj    = nil

-- Static objects
wl_play.statobjlist  = {}
wl_play.laststatobj_idx = 0

-- Control state
wl_play.controlx     = 0
wl_play.controly     = 0
wl_play.buttonstate  = {}
wl_play.buttonheld   = {}

wl_play.singlestep   = false
wl_play.godmode       = false
wl_play.noclip        = false
wl_play.extravbls     = 0

wl_play.demorecord    = false
wl_play.demoplayback  = false
wl_play.demoptr       = nil
wl_play.lastdemoptr   = nil
wl_play.demobuffer    = nil

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
-- Palette shift state (for damage/bonus flashes)
---------------------------------------------------------------------------
local damagecount = 0
local bonuscount  = 0
local palshifted  = false
wl_play.palshifted_red   = 0
wl_play.palshifted_white = 0

-- Red shifts for damage flash (6 levels from original)
local NUMREDSHIFTS = 6
local REDSTEPS     = 8

-- White shift for bonus flash
local NUMWHITESHIFTS = 3
local WHITESTEPS     = 20

---------------------------------------------------------------------------
-- InitActorList
---------------------------------------------------------------------------

function wl_play.InitActorList()
    for i = 1, wl_def.MAXACTORS do
        wl_play.objlist[i] = wl_def.new_objtype()
    end

    -- Build free list
    for i = 2, wl_def.MAXACTORS do
        wl_play.objlist[i].prev = (i < wl_def.MAXACTORS) and wl_play.objlist[i + 1] or nil
    end
    wl_play.objfreelist = wl_play.objlist[2]

    -- Allocate player as first actor
    wl_play.GetNewActor()
    wl_play.player = wl_play.new_obj
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
    wl_play.objfreelist = wl_play.new_obj.prev

    -- Reset the actor
    local fresh = wl_def.new_objtype()
    for k, v in pairs(fresh) do
        wl_play.new_obj[k] = v
    end

    -- Link into active list
    if wl_play.lastobj then
        wl_play.lastobj.next = wl_play.new_obj
    end
    wl_play.new_obj.prev = wl_play.lastobj
    wl_play.new_obj.next = nil
    wl_play.new_obj.active = wl_def.ac_no
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

    gone.state = nil

    if gone == wl_play.lastobj then
        wl_play.lastobj = gone.prev
    else
        if gone.next then gone.next.prev = gone.prev end
    end

    if gone.prev then
        gone.prev.next = gone.next
    end

    -- Add to free list
    gone.prev = wl_play.objfreelist
    wl_play.objfreelist = gone
end

---------------------------------------------------------------------------
-- PollKeyboardButtons
---------------------------------------------------------------------------

function wl_play.PollKeyboardButtons()
    local wl_main = require("wl_main")

    for i = 0, wl_def.NUMBUTTONS - 1 do
        local scan = wl_main.buttonscan[i + 1]
        if scan and scan > 0 and id_in.IN_KeyDown(scan) then
            wl_play.buttonstate[i] = true
        end
    end
end

---------------------------------------------------------------------------
-- PollKeyboardMove
---------------------------------------------------------------------------

function wl_play.PollKeyboardMove()
    local wl_main = require("wl_main")

    local run = wl_play.buttonstate[wl_def.bt_run]
    local speed = run and RUNMOVE or BASEMOVE

    if id_in.IN_KeyDown(wl_main.dirscan[1]) then  -- up
        wl_play.controly = wl_play.controly - speed * wl_main.tics
    end
    if id_in.IN_KeyDown(wl_main.dirscan[3]) then  -- down
        wl_play.controly = wl_play.controly + speed * wl_main.tics
    end
    if id_in.IN_KeyDown(wl_main.dirscan[4]) then  -- left
        wl_play.controlx = wl_play.controlx - speed * wl_main.tics
    end
    if id_in.IN_KeyDown(wl_main.dirscan[2]) then  -- right
        wl_play.controlx = wl_play.controlx + speed * wl_main.tics
    end
end

---------------------------------------------------------------------------
-- PollControls
---------------------------------------------------------------------------

function wl_play.PollControls()
    local wl_main = require("wl_main")
    local wl_draw = require("wl_draw")

    -- Timing
    if wl_play.demoplayback or wl_play.demorecord then
        wl_main.tics = wl_def.DEMOTICS
        wl_main.lasttimecount = wl_main.lasttimecount + wl_def.DEMOTICS
    else
        wl_draw.CalcTics()
    end

    -- Save previous button state
    for i = 0, wl_def.NUMBUTTONS - 1 do
        wl_play.buttonheld[i] = wl_play.buttonstate[i]
        wl_play.buttonstate[i] = false
    end

    wl_play.controlx = 0
    wl_play.controly = 0

    if wl_play.demoplayback then
        wl_main.playstate = wl_def.ex_completed
        return
    end

    -- Poll inputs
    wl_play.PollKeyboardButtons()
    wl_play.PollKeyboardMove()

    -- Bound movement
    local max = 100 * wl_main.tics
    local min = -max
    if wl_play.controlx > max then wl_play.controlx = max
    elseif wl_play.controlx < min then wl_play.controlx = min end
    if wl_play.controly > max then wl_play.controly = max
    elseif wl_play.controly < min then wl_play.controly = min end
end

---------------------------------------------------------------------------
-- CheckKeys - check for in-game special keys
---------------------------------------------------------------------------

function wl_play.CheckKeys()
    local wl_main = require("wl_main")
    local wl_menu = require("wl_menu")
    local wl_game = require("wl_game")

    if id_vl.screenfaded or wl_play.demoplayback then return end

    local scan = id_in.LastScan

    -- Tab key: debug cheats
    if scan == id_in.sc_Tab and id_in.IN_KeyDown(id_in.sc_Tab) then
        local wl_debug = require("wl_debug")
        local handled = wl_debug.DebugKeys()
        if handled ~= 0 then
            id_in.IN_ClearKeysDown()
            wl_game.DrawPlayScreen()
            id_vh.VW_FadeIn()
            wl_main.lasttimecount = id_sd.TimeCount
            return
        end
    end

    -- Pause key
    if scan == id_in.sc_P or scan == id_in.sc_Pause then
        id_in.IN_ClearKeysDown()
        -- Show paused pic
        local id_ca = require("id_ca")
        id_ca.CA_CacheGrChunk(gfx.PAUSEDPIC)
        id_vh.VWB_DrawPic(108, 80, gfx.PAUSEDPIC)
        id_vh.VW_UpdateScreen()
        id_sd.SD_MusicOff()
        id_in.IN_Ack()
        id_in.IN_ClearKeysDown()
        id_sd.SD_MusicOn()
        wl_main.lasttimecount = id_sd.TimeCount
        return
    end

    -- ESC / F-keys -> menu
    if scan == id_in.sc_Escape then
        wl_game.StopMusic()
        wl_game.ClearMemory()
        id_vh.VW_FadeOut()
        wl_menu.US_ControlPanel(scan)
        wl_main.SETFONTCOLOR(0, 15)
        id_in.IN_ClearKeysDown()
        wl_game.DrawPlayScreen()
        if not wl_main.startgame and not wl_main.loadedgame then
            id_vh.VW_FadeIn()
            wl_game.StartMusic()
        end
        if wl_main.loadedgame then
            wl_main.playstate = wl_def.ex_abort
        end
        wl_main.lasttimecount = id_sd.TimeCount
        return
    end

    -- F1: Help
    if scan == id_in.sc_F1 then
        wl_game.StopMusic()
        wl_game.ClearMemory()
        id_vh.VW_FadeOut()
        wl_menu.US_ControlPanel(scan)
        wl_main.SETFONTCOLOR(0, 15)
        id_in.IN_ClearKeysDown()
        wl_game.DrawPlayScreen()
        if not wl_main.startgame and not wl_main.loadedgame then
            id_vh.VW_FadeIn()
            wl_game.StartMusic()
        end
        wl_main.lasttimecount = id_sd.TimeCount
        return
    end

    -- F2-F9: Various menu shortcuts
    if scan >= id_in.sc_F2 and scan <= id_in.sc_F9 then
        wl_game.StopMusic()
        wl_game.ClearMemory()
        id_vh.VW_FadeOut()
        wl_menu.US_ControlPanel(scan)
        wl_main.SETFONTCOLOR(0, 15)
        id_in.IN_ClearKeysDown()
        wl_game.DrawPlayScreen()
        if not wl_main.startgame and not wl_main.loadedgame then
            id_vh.VW_FadeIn()
            wl_game.StartMusic()
        end
        if wl_main.loadedgame then
            wl_main.playstate = wl_def.ex_abort
        end
        wl_main.lasttimecount = id_sd.TimeCount
        return
    end
end

---------------------------------------------------------------------------
-- DoActor - process a single actor
---------------------------------------------------------------------------

function wl_play.DoActor(ob)
    local wl_main  = require("wl_main")
    local wl_state = require("wl_state")

    if not ob.state then
        wl_play.RemoveObj(ob)
        return
    end

    -- Advance tic counter
    if ob.ticcount and ob.ticcount > 0 then
        ob.ticcount = ob.ticcount - wl_main.tics
    end

    while ob.ticcount and ob.ticcount <= 0 do
        -- Call action function
        if ob.state and ob.state.action then
            ob.state.action(ob)
            if not ob.state then
                wl_play.RemoveObj(ob)
                return
            end
        end

        -- Advance to next state
        ob.state = ob.state and ob.state.next or nil
        if not ob.state then
            wl_play.RemoveObj(ob)
            return
        end

        if ob.state.tictime == 0 then
            ob.ticcount = 0
            break
        end

        ob.ticcount = ob.ticcount + ob.state.tictime
    end

    -- Call think function
    if ob.state and ob.state.think then
        ob.state.think(ob)
        if not ob.state then
            wl_play.RemoveObj(ob)
            return
        end
    end
end

---------------------------------------------------------------------------
-- Palette effects
---------------------------------------------------------------------------

function wl_play.InitRedShifts()
    damagecount = 0
    bonuscount = 0
    palshifted = false
    wl_play.palshifted_red = 0
    wl_play.palshifted_white = 0
end

function wl_play.ClearPaletteShifts()
    damagecount = 0
    bonuscount = 0
    palshifted = false
    wl_play.palshifted_red = 0
    wl_play.palshifted_white = 0
end

function wl_play.StartDamageFlash(damage)
    damagecount = damagecount + damage
    if damagecount > NUMREDSHIFTS * REDSTEPS then
        damagecount = NUMREDSHIFTS * REDSTEPS
    end
end

function wl_play.StartBonusFlash()
    bonuscount = NUMWHITESHIFTS * WHITESTEPS
end

function wl_play.UpdatePaletteShifts()
    local wl_main = require("wl_main")

    local red = 0
    local white = 0

    if bonuscount > 0 then
        white = math.floor((bonuscount + WHITESTEPS - 1) / WHITESTEPS)
        if white > NUMWHITESHIFTS then white = NUMWHITESHIFTS end
        bonuscount = bonuscount - wl_main.tics
        if bonuscount < 0 then bonuscount = 0 end
    end

    if damagecount > 0 then
        red = math.floor((damagecount + REDSTEPS - 1) / REDSTEPS)
        if red > NUMREDSHIFTS then red = NUMREDSHIFTS end
        damagecount = damagecount - wl_main.tics
        if damagecount < 0 then damagecount = 0 end
    end

    -- Expose current shift levels for the renderer
    wl_play.palshifted_red = red
    wl_play.palshifted_white = white

    if red > 0 or white > 0 then
        palshifted = true
    else
        if palshifted then
            palshifted = false
        end
    end
end

function wl_play.FinishPaletteShifts()
    damagecount = 0
    bonuscount = 0
    if palshifted then
        palshifted = false
    end
    wl_play.palshifted_red = 0
    wl_play.palshifted_white = 0
end

---------------------------------------------------------------------------
-- PlayLoop - main gameplay tick
---------------------------------------------------------------------------

function wl_play.PlayLoop()
    local wl_main  = require("wl_main")
    local wl_draw  = require("wl_draw")
    local wl_act1  = require("wl_act1")
    local wl_agent = require("wl_agent")

    wl_main.playstate = wl_def.ex_stillplaying
    wl_main.lasttimecount = id_sd.TimeCount
    wl_main.frameon = 0
    wl_agent.anglefrac = 0
    wl_agent.facecount = 0

    wl_play.InitRedShifts()

    while wl_main.playstate == wl_def.ex_stillplaying do
        id_in.IN_ProcessEvents()

        wl_play.PollControls()

        -- Process player
        if wl_play.player and wl_play.player.state and wl_play.player.state.think then
            wl_play.player.state.think(wl_play.player)
        end

        -- Update face
        wl_agent.UpdateFace()

        -- Process actors
        local ob = wl_play.player and wl_play.player.next or nil
        while ob do
            local nextob = ob.next
            if ob.active == wl_def.ac_yes or ob.active == wl_def.ac_allways then
                wl_play.DoActor(ob)
            end
            ob = nextob
        end

        -- Move doors
        wl_act1.MoveDoors()

        -- Move pushwalls
        wl_act1.MovePWalls()

        -- Update sound location
        wl_main.UpdateSoundLoc()

        -- Update palette shifts (damage/bonus flash)
        wl_play.UpdatePaletteShifts()

        -- Render
        wl_draw.ThreeDRefresh()

        -- Check keys
        wl_play.CheckKeys()

        -- Check for game start/load from menu
        if wl_main.startgame or wl_main.loadedgame then
            wl_main.playstate = wl_def.ex_abort
        end
    end

    wl_play.FinishPaletteShifts()
end

function wl_play.CenterWindow(w, h)
    local id_us_mod = require("id_us")
    id_us_mod.US_CenterWindow(w, h)
end

function wl_play.StopMusic()
    id_sd.SD_MusicOff()
end

function wl_play.StartMusic()
    local wl_game = require("wl_game")
    wl_game.StartMusic()
end

return wl_play
