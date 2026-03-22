-- WL_GAME.lua
-- Game loop management - ported from WL_GAME.C
-- Handles level setup, game loop, play screen drawing

local bit = require("bit")
local band, bor, bxor, lshift, rshift = bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift

local wl_def  = require("wl_def")
local id_vl   = require("id_vl")
local id_vh   = require("id_vh")
local id_in   = require("id_in")
local id_sd   = require("id_sd")
local id_ca   = require("id_ca")
local id_us   = require("id_us")
local gfx     = require("gfxv_wl6")
local audiowl6 = require("audiowl6")

local wl_game = {}

---------------------------------------------------------------------------
-- Game state
---------------------------------------------------------------------------
wl_game.ingame    = false
wl_game.fizzlein  = false
wl_game.doornum   = 0

-- Pushwall state
wl_game.pwallstate = 0
wl_game.pwallx     = 0
wl_game.pwally     = 0
wl_game.pwalldir   = 0
wl_game.pwallpos   = 0

-- Door positions (0-indexed)
wl_game.doorposition = {}
for i = 0, wl_def.MAXDOORS - 1 do
    wl_game.doorposition[i] = 0
end

-- Door objects (0-indexed)
wl_game.doorobjlist = {}
for i = 0, wl_def.MAXDOORS - 1 do
    wl_game.doorobjlist[i] = wl_def.new_doorobj()
end

-- Area connectivity (0-indexed)
wl_game.areaconnect = {}
wl_game.areabyplayer = {}
for i = 0, wl_def.NUMAREAS - 1 do
    wl_game.areabyplayer[i] = false
    wl_game.areaconnect[i] = {}
    for j = 0, wl_def.NUMAREAS - 1 do
        wl_game.areaconnect[i][j] = 0
    end
end

-- Elevator back maps
wl_game.ElevatorBackTo = {1,1,7,3,5,3}

-- Music songs per level (WL6)
wl_game.songs = {
    audiowl6.GETTHEM_MUS, audiowl6.SEARCHN_MUS, audiowl6.POW_MUS, audiowl6.SUSPENSE_MUS,
    audiowl6.GETTHEM_MUS, audiowl6.SEARCHN_MUS, audiowl6.POW_MUS, audiowl6.SUSPENSE_MUS,
    audiowl6.WARMARCH_MUS, audiowl6.CORNER_MUS,
    audiowl6.NAZI_OMI_MUS, audiowl6.PREGNANT_MUS, audiowl6.GOINGAFT_MUS, audiowl6.HEADACHE_MUS,
    audiowl6.NAZI_OMI_MUS, audiowl6.PREGNANT_MUS, audiowl6.HEADACHE_MUS, audiowl6.GOINGAFT_MUS,
    audiowl6.WARMARCH_MUS, audiowl6.DUNGEON_MUS,
    audiowl6.INTROCW3_MUS, audiowl6.NAZI_RAP_MUS, audiowl6.TWELFTH_MUS, audiowl6.ZEROHOUR_MUS,
    audiowl6.INTROCW3_MUS, audiowl6.NAZI_RAP_MUS, audiowl6.TWELFTH_MUS, audiowl6.ZEROHOUR_MUS,
    audiowl6.ULTIMATE_MUS, audiowl6.PACMAN_MUS,
    audiowl6.GETTHEM_MUS, audiowl6.SEARCHN_MUS, audiowl6.POW_MUS, audiowl6.SUSPENSE_MUS,
    audiowl6.GETTHEM_MUS, audiowl6.SEARCHN_MUS, audiowl6.POW_MUS, audiowl6.SUSPENSE_MUS,
    audiowl6.WARMARCH_MUS, audiowl6.CORNER_MUS,
    audiowl6.NAZI_OMI_MUS, audiowl6.PREGNANT_MUS, audiowl6.GOINGAFT_MUS, audiowl6.HEADACHE_MUS,
    audiowl6.NAZI_OMI_MUS, audiowl6.PREGNANT_MUS, audiowl6.HEADACHE_MUS, audiowl6.GOINGAFT_MUS,
    audiowl6.WARMARCH_MUS, audiowl6.DUNGEON_MUS,
    audiowl6.INTROCW3_MUS, audiowl6.NAZI_RAP_MUS, audiowl6.TWELFTH_MUS, audiowl6.ZEROHOUR_MUS,
    audiowl6.INTROCW3_MUS, audiowl6.NAZI_RAP_MUS, audiowl6.TWELFTH_MUS, audiowl6.ZEROHOUR_MUS,
    audiowl6.ULTIMATE_MUS, audiowl6.FUNKYOU_MUS,
}

---------------------------------------------------------------------------
-- ScanInfoPlane - parse map plane 1 for actors, items, player start
---------------------------------------------------------------------------

function wl_game.ScanInfoPlane()
    local wl_main  = require("wl_main")
    local wl_act1  = require("wl_act1")
    local wl_agent = require("wl_agent")

    if not id_ca.mapsegs or not id_ca.mapsegs[2] then return end

    local mapdata = id_ca.mapsegs[2]
    local mapw = wl_main.mapwidth
    local maph = wl_main.mapheight

    for y = 0, maph - 1 do
        for x = 0, mapw - 1 do
            local idx = y * mapw + x + 1  -- 1-indexed
            local tile = mapdata[idx] or 0
            if tile == 0 then goto continue end

            -- Player start (19-22)
            if tile >= 19 and tile <= 22 then
                wl_agent.SpawnPlayer(x, y, wl_def.NORTH + tile - 19)

            -- Static objects (23-74)
            elseif tile >= 23 and tile <= 74 then
                wl_act1.SpawnStatic(x, y, tile - 23)

            -- Pushwall marker
            elseif tile == 98 then
                if not wl_main.loadedgame then
                    wl_main.gamestate.secrettotal = wl_main.gamestate.secrettotal + 1
                end

            -- Guard stand (hard)
            elseif tile >= 180 and tile <= 183 then
                if wl_main.gamestate.difficulty >= wl_def.gd_hard then
                    wl_act1.SpawnStand(wl_def.en_guard, x, y, tile - 180 + 36 - 36)
                end
            -- Guard stand (medium)
            elseif tile >= 144 and tile <= 147 then
                if wl_main.gamestate.difficulty >= wl_def.gd_medium then
                    wl_act1.SpawnStand(wl_def.en_guard, x, y, tile - 144 + 36 - 36)
                end
            -- Guard stand (easy)
            elseif tile >= 108 and tile <= 111 then
                wl_act1.SpawnStand(wl_def.en_guard, x, y, tile - 108)

            -- Guard patrol
            elseif tile >= 112 and tile <= 115 then
                wl_act1.SpawnPatrol(wl_def.en_guard, x, y, tile - 112)

            -- Dead guard
            elseif tile == 124 then
                wl_act1.SpawnDeadGuard(x, y)

            -- Officer stand
            elseif tile >= 116 and tile <= 119 then
                wl_act1.SpawnStand(wl_def.en_officer, x, y, tile - 116)
            elseif tile >= 120 and tile <= 123 then
                wl_act1.SpawnPatrol(wl_def.en_officer, x, y, tile - 120)

            -- SS stand
            elseif tile >= 126 and tile <= 129 then
                wl_act1.SpawnStand(wl_def.en_ss, x, y, tile - 126)
            elseif tile >= 130 and tile <= 133 then
                wl_act1.SpawnPatrol(wl_def.en_ss, x, y, tile - 130)

            -- Dog stand
            elseif tile >= 134 and tile <= 137 then
                wl_act1.SpawnStand(wl_def.en_dog, x, y, tile - 134)
            elseif tile >= 138 and tile <= 141 then
                wl_act1.SpawnPatrol(wl_def.en_dog, x, y, tile - 138)

            -- Bosses
            elseif tile == 214 then wl_act1.SpawnBoss(x, y)
            elseif tile == 197 then wl_act1.SpawnGretel(x, y)
            elseif tile == 215 then wl_act1.SpawnGift(x, y)
            elseif tile == 179 then wl_act1.SpawnFat(x, y)
            elseif tile == 196 then wl_act1.SpawnSchabbs(x, y)
            elseif tile == 160 then wl_act1.SpawnFakeHitler(x, y)
            elseif tile == 178 then wl_act1.SpawnHitler(x, y)

            -- Mutant stand
            elseif tile >= 216 and tile <= 219 then
                wl_act1.SpawnStand(wl_def.en_mutant, x, y, tile - 216)
            elseif tile >= 220 and tile <= 223 then
                wl_act1.SpawnPatrol(wl_def.en_mutant, x, y, tile - 220)

            -- Ghosts
            elseif tile == 224 then wl_act1.SpawnGhosts(wl_def.en_blinky, x, y)
            elseif tile == 225 then wl_act1.SpawnGhosts(wl_def.en_clyde, x, y)
            elseif tile == 226 then wl_act1.SpawnGhosts(wl_def.en_pinky, x, y)
            elseif tile == 227 then wl_act1.SpawnGhosts(wl_def.en_inky, x, y)
            end

            ::continue::
        end
    end
end

---------------------------------------------------------------------------
-- SetupGameLevel
---------------------------------------------------------------------------

function wl_game.SetupGameLevel()
    local wl_main  = require("wl_main")
    local wl_play  = require("wl_play")
    local wl_act1  = require("wl_act1")

    local gs = wl_main.gamestate

    if not wl_main.loadedgame then
        gs.TimeCount = 0
        gs.secrettotal = 0
        gs.killtotal = 0
        gs.treasuretotal = 0
        gs.secretcount = 0
        gs.killcount = 0
        gs.treasurecount = 0
    end

    -- Load the map
    local mapnum = gs.mapon + gs.episode * 10
    id_ca.CA_CacheMap(mapnum)

    wl_main.mapwidth = 64
    wl_main.mapheight = 64

    -- Copy wall data, init tilemap and actorat
    for x = 0, wl_def.MAPSIZE - 1 do
        for y = 0, wl_def.MAPSIZE - 1 do
            wl_main.tilemap[x][y] = 0
            wl_main.actorat[x][y] = nil
            wl_main.spotvis[x][y] = 0
        end
    end

    if id_ca.mapsegs and id_ca.mapsegs[1] then
        local mapdata = id_ca.mapsegs[1]
        for y = 0, 63 do
            for x = 0, 63 do
                local idx = y * 64 + x + 1
                local tile = mapdata[idx] or 0
                if tile < wl_def.AREATILE then
                    -- Solid wall
                    wl_main.tilemap[x][y] = tile
                    wl_main.actorat[x][y] = tile
                end
            end
        end
    end

    -- Init actor, door, static lists
    wl_play.InitActorList()
    wl_act1.InitDoorList()
    wl_act1.InitStaticList()

    -- Spawn doors
    if id_ca.mapsegs and id_ca.mapsegs[1] then
        local mapdata = id_ca.mapsegs[1]
        for y = 0, 63 do
            for x = 0, 63 do
                local idx = y * 64 + x + 1
                local tile = mapdata[idx] or 0
                if tile >= 90 and tile <= 101 then
                    if tile % 2 == 0 then
                        -- Vertical door
                        wl_act1.SpawnDoor(x, y, true, math.floor((tile - 90) / 2))
                    else
                        -- Horizontal door
                        wl_act1.SpawnDoor(x, y, false, math.floor((tile - 91) / 2))
                    end
                end
            end
        end
    end

    -- Spawn actors
    wl_game.ScanInfoPlane()

    -- Handle ambush tiles
    if id_ca.mapsegs and id_ca.mapsegs[1] then
        local mapdata = id_ca.mapsegs[1]
        for y = 0, 63 do
            for x = 0, 63 do
                local idx = y * 64 + x + 1
                local tile = mapdata[idx] or 0
                if tile == wl_def.AMBUSHTILE then
                    wl_main.tilemap[x][y] = 0
                    if wl_main.actorat[x][y] == wl_def.AMBUSHTILE then
                        wl_main.actorat[x][y] = nil
                    end
                end
            end
        end
    end

    -- Init areas
    wl_act1.InitAreas()

    -- Reset pushwall
    wl_game.pwallstate = 0
    wl_game.pwallpos = 0
end

---------------------------------------------------------------------------
-- DrawPlayBorder / DrawPlayScreen
---------------------------------------------------------------------------

function wl_game.DrawPlayBorder()
    local wl_main = require("wl_main")

    id_vh.VWB_Bar(0, 0, 320, 200 - wl_def.STATUSLINES, 127)

    local xl = 160 - math.floor(wl_main.viewwidth / 2)
    local yl = math.floor((200 - wl_def.STATUSLINES - wl_main.viewheight) / 2)

    id_vh.VWB_Bar(xl, yl, wl_main.viewwidth, wl_main.viewheight, 0)
    id_vh.VWB_Hlin(xl - 1, xl + wl_main.viewwidth, yl - 1, 0)
    id_vh.VWB_Hlin(xl - 1, xl + wl_main.viewwidth, yl + wl_main.viewheight, 125)
    id_vh.VWB_Vlin(yl - 1, yl + wl_main.viewheight, xl - 1, 0)
    id_vh.VWB_Vlin(yl - 1, yl + wl_main.viewheight, xl + wl_main.viewwidth, 125)
end

function wl_game.DrawPlayScreen()
    local wl_main  = require("wl_main")
    local wl_agent = require("wl_agent")

    id_vh.VW_FadeOut()
    wl_game.DrawPlayBorder()

    -- Draw status bar
    id_ca.CA_CacheGrChunk(gfx.STATUSBARPIC)
    id_vh.VWB_DrawPic(0, 200 - wl_def.STATUSLINES, gfx.STATUSBARPIC)

    wl_agent.DrawFace()
    wl_agent.DrawHealth()
    wl_agent.DrawLives()
    wl_agent.DrawLevel()
    wl_agent.DrawAmmo()
    wl_agent.DrawKeys()
    wl_agent.DrawWeapon()
    wl_agent.DrawScore()
end

function wl_game.DrawAllPlayBorder()
    wl_game.DrawPlayBorder()
end

function wl_game.DrawAllPlayBorderSides()
    -- stub
end

---------------------------------------------------------------------------
-- ClearMemory / NormalScreen / FizzleOut
---------------------------------------------------------------------------

function wl_game.ClearMemory()
    id_sd.SD_StopDigitized()
    id_sd.SD_StopSound()
    id_sd.SD_MusicOff()
end

function wl_game.NormalScreen()
    id_vl.VL_SetLineWidth(40)
end

function wl_game.FizzleOut()
    id_vh.VW_UpdateScreen()
end

---------------------------------------------------------------------------
-- StartMusic / StopMusic
---------------------------------------------------------------------------

function wl_game.StartMusic()
    local wl_main = require("wl_main")
    local wl_menu = require("wl_menu")

    local gs = wl_main.gamestate
    local song_idx = gs.mapon + gs.episode * 10
    local chunk = wl_game.songs[song_idx + 1]

    if chunk then
        wl_menu.StartCPMusic(chunk)
    end
end

function wl_game.StopMusic()
    id_sd.SD_MusicOff()
end

---------------------------------------------------------------------------
-- GameLoop - main game loop
---------------------------------------------------------------------------

function wl_game.GameLoop()
    local wl_main  = require("wl_main")
    local wl_play  = require("wl_play")
    local wl_draw  = require("wl_draw")
    local wl_scale = require("wl_scale")
    local wl_inter = require("wl_inter")

    wl_game.ClearMemory()
    wl_main.SETFONTCOLOR(0, 15)
    wl_game.DrawPlayScreen()

    local died = false

    -- Main game restart loop
    while true do
        if not wl_main.loadedgame then
            wl_main.gamestate.score = wl_main.gamestate.oldscore
        end

        wl_main.startgame = false
        if wl_main.loadedgame then
            wl_main.loadedgame = false
        else
            wl_game.SetupGameLevel()
        end

        wl_game.ingame = true
        wl_game.StartMusic()

        if not died then
            wl_inter.PreloadGraphics()
        else
            died = false
        end

        wl_main.fizzlein = true

        -- Setup scaling for sprites
        wl_scale.SetupScaling(wl_main.viewheight * 2)

        -- Play loop
        wl_play.PlayLoop()

        wl_game.StopMusic()
        wl_game.ingame = false

        -- Handle play result
        local ps = wl_main.playstate
        if ps == wl_def.ex_completed or ps == wl_def.ex_secretlevel then
            wl_main.gamestate.oldscore = wl_main.gamestate.score
            wl_inter.LevelCompleted()
            wl_main.gamestate.mapon = wl_main.gamestate.mapon + 1
            if wl_main.gamestate.mapon >= 10 then
                -- Episode completed
                wl_inter.Victory()
                break
            end
        elseif ps == wl_def.ex_died then
            died = true
            wl_main.gamestate.lives = wl_main.gamestate.lives - 1
            if wl_main.gamestate.lives < 0 then
                -- Game over
                break
            end
            wl_main.gamestate.health = 100
            wl_main.gamestate.weapon = wl_def.wp_pistol
            wl_main.gamestate.bestweapon = wl_def.wp_pistol
            wl_main.gamestate.chosenweapon = wl_def.wp_pistol
            wl_main.gamestate.ammo = wl_def.STARTAMMO
            wl_main.gamestate.keys = 0
            wl_main.gamestate.attackframe = 0
            wl_main.gamestate.attackcount = 0
            wl_main.gamestate.weaponframe = 0
        elseif ps == wl_def.ex_victorious then
            wl_inter.Victory()
            break
        elseif ps == wl_def.ex_abort then
            break
        elseif ps == wl_def.ex_resetgame or ps == wl_def.ex_loadedgame then
            break
        else
            break
        end
    end

    wl_game.ClearMemory()
end

---------------------------------------------------------------------------
-- PlayDemo / DrawHighScores
---------------------------------------------------------------------------

function wl_game.PlayDemo(demonumber)
    local wl_main = require("wl_main")
    wl_main.playstate = wl_def.ex_demodone
end

function wl_game.RecordDemo()
end

function wl_game.DrawHighScores()
    id_ca.CA_CacheScreen(gfx.HIGHSCORESPIC)
end

return wl_game
