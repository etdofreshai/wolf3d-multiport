-- WL_AGENT.lua
-- Player agent - ported from WL_AGENT.C
-- Handles player movement, weapon firing, item pickup, damage

local wl_def = require("wl_def")

local wl_agent = {}

---------------------------------------------------------------------------
-- Player state functions (stubs)
---------------------------------------------------------------------------

function wl_agent.SpawnPlayer(tilex, tiley, dir)
    local wl_play = require("wl_play")

    local player = wl_play.player
    player.tilex = tilex
    player.tiley = tiley
    player.x = (tilex * 65536) + 32768
    player.y = (tiley * 65536) + 32768
    player.angle = dir * 90
    player.obclass = wl_def.playerobj
    player.active = wl_def.ac_yes
    player.flags = 0
end

function wl_agent.T_Player(ob)
    -- Player think function (movement, firing)
end

function wl_agent.T_Attack(ob)
    -- Player attack think
end

function wl_agent.GivePoints(points)
    local wl_main = require("wl_main")
    wl_main.gamestate.score = wl_main.gamestate.score + points
    while wl_main.gamestate.score >= wl_main.gamestate.nextextra do
        wl_main.gamestate.nextextra = wl_main.gamestate.nextextra + wl_def.EXTRAPOINTS
        wl_main.gamestate.lives = wl_main.gamestate.lives + 1
    end
end

function wl_agent.GiveWeapon(weapon)
    local wl_main = require("wl_main")
    wl_main.gamestate.weapon = weapon
    if weapon > wl_main.gamestate.bestweapon then
        wl_main.gamestate.bestweapon = weapon
    end
    wl_main.gamestate.chosenweapon = weapon
end

function wl_agent.GiveAmmo(ammo)
    local wl_main = require("wl_main")
    wl_main.gamestate.ammo = wl_main.gamestate.ammo + ammo
    if wl_main.gamestate.ammo > 99 then
        wl_main.gamestate.ammo = 99
    end
end

function wl_agent.GiveKey(key)
    local wl_main = require("wl_main")
    local bit = require("bit")
    wl_main.gamestate.keys = bit.bor(wl_main.gamestate.keys, bit.lshift(1, key))
end

function wl_agent.TakeDamage(points, attacker)
    local wl_main = require("wl_main")
    wl_main.gamestate.health = wl_main.gamestate.health - points
    if wl_main.gamestate.health <= 0 then
        wl_main.gamestate.health = 0
        -- Player died
    end
end

function wl_agent.HealSelf(points)
    local wl_main = require("wl_main")
    wl_main.gamestate.health = wl_main.gamestate.health + points
    if wl_main.gamestate.health > 100 then
        wl_main.gamestate.health = 100
    end
end

return wl_agent
