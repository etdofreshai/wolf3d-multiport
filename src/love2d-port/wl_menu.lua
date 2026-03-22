-- WL_MENU.lua
-- Menu system - ported from WL_MENU.C / WL_MENU.H
-- Contains menu constants, structures, and core menu routines

local bit = require("bit")
local band, bor, lshift, rshift = bit.band, bit.bor, bit.lshift, bit.rshift

local id_vl  = require("id_vl")
local id_vh  = require("id_vh")
local id_in  = require("id_in")
local id_sd  = require("id_sd")
local id_us  = require("id_us")
local id_ca  = require("id_ca")
local gfx    = require("gfxv_wl6")
local audiowl6 = require("audiowl6")
local foreign = require("foreign")

local wl_menu = {}

---------------------------------------------------------------------------
-- Constants (from WL_MENU.H) - WL6 version (not SPEAR)
---------------------------------------------------------------------------
wl_menu.BORDCOLOR  = 0x29
wl_menu.BORD2COLOR = 0x23
wl_menu.DEACTIVE   = 0x2b
wl_menu.BKGDCOLOR  = 0x2d
wl_menu.STRIPE     = 0x2c

wl_menu.READCOLOR  = 0x4a
wl_menu.READHCOLOR = 0x47
wl_menu.VIEWCOLOR  = 0x7f
wl_menu.TEXTCOLOR  = 0x17
wl_menu.HIGHLIGHT  = 0x13

wl_menu.MENUSONG   = audiowl6.WONDERIN_MUS
wl_menu.INTROSONG  = audiowl6.NAZI_NOR_MUS

wl_menu.SENSITIVE  = 60
wl_menu.CENTER     = 120

wl_menu.MENU_X = 76
wl_menu.MENU_Y = 55
wl_menu.MENU_W = 178
wl_menu.MENU_H = 13 * 10 + 6  -- WL6

wl_menu.SM_X  = 48
wl_menu.SM_W  = 250
wl_menu.SM_Y1 = 20
wl_menu.SM_H1 = 4 * 13 - 7
wl_menu.SM_Y2 = 20 + 5 * 13
wl_menu.SM_H2 = 4 * 13 - 7
wl_menu.SM_Y3 = 20 + 10 * 13
wl_menu.SM_H3 = 3 * 13 - 7

wl_menu.CTL_X = 24
wl_menu.CTL_Y = 70
wl_menu.CTL_W = 284
wl_menu.CTL_H = 13 * 7 - 7

wl_menu.LSM_X = 85
wl_menu.LSM_Y = 55
wl_menu.LSM_W = 175
wl_menu.LSM_H = 10 * 13 + 10

wl_menu.NM_X = 50
wl_menu.NM_Y = 100
wl_menu.NM_W = 225
wl_menu.NM_H = 13 * 4 + 15

wl_menu.NE_X = 10
wl_menu.NE_Y = 23
wl_menu.NE_W = 300
wl_menu.NE_H = 154

wl_menu.CST_X     = 20
wl_menu.CST_Y     = 48
wl_menu.CST_START = 60
wl_menu.CST_SPC   = 60

-- Menu item enum (GOODTIMES, not SPEAR -> no readthis)
wl_menu.mi_newgame    = 0
wl_menu.mi_soundmenu  = 1
wl_menu.mi_control    = 2
wl_menu.mi_loadgame   = 3
wl_menu.mi_savegame   = 4
wl_menu.mi_changeview = 5
wl_menu.mi_viewscores = 6
wl_menu.mi_backtodemo = 7
wl_menu.mi_quit       = 8

-- Input types
wl_menu.MOUSE        = 0
wl_menu.JOYSTICK     = 1
wl_menu.KEYBOARDBTNS = 2
wl_menu.KEYBOARDMOVE = 3

---------------------------------------------------------------------------
-- Menu data structures
---------------------------------------------------------------------------

-- LRstruct (level ratios)
wl_menu.LevelRatios = {}
for i = 0, 7 do
    wl_menu.LevelRatios[i] = {kill = 0, secret = 0, treasure = 0, time = 0}
end

-- Main menu items
wl_menu.MainItems = {
    x = wl_menu.MENU_X,
    y = wl_menu.MENU_Y,
    amount = 9,
    curpos = 0,
    indent = 24,
}

wl_menu.MainMenu = {
    {active = 1, string = foreign.STR_NG, routine = nil},   -- New Game
    {active = 1, string = foreign.STR_SD, routine = nil},   -- Sound
    {active = 1, string = foreign.STR_CL, routine = nil},   -- Control
    {active = 1, string = foreign.STR_LG, routine = nil},   -- Load Game
    {active = 0, string = foreign.STR_SG, routine = nil},   -- Save Game (inactive until in game)
    {active = 1, string = foreign.STR_CV, routine = nil},   -- Change View
    {active = 1, string = foreign.STR_VS, routine = nil},   -- View Scores
    {active = 1, string = foreign.STR_BD, routine = nil},   -- Back to Demo
    {active = 1, string = foreign.STR_QT, routine = nil},   -- Quit
}

-- New Episode menu
wl_menu.NewEMenu = {
    {active = 1, string = "Episode 1\nEscape from Wolfenstein", routine = nil},
    {active = 1, string = "Episode 2\nOperation: Eisenfaust", routine = nil},
    {active = 1, string = "Episode 3\nDie, Fuhrer, Die!", routine = nil},
    {active = 1, string = "Episode 4\nA Dark Secret", routine = nil},
    {active = 1, string = "Episode 5\nTrail of the Madman", routine = nil},
    {active = 1, string = "Episode 6\nConfrontation", routine = nil},
}

-- Save game state
wl_menu.SaveGamesAvail = {}
wl_menu.SaveGameNames  = {}
wl_menu.SaveName       = "SAVEGAM0.WL6"
wl_menu.StartGame      = false
wl_menu.SoundStatus    = 1

for i = 0, 9 do
    wl_menu.SaveGamesAvail[i] = 0
    wl_menu.SaveGameNames[i] = ""
end

---------------------------------------------------------------------------
-- Menu helper functions
---------------------------------------------------------------------------

function wl_menu.MenuFadeOut()
    id_vl.VL_FadeOut(0, 255, 43, 0, 0, 10)
end

function wl_menu.MenuFadeIn()
    id_vl.VL_FadeIn(0, 255, id_vh.gamepal, 10)
end

function wl_menu.ClearMScreen()
    id_vh.VWB_Bar(0, 0, 320, 200, wl_menu.BKGDCOLOR)
end

function wl_menu.DrawWindow(x, y, w, h, wcolor)
    id_vh.VWB_Bar(x, y, w, h, wcolor)
end

function wl_menu.DrawOutline(x, y, w, h, color1, color2)
    id_vh.VWB_Hlin(x, x + w, y, color2)
    id_vh.VWB_Vlin(y, y + h, x, color2)
    id_vh.VWB_Hlin(x, x + w, y + h, color1)
    id_vh.VWB_Vlin(y, y + h, x + w, color1)
end

function wl_menu.DrawStripes(y)
    id_vh.VWB_Bar(0, y, 320, 24, 0)
    for i = 0, 3 do
        id_vh.VWB_Hlin(0, 319, y + i * 6, wl_menu.STRIPE)
    end
end

function wl_menu.Message(str)
    -- Draw a message box
    id_us.US_CenterWindow(18, 3)
    id_us.US_Print(str)
    id_vh.VW_UpdateScreen()
end

function wl_menu.WaitKeyUp()
    while id_in.IN_KeyDown(id_in.sc_Space) or
          id_in.IN_KeyDown(id_in.sc_Return) or
          id_in.IN_KeyDown(id_in.sc_Escape) do
        id_in.IN_WaitAndProcessEvents()
    end
end

function wl_menu.TicDelay(count)
    local id_sd = require("id_sd")
    local start = id_sd.TimeCount
    while (id_sd.TimeCount - start) < count do
        id_in.IN_WaitAndProcessEvents()
    end
end

function wl_menu.ShootSnd()
    id_sd.SD_PlaySound(audiowl6.SHOOTSND)
end

---------------------------------------------------------------------------
-- Cache/Uncache lumps
---------------------------------------------------------------------------

function wl_menu.CacheLump(lumpstart, lumpend)
    for i = lumpstart, lumpend do
        id_ca.CA_CacheGrChunk(i)
    end
end

function wl_menu.UnCacheLump(lumpstart, lumpend)
    for i = lumpstart, lumpend do
        id_ca.UNCACHEGRCHUNK(i)
    end
end

---------------------------------------------------------------------------
-- StartCPMusic - start playing music
---------------------------------------------------------------------------

function wl_menu.StartCPMusic(song)
    local musicchunk = audiowl6.STARTMUSIC + song
    id_sd.SD_MusicOff()
    id_ca.CA_CacheAudioChunk(musicchunk)
    local music = id_ca.audiosegs[musicchunk]
    if music then
        id_sd.SD_StartMusic(music)
    end
end

---------------------------------------------------------------------------
-- CheckForEpisodes - verify game data files exist
---------------------------------------------------------------------------

function wl_menu.CheckForEpisodes()
    -- Check if VSWAP.WL6 exists
    local info = love.filesystem.getInfo("VSWAP.WL6")
    if not info then
        print("WARNING: VSWAP.WL6 not found in love.filesystem path")
        -- Try to set up the source directory
    end
end

---------------------------------------------------------------------------
-- US_ControlPanel - the main menu system
---------------------------------------------------------------------------

function wl_menu.US_ControlPanel(scancode)
    -- Simplified menu - just handle basic navigation
    local wl_main = require("wl_main")

    if scancode == id_in.sc_F7 then
        -- Quick save/load
        return
    end

    -- Setup
    wl_menu.CacheLump(gfx.CONTROLS_LUMP_START, gfx.CONTROLS_LUMP_END)
    id_ca.CA_CacheGrChunk(gfx.STARTFONT + 1)

    -- Draw main menu
    wl_menu.ClearMScreen()
    id_vh.VWB_DrawPic(112, 184, gfx.C_MOUSELBACKPIC)
    wl_menu.DrawStripes(10)

    id_vh.fontnumber = 1
    id_vh.fontcolor = wl_menu.TEXTCOLOR
    id_vh.backcolor = wl_menu.BKGDCOLOR

    wl_menu.DrawWindow(wl_menu.MENU_X - 8, wl_menu.MENU_Y - 3,
        wl_menu.MENU_W, wl_menu.MENU_H, wl_menu.BKGDCOLOR)

    -- Draw menu items
    for i, item in ipairs(wl_menu.MainMenu) do
        local y = wl_menu.MENU_Y + (i - 1) * 13
        if item.active == 0 then
            id_vh.fontcolor = wl_menu.DEACTIVE
        else
            id_vh.fontcolor = wl_menu.TEXTCOLOR
        end
        id_vh.px = wl_menu.MENU_X + wl_menu.MainItems.indent
        id_vh.py = y + 1
        id_vh.VWB_DrawPropString(item.string)
    end

    -- Draw cursor
    local curpos = wl_menu.MainItems.curpos
    id_vh.VWB_DrawPic(wl_menu.MENU_X, wl_menu.MENU_Y + curpos * 13 - 2, gfx.C_CURSOR1PIC)

    id_vh.VW_UpdateScreen()
    wl_menu.MenuFadeIn()

    -- Menu loop
    local done = false
    while not done do
        id_in.IN_WaitAndProcessEvents()

        -- Handle input
        if id_in.LastScan == id_in.sc_Escape then
            done = true
            id_in.IN_ClearKey(id_in.sc_Escape)
        elseif id_in.LastScan == id_in.sc_UpArrow then
            id_in.IN_ClearKey(id_in.sc_UpArrow)
            -- Erase old cursor
            id_vh.VWB_Bar(wl_menu.MENU_X, wl_menu.MENU_Y + curpos * 13 - 2, 24, 16, wl_menu.BKGDCOLOR)
            repeat
                curpos = curpos - 1
                if curpos < 0 then curpos = #wl_menu.MainMenu - 1 end
            until wl_menu.MainMenu[curpos + 1].active ~= 0
            -- Draw new cursor
            id_vh.VWB_DrawPic(wl_menu.MENU_X, wl_menu.MENU_Y + curpos * 13 - 2, gfx.C_CURSOR1PIC)
            id_vh.VW_UpdateScreen()
        elseif id_in.LastScan == id_in.sc_DownArrow then
            id_in.IN_ClearKey(id_in.sc_DownArrow)
            id_vh.VWB_Bar(wl_menu.MENU_X, wl_menu.MENU_Y + curpos * 13 - 2, 24, 16, wl_menu.BKGDCOLOR)
            repeat
                curpos = curpos + 1
                if curpos >= #wl_menu.MainMenu then curpos = 0 end
            until wl_menu.MainMenu[curpos + 1].active ~= 0
            id_vh.VWB_DrawPic(wl_menu.MENU_X, wl_menu.MENU_Y + curpos * 13 - 2, gfx.C_CURSOR1PIC)
            id_vh.VW_UpdateScreen()
        elseif id_in.LastScan == id_in.sc_Return or id_in.LastScan == id_in.sc_Space then
            id_in.IN_ClearKey(id_in.LastScan)
            local sel = curpos

            if sel == wl_menu.mi_newgame then
                -- Start new game (simplified: episode 0, difficulty 1)
                wl_main.NewGame(1, 0)
                wl_main.startgame = true
                done = true
            elseif sel == wl_menu.mi_viewscores then
                -- View high scores
                done = true
            elseif sel == wl_menu.mi_backtodemo then
                done = true
            elseif sel == wl_menu.mi_quit then
                -- Quit game
                love.event.quit()
                done = true
            end
        end
    end

    wl_menu.MainItems.curpos = curpos
    wl_menu.MenuFadeOut()
    wl_menu.UnCacheLump(gfx.CONTROLS_LUMP_START, gfx.CONTROLS_LUMP_END)
end

return wl_menu
