-- WL_MAIN.lua
-- Main game module - ported from WL_MAIN.C
-- Also serves as the Love2D entry point (main.lua requires this)

local bit = require("bit")
local band, bor, lshift, rshift = bit.band, bit.bor, bit.lshift, bit.rshift

local wl_def   = require("wl_def")
local id_vl    = require("id_vl")
local id_vh    = require("id_vh")
local id_in    = require("id_in")
local id_sd    = require("id_sd")
local id_mm    = require("id_mm")
local id_pm    = require("id_pm")
local id_ca    = require("id_ca")
local id_us    = require("id_us")
local gfx      = require("gfxv_wl6")
local audiowl6 = require("audiowl6")
local wl_menu  = require("wl_menu")
local wl_inter = require("wl_inter")

local wl_main = {}

---------------------------------------------------------------------------
-- Constants (from WL_MAIN.C)
---------------------------------------------------------------------------
local FOCALLENGTH = 0x5700
local VIEWGLOBAL  = 0x10000
local VIEWWIDTH   = 256
local VIEWHEIGHT  = 144

---------------------------------------------------------------------------
-- Global variables
---------------------------------------------------------------------------
wl_main.str        = ""
wl_main.str2       = ""
wl_main.tedlevelnum = 0
wl_main.tedlevel   = false
wl_main.nospr      = false
wl_main.IsA386     = true

wl_main.dirangle = {0, 45, 90, 135, 180, 225, 270, 315, 360}

-- Projection variables
wl_main.focallength    = 0
wl_main.screenofs      = 0
wl_main.viewwidth      = 0
wl_main.viewheight     = 0
wl_main.centerx        = 0
wl_main.shootdelta     = 0
wl_main.scale          = 0
wl_main.maxslope       = 0
wl_main.heightnumerator = 0
wl_main.minheightdiv   = 0

wl_main.startgame      = false
wl_main.loadedgame     = false
wl_main.virtualreality = false
wl_main.mouseadjustment = 5

wl_main.configname = "CONFIG.WL6"

-- Math tables
wl_main.pixelangle  = {}   -- [0..MAXVIEWWIDTH-1]
wl_main.finetangent = {}   -- [0..FINEANGLES/4-1]
wl_main.sintable    = {}   -- [0..ANGLES+ANGLEQUAD]
wl_main.costable    = nil  -- Will point into sintable with offset

-- Game state
wl_main.gamestate = wl_def.new_gamestate()

-- Control state
wl_main.mouseenabled  = true
wl_main.joystickenabled = false
wl_main.joypadenabled = false
wl_main.joystickprogressive = false
wl_main.joystickport = 0

wl_main.dirscan = {
    id_in.sc_UpArrow, id_in.sc_RightArrow,
    id_in.sc_DownArrow, id_in.sc_LeftArrow
}

wl_main.buttonscan = {
    id_in.sc_Control, id_in.sc_Alt,
    id_in.sc_RShift, id_in.sc_Space,
    0, 0, 0, 0
}

wl_main.buttonmouse = {0, 1, 2, 3}
wl_main.buttonjoy   = {0, 1, 2, 3}

wl_main.viewsize = 15

-- Wall tables
wl_main.horizwall = {}
wl_main.vertwall  = {}

-- Map lookup tables
wl_main.farmapylookup = {}
wl_main.nearmapylookup = {}

-- Tile data
wl_main.tilemap = {}   -- [x][y] 64x64
wl_main.spotvis = {}   -- [x][y] 64x64
wl_main.actorat = {}   -- [x][y] 64x64

-- Update tables
wl_main.uwidthtable = {}
wl_main.blockstarts = {}
wl_main.update      = {}
wl_main.updateptr   = nil

wl_main.mapwidth  = 0
wl_main.mapheight = 0
wl_main.tics      = 0
wl_main.compatability = false

wl_main.fontcolor = 0
wl_main.backcolor = 15

-- Play state
wl_main.ingame    = false
wl_main.fizzlein  = false
wl_main.playstate = wl_def.ex_stillplaying

-- Screen locations
wl_main.screenloc = {wl_def.PAGE1START, wl_def.PAGE2START, wl_def.PAGE3START}
wl_main.freelatch = wl_def.FREESTART

-- Frame timing
wl_main.lasttimecount = 0
wl_main.frameon       = 0

-- Wall height buffer
wl_main.wallheight = {}
for i = 0, wl_def.MAXVIEWWIDTH - 1 do
    wl_main.wallheight[i] = 0
end

-- View variables
wl_main.viewx     = 0
wl_main.viewy     = 0
wl_main.viewangle = 0
wl_main.viewsin   = 0
wl_main.viewcos   = 0

-- Init 2D arrays
for x = 0, wl_def.MAPSIZE - 1 do
    wl_main.tilemap[x] = {}
    wl_main.spotvis[x] = {}
    wl_main.actorat[x] = {}
    for y = 0, wl_def.MAPSIZE - 1 do
        wl_main.tilemap[x][y] = 0
        wl_main.spotvis[x][y] = 0
        wl_main.actorat[x][y] = nil
    end
end

---------------------------------------------------------------------------
-- SETFONTCOLOR macro
---------------------------------------------------------------------------
function wl_main.SETFONTCOLOR(f, b)
    id_vh.fontcolor = f
    id_vh.backcolor = b
    wl_main.fontcolor = f
    wl_main.backcolor = b
end

---------------------------------------------------------------------------
-- NewGame
---------------------------------------------------------------------------

function wl_main.NewGame(difficulty, episode)
    wl_main.gamestate = wl_def.new_gamestate()
    wl_main.gamestate.difficulty = difficulty
    wl_main.gamestate.weapon = wl_def.wp_pistol
    wl_main.gamestate.bestweapon = wl_def.wp_pistol
    wl_main.gamestate.chosenweapon = wl_def.wp_pistol
    wl_main.gamestate.health = 100
    wl_main.gamestate.ammo = wl_def.STARTAMMO
    wl_main.gamestate.lives = 3
    wl_main.gamestate.nextextra = wl_def.EXTRAPOINTS
    wl_main.gamestate.episode = episode

    wl_main.startgame = true
end

---------------------------------------------------------------------------
-- BuildTables - calculate trig tables
---------------------------------------------------------------------------

local radtoint = wl_def.FINEANGLES / 2 / wl_def.PI

function wl_main.BuildTables()
    -- Calculate fine tangents
    for i = 0, wl_def.FINEANGLES / 8 - 1 do
        local tang = math.tan((i + 0.5) / radtoint)
        wl_main.finetangent[i] = math.floor(tang * wl_def.TILEGLOBAL)
        wl_main.finetangent[wl_def.FINEANGLES / 4 - 1 - i] = math.floor(1 / tang * wl_def.TILEGLOBAL)
    end

    -- Build sine table
    -- sintable has ANGLES + ANGLEQUAD + 1 entries
    local total = wl_def.ANGLES + wl_def.ANGLEQUAD + 1
    for i = 0, total do
        wl_main.sintable[i] = 0
    end

    local angle = 0
    local anglestep = math.pi / 2 / wl_def.ANGLEQUAD
    for i = 0, wl_def.ANGLEQUAD do
        local value = math.floor(wl_def.GLOBAL1 * math.sin(angle))
        wl_main.sintable[i] = value
        wl_main.sintable[wl_def.ANGLES] = value  -- overwritten each time, last = ANGLEQUAD
        wl_main.sintable[wl_def.ANGLES / 2 - i] = value

        -- Negative values for second half: stored as value | 0x80000000
        -- In Lua we just use negative numbers
        wl_main.sintable[wl_def.ANGLES - i] = -value
        wl_main.sintable[wl_def.ANGLES / 2 + i] = -value
        angle = angle + anglestep
    end

    -- costable is sintable offset by ANGLEQUAD
    -- We'll create a function/metatable for this
    wl_main.costable = setmetatable({}, {
        __index = function(_, k)
            return wl_main.sintable[k + wl_def.ANGLEQUAD] or 0
        end
    })
end

---------------------------------------------------------------------------
-- CalcProjection
---------------------------------------------------------------------------

function wl_main.CalcProjection(focal)
    wl_main.focallength = focal
    local facedist = focal + wl_def.MINDIST
    local halfview = math.floor(wl_main.viewwidth / 2)

    wl_main.scale = math.floor(halfview * facedist / (VIEWGLOBAL / 2))
    wl_main.heightnumerator = math.floor((wl_def.TILEGLOBAL * wl_main.scale) / 64)
    wl_main.minheightdiv = math.floor(wl_main.heightnumerator / 0x7fff) + 1

    for i = 0, halfview - 1 do
        local tang = i * VIEWGLOBAL / wl_main.viewwidth / facedist
        local angle_val = math.atan(tang)
        local intang = math.floor(angle_val * radtoint)
        wl_main.pixelangle[halfview - 1 - i] = intang
        wl_main.pixelangle[halfview + i] = -intang
    end

    if wl_main.pixelangle[0] and wl_main.pixelangle[0] >= 0 and
       wl_main.pixelangle[0] < wl_def.FINEANGLES / 4 then
        wl_main.maxslope = wl_main.finetangent[wl_main.pixelangle[0]] or 0
        wl_main.maxslope = rshift(wl_main.maxslope, 8)
    end
end

---------------------------------------------------------------------------
-- SetupWalls
---------------------------------------------------------------------------

function wl_main.SetupWalls()
    for i = 1, wl_def.MAXWALLTILES - 1 do
        wl_main.horizwall[i] = (i - 1) * 2
        wl_main.vertwall[i] = (i - 1) * 2 + 1
    end
end

---------------------------------------------------------------------------
-- SetViewSize / NewViewSize
---------------------------------------------------------------------------

function wl_main.SetViewSize(width, height)
    wl_main.viewwidth = band(width, bit.bnot(15))
    wl_main.viewheight = band(height, bit.bnot(1))
    wl_main.centerx = math.floor(wl_main.viewwidth / 2) - 1
    wl_main.shootdelta = math.floor(wl_main.viewwidth / 10)
    wl_main.screenofs = math.floor((200 - wl_def.STATUSLINES - wl_main.viewheight) / 2 *
        wl_def.SCREENWIDTH + (320 - wl_main.viewwidth) / 8)

    wl_main.CalcProjection(FOCALLENGTH)
    return true
end

function wl_main.NewViewSize(width)
    id_ca.CA_UpLevel()
    id_mm.MM_SortMem()
    wl_main.viewsize = width
    wl_main.SetViewSize(width * 16, math.floor(width * 16 * wl_def.HEIGHTRATIO))
    id_ca.CA_DownLevel()
end

function wl_main.ShowViewSize(width)
    -- Would show the view size border
end

---------------------------------------------------------------------------
-- SignonScreen
---------------------------------------------------------------------------

function wl_main.SignonScreen()
    id_vl.VL_SetVGAPlaneMode()
    id_vl.VL_TestPaletteSet()
    id_vl.VL_SetPalette(id_vh.gamepal)
    -- The signon screen would be displayed here from embedded data
    -- For now, just clear to black
    id_vl.VL_ClearVideo(0)
    id_vl.VL_UpdateScreen()
end

function wl_main.FinishSignon()
    if not id_us.NoWait then
        id_vh.VWB_Bar(0, 189, 300, 11, id_vl.screenbuf[0] or 0)
        id_us.WindowX = 0
        id_us.WindowW = 320
        id_us.PrintY = 190
        wl_main.SETFONTCOLOR(14, 4)
        id_us.US_CPrint("Press a key")
        id_vl.VL_UpdateScreen()

        id_in.IN_Ack()

        id_vh.VWB_Bar(0, 189, 300, 11, id_vl.screenbuf[0] or 0)
        id_us.PrintY = 190
        wl_main.SETFONTCOLOR(10, 4)
        id_us.US_CPrint("Working...")
        id_vl.VL_UpdateScreen()
        wl_main.SETFONTCOLOR(0, 15)
    end
end

---------------------------------------------------------------------------
-- InitDigiMap
---------------------------------------------------------------------------

function wl_main.InitDigiMap()
    local wolfdigimap = {
        audiowl6.HALTSND,            0,
        audiowl6.DOGBARKSND,         1,
        audiowl6.CLOSEDOORSND,       2,
        audiowl6.OPENDOORSND,        3,
        audiowl6.ATKMACHINEGUNSND,   4,
        audiowl6.ATKPISTOLSND,       5,
        audiowl6.ATKGATLINGSND,      6,
        audiowl6.SCHUTZADSND,        7,
        audiowl6.GUTENTAGSND,        8,
        audiowl6.MUTTISND,           9,
        audiowl6.BOSSFIRESND,        10,
        audiowl6.SSFIRESND,          11,
        audiowl6.DEATHSCREAM1SND,    12,
        audiowl6.DEATHSCREAM2SND,    13,
        audiowl6.DEATHSCREAM3SND,    13,
        audiowl6.TAKEDAMAGESND,      14,
        audiowl6.PUSHWALLSND,        15,
        audiowl6.LEBENSND,           20,
        audiowl6.NAZIFIRESND,        21,
        audiowl6.SLURPIESND,         22,
        audiowl6.YEAHSND,            32,
        -- Additional sounds
        audiowl6.DOGDEATHSND,        16,
        audiowl6.AHHHGSND,           17,
        audiowl6.DIESND,             18,
        audiowl6.EVASND,             19,
        audiowl6.TOT_HUNDSND,        23,
        audiowl6.MEINGOTTSND,        24,
        audiowl6.SCHABBSHASND,       25,
        audiowl6.HITLERHASND,        26,
        audiowl6.SPIONSND,           27,
        audiowl6.NEINSOVASSND,       28,
        audiowl6.DOGATTACKSND,       29,
        audiowl6.LEVELDONESND,       30,
        audiowl6.MECHSTEPSND,        31,
        audiowl6.SCHEISTSND,         33,
        audiowl6.DEATHSCREAM4SND,    34,
        audiowl6.DEATHSCREAM5SND,    35,
        audiowl6.DONNERSND,          36,
        audiowl6.EINESND,            37,
        audiowl6.ERLAUBENSND,        38,
        audiowl6.DEATHSCREAM6SND,    39,
        audiowl6.DEATHSCREAM7SND,    40,
        audiowl6.DEATHSCREAM8SND,    41,
        audiowl6.DEATHSCREAM9SND,    42,
        audiowl6.KEINSND,            43,
        audiowl6.MEINSND,            44,
        audiowl6.ROSESND,            45,
    }

    for i = 1, #wolfdigimap, 2 do
        local snd = wolfdigimap[i]
        local digi = wolfdigimap[i + 1]
        if snd then
            id_sd.DigiMap[snd] = digi
        end
    end
end

---------------------------------------------------------------------------
-- InitGame - initialize everything
---------------------------------------------------------------------------

function wl_main.InitGame()
    id_mm.MM_Startup()
    wl_main.SignonScreen()

    id_vl.VL_Startup()
    id_in.IN_Startup()
    id_pm.PM_Startup()
    id_sd.SD_Startup()
    id_ca.CA_Startup()
    id_us.US_Startup()

    wl_main.InitDigiMap()

    -- Build lookup tables
    for i = 0, wl_def.MAPSIZE - 1 do
        wl_main.farmapylookup[i + 1] = i * 64  -- 1-indexed
    end

    for i = 0, wl_def.PORTTILESHIGH - 1 do
        wl_main.uwidthtable[i] = wl_def.UPDATEWIDE * i
    end

    local idx = 0
    for y = 0, wl_def.UPDATEHIGH - 1 do
        for x = 0, wl_def.UPDATEWIDE - 1 do
            wl_main.blockstarts[idx] = wl_def.SCREENWIDTH * 16 * y + x * wl_def.TILEWIDTH
            idx = idx + 1
        end
    end

    for i = 0, wl_def.UPDATEWIDE * wl_def.UPDATEHIGH - 1 do
        wl_main.update[i] = 0
    end

    id_vl.bufferofs = 0
    id_vl.displayofs = 0

    -- Read config (simplified - just set defaults)
    wl_main.viewsize = 15
    wl_main.mouseadjustment = 5

    id_sd.SD_SetSoundMode(id_sd.sdm_AdLib)
    id_sd.SD_SetMusicMode(id_sd.smm_AdLib)
    id_sd.SD_SetDigiDevice(id_sd.sds_SoundBlaster)

    -- IntroScreen
    if not wl_main.virtualreality then
        wl_inter.IntroScreen()
    end

    -- Load fonts and base graphics
    id_ca.CA_CacheGrChunk(gfx.STARTFONT)
    id_mm.MM_SetLock(id_ca.grsegs[gfx.STARTFONT], true)

    id_vh.LoadLatchMem()
    wl_main.BuildTables()
    wl_main.SetupWalls()
    wl_main.NewViewSize(wl_main.viewsize)

    if not wl_main.virtualreality then
        wl_main.FinishSignon()
    end

    id_vl.displayofs = wl_def.PAGE1START
    id_vl.bufferofs = wl_def.PAGE2START
end

---------------------------------------------------------------------------
-- Quit
---------------------------------------------------------------------------

function wl_main.Quit(error_msg)
    if error_msg and #error_msg > 0 then
        print("ERROR: " .. error_msg)
    end
    wl_main.ShutdownId()
    love.event.quit()
end

function wl_main.ShutdownId()
    id_us.US_Shutdown()
    id_sd.SD_Shutdown()
    id_pm.PM_Shutdown()
    id_in.IN_Shutdown()
    id_vl.VL_Shutdown()
    id_ca.CA_Shutdown()
    id_mm.MM_Shutdown()
end

---------------------------------------------------------------------------
-- MS_CheckParm
---------------------------------------------------------------------------

function wl_main.MS_CheckParm(check)
    -- Check command line args (Love2D doesn't really have these)
    -- Return false for all checks
    return false
end

---------------------------------------------------------------------------
-- GameLoop (stub - will be filled in with game logic)
---------------------------------------------------------------------------

function wl_main.GameLoop()
    -- This would run the actual game loop
    -- For now, just return to demo loop
    wl_main.startgame = false
    wl_main.loadedgame = false
    wl_main.playstate = wl_def.ex_completed
end

---------------------------------------------------------------------------
-- DemoLoop - main attract mode loop
---------------------------------------------------------------------------

function wl_main.DemoLoop()
    wl_menu.StartCPMusic(wl_menu.INTROSONG)

    while true do
        -- Title page
        id_ca.CA_CacheScreen(gfx.TITLEPIC)
        id_vh.VW_UpdateScreen()
        id_vh.VW_FadeIn()

        if id_in.IN_UserInput(id_sd.TickBase * 15) then
            -- User pressed something, go to menu
        else
            id_vh.VW_FadeOut()

            -- Credits page
            id_ca.CA_CacheScreen(gfx.CREDITSPIC)
            id_vh.VW_UpdateScreen()
            id_vh.VW_FadeIn()

            if id_in.IN_UserInput(id_sd.TickBase * 10) then
                -- Go to menu
            else
                id_vh.VW_FadeOut()

                -- High scores
                wl_inter.DrawHighScores()
                id_vh.VW_UpdateScreen()
                id_vh.VW_FadeIn()

                if not id_in.IN_UserInput(id_sd.TickBase * 10) then
                    -- Would play demo here
                    id_vh.VW_FadeOut()
                    wl_menu.StartCPMusic(wl_menu.INTROSONG)
                    goto continue_loop
                end
            end
        end

        id_vh.VW_FadeOut()

        -- Show menu
        wl_menu.US_ControlPanel(0)

        if wl_main.startgame or wl_main.loadedgame then
            wl_main.GameLoop()
            id_vh.VW_FadeOut()
            wl_menu.StartCPMusic(wl_menu.INTROSONG)
        end

        ::continue_loop::
    end
end

---------------------------------------------------------------------------
-- PlaySoundLocGlobal (stub)
---------------------------------------------------------------------------

function wl_main.PlaySoundLocGlobal(s, gx, gy)
    id_sd.SD_PlaySound(s)
end

function wl_main.UpdateSoundLoc()
    -- stub
end

return wl_main
