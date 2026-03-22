// ID_SD.C -> IdSd.cs
// Sound Manager - OPL2 AdLib emulation and digitized sound via SDL3

using System;
using System.Runtime.InteropServices;

namespace Wolf3D
{
    public static class IdSd
    {
        // =========================================================================
        //  OPL2 Emulator State
        // =========================================================================
        private const int OPL_NUM_CHANNELS = 9;
        private const int SD_AUDIO_RATE = 44100;

        private struct OPL2State
        {
            public byte[] regs;
            public double[] phase;
            public double[] env;
            public int[] noteOn;
            public double[] freq;
        }

        private static OPL2State opl2;

        // OPL2 register constants
        private const int alFreqL = 0xA0;
        private const int alFreqH = 0xB0;

        private static readonly byte[] carriers = { 3, 4, 5, 11, 12, 13, 19, 20, 21 };
        private static readonly byte[] modifiers = { 0, 1, 2, 8, 9, 10, 16, 17, 18 };

        // Audio device/stream
        private static bool SD_Started;
        private static uint sdl_audiodev;
        private static IntPtr sdl_audiostream = IntPtr.Zero;

        // Sound state
        private static int SoundNumber;
        private static int SoundPriority;

        // AdLib sound effect state
        private static byte[] alSound;
        private static int alSoundPos;
        private static int alLengthLeft;
        private static int alBlock;
        private static uint alTimeCount;

        // PC speaker sound state
        private static byte[] pcSound;
        private static int pcSoundPos;
        private static int pcLengthLeft;
        private static byte pcLastSample;
        private static double pcSpkPhase;
        private static double pcSpkFreq;
        private static ushort[] pcSoundLookup = new ushort[255];

        // Digitized sound playback state
        private static byte[] sd_digiData;
        private static int sd_digiLen;
        private static int sd_digiPos;
        private static int sd_digiLeftVol = 15;
        private static int sd_digiRightVol = 15;

        // Sequencer variables
        private static bool sqActive;
        private static ushort[] sqHack;
        private static int sqHackPtr;
        private static int sqHackLen;
        private static int sqHackSeqLen;
        private static long sqHackTime;

        // Timer tick accumulators for audio callback
        private static double sd_tickAccum;
        private static double sd_seqAccum;

        // Sound user hook
        private static Action SoundUserHook;

        // Timing
        private static ulong sd_audioLastTick;
        private static ulong sd_realTimeEpoch;
        private static int sd_realTimeBase;

        // Digi state
        private static int DigiNumber;
        private static int DigiPriority;
        private static int DigiLeft;
        private static int DigiPage;
        private static int DigiLastStart = 1;
        private static int DigiLastEnd = 0;
        private static bool DigiLastSegment;
        private static bool DigiMissed;
        private static byte[] DigiNextAddr;
        private static int DigiNextLen;

        // Position state
        private static int LeftPosition, RightPosition;

        // =========================================================================
        //  SD_TimeCountUpdate
        // =========================================================================

        public static void SD_TimeCountUpdate()
        {
            ulong now = SDL.SDL_GetTicks();

            // If the audio callback has been active within the last 50ms, let it drive TimeCount
            if (sd_audioLastTick != 0 && (now - sd_audioLastTick < 50))
            {
                sd_realTimeEpoch = now;
                sd_realTimeBase = WL_Globals.TimeCount;
                return;
            }

            // Audio callback is NOT driving TimeCount -- advance from real time
            int elapsed_ticks = (int)((now - sd_realTimeEpoch) * 70 / 1000);
            if (sd_realTimeBase + elapsed_ticks > WL_Globals.TimeCount)
            {
                WL_Globals.TimeCount = sd_realTimeBase + elapsed_ticks;
            }
        }

        // =========================================================================
        //  OPL2 Helper functions
        // =========================================================================

        private static double OPL2_GetFreq(int ch)
        {
            int fnum = opl2.regs[alFreqL + ch] | ((opl2.regs[alFreqH + ch] & 0x03) << 8);
            int block = (opl2.regs[alFreqH + ch] >> 2) & 0x07;
            return (double)fnum * 49716.0 / (double)(1 << (20 - block));
        }

        private static int OPL2_IsKeyOn(int ch)
        {
            return (opl2.regs[alFreqH + ch] >> 5) & 1;
        }

        public static void alOut(byte reg, byte val)
        {
            if (opl2.regs == null) return;

            opl2.regs[reg] = val;

            // Update derived state for channel registers
            if (reg >= alFreqL && reg < alFreqL + OPL_NUM_CHANNELS)
            {
                int ch = reg - alFreqL;
                opl2.freq[ch] = OPL2_GetFreq(ch);
            }
            else if (reg >= alFreqH && reg < alFreqH + OPL_NUM_CHANNELS)
            {
                int ch = reg - alFreqH;
                int keyOn = OPL2_IsKeyOn(ch);
                if (keyOn != 0 && opl2.noteOn[ch] == 0)
                {
                    opl2.env[ch] = 1.0;
                    opl2.phase[ch] = 0.0;
                }
                else if (keyOn == 0 && opl2.noteOn[ch] != 0)
                {
                    opl2.env[ch] = 0.0;
                }
                opl2.noteOn[ch] = keyOn;
                opl2.freq[ch] = OPL2_GetFreq(ch);
            }
        }

        // =========================================================================
        //  SD_AudioCallback - generates audio samples (called from main thread poll)
        // =========================================================================

        private static short[] audioBuffer = new short[2048];

        private static void GenerateAudioSamples(int samplesNeeded)
        {
            if (samplesNeeded <= 0) return;
            if (samplesNeeded * 2 > audioBuffer.Length)
                audioBuffer = new short[samplesNeeded * 2];

            for (int i = 0; i < samplesNeeded; i++)
            {
                double mixL = 0.0, mixR = 0.0;

                // --- OPL2 music/sound synthesis ---
                for (int ch = 0; ch < OPL_NUM_CHANNELS; ch++)
                {
                    if (opl2.noteOn[ch] != 0 && opl2.freq[ch] > 0.0 && opl2.env[ch] > 0.0)
                    {
                        double sample = Math.Sin(opl2.phase[ch] * 2.0 * Math.PI) * opl2.env[ch] * 0.15;
                        opl2.phase[ch] += opl2.freq[ch] / (double)SD_AUDIO_RATE;
                        if (opl2.phase[ch] >= 1.0)
                            opl2.phase[ch] -= 1.0;
                        opl2.env[ch] *= 0.99999;

                        mixL += sample;
                        mixR += sample;
                    }
                }

                // --- PC speaker square wave ---
                if (pcSpkFreq > 0.0)
                {
                    double sample = (pcSpkPhase < 0.5) ? 0.10 : -0.10;
                    pcSpkPhase += pcSpkFreq / (double)SD_AUDIO_RATE;
                    if (pcSpkPhase >= 1.0)
                        pcSpkPhase -= 1.0;
                    mixL += sample;
                    mixR += sample;
                }

                // --- Digitized sound playback ---
                if (sd_digiData != null && sd_digiPos < sd_digiLen)
                {
                    double ratio = 7000.0 / (double)SD_AUDIO_RATE;
                    int srcPos = (int)(sd_digiPos * ratio);
                    if (srcPos < sd_digiData.Length && srcPos >= 0)
                    {
                        double sample = ((double)sd_digiData[srcPos] - 128.0) / 128.0 * 0.5;
                        double lv = (double)sd_digiLeftVol / 15.0;
                        double rv = (double)sd_digiRightVol / 15.0;
                        mixL += sample * lv;
                        mixR += sample * rv;
                    }
                    sd_digiPos++;
                    if ((int)(sd_digiPos * ratio) >= sd_digiLen)
                    {
                        sd_digiData = null;
                        sd_digiLen = 0;
                        sd_digiPos = 0;
                        WL_Globals.DigiPlaying = false;
                    }
                }

                // Clamp
                if (mixL > 1.0) mixL = 1.0;
                if (mixL < -1.0) mixL = -1.0;
                if (mixR > 1.0) mixR = 1.0;
                if (mixR < -1.0) mixR = -1.0;

                audioBuffer[i * 2 + 0] = (short)(mixL * 32767.0);
                audioBuffer[i * 2 + 1] = (short)(mixR * 32767.0);

                // --- Advance game timer at TickBase (70) Hz ---
                sd_tickAccum += (double)WolfConstants.TickBase / (double)SD_AUDIO_RATE;
                while (sd_tickAccum >= 1.0)
                {
                    sd_tickAccum -= 1.0;
                    WL_Globals.TimeCount++;
                    sd_audioLastTick = SDL.SDL_GetTicks();
                    SoundUserHook?.Invoke();

                    // PC sound effect service
                    if (pcSound != null && pcSoundPos < pcSound.Length)
                    {
                        byte s = pcSound[pcSoundPos++];
                        if (s != pcLastSample)
                        {
                            pcLastSample = s;
                            if (s != 0 && s < pcSoundLookup.Length)
                            {
                                ushort t = pcSoundLookup[s];
                                pcSpkFreq = (t > 0) ? 1193180.0 / (double)t : 0.0;
                            }
                            else
                                pcSpkFreq = 0.0;
                        }
                        pcLengthLeft--;
                        if (pcLengthLeft <= 0)
                        {
                            pcSound = null;
                            pcSpkFreq = 0.0;
                            SoundNumber = 0;
                            SoundPriority = 0;
                        }
                    }

                    // AdLib sound effect service
                    if (alSound != null && alSoundPos < alSound.Length)
                    {
                        byte s = alSound[alSoundPos++];
                        if (s == 0)
                            alOut((byte)(alFreqH + 0), 0);
                        else
                        {
                            alOut((byte)(alFreqL + 0), s);
                            alOut((byte)(alFreqH + 0), (byte)alBlock);
                        }
                        alLengthLeft--;
                        if (alLengthLeft <= 0)
                        {
                            alSound = null;
                            alOut((byte)(alFreqH + 0), 0);
                            SoundNumber = 0;
                            SoundPriority = 0;
                        }
                    }
                }

                // --- Music sequencer runs at 700Hz (TickBase * 10) ---
                sd_seqAccum += (double)(WolfConstants.TickBase * 10) / (double)SD_AUDIO_RATE;
                while (sd_seqAccum >= 1.0)
                {
                    sd_seqAccum -= 1.0;
                    if (sqActive && sqHack != null && sqHackLen > 0)
                    {
                        while (sqHackLen > 0 && sqHackTime <= (long)alTimeCount)
                        {
                            if (sqHackPtr + 1 < sqHack.Length)
                            {
                                ushort w = sqHack[sqHackPtr++];
                                ushort delta = sqHack[sqHackPtr++];
                                byte a = (byte)(w & 0xff);
                                byte v = (byte)(w >> 8);
                                alOut(a, v);
                                sqHackTime = alTimeCount + delta;
                                sqHackLen -= 4;
                            }
                            else
                                break;
                        }
                        alTimeCount++;
                        if (sqHackLen <= 0)
                        {
                            sqHackPtr = 0;
                            sqHackLen = sqHackSeqLen;
                            alTimeCount = 0;
                            sqHackTime = 0;
                        }
                    }
                }
            }
        }

        // =========================================================================
        //  SD_Startup
        // =========================================================================

        public static void SD_Startup()
        {
            if (SD_Started) return;
            SD_Started = true;

            // Initialize OPL2 state
            opl2.regs = new byte[256];
            opl2.phase = new double[OPL_NUM_CHANNELS];
            opl2.env = new double[OPL_NUM_CHANNELS];
            opl2.noteOn = new int[OPL_NUM_CHANNELS];
            opl2.freq = new double[OPL_NUM_CHANNELS];

            WL_Globals.SoundMode = SDMode.sdm_Off;
            WL_Globals.MusicMode = SMMode.smm_Off;
            WL_Globals.DigiMode = SDSMode.sds_Off;

            WL_Globals.AdLibPresent = true;
            WL_Globals.SoundBlasterPresent = true;
            WL_Globals.SoundSourcePresent = false;

            sd_realTimeEpoch = SDL.SDL_GetTicks();
            sd_realTimeBase = WL_Globals.TimeCount;

            // Initialize PC speaker lookup table
            for (int i = 0; i < pcSoundLookup.Length; i++)
                pcSoundLookup[i] = (ushort)(i * 60);

            // Initialize SDL audio
            var spec = new SDL.SDL_AudioSpec
            {
                format = SDL.SDL_AUDIO_S16,
                channels = 2,
                freq = SD_AUDIO_RATE
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

        // =========================================================================
        //  SD_Shutdown
        // =========================================================================

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

        // =========================================================================
        //  SD_Default
        // =========================================================================

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

        // =========================================================================
        //  SD_PlaySound
        // =========================================================================

        public static bool SD_PlaySound(soundnames sound)
        {
            int s = (int)sound;
            if (s < 0 || s >= AudioConstants.NUMSOUNDS)
                return false;

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

        // =========================================================================
        //  SD_PositionSound / SD_SetPosition - stereo panning
        // =========================================================================

        public static void SD_PositionSound(int leftvol, int rightvol)
        {
            LeftPosition = leftvol;
            RightPosition = rightvol;
            WL_Globals.SoundPositioned = true;
        }

        public static void SD_SetPosition(int leftpos, int rightpos)
        {
            if (leftpos < 0 || leftpos > 15 || rightpos < 0 || rightpos > 15)
                return;
            if (leftpos == 15 && rightpos == 15)
                return;

            sd_digiLeftVol = leftpos;
            sd_digiRightVol = rightpos;
        }

        // =========================================================================
        //  SD_StopSound
        // =========================================================================

        public static void SD_StopSound()
        {
            alSound = null;
            pcSound = null;
            pcSpkFreq = 0.0;
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

        // =========================================================================
        //  SD_SetSoundMode / SD_SetMusicMode
        // =========================================================================

        public static bool SD_SetSoundMode(SDMode mode)
        {
            SD_StopSound();
            WL_Globals.SoundMode = mode;
            return true;
        }

        public static bool SD_SetMusicMode(SMMode mode)
        {
            SD_MusicOff();
            WL_Globals.MusicMode = mode;
            return true;
        }

        // =========================================================================
        //  Music control
        // =========================================================================

        public static void SD_StartMusic(byte[] music)
        {
            SD_MusicOff();
            if (music == null || music.Length < 4) return;

            // Parse music data: first word is length
            int len = music[0] | (music[1] << 8);
            sqHackSeqLen = len;
            sqHackLen = len;

            // Convert byte array to ushort array for sequencer
            int numWords = (music.Length - 2) / 2;
            sqHack = new ushort[numWords];
            for (int i = 0; i < numWords; i++)
            {
                int ofs = 2 + i * 2;
                if (ofs + 1 < music.Length)
                    sqHack[i] = (ushort)(music[ofs] | (music[ofs + 1] << 8));
            }
            sqHackPtr = 0;
            sqHackTime = 0;
            alTimeCount = 0;

            sqActive = true;
        }

        public static void SD_MusicOn()
        {
            sqActive = true;
        }

        public static void SD_MusicOff()
        {
            sqActive = false;
            // Silence all OPL2 channels
            if (opl2.regs != null)
            {
                for (int ch = 0; ch < OPL_NUM_CHANNELS; ch++)
                {
                    alOut((byte)(alFreqH + ch), 0);
                }
            }
        }

        public static void SD_FadeOutMusic()
        {
            // Simple immediate stop (a full fade would decrement volume over time)
            SD_MusicOff();
        }

        public static bool SD_MusicPlaying()
        {
            return sqActive;
        }

        public static void SD_SetUserHook(Action hook)
        {
            SoundUserHook = hook;
        }

        // =========================================================================
        //  Digitized sound support
        // =========================================================================

        public static void SD_SetDigiDevice(SDSMode mode)
        {
            WL_Globals.DigiMode = mode;
        }

        public static void SD_PlayDigitized(int which, int leftpos, int rightpos)
        {
            if (WL_Globals.DigiMode == SDSMode.sds_Off)
                return;

            SD_StopDigitized();

            if (which < 0 || which >= WL_Globals.DigiMap.Length) return;

            SD_SetPosition(leftpos, rightpos);

            int page = WL_Globals.DigiMap[which];
            if (page < 0) return;

            // Get the digitized sound data from PM
            byte[] sndData = null;
            try { sndData = IdPm.PM_GetSoundPage(page); }
            catch { return; }

            if (sndData == null || sndData.Length == 0) return;

            // Queue PCM data for playback
            sd_digiData = sndData;
            sd_digiLen = sndData.Length;
            sd_digiPos = 0;
            WL_Globals.DigiPlaying = true;
            DigiNumber = which;
        }

        public static void SD_StopDigitized()
        {
            sd_digiData = null;
            sd_digiLen = 0;
            sd_digiPos = 0;
            DigiLeft = 0;
            DigiNextAddr = null;
            DigiNextLen = 0;
            DigiMissed = false;
            WL_Globals.DigiPlaying = false;
            DigiNumber = 0;
            DigiPriority = 0;
            WL_Globals.SoundPositioned = false;
        }

        // =========================================================================
        //  SD_Poll - called every frame to drive audio
        // =========================================================================

        public static void SD_Poll()
        {
            SD_TimeCountUpdate();

            // Drive audio generation from main thread if no hardware callback
            GenerateAudioSamples(SD_AUDIO_RATE / 70);
        }
    }
}
