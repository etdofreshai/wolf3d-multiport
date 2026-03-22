// ID_SD.C -> IdSd.cs
// Sound Manager - OPL2 AdLib emulation and digitized sound via SDL3

using System;
using System.Runtime.InteropServices;

namespace Wolf3D
{
    public static class IdSd
    {
        // OPL2 emulator state (simplified)
        private static byte[] oplRegisters = new byte[256];
        private static bool SD_Started;

        // Audio device/stream
        private static uint sdl_audiodev;
        private static IntPtr sdl_audiostream = IntPtr.Zero;

        // Sound state
        private static int SoundNumber;
        private static int SoundPriority;
        private static byte[] SoundData;
        private static int SoundPos;
        private static int SoundLength;

        // Music state
        private static ushort[] sqHack;
        private static int sqHackPtr;
        private static int sqHackLen;
        private static int sqHackSeqLen;
        private static ulong sqHackTime;
        private static bool sqActive;

        // PC speaker sound state
        private static byte[] pcSoundData;
        private static int pcSoundPos;
        private static int pcSoundLength;

        // Timing
        private static ulong lastTimeUpdate;

        public static void SD_TimeCountUpdate()
        {
            ulong now = SDL.SDL_GetTicks();
            if (lastTimeUpdate == 0)
                lastTimeUpdate = now;

            // 70Hz tick rate
            while (now - lastTimeUpdate >= 14)
            {
                WL_Globals.TimeCount++;
                lastTimeUpdate += 14;
            }
        }

        public static void alOut(byte reg, byte val)
        {
            if (reg < 256)
                oplRegisters[reg] = val;
        }

        public static void SD_Startup()
        {
            if (SD_Started) return;
            SD_Started = true;

            WL_Globals.SoundMode = SDMode.sdm_Off;
            WL_Globals.MusicMode = SMMode.smm_Off;
            WL_Globals.DigiMode = SDSMode.sds_Off;

            WL_Globals.AdLibPresent = true;
            WL_Globals.SoundBlasterPresent = true;
            WL_Globals.SoundSourcePresent = false;

            lastTimeUpdate = SDL.SDL_GetTicks();

            // Initialize SDL audio
            var spec = new SDL.SDL_AudioSpec
            {
                format = SDL.SDL_AUDIO_S16,
                channels = 1,
                freq = 44100
            };

            sdl_audiodev = SDL.SDL_OpenAudioDevice(0, ref spec);
            if (sdl_audiodev != 0)
            {
                SDL.SDL_ResumeAudioDevice(sdl_audiodev);
            }

            // Initialize DigiMap to -1 (no mapping)
            for (int i = 0; i < WL_Globals.DigiMap.Length; i++)
                WL_Globals.DigiMap[i] = -1;

            // Set reasonable defaults
            SD_SetSoundMode(SDMode.sdm_AdLib);
            SD_SetMusicMode(SMMode.smm_AdLib);
        }

        public static void SD_Shutdown()
        {
            if (!SD_Started) return;
            SD_Started = false;

            SD_MusicOff();
            SD_StopSound();

            if (sdl_audiostream != IntPtr.Zero)
            {
                SDL.SDL_DestroyAudioStream(sdl_audiostream);
                sdl_audiostream = IntPtr.Zero;
            }
            if (sdl_audiodev != 0)
            {
                SDL.SDL_CloseAudioDevice(sdl_audiodev);
                sdl_audiodev = 0;
            }
        }

        public static void SD_Default(bool gotit, SDMode sd, SMMode sm)
        {
            if (gotit)
            {
                SD_SetSoundMode(sd);
                SD_SetMusicMode(sm);
            }
            else
            {
                SD_SetSoundMode(SDMode.sdm_AdLib);
                SD_SetMusicMode(SMMode.smm_AdLib);
            }
        }

        public static bool SD_PlaySound(soundnames sound)
        {
            int s = (int)sound;
            if (s < 0 || s >= AudioConstants.NUMSOUNDS)
                return false;

            // Get the sound data
            int chunk = -1;
            switch (WL_Globals.SoundMode)
            {
                case SDMode.sdm_PC:
                    chunk = AudioConstants.STARTPCSOUNDS + s;
                    break;
                case SDMode.sdm_AdLib:
                    chunk = AudioConstants.STARTADLIBSOUNDS + s;
                    break;
                default:
                    return false;
            }

            IdCa.CA_CacheAudioChunk(chunk);
            SoundNumber = s;
            return true;
        }

        public static void SD_PositionSound(int leftvol, int rightvol)
        {
            // Simplified - just track positioning
            WL_Globals.SoundPositioned = true;
        }

        public static void SD_SetPosition(int leftvol, int rightvol)
        {
            // Simplified positioning
        }

        public static void SD_StopSound()
        {
            SoundData = null;
            SoundPos = 0;
            SoundLength = 0;
            SoundNumber = 0;
            SoundPriority = 0;
        }

        public static void SD_WaitSoundDone()
        {
            while (SD_SoundPlaying() != 0)
            {
                SDL.SDL_Delay(5);
                SD_TimeCountUpdate();
            }
        }

        public static ushort SD_SoundPlaying()
        {
            return (ushort)SoundNumber;
        }

        public static bool SD_SetSoundMode(SDMode mode)
        {
            WL_Globals.SoundMode = mode;
            return true;
        }

        public static bool SD_SetMusicMode(SMMode mode)
        {
            WL_Globals.MusicMode = mode;
            return true;
        }

        public static void SD_StartMusic(byte[] music)
        {
            SD_MusicOff();
            if (music == null || music.Length < 4) return;

            sqActive = true;
        }

        public static void SD_MusicOn()
        {
            sqActive = true;
        }

        public static void SD_MusicOff()
        {
            sqActive = false;
        }

        public static void SD_FadeOutMusic()
        {
            sqActive = false;
        }

        public static bool SD_MusicPlaying()
        {
            return sqActive;
        }

        public static void SD_SetUserHook(Action hook)
        {
            // No-op for now
        }

        public static void SD_SetDigiDevice(SDSMode mode)
        {
            WL_Globals.DigiMode = mode;
        }

        public static void SD_PlayDigitized(int which, int leftpos, int rightpos)
        {
            // Digitized sound playback
            // Map the sound number through DigiMap to get the VSWAP page
            if (which < 0 || which >= WL_Globals.DigiMap.Length) return;

            int page = WL_Globals.DigiMap[which];
            if (page < 0) return;

            // Get the digitized sound data from PM
            byte[] sndData = null;
            try { sndData = IdPm.PM_GetSoundPage(page); }
            catch { return; }

            if (sndData == null || sndData.Length == 0) return;

            // In a full implementation, this would queue the PCM data
            // to the SDL audio stream for mixing
            WL_Globals.DigiPlaying = true;
            SoundNumber = which;
        }

        public static void SD_StopDigitized()
        {
            WL_Globals.DigiPlaying = false;
        }

        public static void SD_Poll()
        {
            SD_TimeCountUpdate();
        }
    }
}
