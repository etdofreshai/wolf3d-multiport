-- WL_AGENT.lua
-- Player agent - ported from WL_AGENT.C
-- Handles player movement, weapon firing, item pickup, damage, HUD

local bit = require("bit")
local band, bor, bxor, lshift, rshift = bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift

local wl_def = require("wl_def")
local id_us  = require("id_us")
local id_sd  = require("id_sd")
local gfx    = require("gfxv_wl6")
local audiowl6 = require("audiowl6")

local wl_agent = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------
local MOVESCALE     = 150
local BACKMOVESCALE = 100
local ANGLESCALE    = 20
local MAXMOUSETURN  = 10
local FACETICS      = 70

---------------------------------------------------------------------------
-- Player state info
---------------------------------------------------------------------------
wl_agent.running     = false
wl_agent.thrustspeed = 0
wl_agent.anglefrac   = 0
wl_agent.gotgatgun   = 0
wl_agent.facecount   = 0
wl_agent.LastAttacker = nil
wl_agent.playerxmove = 0
wl_agent.playerymove = 0

-- Attack info: {tics, attack, frame} per weapon per frame
wl_agent.attackinfo = {
    [0] = { {6,0,1},{6,2,2},{6,0,3},{6,-1,4} },  -- knife
    [1] = { {6,0,1},{6,1,2},{6,0,3},{6,-1,4} },  -- pistol
    [2] = { {6,0,1},{6,1,2},{6,3,3},{6,-1,4} },  -- machine gun
    [3] = { {6,0,1},{6,1,2},{6,4,3},{6,-1,4} },  -- chain gun
}

-- Player states
wl_agent.s_player = {rotate = false, shapenum = 0, tictime = 0, think = nil, action = nil, next = nil}
wl_agent.s_attack = {rotate = false, shapenum = 0, tictime = 0, think = nil, action = nil, next = nil}

---------------------------------------------------------------------------
-- SpawnPlayer
---------------------------------------------------------------------------

function wl_agent.SpawnPlayer(tilex, tiley, dir)
    local wl_play = require("wl_play")

    local player = wl_play.player
    if not player then return end

    player.tilex = tilex
    player.tiley = tiley
    player.x = lshift(tilex, wl_def.TILESHIFT) + math.floor(wl_def.TILEGLOBAL / 2)
    player.y = lshift(tiley, wl_def.TILESHIFT) + math.floor(wl_def.TILEGLOBAL / 2)
    player.angle = (1 - dir) * 90  -- NORTH=0->90, EAST=1->0, etc.
    if player.angle < 0 then player.angle = player.angle + 360 end
    player.obclass = wl_def.playerobj
    player.active = wl_def.ac_yes
    player.flags = 0
    player.state = wl_agent.s_player
    player.speed = 0
    player.dir = wl_def.dir_nodir

    -- Set area
    local wl_main = require("wl_main")
    local id_ca = require("id_ca")
    if id_ca.mapsegs and id_ca.mapsegs[1] and wl_main.farmapylookup[tiley + 1] then
        local idx = wl_main.farmapylookup[tiley + 1] + tilex + 1
        local area_val = id_ca.mapsegs[1][idx]
        if area_val then
            player.areanumber = area_val - wl_def.AREATILE
        end
    end

    wl_agent.thrustspeed = 0
    wl_agent.anglefrac = 0
end

---------------------------------------------------------------------------
-- Thrust - move player in a direction
---------------------------------------------------------------------------

function wl_agent.Thrust(angle, speed)
    local wl_play = require("wl_play")
    local wl_main = require("wl_main")

    local player = wl_play.player
    if not player then return end

    local xmove = wl_main.costable[angle] or 0
    local ymove = -(wl_main.sintable[angle] or 0)

    -- FixedByFrac to scale speed
    local wl_draw = require("wl_draw")
    xmove = wl_draw.FixedByFrac(speed, xmove)
    ymove = wl_draw.FixedByFrac(speed, ymove)

    wl_agent.ClipMove(player, xmove, ymove)
    player.tilex = rshift(player.x, wl_def.TILESHIFT)
    player.tiley = rshift(player.y, wl_def.TILESHIFT)
end

---------------------------------------------------------------------------
-- ClipMove - move with wall collision
---------------------------------------------------------------------------

function wl_agent.ClipMove(ob, xmove, ymove)
    local wl_main = require("wl_main")
    local wl_play = require("wl_play")

    -- If noclip, skip collision
    if wl_play.noclip then
        ob.x = ob.x + xmove
        ob.y = ob.y + ymove
        return
    end

    -- Try X move
    local newx = ob.x + xmove
    local newtx = rshift(newx, wl_def.TILESHIFT)
    local ty = rshift(ob.y, wl_def.TILESHIFT)

    if newtx >= 0 and newtx < wl_def.MAPSIZE and ty >= 0 and ty < wl_def.MAPSIZE then
        if wl_main.actorat[newtx][ty] == nil or
           (type(wl_main.actorat[newtx][ty]) ~= "number" or wl_main.actorat[newtx][ty] >= 256) then
            if wl_main.tilemap[newtx][ty] == 0 then
                ob.x = newx
            end
        end
    end

    -- Try Y move
    local newy = ob.y + ymove
    local tx = rshift(ob.x, wl_def.TILESHIFT)
    local newty = rshift(newy, wl_def.TILESHIFT)

    if tx >= 0 and tx < wl_def.MAPSIZE and newty >= 0 and newty < wl_def.MAPSIZE then
        if wl_main.actorat[tx][newty] == nil or
           (type(wl_main.actorat[tx][newty]) ~= "number" or wl_main.actorat[tx][newty] >= 256) then
            if wl_main.tilemap[tx][newty] == 0 then
                ob.y = newy
            end
        end
    end
end

---------------------------------------------------------------------------
-- ControlMovement
---------------------------------------------------------------------------

function wl_agent.ControlMovement(ob)
    local wl_play = require("wl_play")
    local wl_main = require("wl_main")

    wl_agent.thrustspeed = 0
    local oldx = ob.x
    local oldy = ob.y

    -- Side to side (strafe or turn)
    if wl_play.buttonstate[wl_def.bt_strafe] then
        -- Strafing
        if wl_play.controlx > 0 then
            local angle = ob.angle - 90
            if angle < 0 then angle = angle + wl_def.ANGLES end
            wl_agent.Thrust(angle, wl_play.controlx * MOVESCALE)
        elseif wl_play.controlx < 0 then
            local angle = ob.angle + 90
            if angle >= wl_def.ANGLES then angle = angle - wl_def.ANGLES end
            wl_agent.Thrust(angle, -wl_play.controlx * MOVESCALE)
        end
    else
        -- Turning
        wl_agent.anglefrac = wl_agent.anglefrac + wl_play.controlx
        local angleunits = math.floor(wl_agent.anglefrac / ANGLESCALE)
        wl_agent.anglefrac = wl_agent.anglefrac - angleunits * ANGLESCALE
        ob.angle = ob.angle - angleunits

        if ob.angle >= wl_def.ANGLES then ob.angle = ob.angle - wl_def.ANGLES end
        if ob.angle < 0 then ob.angle = ob.angle + wl_def.ANGLES end
    end

    -- Forward/backward
    if wl_play.controly < 0 then
        wl_agent.Thrust(ob.angle, -wl_play.controly * MOVESCALE)
    elseif wl_play.controly > 0 then
        local angle = ob.angle + 180
        if angle >= wl_def.ANGLES then angle = angle - wl_def.ANGLES end
        wl_agent.Thrust(angle, wl_play.controly * BACKMOVESCALE)
    end

    wl_agent.playerxmove = ob.x - oldx
    wl_agent.playerymove = ob.y - oldy
end

---------------------------------------------------------------------------
-- T_Player - Player think function
---------------------------------------------------------------------------

function wl_agent.T_Player(ob)
    local wl_play = require("wl_play")
    local wl_main = require("wl_main")

    if wl_main.gamestate.victoryflag then return end

    -- Check weapon change keys
    wl_agent.CheckWeaponChange()

    -- Movement
    wl_agent.ControlMovement(ob)

    -- Use
    if wl_play.buttonstate[wl_def.bt_use] and not wl_play.buttonheld[wl_def.bt_use] then
        wl_agent.Cmd_Use()
    end

    -- Attack
    if wl_play.buttonstate[wl_def.bt_attack] and not wl_play.buttonheld[wl_def.bt_attack] then
        wl_agent.Cmd_Fire()
    end
end
wl_agent.s_player.think = wl_agent.T_Player

---------------------------------------------------------------------------
-- T_Attack - Player attack think
---------------------------------------------------------------------------

function wl_agent.T_Attack(ob)
    local wl_main = require("wl_main")
    local wl_play = require("wl_play")
    local wl_state = require("wl_state")

    wl_agent.ControlMovement(ob)

    local gs = wl_main.gamestate
    local cur = gs.attackframe
    local weapon = gs.weapon
    if weapon < 0 then weapon = 0 end
    if weapon > 3 then weapon = 3 end

    local info = wl_agent.attackinfo[weapon]
    if not info or not info[cur + 1] then
        -- Attack done
        gs.attackframe = 0
        gs.weaponframe = 0
        wl_state.NewState(ob, wl_agent.s_player)
        return
    end

    local frame = info[cur + 1]
    gs.attackcount = gs.attackcount - wl_main.tics
    while gs.attackcount <= 0 do
        cur = cur + 1
        if not info[cur + 1] or info[cur + 1][2] == -1 then
            -- Attack done
            gs.attackframe = 0
            gs.weaponframe = 0
            wl_state.NewState(ob, wl_agent.s_player)
            return
        end

        frame = info[cur + 1]
        gs.attackframe = cur
        gs.attackcount = gs.attackcount + frame[1]
        gs.weaponframe = frame[3]

        -- Fire shot
        if frame[2] > 0 and frame[2] ~= 2 then
            wl_agent.GunAttack(ob)
        elseif frame[2] == 2 then
            wl_agent.KnifeAttack(ob)
        end
    end
end
wl_agent.s_attack.think = wl_agent.T_Attack

---------------------------------------------------------------------------
-- Cmd_Fire / Cmd_Use
---------------------------------------------------------------------------

function wl_agent.Cmd_Fire()
    local wl_main  = require("wl_main")
    local wl_play  = require("wl_play")
    local wl_state = require("wl_state")

    local gs = wl_main.gamestate

    if gs.weapon ~= wl_def.wp_knife and gs.ammo <= 0 then
        return
    end

    gs.attackframe = 0
    gs.attackcount = wl_agent.attackinfo[gs.weapon][1][1]
    gs.weaponframe = wl_agent.attackinfo[gs.weapon][1][3]

    wl_state.NewState(wl_play.player, wl_agent.s_attack)

    -- Play attack sound
    if gs.weapon == wl_def.wp_knife then
        id_sd.SD_PlaySound(audiowl6.ATKKNIFESND)
    elseif gs.weapon == wl_def.wp_pistol then
        id_sd.SD_PlaySound(audiowl6.ATKPISTOLSND)
    elseif gs.weapon == wl_def.wp_machinegun then
        id_sd.SD_PlaySound(audiowl6.ATKMACHINEGUNSND)
    elseif gs.weapon == wl_def.wp_chaingun then
        id_sd.SD_PlaySound(audiowl6.ATKGATLINGSND)
    end
end

function wl_agent.Cmd_Use()
    local wl_main = require("wl_main")
    local wl_play = require("wl_play")
    local wl_act1 = require("wl_act1")

    local player = wl_play.player
    if not player then return end

    local checkx = player.tilex
    local checky = player.tiley

    -- Check in front of player for doors/pushwalls
    local angle = player.angle
    if angle < 45 or angle >= 315 then
        checkx = checkx + 1  -- facing east
    elseif angle < 135 then
        checky = checky - 1  -- facing north
    elseif angle < 225 then
        checkx = checkx - 1  -- facing west
    else
        checky = checky + 1  -- facing south
    end

    if checkx < 0 or checkx >= wl_def.MAPSIZE or checky < 0 or checky >= wl_def.MAPSIZE then
        return
    end

    local tile = wl_main.tilemap[checkx][checky]

    -- Check for door
    if band(tile, 0x80) ~= 0 then
        local doornum = band(tile, 0x3F)
        wl_act1.OperateDoor(doornum)
        return
    end

    -- Check for pushwall
    if tile == wl_def.PUSHABLETILE then
        local dir
        if checkx > player.tilex then dir = wl_def.di_east
        elseif checkx < player.tilex then dir = wl_def.di_west
        elseif checky > player.tiley then dir = wl_def.di_south
        else dir = wl_def.di_north end
        wl_act1.PushWall(checkx, checky, dir)
    end
end

---------------------------------------------------------------------------
-- GunAttack / KnifeAttack
---------------------------------------------------------------------------

function wl_agent.GunAttack(ob)
    local wl_main = require("wl_main")
    local wl_play = require("wl_play")
    local wl_state = require("wl_state")

    if wl_main.gamestate.ammo > 0 then
        wl_main.gamestate.ammo = wl_main.gamestate.ammo - 1
        wl_agent.DrawAmmo()
    end

    wl_play.madenoise = true

    -- Screen-space hit detection (original Wolf3D algorithm)
    -- Uses viewx (screen x), transx (depth) set by TransformActor/DrawScaleds
    local player = wl_play.player
    if not player then return end

    local centerx = wl_main.centerx
    local shootdelta = wl_main.shootdelta

    local viewdist = 0x7FFFFFFF
    local closest = nil

    local ob_iter = player.next
    while ob_iter do
        if ob_iter.flags and
           band(ob_iter.flags, wl_def.FL_SHOOTABLE) ~= 0 and
           band(ob_iter.flags, wl_def.FL_VISABLE) ~= 0 and
           ob_iter.viewx then
            if math.abs(ob_iter.viewx - centerx) < shootdelta then
                if ob_iter.transx and ob_iter.transx < viewdist then
                    viewdist = ob_iter.transx
                    closest = ob_iter
                end
            end
        end
        ob_iter = ob_iter.next
    end

    if closest then
        -- Verify line of sight
        if wl_state.CheckLine(closest) then
            -- Damage by distance (in tile units: transx >> TILESHIFT)
            local dist = rshift(viewdist, wl_def.TILESHIFT)
            local damage

            if dist < 2 then
                damage = rshift(id_us.US_RndT(), 4)
            elseif dist < 4 then
                damage = rshift(id_us.US_RndT(), 6)
            else
                if id_us.US_RndT() < 128 then
                    return  -- miss at long range
                end
                damage = rshift(id_us.US_RndT(), 6)
            end

            if damage < 1 then damage = 1 end

            id_sd.SD_PlaySound(audiowl6.HITENEMYSND)
            wl_state.DamageActor(closest, damage)
        end
    end
end

function wl_agent.KnifeAttack(ob)
    local wl_play = require("wl_play")

    local player = wl_play.player
    if not player then return end

    -- Check for enemy within melee range (1 tile)
    local ob_iter = player.next
    while ob_iter do
        if ob_iter.flags and band(ob_iter.flags, wl_def.FL_SHOOTABLE) ~= 0 then
            local dx = math.abs(ob_iter.tilex - player.tilex)
            local dy = math.abs(ob_iter.tiley - player.tiley)
            if dx <= 1 and dy <= 1 then
                local damage = rshift(id_us.US_RndT(), 4)
                id_sd.SD_PlaySound(audiowl6.HITENEMYSND)
                local wl_state = require("wl_state")
                wl_state.DamageActor(ob_iter, damage)
                return
            end
        end
        ob_iter = ob_iter.next
    end
end

---------------------------------------------------------------------------
-- CheckWeaponChange
---------------------------------------------------------------------------

function wl_agent.CheckWeaponChange()
    local wl_main = require("wl_main")
    local wl_play = require("wl_play")

    if wl_main.gamestate.ammo == 0 then return end

    for i = wl_def.wp_knife, wl_main.gamestate.bestweapon do
        local bt = wl_def.bt_readyknife + i - wl_def.wp_knife
        if wl_play.buttonstate[bt] then
            wl_main.gamestate.weapon = i
            wl_main.gamestate.chosenweapon = i
            wl_agent.DrawWeapon()
            return
        end
    end
end

---------------------------------------------------------------------------
-- GetBonus - pick up a bonus item
---------------------------------------------------------------------------

function wl_agent.GetBonus(statptr)
    local wl_main = require("wl_main")
    local wl_play = require("wl_play")

    local item = statptr.itemnumber
    local gs = wl_main.gamestate

    if item == wl_def.bo_firstaid then
        if gs.health >= 100 then return end
        id_sd.SD_PlaySound(audiowl6.HEALTH2SND)
        wl_agent.HealSelf(25)
    elseif item == wl_def.bo_key1 then
        wl_agent.GiveKey(0)
        id_sd.SD_PlaySound(audiowl6.GETKEYSND)
    elseif item == wl_def.bo_key2 then
        wl_agent.GiveKey(1)
        id_sd.SD_PlaySound(audiowl6.GETKEYSND)
    elseif item == wl_def.bo_key3 then
        wl_agent.GiveKey(2)
        id_sd.SD_PlaySound(audiowl6.GETKEYSND)
    elseif item == wl_def.bo_key4 then
        wl_agent.GiveKey(3)
        id_sd.SD_PlaySound(audiowl6.GETKEYSND)
    elseif item == wl_def.bo_cross then
        id_sd.SD_PlaySound(audiowl6.BONUS1SND)
        wl_agent.GivePoints(100)
        gs.treasurecount = gs.treasurecount + 1
    elseif item == wl_def.bo_chalice then
        id_sd.SD_PlaySound(audiowl6.BONUS2SND)
        wl_agent.GivePoints(500)
        gs.treasurecount = gs.treasurecount + 1
    elseif item == wl_def.bo_bible then
        id_sd.SD_PlaySound(audiowl6.BONUS3SND)
        wl_agent.GivePoints(1000)
        gs.treasurecount = gs.treasurecount + 1
    elseif item == wl_def.bo_crown then
        id_sd.SD_PlaySound(audiowl6.BONUS4SND)
        wl_agent.GivePoints(5000)
        gs.treasurecount = gs.treasurecount + 1
    elseif item == wl_def.bo_clip then
        if gs.ammo >= 99 then return end
        id_sd.SD_PlaySound(audiowl6.GETAMMOSND)
        wl_agent.GiveAmmo(8)
    elseif item == wl_def.bo_clip2 then
        if gs.ammo >= 99 then return end
        id_sd.SD_PlaySound(audiowl6.GETAMMOSND)
        wl_agent.GiveAmmo(4)
    elseif item == wl_def.bo_25clip then
        if gs.ammo >= 99 then return end
        id_sd.SD_PlaySound(audiowl6.GETAMMOSND)
        wl_agent.GiveAmmo(25)
    elseif item == wl_def.bo_machinegun then
        id_sd.SD_PlaySound(audiowl6.GETMACHINESND)
        wl_agent.GiveWeapon(wl_def.wp_machinegun)
    elseif item == wl_def.bo_chaingun then
        id_sd.SD_PlaySound(audiowl6.GETGATLINGSND)
        wl_agent.GiveWeapon(wl_def.wp_chaingun)
    elseif item == wl_def.bo_food then
        if gs.health >= 100 then return end
        id_sd.SD_PlaySound(audiowl6.HEALTH1SND)
        wl_agent.HealSelf(10)
    elseif item == wl_def.bo_alpo then
        if gs.health >= 100 then return end
        id_sd.SD_PlaySound(audiowl6.HEALTH1SND)
        wl_agent.HealSelf(4)
    elseif item == wl_def.bo_fullheal then
        id_sd.SD_PlaySound(audiowl6.BONUS1UPSND)
        wl_agent.HealSelf(99)
        wl_agent.GiveAmmo(25)
        gs.treasurecount = gs.treasurecount + 1
        if gs.lives < 9 then gs.lives = gs.lives + 1 end
        wl_agent.DrawLives()
    elseif item == wl_def.bo_gibs then
        return  -- no pickup
    else
        return
    end

    wl_play.StartBonusFlash()

    -- Remove the item
    statptr.shapenum = -1
end

---------------------------------------------------------------------------
-- Point/item giving
---------------------------------------------------------------------------

function wl_agent.GivePoints(points)
    local wl_main = require("wl_main")
    wl_main.gamestate.score = wl_main.gamestate.score + points
    while wl_main.gamestate.score >= wl_main.gamestate.nextextra do
        wl_main.gamestate.nextextra = wl_main.gamestate.nextextra + wl_def.EXTRAPOINTS
        if wl_main.gamestate.lives < 9 then
            wl_main.gamestate.lives = wl_main.gamestate.lives + 1
            id_sd.SD_PlaySound(audiowl6.BONUS1UPSND)
            wl_agent.DrawLives()
        end
    end
    wl_agent.DrawScore()
end

function wl_agent.GiveWeapon(weapon)
    local wl_main = require("wl_main")
    wl_agent.GiveAmmo(6)
    if weapon > wl_main.gamestate.bestweapon then
        wl_main.gamestate.bestweapon = weapon
    end
    wl_main.gamestate.weapon = weapon
    wl_main.gamestate.chosenweapon = weapon
    wl_agent.DrawWeapon()
end

function wl_agent.GiveAmmo(ammo)
    local wl_main = require("wl_main")
    if wl_main.gamestate.ammo == 0 then
        -- Knife was out, switch to chosen weapon
        if wl_main.gamestate.attackframe == 0 then
            wl_main.gamestate.weapon = wl_main.gamestate.chosenweapon
            wl_agent.DrawWeapon()
        end
    end
    wl_main.gamestate.ammo = wl_main.gamestate.ammo + ammo
    if wl_main.gamestate.ammo > 99 then
        wl_main.gamestate.ammo = 99
    end
    wl_agent.DrawAmmo()
end

function wl_agent.GiveKey(key)
    local wl_main = require("wl_main")
    wl_main.gamestate.keys = bor(wl_main.gamestate.keys, lshift(1, key))
    wl_agent.DrawKeys()
end

function wl_agent.TakeDamage(points, attacker)
    local wl_main = require("wl_main")
    local wl_play = require("wl_play")

    wl_agent.LastAttacker = attacker

    if wl_main.gamestate.victoryflag then return end
    if wl_main.gamestate.difficulty == wl_def.gd_baby then
        points = rshift(points, 2)
    end

    if not wl_play.godmode then
        wl_main.gamestate.health = wl_main.gamestate.health - points
    end

    if wl_main.gamestate.health <= 0 then
        wl_main.gamestate.health = 0
        wl_main.playstate = wl_def.ex_died
        wl_play.killerobj = attacker
    end

    wl_play.StartDamageFlash(points)
    wl_agent.gotgatgun = 0
    wl_agent.DrawHealth()
    wl_agent.DrawFace()
end

function wl_agent.HealSelf(points)
    local wl_main = require("wl_main")
    wl_main.gamestate.health = wl_main.gamestate.health + points
    if wl_main.gamestate.health > 100 then
        wl_main.gamestate.health = 100
    end
    wl_agent.DrawHealth()
    wl_agent.gotgatgun = 0
    wl_agent.DrawFace()
end

---------------------------------------------------------------------------
-- HUD Drawing functions - StatusDrawPic, LatchNumber, then high-level
-- x,y are in latch tile units (each unit = 8 pixels)
-- Status bar occupies bottom 40 lines (y=160..199)
---------------------------------------------------------------------------

function wl_agent.StatusDrawPic(x, y, picnum)
    local id_vh = require("id_vh")
    -- x in tile units (8 pixels), y in pixels from top of status bar
    -- Status bar starts at screen y = 160
    local sx = x * 8
    local sy = 160 + y
    id_vh.VWB_DrawPic(sx, sy, picnum)
end

function wl_agent.LatchNumber(x, y, width, number)
    local str = tostring(math.floor(math.abs(number)))
    local length = #str

    -- Pad with blanks on the left
    while length < width do
        wl_agent.StatusDrawPic(x, y, gfx.N_BLANKPIC)
        x = x + 1
        width = width - 1
    end

    -- Start position if number is wider than width
    local c = 1
    if length > width then
        c = length - width + 1
    end

    while c <= length do
        local digit = string.byte(str, c) - string.byte("0")
        wl_agent.StatusDrawPic(x, y, gfx.N_0PIC + digit)
        x = x + 1
        c = c + 1
    end
end

---------------------------------------------------------------------------
-- DrawFace - draw BJ's face in the status bar
-- Face pics: FACE1APIC through FACE8APIC
-- 3 frames per row (A, B, C), 8 health ranges (7 alive + 1 dead)
-- Row = (100 - health) / 16, clamped 0..6 for alive
---------------------------------------------------------------------------

function wl_agent.DrawFace()
    local wl_main = require("wl_main")
    local wl_play = require("wl_play")
    local gs = wl_main.gamestate

    if gs.health > 0 then
        if wl_agent.gotgatgun ~= 0 and wl_play.godmode then
            -- Got gatling gun face
            wl_agent.StatusDrawPic(17, 4, gfx.GOTGATLINGPIC)
        else
            local healthrow = math.floor((100 - gs.health) / 16)
            if healthrow < 0 then healthrow = 0 end
            if healthrow > 6 then healthrow = 6 end
            local faceframe = gs.faceframe or 0
            if faceframe > 2 then faceframe = 0 end
            wl_agent.StatusDrawPic(17, 4, gfx.FACE1APIC + 3 * healthrow + faceframe)
        end
    else
        -- Dead face
        if wl_agent.LastAttacker and wl_agent.LastAttacker.obclass == wl_def.needleobj then
            wl_agent.StatusDrawPic(17, 4, gfx.MUTANTBJPIC)
        else
            wl_agent.StatusDrawPic(17, 4, gfx.FACE8APIC)
        end
    end
end

function wl_agent.UpdateFace()
    local wl_main = require("wl_main")

    -- Don't change face while gatling gun sound plays
    if id_sd.SD_SoundPlaying() == audiowl6.GETGATLINGSND then
        return
    end

    wl_agent.facecount = wl_agent.facecount + wl_main.tics
    if wl_agent.facecount > (id_us.US_RndT() or 128) then
        local gs = wl_main.gamestate
        gs.faceframe = rshift(id_us.US_RndT(), 6)
        if gs.faceframe == 3 then gs.faceframe = 1 end

        wl_agent.facecount = 0
        wl_agent.DrawFace()
    end
end

function wl_agent.DrawHealth()
    local wl_main = require("wl_main")
    wl_agent.LatchNumber(21, 16, 3, wl_main.gamestate.health)
end

function wl_agent.DrawLives()
    local wl_main = require("wl_main")
    wl_agent.LatchNumber(14, 16, 1, wl_main.gamestate.lives)
end

function wl_agent.DrawLevel()
    local wl_main = require("wl_main")
    wl_agent.LatchNumber(2, 16, 2, wl_main.gamestate.mapon + 1)
end

function wl_agent.DrawAmmo()
    local wl_main = require("wl_main")
    wl_agent.LatchNumber(27, 16, 2, wl_main.gamestate.ammo)
end

function wl_agent.DrawScore()
    local wl_main = require("wl_main")
    wl_agent.LatchNumber(6, 16, 6, wl_main.gamestate.score)
end

function wl_agent.DrawWeapon()
    local wl_main = require("wl_main")
    wl_agent.StatusDrawPic(32, 8, gfx.KNIFEPIC + wl_main.gamestate.weapon)
end

function wl_agent.DrawKeys()
    local wl_main = require("wl_main")

    if band(wl_main.gamestate.keys, 1) ~= 0 then
        wl_agent.StatusDrawPic(30, 4, gfx.GOLDKEYPIC)
    else
        wl_agent.StatusDrawPic(30, 4, gfx.NOKEYPIC)
    end

    if band(wl_main.gamestate.keys, 2) ~= 0 then
        wl_agent.StatusDrawPic(30, 20, gfx.SILVERKEYPIC)
    else
        wl_agent.StatusDrawPic(30, 20, gfx.NOKEYPIC)
    end
end

---------------------------------------------------------------------------
-- DrawAllHUD - convenience to draw all HUD elements at once
---------------------------------------------------------------------------

function wl_agent.DrawAllHUD()
    wl_agent.DrawFace()
    wl_agent.DrawHealth()
    wl_agent.DrawLives()
    wl_agent.DrawLevel()
    wl_agent.DrawAmmo()
    wl_agent.DrawScore()
    wl_agent.DrawWeapon()
    wl_agent.DrawKeys()
end

return wl_agent
