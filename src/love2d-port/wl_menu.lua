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
-- Quit messages (from WL_MENU.C)
---------------------------------------------------------------------------
local endStrings = {
    "Dost thou wish to\nleave with such hasty\nabandon?",
    "Chickening out...\nalready?",
    "Press N for more carnage.\nPress Y to be a weenie.",
    "So, you think you can\nquit this easily, huh?",
    "Press N to save the world.\nPress Y to abandon it in\nits hour of need.",
    "Press N if you are brave.\nPress Y to cower in shame.",
    "Heroes, press N.\nWimps, press Y.",
    "You are at an intersection.\nA sign says, 'Press Y to quit.'\n>",
    "For guns and glory, press N.\nFor work and worry, press Y.",
}

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
wl_menu.NewEItems = {
    x = wl_menu.NE_X,
    y = wl_menu.NE_Y,
    amount = 6,
    curpos = 0,
    indent = 88,
}

wl_menu.NewEMenu = {
    {active = 1, string = "Episode 1\nEscape from Wolfenstein"},
    {active = 1, string = "Episode 2\nOperation: Eisenfaust"},
    {active = 1, string = "Episode 3\nDie, Fuhrer, Die!"},
    {active = 1, string = "Episode 4\nA Dark Secret"},
    {active = 1, string = "Episode 5\nTrail of the Madman"},
    {active = 1, string = "Episode 6\nConfrontation"},
}

-- Difficulty menu
wl_menu.NewItems = {
    x = wl_menu.NM_X,
    y = wl_menu.NM_Y,
    amount = 4,
    curpos = 2,
    indent = 24,
}

wl_menu.NewMenu = {
    {active = 1, string = foreign.STR_DADDY},
    {active = 1, string = foreign.STR_HURTME},
    {active = 1, string = foreign.STR_BRINGEM},
    {active = 1, string = foreign.STR_DEATH},
}

-- Sound menu
wl_menu.SndItems = {
    x = wl_menu.SM_X,
    y = wl_menu.SM_Y1,
    amount = 12,
    curpos = 0,
    indent = 52,
}

wl_menu.SndMenu = {
    {active = 1, string = foreign.STR_NONE},
    {active = 1, string = foreign.STR_PC},
    {active = 1, string = foreign.STR_ALSB},
    {active = 0, string = ""},           -- separator
    {active = 0, string = ""},           -- separator
    {active = 1, string = foreign.STR_NONE},
    {active = 1, string = foreign.STR_DISNEY},
    {active = 1, string = foreign.STR_SB},
    {active = 0, string = ""},           -- separator
    {active = 0, string = ""},           -- separator
    {active = 1, string = foreign.STR_NONE},
    {active = 1, string = foreign.STR_ALSB},
}

-- Control menu
wl_menu.CtlItems = {
    x = wl_menu.CTL_X,
    y = wl_menu.CTL_Y,
    amount = 6,
    curpos = -1,
    indent = 56,
}

wl_menu.CtlMenu = {
    {active = 0, string = foreign.STR_MOUSEEN},
    {active = 0, string = foreign.STR_JOYEN},
    {active = 0, string = foreign.STR_PORT2},
    {active = 0, string = foreign.STR_GAMEPAD},
    {active = 0, string = foreign.STR_SENS},
    {active = 1, string = foreign.STR_CUSTOM},
}

-- Load/Save menu
wl_menu.LSItems = {
    x = wl_menu.LSM_X,
    y = wl_menu.LSM_Y,
    amount = 10,
    curpos = 0,
    indent = 24,
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
    -- Count lines and max width
    local lines = 1
    local maxw = 0
    local cw = 0
    for i = 1, #str do
        if string.byte(str, i) == 10 then
            lines = lines + 1
            if cw > maxw then maxw = cw end
            cw = 0
        else
            cw = cw + 1
        end
    end
    if cw > maxw then maxw = cw end

    local w = math.max(maxw + 2, 18)
    local h = lines + 1
    id_us.US_CenterWindow(w, h)
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
    local start = id_sd.TimeCount
    while (id_sd.TimeCount - start) < count do
        id_in.IN_WaitAndProcessEvents()
    end
end

function wl_menu.ShootSnd()
    id_sd.SD_PlaySound(audiowl6.SHOOTSND)
end

---------------------------------------------------------------------------
-- Confirm message (Y/N prompt)
---------------------------------------------------------------------------

function wl_menu.Confirm(str)
    wl_menu.Message(str)
    id_in.IN_ClearKeysDown()

    while true do
        id_in.IN_WaitAndProcessEvents()
        if id_in.LastScan == id_in.sc_Y then
            id_in.IN_ClearKeysDown()
            wl_menu.ShootSnd()
            return true
        elseif id_in.LastScan == id_in.sc_N or id_in.LastScan == id_in.sc_Escape then
            id_in.IN_ClearKeysDown()
            return false
        end
    end
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
    local info = love.filesystem.getInfo("VSWAP.WL6")
    if not info then
        print("WARNING: VSWAP.WL6 not found in love.filesystem path")
    end
end

---------------------------------------------------------------------------
-- SetupControlPanel - setup for entering the menu
---------------------------------------------------------------------------

function wl_menu.SetupControlPanel()
    -- Enable save if in-game
    local wl_main = require("wl_main")
    if wl_main.ingame then
        wl_menu.MainMenu[5].active = 1  -- Save Game
    else
        wl_menu.MainMenu[5].active = 0
    end

    -- Scan for save games on disk
    for i = 0, 9 do
        local fname = string.format("savegam%d.wl6", i)
        local info = love.filesystem.getInfo(fname)
        if info then
            wl_menu.SaveGamesAvail[i] = 1
            -- Try to read the name
            local data = love.filesystem.read(fname)
            if data and #data >= 32 then
                local name = string.sub(data, 1, 32)
                -- Strip trailing nulls
                local stripped = name:gsub("%z+$", "")
                wl_menu.SaveGameNames[i] = stripped
            else
                wl_menu.SaveGameNames[i] = "Save " .. tostring(i)
            end
        else
            wl_menu.SaveGamesAvail[i] = 0
            wl_menu.SaveGameNames[i] = ""
        end
    end
end

---------------------------------------------------------------------------
-- HandleMenu - generic keyboard-driven menu navigation
-- Returns the selected item index (0-based), or -1 for escape
---------------------------------------------------------------------------

function wl_menu.HandleMenu(items, menu_table, draw_routine)
    local curpos = items.curpos
    if curpos < 0 then curpos = 0 end
    local done = false
    local result = -1

    -- Find first active item if current isn't active
    if menu_table[curpos + 1] and menu_table[curpos + 1].active == 0 then
        for i = 0, items.amount - 1 do
            if menu_table[i + 1].active ~= 0 then
                curpos = i
                break
            end
        end
    end

    -- Draw cursor
    id_vh.VWB_DrawPic(items.x, items.y + curpos * 13 - 2, gfx.C_CURSOR1PIC)
    id_vh.VW_UpdateScreen()

    while not done do
        id_in.IN_WaitAndProcessEvents()

        if id_in.LastScan == id_in.sc_Escape then
            done = true
            result = -1
            id_in.IN_ClearKey(id_in.sc_Escape)
            id_sd.SD_PlaySound(audiowl6.ESCPRESSEDSND)
        elseif id_in.LastScan == id_in.sc_UpArrow then
            id_in.IN_ClearKey(id_in.sc_UpArrow)
            -- Erase old cursor
            id_vh.VWB_Bar(items.x, items.y + curpos * 13 - 2, 24, 16, wl_menu.BKGDCOLOR)
            repeat
                curpos = curpos - 1
                if curpos < 0 then curpos = items.amount - 1 end
            until menu_table[curpos + 1].active ~= 0
            id_vh.VWB_DrawPic(items.x, items.y + curpos * 13 - 2, gfx.C_CURSOR1PIC)
            id_vh.VW_UpdateScreen()
        elseif id_in.LastScan == id_in.sc_DownArrow then
            id_in.IN_ClearKey(id_in.sc_DownArrow)
            id_vh.VWB_Bar(items.x, items.y + curpos * 13 - 2, 24, 16, wl_menu.BKGDCOLOR)
            repeat
                curpos = curpos + 1
                if curpos >= items.amount then curpos = 0 end
            until menu_table[curpos + 1].active ~= 0
            id_vh.VWB_DrawPic(items.x, items.y + curpos * 13 - 2, gfx.C_CURSOR1PIC)
            id_vh.VW_UpdateScreen()
        elseif id_in.LastScan == id_in.sc_Return or id_in.LastScan == id_in.sc_Space then
            id_in.IN_ClearKey(id_in.LastScan)
            if menu_table[curpos + 1].active ~= 0 then
                result = curpos
                done = true
                wl_menu.ShootSnd()
            end
        end
    end

    items.curpos = curpos
    return result
end

---------------------------------------------------------------------------
-- DrawMenuItems - draw items for a menu
---------------------------------------------------------------------------

function wl_menu.DrawMenuItems(items, menu_table)
    for i = 1, items.amount do
        local item = menu_table[i]
        if not item then break end
        local y = items.y + (i - 1) * 13
        if item.active == 0 then
            id_vh.fontcolor = wl_menu.DEACTIVE
        else
            id_vh.fontcolor = wl_menu.TEXTCOLOR
        end
        id_vh.px = items.x + items.indent
        id_vh.py = y + 1
        -- Only draw first line (before newline)
        local str = item.string
        local nl = string.find(str, "\n")
        if nl then str = string.sub(str, 1, nl - 1) end
        id_vh.VWB_DrawPropString(str)
    end
end

---------------------------------------------------------------------------
-- CP_NewGame - Episode + Difficulty selection
---------------------------------------------------------------------------

function wl_menu.CP_NewGame()
    local wl_main = require("wl_main")

    -- Episode selection
    wl_menu.ClearMScreen()
    id_vh.VWB_DrawPic(112, 184, gfx.C_MOUSELBACKPIC)
    wl_menu.DrawStripes(10)
    id_vh.fontnumber = 1
    id_vh.fontcolor = wl_menu.READHCOLOR
    id_vh.backcolor = wl_menu.BKGDCOLOR

    id_vh.px = 100; id_vh.py = 10
    id_vh.VWB_DrawPropString("Which episode to play?")

    wl_menu.DrawWindow(wl_menu.NE_X - 5, wl_menu.NE_Y - 10,
        wl_menu.NE_W, wl_menu.NE_H, wl_menu.BKGDCOLOR)

    -- Draw episode pics
    for i = 0, 5 do
        id_ca.CA_CacheGrChunk(gfx.C_EPISODE1PIC + i)
        id_vh.VWB_DrawPic(wl_menu.NE_X + 4, wl_menu.NE_Y + i * 26 - 8, gfx.C_EPISODE1PIC + i)
    end

    id_vh.VW_UpdateScreen()

    -- Use simplified episode selection
    local ep_items = {
        x = wl_menu.NE_X,
        y = wl_menu.NE_Y,
        amount = 6,
        curpos = wl_menu.NewEItems.curpos,
        indent = 88,
    }
    -- Build temporary 13-pixel spaced menu
    local ep_menu = {}
    for i = 1, 6 do
        ep_menu[i] = {active = 1, string = "Episode " .. i}
    end

    -- Manual episode selection loop (26-pixel spaced)
    local curpos = ep_items.curpos
    local episode = -1
    id_vh.VWB_DrawPic(wl_menu.NE_X, wl_menu.NE_Y + curpos * 26 - 2, gfx.C_CURSOR1PIC)
    id_vh.VW_UpdateScreen()

    while true do
        id_in.IN_WaitAndProcessEvents()
        if id_in.LastScan == id_in.sc_Escape then
            id_in.IN_ClearKey(id_in.sc_Escape)
            return false
        elseif id_in.LastScan == id_in.sc_UpArrow then
            id_in.IN_ClearKey(id_in.sc_UpArrow)
            id_vh.VWB_Bar(wl_menu.NE_X, wl_menu.NE_Y + curpos * 26 - 2, 24, 16, wl_menu.BKGDCOLOR)
            curpos = curpos - 1
            if curpos < 0 then curpos = 5 end
            id_vh.VWB_DrawPic(wl_menu.NE_X, wl_menu.NE_Y + curpos * 26 - 2, gfx.C_CURSOR1PIC)
            id_vh.VW_UpdateScreen()
        elseif id_in.LastScan == id_in.sc_DownArrow then
            id_in.IN_ClearKey(id_in.sc_DownArrow)
            id_vh.VWB_Bar(wl_menu.NE_X, wl_menu.NE_Y + curpos * 26 - 2, 24, 16, wl_menu.BKGDCOLOR)
            curpos = curpos + 1
            if curpos > 5 then curpos = 0 end
            id_vh.VWB_DrawPic(wl_menu.NE_X, wl_menu.NE_Y + curpos * 26 - 2, gfx.C_CURSOR1PIC)
            id_vh.VW_UpdateScreen()
        elseif id_in.LastScan == id_in.sc_Return or id_in.LastScan == id_in.sc_Space then
            id_in.IN_ClearKey(id_in.LastScan)
            episode = curpos
            wl_menu.ShootSnd()
            break
        end
    end

    wl_menu.NewEItems.curpos = curpos
    if episode < 0 then return false end

    -- Difficulty selection
    wl_menu.ClearMScreen()
    id_vh.VWB_DrawPic(112, 184, gfx.C_MOUSELBACKPIC)
    wl_menu.DrawStripes(10)

    id_vh.fontnumber = 1
    id_vh.fontcolor = wl_menu.READHCOLOR
    id_vh.backcolor = wl_menu.BKGDCOLOR
    id_vh.px = 100; id_vh.py = 10
    id_vh.VWB_DrawPropString("How tough are you?")

    wl_menu.DrawWindow(wl_menu.NM_X - 5, wl_menu.NM_Y - 10,
        wl_menu.NM_W, wl_menu.NM_H, wl_menu.BKGDCOLOR)

    -- Draw difficulty pics
    id_ca.CA_CacheGrChunk(gfx.C_BABYMODEPIC)
    id_ca.CA_CacheGrChunk(gfx.C_EASYPIC)
    id_ca.CA_CacheGrChunk(gfx.C_NORMALPIC)
    id_ca.CA_CacheGrChunk(gfx.C_HARDPIC)
    id_vh.VWB_DrawPic(wl_menu.NM_X + 160, wl_menu.NM_Y, gfx.C_BABYMODEPIC)

    wl_menu.DrawMenuItems(wl_menu.NewItems, wl_menu.NewMenu)
    id_vh.VW_UpdateScreen()

    local diff = wl_menu.HandleMenu(wl_menu.NewItems, wl_menu.NewMenu)
    if diff < 0 then return false end

    -- Start the game
    wl_main.NewGame(diff, episode * 10)
    wl_main.startgame = true
    return true
end

---------------------------------------------------------------------------
-- CP_Sound - Sound menu
---------------------------------------------------------------------------

function wl_menu.CP_Sound()
    wl_menu.ClearMScreen()
    id_vh.VWB_DrawPic(112, 184, gfx.C_MOUSELBACKPIC)
    wl_menu.DrawStripes(10)

    id_vh.fontnumber = 1
    id_vh.fontcolor = wl_menu.READHCOLOR
    id_vh.backcolor = wl_menu.BKGDCOLOR

    -- Title
    id_vh.VWB_DrawPic(wl_menu.SM_X + 20, wl_menu.SM_Y1 - 20, gfx.C_FXTITLEPIC)
    id_vh.VWB_DrawPic(wl_menu.SM_X + 20, wl_menu.SM_Y2 - 20, gfx.C_DIGITITLEPIC)
    id_vh.VWB_DrawPic(wl_menu.SM_X + 20, wl_menu.SM_Y3 - 20, gfx.C_MUSICTITLEPIC)

    -- Draw boxes for each section
    wl_menu.DrawWindow(wl_menu.SM_X - 2, wl_menu.SM_Y1 - 2, wl_menu.SM_W, wl_menu.SM_H1, wl_menu.BKGDCOLOR)
    wl_menu.DrawWindow(wl_menu.SM_X - 2, wl_menu.SM_Y2 - 2, wl_menu.SM_W, wl_menu.SM_H2, wl_menu.BKGDCOLOR)
    wl_menu.DrawWindow(wl_menu.SM_X - 2, wl_menu.SM_Y3 - 2, wl_menu.SM_W, wl_menu.SM_H3, wl_menu.BKGDCOLOR)

    -- Draw sound option items in each section
    id_vh.fontcolor = wl_menu.TEXTCOLOR
    local snd_strings = {
        foreign.STR_NONE, foreign.STR_PC, foreign.STR_ALSB,
    }
    for i = 1, 3 do
        id_vh.px = wl_menu.SM_X + 52; id_vh.py = wl_menu.SM_Y1 + (i - 1) * 13 + 1
        id_vh.VWB_DrawPropString(snd_strings[i])
    end

    local digi_strings = {foreign.STR_NONE, foreign.STR_DISNEY, foreign.STR_SB}
    for i = 1, 3 do
        id_vh.px = wl_menu.SM_X + 52; id_vh.py = wl_menu.SM_Y2 + (i - 1) * 13 + 1
        id_vh.VWB_DrawPropString(digi_strings[i])
    end

    local mus_strings = {foreign.STR_NONE, foreign.STR_ALSB}
    for i = 1, 2 do
        id_vh.px = wl_menu.SM_X + 52; id_vh.py = wl_menu.SM_Y3 + (i - 1) * 13 + 1
        id_vh.VWB_DrawPropString(mus_strings[i])
    end

    -- Draw current selection bullets
    -- SFX: AdLib is index 2 (item 3)
    local sfx_sel = 2  -- AdLib by default
    if id_sd.SoundMode == id_sd.sdm_Off then sfx_sel = 0
    elseif id_sd.SoundMode == id_sd.sdm_PC then sfx_sel = 1 end
    id_vh.VWB_DrawPic(wl_menu.SM_X + 36, wl_menu.SM_Y1 + sfx_sel * 13 - 1, gfx.C_SELECTEDPIC)

    -- Digi: SoundBlaster is index 2
    local digi_sel = 2
    if id_sd.DigiMode == id_sd.sds_Off then digi_sel = 0
    elseif id_sd.DigiMode == id_sd.sds_SoundSource then digi_sel = 1 end
    id_vh.VWB_DrawPic(wl_menu.SM_X + 36, wl_menu.SM_Y2 + digi_sel * 13 - 1, gfx.C_SELECTEDPIC)

    -- Music: AdLib is index 1
    local mus_sel = 1
    if id_sd.MusicMode == id_sd.smm_Off then mus_sel = 0 end
    id_vh.VWB_DrawPic(wl_menu.SM_X + 36, wl_menu.SM_Y3 + mus_sel * 13 - 1, gfx.C_SELECTEDPIC)

    id_vh.VW_UpdateScreen()

    -- Wait for ESC to exit
    while true do
        id_in.IN_WaitAndProcessEvents()
        if id_in.LastScan == id_in.sc_Escape then
            id_in.IN_ClearKey(id_in.sc_Escape)
            id_sd.SD_PlaySound(audiowl6.ESCPRESSEDSND)
            return
        end
    end
end

---------------------------------------------------------------------------
-- CP_Control - Control menu
---------------------------------------------------------------------------

function wl_menu.CP_Control()
    wl_menu.ClearMScreen()
    id_vh.VWB_DrawPic(112, 184, gfx.C_MOUSELBACKPIC)
    wl_menu.DrawStripes(10)
    id_vh.VWB_DrawPic(80, 0, gfx.C_CONTROLPIC)

    wl_menu.DrawWindow(wl_menu.CTL_X - 8, wl_menu.CTL_Y - 3,
        wl_menu.CTL_W, wl_menu.CTL_H, wl_menu.BKGDCOLOR)

    id_vh.fontnumber = 1
    id_vh.fontcolor = wl_menu.TEXTCOLOR
    id_vh.backcolor = wl_menu.BKGDCOLOR

    -- Draw the control items
    wl_menu.DrawMenuItems(wl_menu.CtlItems, wl_menu.CtlMenu)
    id_vh.VW_UpdateScreen()

    -- Wait for ESC
    while true do
        id_in.IN_WaitAndProcessEvents()
        if id_in.LastScan == id_in.sc_Escape then
            id_in.IN_ClearKey(id_in.sc_Escape)
            id_sd.SD_PlaySound(audiowl6.ESCPRESSEDSND)
            return
        end
    end
end

---------------------------------------------------------------------------
-- CP_LoadGame - Load saved game
---------------------------------------------------------------------------

function wl_menu.CP_LoadGame()
    local wl_main = require("wl_main")

    wl_menu.ClearMScreen()
    id_vh.VWB_DrawPic(112, 184, gfx.C_MOUSELBACKPIC)
    wl_menu.DrawStripes(10)
    id_vh.VWB_DrawPic(86, 0, gfx.C_LOADGAMEPIC)

    wl_menu.DrawWindow(wl_menu.LSM_X - 8, wl_menu.LSM_Y - 5,
        wl_menu.LSM_W, wl_menu.LSM_H, wl_menu.BKGDCOLOR)

    id_vh.fontnumber = 1
    id_vh.fontcolor = wl_menu.TEXTCOLOR
    id_vh.backcolor = wl_menu.BKGDCOLOR

    -- Draw save slot names
    for i = 0, 9 do
        id_vh.px = wl_menu.LSM_X + wl_menu.LSItems.indent
        id_vh.py = wl_menu.LSM_Y + i * 13 + 1
        if wl_menu.SaveGamesAvail[i] ~= 0 then
            id_vh.fontcolor = wl_menu.TEXTCOLOR
            id_vh.VWB_DrawPropString(wl_menu.SaveGameNames[i])
        else
            id_vh.fontcolor = wl_menu.DEACTIVE
            id_vh.VWB_DrawPropString("- " .. foreign.STR_EMPTY .. " -")
        end
    end

    id_vh.VW_UpdateScreen()

    -- Menu loop
    local items = {
        x = wl_menu.LSM_X,
        y = wl_menu.LSM_Y,
        amount = 10,
        curpos = wl_menu.LSItems.curpos,
        indent = 24,
    }
    local load_menu = {}
    for i = 0, 9 do
        load_menu[i + 1] = {
            active = (wl_menu.SaveGamesAvail[i] ~= 0) and 1 or 0,
            string = wl_menu.SaveGameNames[i],
        }
    end

    -- Check if any saves exist
    local has_saves = false
    for i = 0, 9 do
        if wl_menu.SaveGamesAvail[i] ~= 0 then
            has_saves = true
            break
        end
    end

    if not has_saves then
        wl_menu.Message("No saved games found!")
        wl_menu.TicDelay(id_sd.TickBase * 2)
        return
    end

    local sel = wl_menu.HandleMenu(items, load_menu)
    wl_menu.LSItems.curpos = items.curpos

    if sel >= 0 then
        -- Load the game
        local fname = string.format("savegam%d.wl6", sel)
        local data = love.filesystem.read(fname)
        if data then
            -- Signal game loaded
            wl_main.loadedgame = true
            wl_main.startgame = true
        end
    end
end

---------------------------------------------------------------------------
-- CP_SaveGame - Save game
---------------------------------------------------------------------------

function wl_menu.CP_SaveGame()
    local wl_main = require("wl_main")

    wl_menu.ClearMScreen()
    id_vh.VWB_DrawPic(112, 184, gfx.C_MOUSELBACKPIC)
    wl_menu.DrawStripes(10)
    id_vh.VWB_DrawPic(86, 0, gfx.C_SAVEGAMEPIC)

    wl_menu.DrawWindow(wl_menu.LSM_X - 8, wl_menu.LSM_Y - 5,
        wl_menu.LSM_W, wl_menu.LSM_H, wl_menu.BKGDCOLOR)

    id_vh.fontnumber = 1
    id_vh.fontcolor = wl_menu.TEXTCOLOR
    id_vh.backcolor = wl_menu.BKGDCOLOR

    -- Draw save slot names
    for i = 0, 9 do
        id_vh.px = wl_menu.LSM_X + wl_menu.LSItems.indent
        id_vh.py = wl_menu.LSM_Y + i * 13 + 1
        if wl_menu.SaveGamesAvail[i] ~= 0 then
            id_vh.fontcolor = wl_menu.TEXTCOLOR
            id_vh.VWB_DrawPropString(wl_menu.SaveGameNames[i])
        else
            id_vh.fontcolor = wl_menu.DEACTIVE
            id_vh.VWB_DrawPropString("- " .. foreign.STR_EMPTY .. " -")
        end
    end

    id_vh.VW_UpdateScreen()

    -- All slots are active for saving
    local items = {
        x = wl_menu.LSM_X,
        y = wl_menu.LSM_Y,
        amount = 10,
        curpos = wl_menu.LSItems.curpos,
        indent = 24,
    }
    local save_menu = {}
    for i = 0, 9 do
        save_menu[i + 1] = {active = 1, string = ""}
    end

    local sel = wl_menu.HandleMenu(items, save_menu)
    wl_menu.LSItems.curpos = items.curpos

    if sel >= 0 then
        -- Check if overwriting
        if wl_menu.SaveGamesAvail[sel] ~= 0 then
            if not wl_menu.Confirm(foreign.GAMESVD) then
                return
            end
        end

        -- Get name from line input
        local ok, name = id_us.US_LineInput(
            wl_menu.LSM_X + wl_menu.LSItems.indent,
            wl_menu.LSM_Y + sel * 13 + 1,
            "", wl_menu.SaveGameNames[sel],
            true, 31, wl_menu.LSM_W - 30)

        if ok and name and #name > 0 then
            -- Save the game data using love.filesystem
            local fname = string.format("savegam%d.wl6", sel)
            local gs = wl_main.gamestate
            local savedata = name .. string.rep("\0", 32 - #name)
            -- Append basic gamestate
            savedata = savedata .. string.char(
                band(gs.score, 0xFF), band(rshift(gs.score, 8), 0xFF),
                band(rshift(gs.score, 16), 0xFF), band(rshift(gs.score, 24), 0xFF),
                gs.episode, gs.mapon, gs.lives, gs.health,
                gs.ammo, gs.keys, gs.weapon, gs.difficulty
            )
            local ok_write, err = love.filesystem.write(fname, savedata)
            if ok_write then
                wl_menu.SaveGamesAvail[sel] = 1
                wl_menu.SaveGameNames[sel] = name
            end
        end
    end
end

---------------------------------------------------------------------------
-- CP_ChangeView - Change screen size
---------------------------------------------------------------------------

function wl_menu.CP_ChangeView()
    local wl_main = require("wl_main")

    wl_menu.ClearMScreen()
    id_vh.VWB_DrawPic(112, 184, gfx.C_MOUSELBACKPIC)
    wl_menu.DrawStripes(10)

    id_vh.fontnumber = 1
    id_vh.fontcolor = wl_menu.READHCOLOR
    id_vh.backcolor = wl_menu.BKGDCOLOR

    id_vh.px = 64; id_vh.py = 10
    id_vh.VWB_DrawPropString(foreign.STR_SIZE1)
    id_vh.px = 64; id_vh.py = 22
    id_vh.VWB_DrawPropString(foreign.STR_SIZE2)
    id_vh.px = 64; id_vh.py = 34
    id_vh.VWB_DrawPropString(foreign.STR_SIZE3)

    -- Draw view size indicator
    local viewsize = wl_main.viewsize or 15
    local function DrawViewSize()
        id_vh.VWB_Bar(50, 60, 220, 120, wl_menu.BKGDCOLOR)
        -- Draw outline representing view
        local w = math.floor(viewsize * 14)
        local h = math.floor(viewsize * 8)
        local vx = 160 - math.floor(w / 2)
        local vy = 120 - math.floor(h / 2)
        id_vh.VWB_Bar(vx, vy, w, h, wl_menu.VIEWCOLOR)
        wl_menu.DrawOutline(vx - 1, vy - 1, w + 1, h + 1, wl_menu.BORD2COLOR, wl_menu.BORDCOLOR)
    end

    DrawViewSize()
    id_vh.VW_UpdateScreen()

    -- Arrow key loop
    while true do
        id_in.IN_WaitAndProcessEvents()
        if id_in.LastScan == id_in.sc_Escape then
            id_in.IN_ClearKey(id_in.sc_Escape)
            return
        elseif id_in.LastScan == id_in.sc_Return or id_in.LastScan == id_in.sc_Space then
            id_in.IN_ClearKey(id_in.LastScan)
            return
        elseif id_in.LastScan == id_in.sc_LeftArrow then
            id_in.IN_ClearKey(id_in.sc_LeftArrow)
            if viewsize > 4 then
                viewsize = viewsize - 1
                wl_main.viewsize = viewsize
                DrawViewSize()
                id_vh.VW_UpdateScreen()
            end
        elseif id_in.LastScan == id_in.sc_RightArrow then
            id_in.IN_ClearKey(id_in.sc_RightArrow)
            if viewsize < 21 then
                viewsize = viewsize + 1
                wl_main.viewsize = viewsize
                DrawViewSize()
                id_vh.VW_UpdateScreen()
            end
        end
    end
end

---------------------------------------------------------------------------
-- CP_ViewScores - View High Scores
---------------------------------------------------------------------------

function wl_menu.CP_ViewScores()
    local wl_inter = require("wl_inter")
    wl_inter.DrawHighScores()
    id_vh.VW_UpdateScreen()
    wl_menu.MenuFadeIn()
    id_in.IN_Ack()
    wl_menu.MenuFadeOut()
end

---------------------------------------------------------------------------
-- CP_Quit - Quit with random message
---------------------------------------------------------------------------

function wl_menu.CP_Quit()
    local idx = (id_us.US_RndT() % #endStrings) + 1
    if wl_menu.Confirm(endStrings[idx]) then
        love.event.quit()
        return true
    end
    return false
end

---------------------------------------------------------------------------
-- US_ControlPanel - the main menu system
---------------------------------------------------------------------------

function wl_menu.US_ControlPanel(scancode)
    local wl_main = require("wl_main")

    wl_menu.SetupControlPanel()

    -- Handle F-key shortcuts
    if scancode == id_in.sc_F1 then
        -- Help
        local wl_text = require("wl_text")
        wl_text.HelpScreens()
        return
    elseif scancode == id_in.sc_F2 then
        -- Save game
        if wl_main.ingame then
            wl_menu.CacheLump(gfx.CONTROLS_LUMP_START, gfx.CONTROLS_LUMP_END)
            wl_menu.CP_SaveGame()
            wl_menu.UnCacheLump(gfx.CONTROLS_LUMP_START, gfx.CONTROLS_LUMP_END)
        end
        return
    elseif scancode == id_in.sc_F3 then
        -- Load game
        wl_menu.CacheLump(gfx.CONTROLS_LUMP_START, gfx.CONTROLS_LUMP_END)
        wl_menu.CP_LoadGame()
        wl_menu.UnCacheLump(gfx.CONTROLS_LUMP_START, gfx.CONTROLS_LUMP_END)
        return
    elseif scancode == id_in.sc_F4 then
        -- Sound
        wl_menu.CacheLump(gfx.CONTROLS_LUMP_START, gfx.CONTROLS_LUMP_END)
        wl_menu.CP_Sound()
        wl_menu.UnCacheLump(gfx.CONTROLS_LUMP_START, gfx.CONTROLS_LUMP_END)
        return
    elseif scancode == id_in.sc_F5 then
        -- Change view
        wl_menu.CacheLump(gfx.CONTROLS_LUMP_START, gfx.CONTROLS_LUMP_END)
        wl_menu.CP_ChangeView()
        wl_menu.UnCacheLump(gfx.CONTROLS_LUMP_START, gfx.CONTROLS_LUMP_END)
        return
    elseif scancode == id_in.sc_F7 then
        -- Quick save/load
        return
    elseif scancode == id_in.sc_F8 then
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
    id_vh.VWB_DrawPic(84, 0, gfx.C_OPTIONSPIC)

    id_vh.fontnumber = 1
    id_vh.fontcolor = wl_menu.TEXTCOLOR
    id_vh.backcolor = wl_menu.BKGDCOLOR

    wl_menu.DrawWindow(wl_menu.MENU_X - 8, wl_menu.MENU_Y - 3,
        wl_menu.MENU_W, wl_menu.MENU_H, wl_menu.BKGDCOLOR)

    -- Draw menu items
    wl_menu.DrawMenuItems(wl_menu.MainItems, wl_menu.MainMenu)

    id_vh.VW_UpdateScreen()
    wl_menu.MenuFadeIn()

    -- Menu loop
    local done = false
    while not done do
        local sel = wl_menu.HandleMenu(wl_menu.MainItems, wl_menu.MainMenu)

        if sel < 0 then
            -- Escape pressed
            done = true
        elseif sel == wl_menu.mi_newgame then
            if wl_menu.CP_NewGame() then
                done = true
            else
                -- Redraw main menu
                wl_menu.ClearMScreen()
                id_vh.VWB_DrawPic(112, 184, gfx.C_MOUSELBACKPIC)
                wl_menu.DrawStripes(10)
                id_vh.VWB_DrawPic(84, 0, gfx.C_OPTIONSPIC)
                wl_menu.DrawWindow(wl_menu.MENU_X - 8, wl_menu.MENU_Y - 3,
                    wl_menu.MENU_W, wl_menu.MENU_H, wl_menu.BKGDCOLOR)
                wl_menu.DrawMenuItems(wl_menu.MainItems, wl_menu.MainMenu)
                id_vh.VW_UpdateScreen()
            end
        elseif sel == wl_menu.mi_soundmenu then
            wl_menu.CP_Sound()
            wl_menu.ClearMScreen()
            id_vh.VWB_DrawPic(112, 184, gfx.C_MOUSELBACKPIC)
            wl_menu.DrawStripes(10)
            id_vh.VWB_DrawPic(84, 0, gfx.C_OPTIONSPIC)
            wl_menu.DrawWindow(wl_menu.MENU_X - 8, wl_menu.MENU_Y - 3,
                wl_menu.MENU_W, wl_menu.MENU_H, wl_menu.BKGDCOLOR)
            wl_menu.DrawMenuItems(wl_menu.MainItems, wl_menu.MainMenu)
            id_vh.VW_UpdateScreen()
        elseif sel == wl_menu.mi_control then
            wl_menu.CP_Control()
            wl_menu.ClearMScreen()
            id_vh.VWB_DrawPic(112, 184, gfx.C_MOUSELBACKPIC)
            wl_menu.DrawStripes(10)
            id_vh.VWB_DrawPic(84, 0, gfx.C_OPTIONSPIC)
            wl_menu.DrawWindow(wl_menu.MENU_X - 8, wl_menu.MENU_Y - 3,
                wl_menu.MENU_W, wl_menu.MENU_H, wl_menu.BKGDCOLOR)
            wl_menu.DrawMenuItems(wl_menu.MainItems, wl_menu.MainMenu)
            id_vh.VW_UpdateScreen()
        elseif sel == wl_menu.mi_loadgame then
            wl_menu.CP_LoadGame()
            if wl_main.loadedgame then
                done = true
            else
                wl_menu.ClearMScreen()
                id_vh.VWB_DrawPic(112, 184, gfx.C_MOUSELBACKPIC)
                wl_menu.DrawStripes(10)
                id_vh.VWB_DrawPic(84, 0, gfx.C_OPTIONSPIC)
                wl_menu.DrawWindow(wl_menu.MENU_X - 8, wl_menu.MENU_Y - 3,
                    wl_menu.MENU_W, wl_menu.MENU_H, wl_menu.BKGDCOLOR)
                wl_menu.DrawMenuItems(wl_menu.MainItems, wl_menu.MainMenu)
                id_vh.VW_UpdateScreen()
            end
        elseif sel == wl_menu.mi_savegame then
            wl_menu.CP_SaveGame()
            wl_menu.ClearMScreen()
            id_vh.VWB_DrawPic(112, 184, gfx.C_MOUSELBACKPIC)
            wl_menu.DrawStripes(10)
            id_vh.VWB_DrawPic(84, 0, gfx.C_OPTIONSPIC)
            wl_menu.DrawWindow(wl_menu.MENU_X - 8, wl_menu.MENU_Y - 3,
                wl_menu.MENU_W, wl_menu.MENU_H, wl_menu.BKGDCOLOR)
            wl_menu.DrawMenuItems(wl_menu.MainItems, wl_menu.MainMenu)
            id_vh.VW_UpdateScreen()
        elseif sel == wl_menu.mi_changeview then
            wl_menu.CP_ChangeView()
            wl_menu.ClearMScreen()
            id_vh.VWB_DrawPic(112, 184, gfx.C_MOUSELBACKPIC)
            wl_menu.DrawStripes(10)
            id_vh.VWB_DrawPic(84, 0, gfx.C_OPTIONSPIC)
            wl_menu.DrawWindow(wl_menu.MENU_X - 8, wl_menu.MENU_Y - 3,
                wl_menu.MENU_W, wl_menu.MENU_H, wl_menu.BKGDCOLOR)
            wl_menu.DrawMenuItems(wl_menu.MainItems, wl_menu.MainMenu)
            id_vh.VW_UpdateScreen()
        elseif sel == wl_menu.mi_viewscores then
            wl_menu.CP_ViewScores()
            wl_menu.ClearMScreen()
            id_vh.VWB_DrawPic(112, 184, gfx.C_MOUSELBACKPIC)
            wl_menu.DrawStripes(10)
            id_vh.VWB_DrawPic(84, 0, gfx.C_OPTIONSPIC)
            wl_menu.DrawWindow(wl_menu.MENU_X - 8, wl_menu.MENU_Y - 3,
                wl_menu.MENU_W, wl_menu.MENU_H, wl_menu.BKGDCOLOR)
            wl_menu.DrawMenuItems(wl_menu.MainItems, wl_menu.MainMenu)
            id_vh.VW_UpdateScreen()
        elseif sel == wl_menu.mi_backtodemo then
            done = true
        elseif sel == wl_menu.mi_quit then
            if wl_menu.CP_Quit() then
                done = true
            end
        end
    end

    wl_menu.MenuFadeOut()
    wl_menu.UnCacheLump(gfx.CONTROLS_LUMP_START, gfx.CONTROLS_LUMP_END)
end

return wl_menu
