-- WL_DEBUG.lua
-- Debug routines - ported from WL_DEBUG.C
-- God mode, noclip, level warp, memory info, object counts

local bit = require("bit")
local band, bor, lshift, rshift = bit.band, bit.bor, bit.lshift, bit.rshift

local wl_def = require("wl_def")
local id_in  = require("id_in")
local id_us  = require("id_us")
local id_vh  = require("id_vh")
local id_sd  = require("id_sd")

local wl_debug = {}

-- Debug enabled flag (set by typing "tab" at right time, or always enabled)
local DebugOk = true

---------------------------------------------------------------------------
-- DebugMemory - show memory usage
---------------------------------------------------------------------------

function wl_debug.DebugMemory()
    id_us.US_CenterWindow(16, 4)
    id_us.US_CPrint("Memory Usage")
    id_us.US_CPrint("------------")
    id_us.US_Print("Lua mem: ")
    id_us.US_PrintUnsigned(math.floor(collectgarbage("count")))
    id_us.US_Print("k\n")
    id_vh.VW_UpdateScreen()
    id_in.IN_Ack()
end

---------------------------------------------------------------------------
-- CountObjects - show actor counts
---------------------------------------------------------------------------

function wl_debug.CountObjects()
    local wl_play = require("wl_play")
    local wl_game = require("wl_game")

    id_us.US_CenterWindow(16, 7)

    local total = wl_play.laststatobj_idx
    id_us.US_Print("Total statics :")
    id_us.US_PrintUnsigned(total)

    local count = 0
    for i = 1, total do
        if wl_play.statobjlist[i] and wl_play.statobjlist[i].shapenum ~= -1 then
            count = count + 1
        end
    end
    id_us.US_Print("\nIn use statics:")
    id_us.US_PrintUnsigned(count)

    id_us.US_Print("\nDoors         :")
    id_us.US_PrintUnsigned(wl_game.doornum)

    local active = 0
    local inactive = 0
    if wl_play.player then
        local ob = wl_play.player.next
        while ob do
            if ob.active and ob.active ~= wl_def.ac_no then
                active = active + 1
            else
                inactive = inactive + 1
            end
            ob = ob.next
        end
    end

    id_us.US_Print("\nTotal actors  :")
    id_us.US_PrintUnsigned(active + inactive)
    id_us.US_Print("\nActive actors :")
    id_us.US_PrintUnsigned(active)

    id_vh.VW_UpdateScreen()
    id_in.IN_Ack()
end

---------------------------------------------------------------------------
-- DebugKeys - handle debug key combinations
-- Called when Tab is pressed during gameplay
-- Returns 1 if handled, 0 if not
---------------------------------------------------------------------------

function wl_debug.DebugKeys()
    local wl_play = require("wl_play")
    local wl_main = require("wl_main")

    if not DebugOk then return 0 end

    -- Tab+G: God mode toggle
    if id_in.IN_KeyDown(id_in.sc_G) then
        id_in.IN_ClearKeysDown()
        wl_play.godmode = not wl_play.godmode
        if wl_play.godmode then
            id_us.US_CenterWindow(12, 2)
            id_us.US_CPrint("God mode ON")
        else
            id_us.US_CenterWindow(12, 2)
            id_us.US_CPrint("God mode OFF")
        end
        id_vh.VW_UpdateScreen()
        id_in.IN_Ack()
        return 1
    end

    -- Tab+N: Noclip toggle
    if id_in.IN_KeyDown(id_in.sc_N) then
        id_in.IN_ClearKeysDown()
        wl_play.noclip = not wl_play.noclip
        if wl_play.noclip then
            id_us.US_CenterWindow(12, 2)
            id_us.US_CPrint("Noclip ON")
        else
            id_us.US_CenterWindow(12, 2)
            id_us.US_CPrint("Noclip OFF")
        end
        id_vh.VW_UpdateScreen()
        id_in.IN_Ack()
        return 1
    end

    -- Tab+I: Free items (full health, ammo, keys)
    if id_in.IN_KeyDown(id_in.sc_I) then
        id_in.IN_ClearKeysDown()
        local gs = wl_main.gamestate
        gs.health = 100
        gs.ammo = 99
        gs.keys = bor(gs.keys, 3)  -- both keys
        gs.score = 0
        gs.TimeCount = gs.TimeCount + 42000
        local wl_agent = require("wl_agent")
        wl_agent.GiveWeapon(wl_def.wp_chaingun)
        wl_agent.DrawHealth()
        wl_agent.DrawAmmo()
        wl_agent.DrawKeys()
        wl_agent.DrawFace()
        wl_agent.DrawScore()
        id_us.US_CenterWindow(16, 3)
        local foreign = require("foreign")
        id_us.US_CPrint(foreign.STR_CHEATER1 or "Cheat activated!")
        id_vh.VW_UpdateScreen()
        id_in.IN_Ack()
        return 1
    end

    -- Tab+W: Warp to level
    if id_in.IN_KeyDown(id_in.sc_W) then
        id_in.IN_ClearKeysDown()
        id_us.US_CenterWindow(20, 3)
        id_us.US_CPrint("Warp to which level (0-59)?")
        id_vh.VW_UpdateScreen()

        -- Simple number input
        local num_str = ""
        while true do
            id_in.IN_WaitAndProcessEvents()
            if id_in.LastScan == id_in.sc_Return then
                id_in.IN_ClearKey(id_in.sc_Return)
                break
            elseif id_in.LastScan == id_in.sc_Escape then
                id_in.IN_ClearKey(id_in.sc_Escape)
                return 1
            elseif id_in.LastScan >= id_in.sc_1 and id_in.LastScan <= id_in.sc_0 then
                local digit = id_in.LastScan - id_in.sc_1
                if id_in.LastScan == id_in.sc_0 then digit = 9 end
                num_str = num_str .. tostring(digit)
                id_in.IN_ClearKey(id_in.LastScan)
            end
        end

        local level = tonumber(num_str)
        if level and level >= 0 and level < 60 then
            wl_main.gamestate.mapon = level
            wl_main.playstate = wl_def.ex_warped
        end
        return 1
    end

    -- Tab+C: Count objects
    if id_in.IN_KeyDown(id_in.sc_C) then
        id_in.IN_ClearKeysDown()
        wl_debug.CountObjects()
        return 1
    end

    -- Tab+M: Memory info
    if id_in.IN_KeyDown(id_in.sc_M) then
        id_in.IN_ClearKeysDown()
        wl_debug.DebugMemory()
        return 1
    end

    -- Tab+E: Skip to next level
    if id_in.IN_KeyDown(id_in.sc_E) then
        id_in.IN_ClearKeysDown()
        if wl_main.gamestate.mapon < 59 then
            wl_main.gamestate.mapon = wl_main.gamestate.mapon + 1
            wl_main.playstate = wl_def.ex_warped
        end
        return 1
    end

    return 0
end

---------------------------------------------------------------------------
-- PicturePause - pause and show picture debug info
---------------------------------------------------------------------------

function wl_debug.PicturePause()
    -- Simplified: just pause
    id_in.IN_Ack()
end

return wl_debug
