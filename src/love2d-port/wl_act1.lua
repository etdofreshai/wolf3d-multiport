-- WL_ACT1.lua
-- Actor spawning and static objects - ported from WL_ACT1.C
-- Handles spawning of all object types, door management, pushwalls

local bit = require("bit")
local band, bor, bxor, lshift, rshift = bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift

local wl_def = require("wl_def")
local id_sd  = require("id_sd")
local id_us  = require("id_us")

local wl_act1 = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------
local DOORWIDTH = 0x7800
local OPENTICS  = 300

---------------------------------------------------------------------------
-- Static info table: maps tile value to {picnum, type}
---------------------------------------------------------------------------
wl_act1.statinfo = {
    {wl_def.SPR_STAT_0,  wl_def.dressing},     -- puddle
    {wl_def.SPR_STAT_1,  wl_def.block},         -- Green Barrel
    {wl_def.SPR_STAT_2,  wl_def.block},         -- Table/chairs
    {wl_def.SPR_STAT_3,  wl_def.block},         -- Floor lamp
    {wl_def.SPR_STAT_4,  wl_def.dressing},      -- Chandelier
    {wl_def.SPR_STAT_5,  wl_def.block},         -- Hanged man
    {wl_def.SPR_STAT_6,  wl_def.bo_alpo},       -- Bad food
    {wl_def.SPR_STAT_7,  wl_def.block},         -- Red pillar
    {wl_def.SPR_STAT_8,  wl_def.block},         -- Tree
    {wl_def.SPR_STAT_9,  wl_def.dressing},      -- Skeleton flat
    {wl_def.SPR_STAT_10, wl_def.block},         -- Sink
    {wl_def.SPR_STAT_11, wl_def.block},         -- Potted plant
    {wl_def.SPR_STAT_12, wl_def.block},         -- Urn
    {wl_def.SPR_STAT_13, wl_def.block},         -- Bare table
    {wl_def.SPR_STAT_14, wl_def.dressing},      -- Ceiling light
    {wl_def.SPR_STAT_15, wl_def.dressing},      -- Kitchen stuff (WL6)
    {wl_def.SPR_STAT_16, wl_def.block},         -- Suit of armor
    {wl_def.SPR_STAT_17, wl_def.block},         -- Hanging cage
    {wl_def.SPR_STAT_18, wl_def.block},         -- Skeleton in cage
    {wl_def.SPR_STAT_19, wl_def.dressing},      -- Skeleton relax
    {wl_def.SPR_STAT_20, wl_def.bo_key1},       -- Key 1
    {wl_def.SPR_STAT_21, wl_def.bo_key2},       -- Key 2
    {wl_def.SPR_STAT_22, wl_def.block},         -- Stuff
    {wl_def.SPR_STAT_23, wl_def.dressing},      -- Stuff
    {wl_def.SPR_STAT_24, wl_def.bo_food},       -- Good food
    {wl_def.SPR_STAT_25, wl_def.bo_firstaid},   -- First aid
    {wl_def.SPR_STAT_26, wl_def.bo_clip},       -- Clip
    {wl_def.SPR_STAT_27, wl_def.bo_machinegun}, -- Machine gun
    {wl_def.SPR_STAT_28, wl_def.bo_chaingun},   -- Gatling gun
    {wl_def.SPR_STAT_29, wl_def.bo_cross},      -- Cross
    {wl_def.SPR_STAT_30, wl_def.bo_chalice},    -- Chalice
    {wl_def.SPR_STAT_31, wl_def.bo_bible},      -- Bible
    {wl_def.SPR_STAT_32, wl_def.bo_crown},      -- Crown
    {wl_def.SPR_STAT_33, wl_def.bo_fullheal},   -- One up
    {wl_def.SPR_STAT_34, wl_def.bo_gibs},       -- Gibs
    {wl_def.SPR_STAT_35, wl_def.block},         -- Barrel
    {wl_def.SPR_STAT_36, wl_def.block},         -- Well
    {wl_def.SPR_STAT_37, wl_def.block},         -- Empty well
    {wl_def.SPR_STAT_38, wl_def.bo_gibs},       -- Gibs 2
    {wl_def.SPR_STAT_39, wl_def.block},         -- Flag
    {wl_def.SPR_STAT_40, wl_def.block},         -- Call Apogee (WL6)
    {wl_def.SPR_STAT_41, wl_def.dressing},      -- Junk
    {wl_def.SPR_STAT_42, wl_def.dressing},      -- Junk
    {wl_def.SPR_STAT_43, wl_def.dressing},      -- Junk
    {wl_def.SPR_STAT_44, wl_def.dressing},      -- Pots (WL6)
    {wl_def.SPR_STAT_45, wl_def.block},         -- Stove
    {wl_def.SPR_STAT_46, wl_def.block},         -- Spears
    {wl_def.SPR_STAT_47, wl_def.dressing},      -- Vines
    -- Extra clip2 entry
    {wl_def.SPR_STAT_26, wl_def.bo_clip2},      -- Clip (second mapping)
    {-1, wl_def.dressing},                       -- Terminator
}

---------------------------------------------------------------------------
-- InitStaticList
---------------------------------------------------------------------------

function wl_act1.InitStaticList()
    local wl_play = require("wl_play")
    wl_play.laststatobj_idx = 0
end

---------------------------------------------------------------------------
-- SpawnStatic
---------------------------------------------------------------------------

function wl_act1.SpawnStatic(tilex, tiley, stattype)
    local wl_play = require("wl_play")
    local wl_main = require("wl_main")

    local idx = wl_play.laststatobj_idx + 1
    if idx > wl_def.MAXSTATS then
        print("Too many static objects!")
        return
    end

    local info = wl_act1.statinfo[stattype + 1]  -- 1-indexed, stattype is 0-based
    if not info then return end

    local spot = wl_play.statobjlist[idx]
    if not spot then
        spot = wl_def.new_statobj()
        wl_play.statobjlist[idx] = spot
    end

    spot.shapenum = info[1]
    spot.tilex = tilex
    spot.tiley = tiley

    local item_type = info[2]

    if item_type == wl_def.block then
        wl_main.actorat[tilex][tiley] = 1  -- blocking
        spot.flags = 0
    elseif item_type == wl_def.dressing then
        spot.flags = 0
    else
        -- Treasure items
        if item_type == wl_def.bo_cross or item_type == wl_def.bo_chalice or
           item_type == wl_def.bo_bible or item_type == wl_def.bo_crown or
           item_type == wl_def.bo_fullheal then
            wl_main.gamestate.treasuretotal = wl_main.gamestate.treasuretotal + 1
        end
        spot.flags = wl_def.FL_BONUS
        spot.itemnumber = item_type
    end

    wl_play.laststatobj_idx = idx
end

---------------------------------------------------------------------------
-- PlaceItemType - drop items during gameplay
---------------------------------------------------------------------------

function wl_act1.PlaceItemType(itemtype, tilex, tiley)
    local wl_play = require("wl_play")
    local wl_main = require("wl_main")

    -- Find item number in statinfo
    local stat_idx = nil
    for i = 1, #wl_act1.statinfo do
        if wl_act1.statinfo[i][1] == -1 then break end
        if wl_act1.statinfo[i][2] == itemtype then
            stat_idx = i
            break
        end
    end
    if not stat_idx then return end

    -- Find a free spot
    local spot_idx = nil
    for i = 1, wl_play.laststatobj_idx do
        if wl_play.statobjlist[i].shapenum == -1 then
            spot_idx = i
            break
        end
    end
    if not spot_idx then
        if wl_play.laststatobj_idx >= wl_def.MAXSTATS then return end
        wl_play.laststatobj_idx = wl_play.laststatobj_idx + 1
        spot_idx = wl_play.laststatobj_idx
    end

    local spot = wl_play.statobjlist[spot_idx]
    if not spot then
        spot = wl_def.new_statobj()
        wl_play.statobjlist[spot_idx] = spot
    end

    spot.shapenum = wl_act1.statinfo[stat_idx][1]
    spot.tilex = tilex
    spot.tiley = tiley
    spot.flags = wl_def.FL_BONUS
    spot.itemnumber = itemtype
end

---------------------------------------------------------------------------
-- Door management
---------------------------------------------------------------------------

function wl_act1.InitDoorList()
    local wl_game = require("wl_game")

    for i = 0, wl_def.NUMAREAS - 1 do
        wl_game.areabyplayer[i] = false
        for j = 0, wl_def.NUMAREAS - 1 do
            wl_game.areaconnect[i][j] = 0
        end
    end

    wl_game.doornum = 0
end

function wl_act1.SpawnDoor(tilex, tiley, vertical, lock)
    local wl_game = require("wl_game")
    local wl_main = require("wl_main")
    local id_ca   = require("id_ca")

    local dn = wl_game.doornum
    if dn >= wl_def.MAXDOORS then
        print("64+ doors on level!")
        return
    end

    wl_game.doorposition[dn] = 0  -- fully closed
    local door = wl_game.doorobjlist[dn]
    door.tilex = tilex
    door.tiley = tiley
    door.vertical = vertical
    door.lock = lock
    door.action = wl_def.dr_closed

    wl_main.actorat[tilex][tiley] = bor(dn, 0x80)
    wl_main.tilemap[tilex][tiley] = bor(dn, 0x80)

    -- Mark adjacent tiles for door sides
    if vertical then
        if tiley > 0 then
            wl_main.tilemap[tilex][tiley - 1] = bor(wl_main.tilemap[tilex][tiley - 1], 0x40)
        end
        if tiley < wl_def.MAPSIZE - 1 then
            wl_main.tilemap[tilex][tiley + 1] = bor(wl_main.tilemap[tilex][tiley + 1], 0x40)
        end
    else
        if tilex > 0 then
            wl_main.tilemap[tilex - 1][tiley] = bor(wl_main.tilemap[tilex - 1][tiley], 0x40)
        end
        if tilex < wl_def.MAPSIZE - 1 then
            wl_main.tilemap[tilex + 1][tiley] = bor(wl_main.tilemap[tilex + 1][tiley], 0x40)
        end
    end

    wl_game.doornum = dn + 1
end

function wl_act1.RecursiveConnect(areanumber)
    local wl_game = require("wl_game")
    for i = 0, wl_def.NUMAREAS - 1 do
        if (wl_game.areaconnect[areanumber][i] or 0) > 0 and not wl_game.areabyplayer[i] then
            wl_game.areabyplayer[i] = true
            wl_act1.RecursiveConnect(i)
        end
    end
end

function wl_act1.ConnectAreas()
    local wl_game = require("wl_game")
    local wl_play = require("wl_play")

    for i = 0, wl_def.NUMAREAS - 1 do
        wl_game.areabyplayer[i] = false
    end
    if wl_play.player then
        wl_game.areabyplayer[wl_play.player.areanumber or 0] = true
        wl_act1.RecursiveConnect(wl_play.player.areanumber or 0)
    end
end

function wl_act1.InitAreas()
    local wl_game = require("wl_game")
    local wl_play = require("wl_play")

    for i = 0, wl_def.NUMAREAS - 1 do
        wl_game.areabyplayer[i] = false
    end
    if wl_play.player then
        wl_game.areabyplayer[wl_play.player.areanumber or 0] = true
    end
end

function wl_act1.OpenDoor(door)
    local wl_game = require("wl_game")
    if wl_game.doorobjlist[door].action == wl_def.dr_open then
        wl_game.doorobjlist[door].ticcount = 0
    else
        wl_game.doorobjlist[door].action = wl_def.dr_opening
    end
end

function wl_act1.CloseDoor(door)
    local wl_game = require("wl_game")
    local wl_main = require("wl_main")
    local wl_play = require("wl_play")

    local tilex = wl_game.doorobjlist[door].tilex
    local tiley = wl_game.doorobjlist[door].tiley

    if wl_main.actorat[tilex][tiley] and wl_main.actorat[tilex][tiley] ~= bor(door, 0x80) then
        return  -- something blocking
    end

    if wl_play.player and wl_play.player.tilex == tilex and wl_play.player.tiley == tiley then
        return
    end

    wl_game.doorobjlist[door].action = wl_def.dr_closing
    wl_main.actorat[tilex][tiley] = bor(door, 0x80)
end

function wl_act1.OperateDoor(door)
    local wl_game = require("wl_game")
    local wl_main = require("wl_main")

    local action = wl_game.doorobjlist[door].action
    local lock = wl_game.doorobjlist[door].lock

    if lock >= wl_def.dr_lock1 and lock <= wl_def.dr_lock4 then
        local key_bit = lshift(1, lock - wl_def.dr_lock1)
        if band(wl_main.gamestate.keys, key_bit) == 0 then
            -- No key
            id_sd.SD_PlaySound(0)  -- locked sound
            return
        end
    end

    if action == wl_def.dr_open then
        -- Already open - just reset the countdown
    elseif action == wl_def.dr_closed then
        wl_act1.OpenDoor(door)
    end
end

function wl_act1.DoorOpening(door)
    local wl_game = require("wl_game")
    local wl_main = require("wl_main")

    local position = wl_game.doorposition[door]
    position = position + wl_main.tics * 10  -- speed

    if position >= 0xFFFF then
        position = 0xFFFF
        wl_game.doorobjlist[door].action = wl_def.dr_open
        wl_game.doorobjlist[door].ticcount = 0
        wl_main.actorat[wl_game.doorobjlist[door].tilex][wl_game.doorobjlist[door].tiley] = nil

        -- Connect areas
        local dx = wl_game.doorobjlist[door].tilex
        local dy = wl_game.doorobjlist[door].tiley
        -- Increment area connection
        local id_ca = require("id_ca")
        if wl_game.doorobjlist[door].vertical then
            if dy > 0 and dy < wl_def.MAPSIZE - 1 and id_ca.mapsegs and id_ca.mapsegs[1] then
                local a1_idx = wl_main.farmapylookup[dy] + dx + 1
                local a2_idx = wl_main.farmapylookup[dy + 2] + dx + 1
                local area1 = (id_ca.mapsegs[1][a1_idx] or wl_def.AREATILE) - wl_def.AREATILE
                local area2 = (id_ca.mapsegs[1][a2_idx] or wl_def.AREATILE) - wl_def.AREATILE
                if area1 >= 0 and area1 < wl_def.NUMAREAS and area2 >= 0 and area2 < wl_def.NUMAREAS then
                    wl_game.areaconnect[area1][area2] = (wl_game.areaconnect[area1][area2] or 0) + 1
                    wl_game.areaconnect[area2][area1] = (wl_game.areaconnect[area2][area1] or 0) + 1
                end
            end
        else
            if dx > 0 and dx < wl_def.MAPSIZE - 1 and id_ca.mapsegs and id_ca.mapsegs[1] then
                local a1_idx = wl_main.farmapylookup[dy + 1] + dx
                local a2_idx = wl_main.farmapylookup[dy + 1] + dx + 2
                local area1 = (id_ca.mapsegs[1][a1_idx] or wl_def.AREATILE) - wl_def.AREATILE
                local area2 = (id_ca.mapsegs[1][a2_idx] or wl_def.AREATILE) - wl_def.AREATILE
                if area1 >= 0 and area1 < wl_def.NUMAREAS and area2 >= 0 and area2 < wl_def.NUMAREAS then
                    wl_game.areaconnect[area1][area2] = (wl_game.areaconnect[area1][area2] or 0) + 1
                    wl_game.areaconnect[area2][area1] = (wl_game.areaconnect[area2][area1] or 0) + 1
                end
            end
        end
        wl_act1.ConnectAreas()
    end
    wl_game.doorposition[door] = position
end

function wl_act1.DoorClosing(door)
    local wl_game = require("wl_game")
    local wl_main = require("wl_main")

    local position = wl_game.doorposition[door]
    position = position - wl_main.tics * 10

    if position <= 0 then
        position = 0
        wl_game.doorobjlist[door].action = wl_def.dr_closed
    end
    wl_game.doorposition[door] = position
end

function wl_act1.DoorOpen(door)
    local wl_game = require("wl_game")
    local wl_main = require("wl_main")

    wl_game.doorobjlist[door].ticcount = wl_game.doorobjlist[door].ticcount + wl_main.tics
    if wl_game.doorobjlist[door].ticcount >= OPENTICS then
        wl_act1.CloseDoor(door)
    end
end

function wl_act1.MoveDoors()
    local wl_game = require("wl_game")

    for door = 0, wl_game.doornum - 1 do
        local action = wl_game.doorobjlist[door].action
        if action == wl_def.dr_open then
            wl_act1.DoorOpen(door)
        elseif action == wl_def.dr_opening then
            wl_act1.DoorOpening(door)
        elseif action == wl_def.dr_closing then
            wl_act1.DoorClosing(door)
        end
    end
end

---------------------------------------------------------------------------
-- Pushwall
---------------------------------------------------------------------------

function wl_act1.PushWall(checkx, checky, dir)
    local wl_game = require("wl_game")
    local wl_main = require("wl_main")

    if wl_game.pwallstate ~= 0 then return end

    -- Check if the destination tiles are free
    local destx, desty = checkx, checky
    if dir == wl_def.di_north then desty = checky - 1
    elseif dir == wl_def.di_east then destx = checkx + 1
    elseif dir == wl_def.di_south then desty = checky + 1
    elseif dir == wl_def.di_west then destx = checkx - 1
    end

    if destx < 0 or destx >= wl_def.MAPSIZE or desty < 0 or desty >= wl_def.MAPSIZE then return end
    if wl_main.actorat[destx][desty] then return end
    if wl_main.tilemap[destx][desty] ~= 0 then return end

    -- Check second tile
    local dest2x, dest2y = destx, desty
    if dir == wl_def.di_north then dest2y = desty - 1
    elseif dir == wl_def.di_east then dest2x = destx + 1
    elseif dir == wl_def.di_south then dest2y = desty + 1
    elseif dir == wl_def.di_west then dest2x = destx - 1
    end

    if dest2x >= 0 and dest2x < wl_def.MAPSIZE and dest2y >= 0 and dest2y < wl_def.MAPSIZE then
        if wl_main.actorat[dest2x][dest2y] or wl_main.tilemap[dest2x][dest2y] ~= 0 then
            -- Can only go one tile
        end
    end

    wl_game.pwallstate = 1
    wl_game.pwallx = checkx
    wl_game.pwally = checky
    wl_game.pwalldir = dir
    wl_game.pwallpos = 0

    -- Set tilemap to pushwall marker
    wl_main.tilemap[checkx][checky] = bor(wl_main.tilemap[checkx][checky], 0x40)

    wl_main.gamestate.secretcount = wl_main.gamestate.secretcount + 1

    id_sd.SD_PlaySound(0)  -- pushwall sound
end

function wl_act1.MovePWalls()
    local wl_game = require("wl_game")
    local wl_main = require("wl_main")

    if wl_game.pwallstate == 0 then return end

    wl_game.pwallpos = wl_game.pwallpos + wl_main.tics * 2
    if wl_game.pwallpos >= 64 then
        wl_game.pwallpos = 64

        -- Move wall to next tile
        local oldx = wl_game.pwallx
        local oldy = wl_game.pwally
        local newx, newy = oldx, oldy

        if wl_game.pwalldir == wl_def.di_north then newy = oldy - 1
        elseif wl_game.pwalldir == wl_def.di_east then newx = oldx + 1
        elseif wl_game.pwalldir == wl_def.di_south then newy = oldy + 1
        elseif wl_game.pwalldir == wl_def.di_west then newx = oldx - 1
        end

        if newx >= 0 and newx < wl_def.MAPSIZE and newy >= 0 and newy < wl_def.MAPSIZE then
            local old_tile = band(wl_main.tilemap[oldx][oldy], 63)
            wl_main.tilemap[oldx][oldy] = 0
            wl_main.actorat[oldx][oldy] = nil

            wl_main.tilemap[newx][newy] = old_tile
            wl_main.actorat[newx][newy] = old_tile

            -- Check if we can continue
            local next2x, next2y = newx, newy
            if wl_game.pwalldir == wl_def.di_north then next2y = newy - 1
            elseif wl_game.pwalldir == wl_def.di_east then next2x = newx + 1
            elseif wl_game.pwalldir == wl_def.di_south then next2y = newy + 1
            elseif wl_game.pwalldir == wl_def.di_west then next2x = newx - 1
            end

            if next2x >= 0 and next2x < wl_def.MAPSIZE and next2y >= 0 and next2y < wl_def.MAPSIZE and
               wl_main.tilemap[next2x][next2y] == 0 and not wl_main.actorat[next2x][next2y] then
                wl_game.pwallx = newx
                wl_game.pwally = newy
                wl_game.pwallpos = 0
                wl_main.tilemap[newx][newy] = bor(old_tile, 0x40)
            else
                wl_game.pwallstate = 0  -- done
            end
        else
            wl_game.pwallstate = 0
        end
    end
end

---------------------------------------------------------------------------
-- Spawn functions
---------------------------------------------------------------------------

function wl_act1.SpawnStand(enemy, tilex, tiley, dir)
    local wl_act2 = require("wl_act2")
    local wl_main = require("wl_main")
    local wl_state_mod = require("wl_state")

    local state = wl_act2.GetStandState(enemy)
    if not state then return end

    local obj = wl_state_mod.SpawnNewObj(tilex, tiley, state)
    if not obj then return end

    obj.obclass = wl_act2.GetObjClass(enemy)
    obj.hitpoints = wl_act2.GetHitPoints(enemy, wl_main.gamestate.difficulty)
    obj.dir = dir * 2  -- convert from 0-3 to dir enum (0,2,4,6)
    obj.speed = wl_def.SPDPATROL

    if not wl_main.loadedgame then
        wl_main.gamestate.killtotal = wl_main.gamestate.killtotal + 1
    end
end

function wl_act1.SpawnPatrol(enemy, tilex, tiley, dir)
    local wl_act2 = require("wl_act2")
    local wl_main = require("wl_main")
    local wl_state_mod = require("wl_state")

    local state = wl_act2.GetPathState(enemy)
    if not state then return end

    local obj = wl_state_mod.SpawnNewObj(tilex, tiley, state)
    if not obj then return end

    obj.obclass = wl_act2.GetObjClass(enemy)
    obj.hitpoints = wl_act2.GetHitPoints(enemy, wl_main.gamestate.difficulty)
    obj.dir = dir * 2
    obj.speed = wl_def.SPDPATROL
    obj.active = wl_def.ac_yes
    obj.distance = wl_def.TILEGLOBAL

    wl_main.actorat[tilex][tiley] = obj

    if not wl_main.loadedgame then
        wl_main.gamestate.killtotal = wl_main.gamestate.killtotal + 1
    end
end

function wl_act1.SpawnDeadGuard(tilex, tiley)
    local wl_state_mod = require("wl_state")
    local wl_act2 = require("wl_act2")

    local state = wl_act2.s_grddie4
    local obj = wl_state_mod.SpawnNewObj(tilex, tiley, state)
    if not obj then return end

    obj.obclass = wl_def.inertobj
end

function wl_act1.SpawnBoss(tilex, tiley)
    local wl_state_mod = require("wl_state")
    local wl_act2 = require("wl_act2")
    local wl_main = require("wl_main")

    local obj = wl_state_mod.SpawnNewObj(tilex, tiley, wl_act2.s_bossstand)
    if not obj then return end

    obj.obclass = wl_def.bossobj
    obj.hitpoints = wl_act2.GetHitPoints(wl_def.en_boss, wl_main.gamestate.difficulty)
    obj.speed = wl_def.SPDPATROL
    if not wl_main.loadedgame then
        wl_main.gamestate.killtotal = wl_main.gamestate.killtotal + 1
    end
end

function wl_act1.SpawnGretel(tilex, tiley)
    local wl_state_mod = require("wl_state")
    local wl_act2 = require("wl_act2")
    local wl_main = require("wl_main")

    local obj = wl_state_mod.SpawnNewObj(tilex, tiley, wl_act2.s_gretelstand)
    if not obj then return end

    obj.obclass = wl_def.gretelobj
    obj.hitpoints = wl_act2.GetHitPoints(wl_def.en_gretel, wl_main.gamestate.difficulty)
    obj.speed = wl_def.SPDPATROL
    if not wl_main.loadedgame then
        wl_main.gamestate.killtotal = wl_main.gamestate.killtotal + 1
    end
end

function wl_act1.SpawnSchabbs(tilex, tiley)
    local wl_state_mod = require("wl_state")
    local wl_act2 = require("wl_act2")
    local wl_main = require("wl_main")

    local obj = wl_state_mod.SpawnNewObj(tilex, tiley, wl_act2.s_schabbstand)
    if not obj then return end

    obj.obclass = wl_def.schabbobj
    obj.hitpoints = wl_act2.GetHitPoints(wl_def.en_schabbs, wl_main.gamestate.difficulty)
    obj.speed = wl_def.SPDPATROL
    if not wl_main.loadedgame then
        wl_main.gamestate.killtotal = wl_main.gamestate.killtotal + 1
    end
end

function wl_act1.SpawnGift(tilex, tiley)
    local wl_state_mod = require("wl_state")
    local wl_act2 = require("wl_act2")
    local wl_main = require("wl_main")

    local obj = wl_state_mod.SpawnNewObj(tilex, tiley, wl_act2.s_giftstand)
    if not obj then return end

    obj.obclass = wl_def.giftobj
    obj.hitpoints = wl_act2.GetHitPoints(wl_def.en_gift, wl_main.gamestate.difficulty)
    obj.speed = wl_def.SPDPATROL
    if not wl_main.loadedgame then
        wl_main.gamestate.killtotal = wl_main.gamestate.killtotal + 1
    end
end

function wl_act1.SpawnFat(tilex, tiley)
    local wl_state_mod = require("wl_state")
    local wl_act2 = require("wl_act2")
    local wl_main = require("wl_main")

    local obj = wl_state_mod.SpawnNewObj(tilex, tiley, wl_act2.s_fatstand)
    if not obj then return end

    obj.obclass = wl_def.fatobj
    obj.hitpoints = wl_act2.GetHitPoints(wl_def.en_fat, wl_main.gamestate.difficulty)
    obj.speed = wl_def.SPDPATROL
    if not wl_main.loadedgame then
        wl_main.gamestate.killtotal = wl_main.gamestate.killtotal + 1
    end
end

function wl_act1.SpawnFakeHitler(tilex, tiley)
    local wl_state_mod = require("wl_state")
    local wl_act2 = require("wl_act2")
    local wl_main = require("wl_main")

    local obj = wl_state_mod.SpawnNewObj(tilex, tiley, wl_act2.s_fakestand)
    if not obj then return end

    obj.obclass = wl_def.fakeobj
    obj.hitpoints = wl_act2.GetHitPoints(wl_def.en_fake, wl_main.gamestate.difficulty)
    obj.speed = wl_def.SPDPATROL
    if not wl_main.loadedgame then
        wl_main.gamestate.killtotal = wl_main.gamestate.killtotal + 1
    end
end

function wl_act1.SpawnHitler(tilex, tiley)
    local wl_state_mod = require("wl_state")
    local wl_act2 = require("wl_act2")
    local wl_main = require("wl_main")

    local obj = wl_state_mod.SpawnNewObj(tilex, tiley, wl_act2.s_mechastand)
    if not obj then return end

    obj.obclass = wl_def.mechahitlerobj
    obj.hitpoints = wl_act2.GetHitPoints(wl_def.en_hitler, wl_main.gamestate.difficulty)
    obj.speed = wl_def.SPDPATROL
    if not wl_main.loadedgame then
        wl_main.gamestate.killtotal = wl_main.gamestate.killtotal + 1
    end
end

function wl_act1.SpawnGhosts(which, tilex, tiley)
    local wl_state_mod = require("wl_state")
    local wl_act2 = require("wl_act2")

    local state
    if which == wl_def.en_blinky then state = wl_act2.s_blinkychase1
    elseif which == wl_def.en_clyde then state = wl_act2.s_clydechase1
    elseif which == wl_def.en_pinky then state = wl_act2.s_pinkychase1
    elseif which == wl_def.en_inky then state = wl_act2.s_inkychase1
    else return end

    local obj = wl_state_mod.SpawnNewObj(tilex, tiley, state)
    if not obj then return end

    obj.obclass = wl_def.ghostobj
    obj.speed = wl_def.SPDDOG
    obj.active = wl_def.ac_yes
end

return wl_act1
