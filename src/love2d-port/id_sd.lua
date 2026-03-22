-- ID_SD.lua
-- Sound Manager - ported from ID_SD.C (SDL3 version)
-- Uses Love2D audio for sound output
-- PC speaker beeps via generated SoundData, digitized sounds via PCM

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

-- PC speaker beep cache (generated SoundData for basic tones)
local beep_sources = {}
local MAX_BEEP_SOURCES = 8
local current_beep_source = 1

-- Digitized sound cache
local digi_sources = {}
local MAX_DIGI_SOURCES = 4
local current_digi_source = 1

---------------------------------------------------------------------------
-- Startup / Shutdown
---------------------------------------------------------------------------

function id_sd.SD_Startup()
    -- Initialize time tracking
    timecount_start = love.timer.getTime()
    id_sd.TimeCount = 0

    -- Pre-generate a few beep tones for PC speaker sounds
    -- We create short square-wave SoundData objects
    local sample_rate = 22050
    local beep_duration = 0.1  -- 100ms beep

    for i = 1, MAX_BEEP_SOURCES do
        beep_sources[i] = nil  -- lazy-created
    end
    for i = 1, MAX_DIGI_SOURCES do
        digi_sources[i] = nil
    end
end

function id_sd.SD_Shutdown()
    id_sd.SD_MusicOff()
    id_sd.SD_StopSound()
    -- Stop all sources
    for i = 1, MAX_BEEP_SOURCES do
        if beep_sources[i] then
            beep_sources[i]:stop()
        end
    end
    for i = 1, MAX_DIGI_SOURCES do
        if digi_sources[i] then
            digi_sources[i]:stop()
        end
    end
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

function id_sd.SD_SetTimeCount(val)
    -- Reset so TimeCount starts from val
    timecount_start = love.timer.getTime() - val / id_sd.TickBase
    id_sd.TimeCount = val
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
-- Generate a PC speaker beep tone
---------------------------------------------------------------------------

local function GenerateBeep(frequency, duration)
    local sample_rate = 22050
    local samples = math.floor(sample_rate * duration)
    if samples < 1 then samples = 1 end

    local sd = love.sound.newSoundData(samples, sample_rate, 16, 1)
    if frequency > 0 then
        local period = sample_rate / frequency
        for i = 0, samples - 1 do
            -- Square wave at low volume
            local t = (i % math.floor(period + 0.5))
            local val = (t < period / 2) and 0.15 or -0.15
            -- Apply a quick fade-out envelope
            local env = 1.0 - (i / samples)
            sd:setSample(i, val * env)
        end
    else
        -- Silence
        for i = 0, samples - 1 do
            sd:setSample(i, 0)
        end
    end
    return sd
end

---------------------------------------------------------------------------
-- Sound playback
---------------------------------------------------------------------------

-- Simple mapping from sound index to approximate beep frequency
local sound_freqs = {
    [0]  = 200,   -- HITWALLSND
    [6]  = 100,   -- NOWAYSND
    [12] = 800,   -- GETKEYSND
    [18] = 300,   -- OPENDOORSND
    [19] = 250,   -- CLOSEDOORSND
    [23] = 600,   -- ATKKNIFESND
    [24] = 1200,  -- ATKPISTOLSND
    [26] = 1400,  -- ATKMACHINEGUNSND
    [27] = 500,   -- HITENEMYSND
    [29] = 150,   -- DEATHSCREAM1SND
    [31] = 900,   -- GETAMMOSND
    [32] = 1000,  -- SHOOTSND
    [33] = 700,   -- HEALTH1SND
    [34] = 700,   -- HEALTH2SND
    [35] = 1100,  -- BONUS1SND
    [36] = 1100,  -- BONUS2SND
    [37] = 1100,  -- BONUS3SND
    [38] = 1500,  -- GETGATLINGSND
    [39] = 400,   -- ESCPRESSEDSND
    [40] = 1600,  -- LEVELDONESND
    [44] = 1800,  -- BONUS1UPSND
    [46] = 200,   -- PUSHWALLSND
}

function id_sd.SD_PlaySound(sound)
    if id_sd.SoundMode == id_sd.sdm_Off then
        SoundPlaying = sound
        return true
    end

    SoundPlaying = sound

    -- Generate and play a beep for this sound
    local freq = sound_freqs[sound] or (200 + (sound * 37) % 1400)
    local duration = 0.08
    -- Some sounds are longer
    if sound == audiowl6.DEATHSCREAM1SND or sound == audiowl6.PLAYERDEATHSND then
        duration = 0.3
    elseif sound == audiowl6.LEVELDONESND then
        duration = 0.5
    end

    local sd = GenerateBeep(freq, duration)
    local source = love.audio.newSource(sd)
    source:setVolume(0.3)
    source:play()

    -- Store in rotating buffer so GC doesn't kill it
    beep_sources[current_beep_source] = source
    current_beep_source = (current_beep_source % MAX_BEEP_SOURCES) + 1

    return true
end

function id_sd.SD_StopSound()
    SoundPlaying = 0
    SoundPriority = 0
end

function id_sd.SD_WaitSoundDone()
    -- Brief pause for sound to finish
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
-- Music playback (stub - OPL emulation not implemented)
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
-- Digitized sound playback
---------------------------------------------------------------------------

function id_sd.SD_PlayDigitized(which, leftpos, rightpos)
    id_sd.DigiPlaying = true

    -- If we have page manager data, could play actual digitized sound
    -- For now, fall back to beep
    local freq = 300 + (which * 53) % 1200
    local sd = GenerateBeep(freq, 0.15)
    local source = love.audio.newSource(sd)
    source:setVolume(0.4)
    source:play()

    digi_sources[current_digi_source] = source
    current_digi_source = (current_digi_source % MAX_DIGI_SOURCES) + 1
end

function id_sd.SD_StopDigitized()
    id_sd.DigiPlaying = false
    for i = 1, MAX_DIGI_SOURCES do
        if digi_sources[i] then
            digi_sources[i]:stop()
        end
    end
end

function id_sd.SD_Poll()
    -- Update TimeCount
    id_sd.SD_TimeCountUpdate()

    -- Call user hook if set
    if UserHook then
        UserHook()
    end
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
    -- OPL2 emulation not implemented
end

return id_sd
