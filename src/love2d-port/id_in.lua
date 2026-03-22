-- ID_IN.lua
-- Input Manager - ported from ID_IN.C (SDL3 version)
-- Uses Love2D keyboard/mouse callbacks

local id_in = {}

---------------------------------------------------------------------------
-- Constants (from ID_IN.H)
---------------------------------------------------------------------------
id_in.MaxPlayers = 4
id_in.MaxKbds    = 2
id_in.MaxJoys    = 2
id_in.NumCodes   = 128

-- Scan codes (DOS keyboard scan codes)
id_in.sc_None       = 0
id_in.sc_Bad        = 0xff
id_in.sc_Return     = 0x1c
id_in.sc_Enter      = 0x1c
id_in.sc_Escape     = 0x01
id_in.sc_Space      = 0x39
id_in.sc_BackSpace  = 0x0e
id_in.sc_Tab        = 0x0f
id_in.sc_Alt        = 0x38
id_in.sc_Control    = 0x1d
id_in.sc_CapsLock   = 0x3a
id_in.sc_LShift     = 0x2a
id_in.sc_RShift     = 0x36
id_in.sc_UpArrow    = 0x48
id_in.sc_DownArrow  = 0x50
id_in.sc_LeftArrow  = 0x4b
id_in.sc_RightArrow = 0x4d
id_in.sc_Insert     = 0x52
id_in.sc_Delete     = 0x53
id_in.sc_Home       = 0x47
id_in.sc_End        = 0x4f
id_in.sc_PgUp       = 0x49
id_in.sc_PgDn       = 0x51
id_in.sc_F1         = 0x3b
id_in.sc_F2         = 0x3c
id_in.sc_F3         = 0x3d
id_in.sc_F4         = 0x3e
id_in.sc_F5         = 0x3f
id_in.sc_F6         = 0x40
id_in.sc_F7         = 0x41
id_in.sc_F8         = 0x42
id_in.sc_F9         = 0x43
id_in.sc_F10        = 0x44
id_in.sc_F11        = 0x57
id_in.sc_F12        = 0x59
id_in.sc_Pause      = 0x61

id_in.sc_1 = 0x02;  id_in.sc_2 = 0x03;  id_in.sc_3 = 0x04
id_in.sc_4 = 0x05;  id_in.sc_5 = 0x06;  id_in.sc_6 = 0x07
id_in.sc_7 = 0x08;  id_in.sc_8 = 0x09;  id_in.sc_9 = 0x0a
id_in.sc_0 = 0x0b

id_in.sc_A = 0x1e;  id_in.sc_B = 0x30;  id_in.sc_C = 0x2e
id_in.sc_D = 0x20;  id_in.sc_E = 0x12;  id_in.sc_F = 0x21
id_in.sc_G = 0x22;  id_in.sc_H = 0x23;  id_in.sc_I = 0x17
id_in.sc_J = 0x24;  id_in.sc_K = 0x25;  id_in.sc_L = 0x26
id_in.sc_M = 0x32;  id_in.sc_N = 0x31;  id_in.sc_O = 0x18
id_in.sc_P = 0x19;  id_in.sc_Q = 0x10;  id_in.sc_R = 0x13
id_in.sc_S = 0x1f;  id_in.sc_T = 0x14;  id_in.sc_U = 0x16
id_in.sc_V = 0x2f;  id_in.sc_W = 0x11;  id_in.sc_X = 0x2d
id_in.sc_Y = 0x15;  id_in.sc_Z = 0x2c

-- Demo modes
id_in.demo_Off       = 0
id_in.demo_Record    = 1
id_in.demo_Playback  = 2
id_in.demo_PlayDone  = 3

-- Control types
id_in.ctrl_Keyboard  = 0
id_in.ctrl_Keyboard1 = 0
id_in.ctrl_Keyboard2 = 1
id_in.ctrl_Joystick  = 2
id_in.ctrl_Joystick1 = 2
id_in.ctrl_Joystick2 = 3
id_in.ctrl_Mouse     = 4

-- Motion
id_in.motion_Left  = -1
id_in.motion_Up    = -1
id_in.motion_None  = 0
id_in.motion_Right = 1
id_in.motion_Down  = 1

-- Direction
id_in.dir_North     = 0
id_in.dir_NorthEast = 1
id_in.dir_East      = 2
id_in.dir_SouthEast = 3
id_in.dir_South     = 4
id_in.dir_SouthWest = 5
id_in.dir_West      = 6
id_in.dir_NorthWest = 7
id_in.dir_None      = 8

---------------------------------------------------------------------------
-- Global state
---------------------------------------------------------------------------
id_in.Keyboard     = {}    -- [scancode] = true/false
id_in.MousePresent = true
id_in.JoysPresent  = {false, false}
id_in.Paused       = false
id_in.LastASCII    = 0
id_in.LastScan     = 0

id_in.KbdDefs = {
    button0  = 0x1d,  -- ctrl
    button1  = 0x38,  -- alt
    upleft   = 0x47,
    up       = 0x48,
    upright  = 0x49,
    left     = 0x4b,
    right    = 0x4d,
    downleft = 0x4f,
    down     = 0x50,
    downright = 0x51,
}

id_in.JoyDefs  = {{}, {}}
id_in.Controls = {0, 0, 0, 0}  -- ControlType for each player

id_in.DemoMode   = 0  -- demo_Off
id_in.DemoBuffer = nil
id_in.DemoOffset = 0
id_in.DemoSize   = 0

-- Internal state
local IN_Started   = false
local CapsLock     = false
local CurCode      = 0
local LastCode     = 0
local INL_KeyHook  = nil
local mouse_dx, mouse_dy = 0, 0
local mouse_buttons = 0

-- Initialize keyboard array
for i = 0, id_in.NumCodes - 1 do
    id_in.Keyboard[i] = false
end

---------------------------------------------------------------------------
-- Love2D key -> DOS scancode mapping
---------------------------------------------------------------------------
local love_to_scancode = {
    ["escape"]    = 0x01,
    ["1"]         = 0x02, ["2"] = 0x03, ["3"] = 0x04, ["4"] = 0x05,
    ["5"]         = 0x06, ["6"] = 0x07, ["7"] = 0x08, ["8"] = 0x09,
    ["9"]         = 0x0a, ["0"] = 0x0b,
    ["-"]         = 0x0c, ["="] = 0x0d,
    ["backspace"] = 0x0e, ["tab"] = 0x0f,
    ["q"] = 0x10, ["w"] = 0x11, ["e"] = 0x12, ["r"] = 0x13,
    ["t"] = 0x14, ["y"] = 0x15, ["u"] = 0x16, ["i"] = 0x17,
    ["o"] = 0x18, ["p"] = 0x19,
    ["["]  = 0x1a, ["]"] = 0x1b,
    ["return"]  = 0x1c,
    ["lctrl"]   = 0x1d, ["rctrl"] = 0x1d,
    ["a"] = 0x1e, ["s"] = 0x1f, ["d"] = 0x20, ["f"] = 0x21,
    ["g"] = 0x22, ["h"] = 0x23, ["j"] = 0x24, ["k"] = 0x25,
    ["l"] = 0x26,
    [";"]  = 0x27, ["'"] = 0x28, ["`"] = 0x29,
    ["lshift"]  = 0x2a, ["\\"] = 0x2b,
    ["z"] = 0x2c, ["x"] = 0x2d, ["c"] = 0x2e, ["v"] = 0x2f,
    ["b"] = 0x30, ["n"] = 0x31, ["m"] = 0x32,
    [","]  = 0x33, ["."] = 0x34, ["/"] = 0x35,
    ["rshift"]  = 0x36,
    ["lalt"]    = 0x38, ["ralt"] = 0x38,
    ["space"]   = 0x39,
    ["capslock"] = 0x3a,
    ["f1"] = 0x3b, ["f2"] = 0x3c, ["f3"] = 0x3d, ["f4"] = 0x3e,
    ["f5"] = 0x3f, ["f6"] = 0x40, ["f7"] = 0x41, ["f8"] = 0x42,
    ["f9"] = 0x43, ["f10"] = 0x44,
    ["f11"]     = 0x57, ["f12"] = 0x59,
    ["home"]    = 0x47, ["up"]    = 0x48, ["pageup"]   = 0x49,
    ["left"]    = 0x4b, ["right"] = 0x4d,
    ["end"]     = 0x4f, ["down"]  = 0x50, ["pagedown"] = 0x51,
    ["insert"]  = 0x52, ["delete"] = 0x53,
    ["kp7"] = 0x47, ["kp8"] = 0x48, ["kp9"] = 0x49,
    ["kp4"] = 0x4b, ["kp5"] = 0x4c, ["kp6"] = 0x4d,
    ["kp1"] = 0x4f, ["kp2"] = 0x50, ["kp3"] = 0x51,
    ["kp0"] = 0x52, ["kp."] = 0x53,
    ["kpenter"] = 0x1c,
}

-- Unshifted ASCII table (indexed by scancode)
local ASCIINames = {
    [0x00]=0, [0x01]=27, [0x02]=49, [0x03]=50, [0x04]=51, [0x05]=52,
    [0x06]=53, [0x07]=54, [0x08]=55, [0x09]=56, [0x0a]=57, [0x0b]=48,
    [0x0c]=45, [0x0d]=61, [0x0e]=8, [0x0f]=9,
    [0x10]=113, [0x11]=119, [0x12]=101, [0x13]=114, [0x14]=116, [0x15]=121,
    [0x16]=117, [0x17]=105, [0x18]=111, [0x19]=112, [0x1a]=91, [0x1b]=93,
    [0x1c]=13, [0x1d]=0, [0x1e]=97, [0x1f]=115,
    [0x20]=100, [0x21]=102, [0x22]=103, [0x23]=104, [0x24]=106, [0x25]=107,
    [0x26]=108, [0x27]=59, [0x28]=39, [0x29]=96,
    [0x2a]=0, [0x2b]=92, [0x2c]=122, [0x2d]=120, [0x2e]=99, [0x2f]=118,
    [0x30]=98, [0x31]=110, [0x32]=109, [0x33]=44, [0x34]=46, [0x35]=47,
    [0x36]=0, [0x37]=42, [0x38]=0, [0x39]=32,
}

-- Shifted ASCII table
local ShiftNames = {
    [0x00]=0, [0x01]=27, [0x02]=33, [0x03]=64, [0x04]=35, [0x05]=36,
    [0x06]=37, [0x07]=94, [0x08]=38, [0x09]=42, [0x0a]=40, [0x0b]=41,
    [0x0c]=95, [0x0d]=43, [0x0e]=8, [0x0f]=9,
    [0x10]=81, [0x11]=87, [0x12]=69, [0x13]=82, [0x14]=84, [0x15]=89,
    [0x16]=85, [0x17]=73, [0x18]=79, [0x19]=80, [0x1a]=123, [0x1b]=125,
    [0x1c]=13, [0x1d]=0, [0x1e]=65, [0x1f]=83,
    [0x20]=68, [0x21]=70, [0x22]=71, [0x23]=72, [0x24]=74, [0x25]=75,
    [0x26]=76, [0x27]=58, [0x28]=34, [0x29]=126,
    [0x2a]=0, [0x2b]=124, [0x2c]=90, [0x2d]=88, [0x2e]=67, [0x2f]=86,
    [0x30]=66, [0x31]=78, [0x32]=77, [0x33]=60, [0x34]=62, [0x35]=63,
    [0x36]=0, [0x37]=42, [0x38]=0, [0x39]=32,
}

-- Direction lookup table
local DirTable = {
    id_in.dir_NorthWest, id_in.dir_North, id_in.dir_NorthEast,
    id_in.dir_West,      id_in.dir_None,  id_in.dir_East,
    id_in.dir_SouthWest, id_in.dir_South, id_in.dir_SouthEast,
}

---------------------------------------------------------------------------
-- Key hook support
---------------------------------------------------------------------------

function id_in.IN_SetKeyHook(hook)
    INL_KeyHook = hook
end

---------------------------------------------------------------------------
-- Love2D keyboard callbacks (called from main.lua)
---------------------------------------------------------------------------

function id_in.keypressed(key, scancode, isrepeat)
    if isrepeat then return end

    local k = love_to_scancode[key]
    if not k then return end

    if key == "pause" then
        id_in.Paused = true
        return
    end

    if k ~= id_in.sc_None and k < id_in.NumCodes then
        LastCode = CurCode
        CurCode = k
        id_in.LastScan = k
        id_in.Keyboard[k] = true

        if k == id_in.sc_CapsLock then
            CapsLock = not CapsLock
        end

        -- Determine ASCII character
        local c = 0
        if id_in.Keyboard[id_in.sc_LShift] or id_in.Keyboard[id_in.sc_RShift] then
            c = ShiftNames[k] or 0
            if c >= 65 and c <= 90 and CapsLock then
                c = c + 32
            end
        else
            c = ASCIINames[k] or 0
            if c >= 97 and c <= 122 and CapsLock then
                c = c - 32
            end
        end
        if c ~= 0 then
            id_in.LastASCII = c
        end
    end

    if INL_KeyHook then
        INL_KeyHook()
    end
end

function id_in.keyreleased(key, scancode)
    local k = love_to_scancode[key]
    if not k then return end

    if k ~= id_in.sc_None and k < id_in.NumCodes then
        id_in.Keyboard[k] = false
    end

    if INL_KeyHook then
        INL_KeyHook()
    end
end

---------------------------------------------------------------------------
-- Mouse callbacks
---------------------------------------------------------------------------

function id_in.mousemoved(x, y, dx, dy)
    mouse_dx = mouse_dx + dx
    mouse_dy = mouse_dy + dy
end

function id_in.mousepressed(x, y, button)
    if button == 1 then mouse_buttons = mouse_buttons + 1 end   -- rough tracking
end

function id_in.mousereleased(x, y, button)
    -- handled by polling
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function id_in.IN_Startup()
    IN_Started = true
    INL_KeyHook = nil
    id_in.IN_ClearKeysDown()
    id_in.MousePresent = true
end

function id_in.IN_Shutdown()
    IN_Started = false
end

function id_in.IN_Default(gotit, ctrl_type)
    -- Set default control type
    id_in.Controls[1] = ctrl_type
end

function id_in.IN_ClearKeysDown()
    id_in.LastScan = id_in.sc_None
    id_in.LastASCII = 0
    for i = 0, id_in.NumCodes - 1 do
        id_in.Keyboard[i] = false
    end
end

function id_in.IN_KeyDown(code)
    return id_in.Keyboard[code] or false
end

function id_in.IN_ClearKey(code)
    id_in.Keyboard[code] = false
    if code == id_in.LastScan then
        id_in.LastScan = id_in.sc_None
    end
end

function id_in.IN_ProcessEvents()
    -- In Love2D, events are processed via callbacks.
    -- This function is a placeholder that may pump love.event.
    love.event.pump()
    for name, a, b, c, d, e, f in love.event.poll() do
        if name == "quit" then
            return "quit"
        elseif name == "keypressed" then
            id_in.keypressed(a, b, c)
        elseif name == "keyreleased" then
            id_in.keyreleased(a, b)
        elseif name == "mousemoved" then
            id_in.mousemoved(a, b, c, d)
        elseif name == "mousepressed" then
            id_in.mousepressed(a, b, c)
        elseif name == "mousereleased" then
            id_in.mousereleased(a, b, c)
        end
    end

    -- Update TimeCount from real time
    local id_sd = require("id_sd")
    id_sd.SD_TimeCountUpdate()

    return nil
end

function id_in.IN_WaitAndProcessEvents()
    -- Yield to Love2D event loop if in a coroutine
    local co = coroutine.running()
    if co then
        coroutine.yield()
    else
        love.timer.sleep(0.001)
    end
    id_in.IN_ProcessEvents()
end

function id_in.IN_MouseButtons()
    local buttons = 0
    if love.mouse.isDown(1) then buttons = buttons + 1 end
    if love.mouse.isDown(2) then buttons = buttons + 2 end
    if love.mouse.isDown(3) then buttons = buttons + 4 end
    return buttons
end

function id_in.IN_GetMouseDelta()
    local dx, dy = mouse_dx, mouse_dy
    mouse_dx, mouse_dy = 0, 0
    return dx, dy
end

function id_in.IN_JoyButtons()
    return 0
end

function id_in.INL_GetJoyDelta(joy)
    return 0, 0
end

function id_in.IN_GetJoyAbs(joy)
    return 0, 0
end

function id_in.IN_SetupJoy(joy, minx, maxx, miny, maxy)
    -- stub
end

function id_in.IN_GetJoyButtonsDB(joy)
    return 0
end

function id_in.IN_GetScanName(sc)
    -- Return name for scancode (stub - returns empty string)
    return ""
end

---------------------------------------------------------------------------
-- Acknowledgement functions (wait for keypress)
---------------------------------------------------------------------------

local ack_buttons = false
local ack_keys = {}

function id_in.IN_StartAck()
    -- Record current state
    id_in.IN_ProcessEvents()
    ack_buttons = (id_in.IN_MouseButtons() ~= 0)
    for i = 0, id_in.NumCodes - 1 do
        ack_keys[i] = id_in.Keyboard[i]
    end
end

function id_in.IN_CheckAck()
    id_in.IN_ProcessEvents()

    -- Check if any NEW key was pressed
    for i = 0, id_in.NumCodes - 1 do
        if id_in.Keyboard[i] and not ack_keys[i] then
            return true
        end
    end

    -- Check mouse buttons
    if not ack_buttons and (id_in.IN_MouseButtons() ~= 0) then
        return true
    end

    return false
end

function id_in.IN_Ack()
    id_in.IN_StartAck()
    while true do
        id_in.IN_WaitAndProcessEvents()
        if id_in.IN_CheckAck() then
            return
        end
    end
end

function id_in.IN_AckBack()
    -- Same as IN_Ack for our purposes
    id_in.IN_Ack()
end

function id_in.IN_UserInput(delay)
    -- Wait up to 'delay' ticks (70Hz) for input, return true if input received
    local id_sd = require("id_sd")
    local lasttime = id_sd.TimeCount
    id_in.IN_StartAck()

    while true do
        id_in.IN_WaitAndProcessEvents()
        if id_in.IN_CheckAck() then
            return true
        end
        if (id_sd.TimeCount - lasttime) >= delay then
            return false
        end
    end
end

function id_in.IN_WaitForKey()
    while true do
        id_in.IN_WaitAndProcessEvents()
        if id_in.LastScan ~= id_in.sc_None then
            local sc = id_in.LastScan
            id_in.LastScan = id_in.sc_None
            return sc
        end
    end
end

function id_in.IN_WaitForASCII()
    while true do
        id_in.IN_WaitAndProcessEvents()
        if id_in.LastASCII ~= 0 then
            local c = id_in.LastASCII
            id_in.LastASCII = 0
            return string.char(c)
        end
    end
end

---------------------------------------------------------------------------
-- Control reading
---------------------------------------------------------------------------

function id_in.IN_ReadControl(player_num)
    local info = {
        button0 = false,
        button1 = false,
        button2 = false,
        button3 = false,
        x = 0,
        y = 0,
        xaxis = id_in.motion_None,
        yaxis = id_in.motion_None,
        dir = id_in.dir_None,
    }

    id_in.IN_ProcessEvents()

    -- Keyboard reading
    local kbd = id_in.KbdDefs
    if id_in.Keyboard[kbd.button0] then info.button0 = true end
    if id_in.Keyboard[kbd.button1] then info.button1 = true end

    -- Direction from keyboard
    local dx, dy = 0, 0
    if id_in.Keyboard[kbd.up]      then dy = dy - 1 end
    if id_in.Keyboard[kbd.down]    then dy = dy + 1 end
    if id_in.Keyboard[kbd.left]    then dx = dx - 1 end
    if id_in.Keyboard[kbd.right]   then dx = dx + 1 end
    if id_in.Keyboard[kbd.upleft]  then dx = dx - 1; dy = dy - 1 end
    if id_in.Keyboard[kbd.upright] then dx = dx + 1; dy = dy - 1 end
    if id_in.Keyboard[kbd.downleft]  then dx = dx - 1; dy = dy + 1 end
    if id_in.Keyboard[kbd.downright] then dx = dx + 1; dy = dy + 1 end

    -- Clamp
    if dx < -1 then dx = -1 elseif dx > 1 then dx = 1 end
    if dy < -1 then dy = -1 elseif dy > 1 then dy = 1 end

    info.x = dx
    info.y = dy
    info.xaxis = dx
    info.yaxis = dy

    -- Direction lookup
    local dir_idx = (dy + 1) * 3 + (dx + 1) + 1  -- 1-indexed into DirTable
    info.dir = DirTable[dir_idx] or id_in.dir_None

    return info
end

function id_in.IN_ReadCursor()
    -- Same as ReadControl for cursor
    return id_in.IN_ReadControl(1)
end

function id_in.IN_SetControlType(player, ctrl_type)
    if player >= 1 and player <= id_in.MaxPlayers then
        id_in.Controls[player] = ctrl_type
    end
end

function id_in.IN_StopDemo()
    id_in.DemoMode = id_in.demo_Off
end

function id_in.IN_FreeDemoBuffer()
    id_in.DemoBuffer = nil
    id_in.DemoMode = id_in.demo_Off
end

return id_in
