-- WL_ACT1.lua
-- Actor spawning and static objects - ported from WL_ACT1.C
-- Handles spawning of all object types, door management

local wl_def = require("wl_def")

local wl_act1 = {}

-- Static info table: maps tile value to {sprite, type}
-- This would contain all the static object definitions
wl_act1.statinfo = {}

-- Door opening/closing speed
wl_act1.OPENTICS = 300

---------------------------------------------------------------------------
-- Spawn functions (stubs)
---------------------------------------------------------------------------

function wl_act1.SpawnStand(enemy, tilex, tiley, dir)
end

function wl_act1.SpawnPatrol(enemy, tilex, tiley, dir)
end

function wl_act1.SpawnDeadGuard(tilex, tiley)
end

function wl_act1.SpawnBoss(tilex, tiley)
end

function wl_act1.SpawnGretel(tilex, tiley)
end

function wl_act1.SpawnSchabbs(tilex, tiley)
end

function wl_act1.SpawnGift(tilex, tiley)
end

function wl_act1.SpawnFat(tilex, tiley)
end

function wl_act1.SpawnFakeHitler(tilex, tiley)
end

function wl_act1.SpawnHitler(tilex, tiley)
end

---------------------------------------------------------------------------
-- Door management (stubs)
---------------------------------------------------------------------------

function wl_act1.OpenDoor(door)
end

function wl_act1.CloseDoor(door)
end

function wl_act1.OperateDoor(door)
end

function wl_act1.DoorOpen(door)
end

function wl_act1.DoorOpening(door)
end

function wl_act1.DoorClosing(door)
end

function wl_act1.MoveDoors()
end

---------------------------------------------------------------------------
-- Pushwall (stub)
---------------------------------------------------------------------------

function wl_act1.PushWall(checkx, checky, dir)
end

function wl_act1.MovePWalls()
end

return wl_act1
