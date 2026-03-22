-- ID_US.lua
-- User Manager - ported from ID_US_1.C
-- Handles windows, printing, high scores, random numbers

local id_vl = require("id_vl")
local id_vh = require("id_vh")
local id_in = require("id_in")

local id_us = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------
id_us.MaxX = 320
id_us.MaxY = 200
id_us.MaxHighName = 57
id_us.MaxScores = 7
id_us.MaxGameName = 32
id_us.MaxSaveGames = 6
id_us.MaxString = 128

---------------------------------------------------------------------------
-- Global state
---------------------------------------------------------------------------
id_us.ingame       = false
id_us.abortgame    = false
id_us.loadedgame   = false
id_us.NoWait       = false
id_us.HighScoresDirty = false
id_us.abortprogram = nil

-- Game difficulty (gd_Continue, gd_Easy, etc.)
id_us.gd_Continue = 0
id_us.gd_Easy     = 1
id_us.gd_Normal   = 2
id_us.gd_Hard     = 3
id_us.restartgame = 0  -- gd_Continue

-- Print state
id_us.PrintX  = 0
id_us.PrintY  = 0
id_us.WindowX = 0
id_us.WindowY = 0
id_us.WindowW = 320
id_us.WindowH = 200

-- Cursor state
id_us.Button0   = false
id_us.Button1   = false
id_us.CursorBad = false
id_us.CursorX   = 0
id_us.CursorY   = 0

-- Function pointers for string measurement/drawing
id_us.USL_MeasureString = nil
id_us.USL_DrawString    = nil

-- Save/Load hooks
id_us.USL_SaveGame  = nil
id_us.USL_LoadGame  = nil
id_us.USL_ResetGame = nil

-- Save game slots
id_us.Games = {}
for i = 1, id_us.MaxSaveGames do
    id_us.Games[i] = {
        signature = "",
        oldtest   = nil,
        present   = false,
        name      = "",
    }
end

-- High scores
id_us.Scores = {}
for i = 1, id_us.MaxScores do
    id_us.Scores[i] = {
        name      = "",
        score     = 0,
        completed = 0,
        episode   = 0,
    }
end

-- Default high scores (WL6)
local defaultScores = {
    {"id software-'92",10000,1,0},
    {"Adrian Carmack",10000,1,0},
    {"John Carmack",10000,1,0},
    {"Kevin Cloud",10000,1,0},
    {"Tom Hall",10000,1,0},
    {"John Romero",10000,1,0},
    {"Jay Wilbur",10000,1,0},
}

for i = 1, #defaultScores do
    id_us.Scores[i].name = defaultScores[i][1]
    id_us.Scores[i].score = defaultScores[i][2]
    id_us.Scores[i].completed = defaultScores[i][3]
    id_us.Scores[i].episode = defaultScores[i][4]
end

-- Random number table (rndtable from original)
local rndtable = {
      0,   8, 109, 220, 222, 241, 149, 107,  75, 248, 254, 140,  16,  66,
     74,  21, 211,  47,  80, 242, 154,  27, 205, 128, 161,  89,  77,  36,
     95, 110,  85,  48, 212, 140, 211, 249,  22,  79, 200,  50,  28, 188,
     52, 140, 202, 120,  68, 145,  62,  70, 184, 190,  91, 197, 152, 224,
    149, 104,  25, 178, 252, 182, 202, 182, 141, 197,   4,  81, 181, 242,
    145,  42,  39, 227, 156, 198, 225, 193, 219,  93, 122,  175,  249,   0,
    175, 143,  70, 239,  46, 246, 163,  53, 163, 109, 168, 135,   2, 235,
     25,  92,  20, 145, 138,  77,  69, 166,  78, 176, 173, 212, 166, 113,
     94, 161,  41,  50, 239,  49, 111, 164,  70,  60,   2,  37, 171,  75,
    136, 156,  11,  56,  42, 146, 138, 229,  73, 146,  77,  61,  98, 196,
    135, 106,  63, 197, 195,  86,  96, 203, 113, 101, 170, 247, 181, 113,
     80, 250, 108,   7, 255, 237, 129, 226,  79, 107, 112, 166, 103, 241,
     24, 223, 239, 120, 198,  58,  60,  82, 128,   3, 184,  66, 143, 224,
    145, 224,  81, 206, 163,  45,  63,  90, 168, 114,  59,  33, 159,  95,
     28, 139, 123,  98, 125, 196,  15,  70, 194, 253,  54,  14, 109, 226,
     71,  17, 161,  93, 186,  87, 244, 138,  20,  52, 123, 251,  26,  36,
     17,  46,  52, 231, 232,  76,  31, 221,  84,  37, 216, 165, 212, 106,
    197, 242,  98,  43,  39, 175, 254, 145, 190,  84, 118, 222, 187, 136,
    120, 163, 236, 249,
}

local rndindex = 1

---------------------------------------------------------------------------
-- Startup / Shutdown
---------------------------------------------------------------------------

function id_us.US_Startup()
    -- Set up default string drawing functions
    id_us.USL_MeasureString = function(str)
        return id_vh.VW_MeasurePropString(str)
    end
    id_us.USL_DrawString = function(str)
        id_vh.VWB_DrawPropString(str)
    end
end

function id_us.US_Setup()
    -- Additional setup
end

function id_us.US_Shutdown()
    -- Nothing to clean up
end

---------------------------------------------------------------------------
-- Random numbers
---------------------------------------------------------------------------

function id_us.US_InitRndT(randomize)
    if randomize then
        rndindex = math.floor(love.timer.getTime() * 1000) % 256 + 1
    else
        rndindex = 1
    end
end

function id_us.US_RndT()
    rndindex = (rndindex % 256) + 1
    return rndtable[rndindex] or 0
end

---------------------------------------------------------------------------
-- Window management
---------------------------------------------------------------------------

function id_us.US_DrawWindow(x, y, w, h)
    id_vh.VWB_Bar(x, y, w, h, id_vh.backcolor)
    -- Draw borders
    id_vh.VWB_Hlin(x, x + w - 1, y, 0)           -- top
    id_vh.VWB_Hlin(x, x + w - 1, y + h - 1, 0)   -- bottom
    id_vh.VWB_Vlin(y, y + h - 1, x, 0)            -- left
    id_vh.VWB_Vlin(y, y + h - 1, x + w - 1, 0)   -- right
end

function id_us.US_CenterWindow(w, h)
    -- w, h in character units (8 pixels each)
    local pw = w * 8
    local ph = h * 8
    id_us.WindowX = math.floor((320 - pw) / 2)
    id_us.WindowY = math.floor((200 - ph) / 2)
    id_us.WindowW = pw
    id_us.WindowH = ph
    id_us.PrintX = id_us.WindowX
    id_us.PrintY = id_us.WindowY

    id_us.US_DrawWindow(id_us.WindowX - 8, id_us.WindowY - 8, pw + 16, ph + 16)
end

function id_us.US_SaveWindow()
    return {
        x = id_us.WindowX,
        y = id_us.WindowY,
        w = id_us.WindowW,
        h = id_us.WindowH,
        px = id_us.PrintX,
        py = id_us.PrintY,
    }
end

function id_us.US_RestoreWindow(win)
    id_us.WindowX = win.x
    id_us.WindowY = win.y
    id_us.WindowW = win.w
    id_us.WindowH = win.h
    id_us.PrintX  = win.px
    id_us.PrintY  = win.py
end

function id_us.US_ClearWindow()
    id_vh.VWB_Bar(id_us.WindowX, id_us.WindowY, id_us.WindowW, id_us.WindowH, id_vh.backcolor)
    id_us.PrintX = id_us.WindowX
    id_us.PrintY = id_us.WindowY
end

function id_us.US_HomeWindow()
    id_us.PrintX = id_us.WindowX
    id_us.PrintY = id_us.WindowY
end

---------------------------------------------------------------------------
-- String printing
---------------------------------------------------------------------------

function id_us.US_SetPrintRoutines(measure, print_fn)
    id_us.USL_MeasureString = measure
    id_us.USL_DrawString = print_fn
end

function id_us.US_Print(str)
    -- Handle newlines
    local lines = {}
    local current = ""
    for i = 1, #str do
        local c = string.sub(str, i, i)
        if c == "\n" then
            table.insert(lines, current)
            current = ""
        else
            current = current .. c
        end
    end
    table.insert(lines, current)

    for li, line in ipairs(lines) do
        if #line > 0 then
            id_vh.px = id_us.PrintX
            id_vh.py = id_us.PrintY
            if id_us.USL_DrawString then
                id_us.USL_DrawString(line)
            end
            id_us.PrintX = id_vh.px
        end

        if li < #lines then
            -- Newline: move down, reset X
            local _, h = 0, 10
            if id_us.USL_MeasureString then
                _, h = id_us.USL_MeasureString("A")
            end
            id_us.PrintY = id_us.PrintY + h
            id_us.PrintX = id_us.WindowX
        end
    end
end

function id_us.US_PrintUnsigned(n)
    id_us.US_Print(tostring(math.floor(n)))
end

function id_us.US_PrintSigned(n)
    id_us.US_Print(tostring(math.floor(n)))
end

function id_us.US_CPrint(str)
    -- Center-print within the window
    local w, h = 0, 10
    if id_us.USL_MeasureString then
        w, h = id_us.USL_MeasureString(str)
    end

    id_us.PrintX = id_us.WindowX + math.floor((id_us.WindowW - w) / 2)
    id_vh.px = id_us.PrintX
    id_vh.py = id_us.PrintY
    if id_us.USL_DrawString then
        id_us.USL_DrawString(str)
    end
    id_us.PrintY = id_us.PrintY + h
end

function id_us.US_CPrintLine(str)
    id_us.US_CPrint(str)
end

function id_us.US_PrintCentered(str)
    id_us.US_CPrint(str)
end

function id_us.USL_PrintInCenter(str, rect)
    -- Print string centered in a rectangle
    local w, h = 0, 10
    if id_us.USL_MeasureString then
        w, h = id_us.USL_MeasureString(str)
    end
    id_us.PrintX = rect.ul.x + math.floor(((rect.lr.x - rect.ul.x) - w) / 2)
    id_us.PrintY = rect.ul.y + math.floor(((rect.lr.y - rect.ul.y) - h) / 2)
    id_vh.px = id_us.PrintX
    id_vh.py = id_us.PrintY
    if id_us.USL_DrawString then
        id_us.USL_DrawString(str)
    end
end

---------------------------------------------------------------------------
-- Hooks
---------------------------------------------------------------------------

function id_us.US_SetLoadSaveHooks(load_fn, save_fn, reset_fn)
    id_us.USL_LoadGame = load_fn
    id_us.USL_SaveGame = save_fn
    id_us.USL_ResetGame = reset_fn
end

---------------------------------------------------------------------------
-- High scores
---------------------------------------------------------------------------

function id_us.US_CheckHighScore(score, other)
    -- Check if score qualifies for high score table
    local index = -1
    for i = 1, id_us.MaxScores do
        if score > id_us.Scores[i].score then
            index = i
            break
        end
    end

    if index > 0 then
        -- Shift scores down
        for i = id_us.MaxScores, index + 1, -1 do
            id_us.Scores[i] = id_us.Scores[i - 1]
        end
        id_us.Scores[index] = {
            name = "Unknown",
            score = score,
            completed = other,
            episode = 0,
        }
        id_us.HighScoresDirty = true
    end
end

function id_us.US_DisplayHighScores(which)
    -- Display high scores (stub - would draw to screen)
end

---------------------------------------------------------------------------
-- Parameter checking
---------------------------------------------------------------------------

function id_us.US_CheckParm(parm, strings)
    if not strings then return -1 end
    local parm_lower = string.lower(parm)
    for i, s in ipairs(strings) do
        if s and string.lower(s) == parm_lower then
            return i - 1  -- 0-indexed like C
        end
    end
    return -1
end

---------------------------------------------------------------------------
-- Line input
---------------------------------------------------------------------------

function id_us.US_LineInput(x, y, buf, def, escok, maxchars, maxwidth)
    -- Text entry with cursor, backspace, and character input
    -- Returns ok (bool), result_string
    local id_vh = require("id_vh")
    local id_in = require("id_in")
    local id_sd = require("id_sd")

    local result = def or ""
    maxchars = maxchars or 31
    maxwidth = maxwidth or 200
    local cursor_visible = true
    local cursor_timer = 0
    local CURSOR_BLINK_RATE = 25  -- tics

    -- Save font state
    local saved_fc = id_vh.fontcolor
    local saved_bc = id_vh.backcolor

    id_vh.fontnumber = 0
    id_vh.fontcolor = 0x0f
    id_vh.backcolor = 0x00

    id_in.IN_ClearKeysDown()

    while true do
        -- Draw current text with cursor
        id_vh.VWB_Bar(x, y, maxwidth, 10, 0x00)
        id_vh.px = x
        id_vh.py = y
        id_vh.VWB_DrawPropString(result)

        -- Draw cursor
        if cursor_visible then
            id_vh.VWB_Bar(id_vh.px, y, 1, 10, 0x0f)
        end

        id_vh.VW_UpdateScreen()

        -- Process input
        id_in.IN_WaitAndProcessEvents()

        -- Blink cursor
        cursor_timer = cursor_timer + 1
        if cursor_timer >= CURSOR_BLINK_RATE then
            cursor_timer = 0
            cursor_visible = not cursor_visible
        end

        local scan = id_in.LastScan
        if scan == id_in.sc_Return then
            id_in.IN_ClearKey(id_in.sc_Return)
            id_vh.fontcolor = saved_fc
            id_vh.backcolor = saved_bc
            return true, result
        elseif scan == id_in.sc_Escape then
            id_in.IN_ClearKey(id_in.sc_Escape)
            id_vh.fontcolor = saved_fc
            id_vh.backcolor = saved_bc
            if escok then
                return false, def or ""
            end
            return true, def or ""
        elseif scan == id_in.sc_BackSpace then
            id_in.IN_ClearKey(id_in.sc_BackSpace)
            if #result > 0 then
                result = string.sub(result, 1, #result - 1)
            end
            cursor_visible = true
            cursor_timer = 0
        else
            -- Check for printable character via LastASCII
            local ascii = id_in.LastASCII or 0
            if ascii >= 32 and ascii < 127 and #result < maxchars then
                -- Check if adding character would exceed max width
                local test_str = result .. string.char(ascii)
                local w, _ = id_vh.VW_MeasurePropString(test_str)
                if w <= maxwidth then
                    result = test_str
                end
                cursor_visible = true
                cursor_timer = 0
            end
            id_in.LastASCII = 0
            if scan ~= 0 then
                id_in.IN_ClearKey(scan)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Text screen (not used in graphical mode)
---------------------------------------------------------------------------

function id_us.US_TextScreen()
end

function id_us.US_UpdateTextScreen()
end

function id_us.US_FinishTextScreen()
end

---------------------------------------------------------------------------
-- Save game name helper
---------------------------------------------------------------------------

function id_us.USL_GiveSaveName(game)
    return string.format("SAVEGAM%d.WL6", game)
end

return id_us
