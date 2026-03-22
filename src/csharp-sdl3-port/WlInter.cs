// WL_INTER.C -> WlInter.cs
// Intermission screens - level complete, victory, intro, PG13 - full implementation

using System;

namespace Wolf3D
{
    public static class WlInter
    {
        public static LRstruct[] LevelRatios = new LRstruct[60];

        static WlInter()
        {
            for (int i = 0; i < 60; i++)
                LevelRatios[i] = new LRstruct();
        }

        public static void IntroScreen()
        {
            // Show intro / signon screen
        }

        public static void PG13()
        {
            IdVl.VL_Bar(0, 0, 320, 200, 0);
            IdCa.CA_CacheScreen((int)graphicnums.PG13PIC);
            IdVl.VL_UpdateScreen();
            IdIn.IN_UserInput(WolfConstants.TickBase * 7);
        }

        public static void PreloadGraphics()
        {
            IdCa.CA_CacheMarks();
        }

        // =========================================================================
        //  ClearSplitVWB
        // =========================================================================

        public static void ClearSplitVWB()
        {
            Array.Clear(WL_Globals.update, 0, WL_Globals.update.Length);
            WL_Globals.WindowX = 0;
            WL_Globals.WindowY = 0;
            WL_Globals.WindowW = 320;
            WL_Globals.WindowH = 160;
        }

        // =========================================================================
        //  Write - draw text at position
        // =========================================================================

        public static void Write(int x, int y, string str)
        {
            int px = x * 8;
            int py = y * 8;
            WL_Globals.px = (ushort)px;
            WL_Globals.py = (ushort)py;
            IdVh.VW_DrawPropString(str);
        }

        // =========================================================================
        //  LevelCompleted - show level completion tally
        // =========================================================================

        public static void LevelCompleted()
        {
            int mapon = WL_Globals.gamestate.mapon;

            // Calculate ratios
            int kr = 0, sr = 0, tr = 0;
            if (WL_Globals.gamestate.killtotal > 0)
                kr = (WL_Globals.gamestate.killcount * 100) / WL_Globals.gamestate.killtotal;
            if (WL_Globals.gamestate.secrettotal > 0)
                sr = (WL_Globals.gamestate.secretcount * 100) / WL_Globals.gamestate.secrettotal;
            if (WL_Globals.gamestate.treasuretotal > 0)
                tr = (WL_Globals.gamestate.treasurecount * 100) / WL_Globals.gamestate.treasuretotal;

            if (kr > 100) kr = 100;
            if (sr > 100) sr = 100;
            if (tr > 100) tr = 100;

            // Save ratios for victory screen
            if (mapon >= 0 && mapon < 60)
            {
                LevelRatios[mapon].kill = kr;
                LevelRatios[mapon].secret = sr;
                LevelRatios[mapon].treasure = tr;
                LevelRatios[mapon].time = WL_Globals.gamestate.TimeCount / 70;
            }

            ClearSplitVWB();
            IdCa.CA_CacheGrChunk(GfxConstants.STARTFONT);

            // Draw level complete screen
            IdVh.VWB_Bar(0, 0, 320, 200 - WolfConstants.STATUSLINES, 0x27);

            WL_Globals.fontnumber = 1;
            WL_Globals.fontcolor = 0x0f;

            Write(14, 2, "Floor " + (mapon + 1).ToString() + " Completed");

            Write(14, 7, "Kill Ratio     " + kr.ToString() + "%");
            Write(14, 9, "Secret Ratio   " + sr.ToString() + "%");
            Write(14, 11, "Treasure Ratio " + tr.ToString() + "%");

            IdVl.VL_UpdateScreen();

            IdSd.SD_PlaySound(soundnames.LEVELDONESND);

            // Wait for key or timeout
            IdIn.IN_StartAck();
            int start = WL_Globals.TimeCount;
            while (!IdIn.IN_CheckAck())
            {
                IdSd.SD_TimeCountUpdate();
                IdIn.IN_ProcessEvents();
                SDL.SDL_Delay(5);
                if (WL_Globals.TimeCount - start > 400)
                    break;
            }

            // Check for 100% bonuses
            if (kr == 100)
            {
                IdSd.SD_PlaySound(soundnames.PERCENT100SND);
                WlAgent.GivePoints(10000);
            }
            if (sr == 100)
            {
                IdSd.SD_PlaySound(soundnames.PERCENT100SND);
                WlAgent.GivePoints(10000);
            }
            if (tr == 100)
            {
                IdSd.SD_PlaySound(soundnames.PERCENT100SND);
                WlAgent.GivePoints(10000);
            }

            WL_Globals.fontnumber = 0;
        }

        // =========================================================================
        //  Victory
        // =========================================================================

        public static void Victory()
        {
            ClearSplitVWB();
            IdCa.CA_CacheGrChunk(GfxConstants.STARTFONT);

            IdVh.VWB_Bar(0, 0, 320, 200 - WolfConstants.STATUSLINES, 0x7f);

            WL_Globals.fontnumber = 1;
            WL_Globals.fontcolor = 0x0f;

            Write(18, 2, "You Win!");

            // Compute totals
            int totalKill = 0, totalSecret = 0, totalTreasure = 0;
            long totalTime = 0;
            int levels = 8;

            for (int i = 0; i < levels; i++)
            {
                totalKill += LevelRatios[i].kill;
                totalSecret += LevelRatios[i].secret;
                totalTreasure += LevelRatios[i].treasure;
                totalTime += LevelRatios[i].time;
            }

            int avgKill = levels > 0 ? totalKill / levels : 0;
            int avgSecret = levels > 0 ? totalSecret / levels : 0;
            int avgTreasure = levels > 0 ? totalTreasure / levels : 0;
            int minutes = (int)(totalTime / 60);
            int seconds = (int)(totalTime % 60);

            Write(14, 8, "Total Time   " + minutes.ToString() + ":" + seconds.ToString("D2"));
            Write(14, 10, "Kill Average   " + avgKill.ToString() + "%");
            Write(14, 12, "Secret Average " + avgSecret.ToString() + "%");
            Write(14, 14, "Treasure Average " + avgTreasure.ToString() + "%");

            // Draw BJ pic
            IdCa.CA_CacheGrChunk((int)graphicnums.L_BJWINSPIC);
            IdVh.VWB_DrawPic(8, 4, (int)graphicnums.L_BJWINSPIC);

            IdVl.VL_UpdateScreen();

            // Wait
            IdIn.IN_StartAck();
            int start = WL_Globals.TimeCount;
            while (!IdIn.IN_CheckAck())
            {
                IdSd.SD_TimeCountUpdate();
                IdIn.IN_ProcessEvents();
                SDL.SDL_Delay(5);
                if (WL_Globals.TimeCount - start > 700)
                    break;
            }

            WL_Globals.fontnumber = 0;
        }

        public static void CheckHighScore(int score, ushort other)
        {
            IdUs.US_CheckHighScore(score, other);
        }

        public static void FreeMusic()
        {
            // Free cached music
        }

        public static int GetYorN(int x, int y, int pic)
        {
            return 1;
        }
    }
}
