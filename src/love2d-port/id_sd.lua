-- ID_SD.lua
-- Sound Manager - ported from ID_SD.C (SDL3 version)
-- Uses Love2D audio for sound output
-- OPL2/AdLib emulation is stubbed - sounds will be silent until implemented

local id_sd = {}

---------------------------------------------------------------------------
-- Constants (from ID_SD.H)
---------------------------------------------------------------------------
id_sd.TickBase = 70  -- 70Hz tick rate

-- Sound modes
id_sd.sdm_Off   = 0
id_sd.sdm_PC    = 1
id_sd.sdm_AdLib = 2

-- Music modes
id_sd.smm_Off   = 0
id_sd.smm_AdLib = 1

-- Digitized sound modes
id_sd.sds_Off          = 0
id_sd.sds_PC           = 1
id_sd.sds_SoundSource  = 2
id_sd.sds_SoundBlaster = 3

---------------------------------------------------------------------------
-- Global state
---------------------------------------------------------------------------
id_sd.AdLibPresent       = true    -- Pretend AdLib is present
id_sd.SoundSourcePresent = false
id_sd.SoundBlasterPresent = true   -- Pretend SB is present
id_sd.NeedsMusic         = false
id_sd.SoundPositioned    = false

id_sd.SoundMode  = id_sd.sdm_AdLib
id_sd.DigiMode   = id_sd.sds_SoundBlaster
id_sd.MusicMode  = id_sd.smm_AdLib
id_sd.DigiPlaying = false

-- TimeCount: global game time in ticks (70Hz)
id_sd.TimeCount  = 0

-- DigiMap: maps sound names to digitized sound chunk numbers
local audiowl6 = require("audiowl6")
id_sd.DigiMap = {}
for i = 0, audiowl6.LASTSOUND - 1 do
    id_sd.DigiMap[i] = -1
end

-- Sound playing state
local SoundPlaying  = 0
local SoundPriority = 0
local UserHook      = nil

-- Music state
local MusicPlaying = false
local sqHack       = nil
local sqHackLen    = 0

-- Time tracking for TimeCount
local timecount_start = nil
local timecount_last_update = 0

---------------------------------------------------------------------------
-- Startup / Shutdown
---------------------------------------------------------------------------

function id_sd.SD_Startup()
    -- Initialize time tracking
    timecount_start = love.timer.getTime()
    id_sd.TimeCount = 0
end

function id_sd.SD_Shutdown()
    id_sd.SD_MusicOff()
    id_sd.SD_StopSound()
end

---------------------------------------------------------------------------
-- TimeCount management
-- In the original, TimeCount was incremented by the audio callback at 70Hz.
-- We simulate this from real time.
---------------------------------------------------------------------------

function id_sd.SD_TimeCountUpdate()
    if not timecount_start then
        timecount_start = love.timer.getTime()
    end
    local now = love.timer.getTime()
    local elapsed = now - timecount_start
    id_sd.TimeCount = math.floor(elapsed * id_sd.TickBase)
end

---------------------------------------------------------------------------
-- Sound mode control
---------------------------------------------------------------------------

function id_sd.SD_SetSoundMode(mode)
    id_sd.SoundMode = mode
    return true
end

function id_sd.SD_SetMusicMode(mode)
    id_sd.MusicMode = mode
    return true
end

function id_sd.SD_SetDigiDevice(mode)
    id_sd.DigiMode = mode
end

function id_sd.SD_Default(gotit, sd, sm)
    if gotit then
        id_sd.SD_SetSoundMode(sd)
        id_sd.SD_SetMusicMode(sm)
    else
        id_sd.SD_SetSoundMode(id_sd.sdm_Off)
        id_sd.SD_SetMusicMode(id_sd.smm_Off)
    end
end

---------------------------------------------------------------------------
-- Sound playback (stub - no actual audio yet)
---------------------------------------------------------------------------

function id_sd.SD_PlaySound(sound)
    -- TODO: Implement actual sound playback
    SoundPlaying = sound
    return true
end

function id_sd.SD_StopSound()
    SoundPlaying = 0
    SoundPriority = 0
end

function id_sd.SD_WaitSoundDone()
    -- Sounds are instantaneous in stub mode
end

function id_sd.SD_SoundPlaying()
    return SoundPlaying
end

function id_sd.SD_SetPosition(leftvol, rightvol)
    id_sd.SoundPositioned = true
end

function id_sd.SD_PositionSound(leftvol, rightvol)
    id_sd.SoundPositioned = true
end

---------------------------------------------------------------------------
-- Music playback (stub)
---------------------------------------------------------------------------

function id_sd.SD_StartMusic(music)
    MusicPlaying = true
end

function id_sd.SD_MusicOn()
    MusicPlaying = true
end

function id_sd.SD_MusicOff()
    MusicPlaying = false
end

function id_sd.SD_FadeOutMusic()
    MusicPlaying = false
end

function id_sd.SD_MusicPlaying()
    return MusicPlaying
end

---------------------------------------------------------------------------
-- Digitized sound playback (stub)
---------------------------------------------------------------------------

function id_sd.SD_PlayDigitized(which, leftpos, rightpos)
    id_sd.DigiPlaying = true
end

function id_sd.SD_StopDigitized()
    id_sd.DigiPlaying = false
end

function id_sd.SD_Poll()
    -- No-op in stub mode
end

---------------------------------------------------------------------------
-- User hook
---------------------------------------------------------------------------

function id_sd.SD_SetUserHook(hook)
    UserHook = hook
end

---------------------------------------------------------------------------
-- OPL register write (stub)
---------------------------------------------------------------------------

function id_sd.alOut(reg, val)
    -- TODO: OPL2 emulation
end

return id_sd
