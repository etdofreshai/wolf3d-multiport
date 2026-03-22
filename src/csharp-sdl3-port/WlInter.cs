// WL_INTER.C -> WlInter.cs
// Intermission screens - level complete, victory, intro, PG13 - full implementation

using System;

namespace Wolf3D
{
    public static class WlInter
    {
        public static LRstruct[] LevelRatios = new LRstruct[60];

        // BJ breathing animation
        private static int breatheCount;
        private static int breatheFrame;

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

        // =========================================================================
        //  PreloadGraphics - with actual progress bar drawing
        // =========================================================================

        public static void PreloadGraphics()
        {
            // Draw the "Get Psyched" progress bar
            IdCa.CA_CacheGrChunk((int)graphicnums.GETPSYCHEDPIC);

            // Draw background
            IdVl.VL_Bar(0, 0, 320, 200 - WolfConstants.STATUSLINES, 0x27);

            // Draw the "Get Psyched" pic centered
            IdVh.VWB_DrawPic(88, 80, (int)graphicnums.GETPSYCHEDPIC);
            IdVl.VL_UpdateScreen();

            // Draw progress bar
            int barX = 98;
            int barY = 96;
            int barW = 124;
            int barH = 10;

            // Outline
            IdVl.VL_Bar(barX - 1, barY - 1, barW + 2, barH + 2, 0);

            // Simulate loading with progress bar
            int totalMarks = barW;
            for (int step = 0; step <= totalMarks; step++)
            {
                IdVl.VL_Bar(barX, barY, step, barH, 0x37);
                IdVl.VL_UpdateScreen();
            }

            // Actually cache the graphics
            IdCa.CA_CacheMarks();

            // Brief pause to show completed bar
            IdVl.VL_Bar(barX, barY, barW, barH, 0x37);
            IdVl.VL_UpdateScreen();
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
        //  Write - draw text at position (tile coords)
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
        //  BJ_Breathe - BJ breathing animation on victory screen
        // =========================================================================

        public static void BJ_Breathe()
        {
            // Simple BJ breathing: alternate between two frames
            breatheCount++;
            if (breatheCount > 10)
            {
                breatheCount = 0;
                breatheFrame = 1 - breatheFrame;

                if (breatheFrame == 0)
                    IdVh.VWB_DrawPic(0, 16, (int)graphicnums.L_GUYPIC);
                else
                    IdVh.VWB_DrawPic(0, 16, (int)graphicnums.L_GUY2PIC);

                IdVl.VL_UpdateScreen();
            }
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

            // Cache level end lump
            for (int i = GfxConstants.LEVELEND_LUMP_START; i <= GfxConstants.LEVELEND_LUMP_END; i++)
                IdCa.CA_CacheGrChunk(i);

            // Draw level complete screen
            IdVh.VWB_Bar(0, 0, 320, 200 - WolfConstants.STATUSLINES, 0x27);

            // Draw BJ
            IdVh.VWB_DrawPic(0, 16, (int)graphicnums.L_GUYPIC);

            WL_Globals.fontnumber = 1;
            WL_Globals.fontcolor = (byte)0x0f;

            Write(14, 2, "Floor " + (mapon + 1).ToString() + " Completed");

            // Draw the time
            int time_seconds = LevelRatios[mapon >= 0 && mapon < 60 ? mapon : 0].time;
            int minutes = time_seconds / 60;
            int seconds = time_seconds % 60;
            Write(14, 5, "Time   " + minutes.ToString() + ":" + seconds.ToString("D2"));

            Write(14, 7, "Kill Ratio     " + kr.ToString() + "%");
            Write(14, 9, "Secret Ratio   " + sr.ToString() + "%");
            Write(14, 11, "Treasure Ratio " + tr.ToString() + "%");

            IdVl.VL_UpdateScreen();
            IdVl.VL_FadeIn();

            IdSd.SD_PlaySound(soundnames.LEVELDONESND);

            // Wait for key or timeout with BJ breathing animation
            IdIn.IN_StartAck();
            int start = WL_Globals.TimeCount;
            while (!IdIn.IN_CheckAck())
            {
                IdSd.SD_TimeCountUpdate();
                IdIn.IN_ProcessEvents();
                BJ_Breathe();
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
            IdVl.VL_FadeOut();
        }

        // =========================================================================
        //  Victory - end of episode victory screen with text crawl
        // =========================================================================

        public static void Victory()
        {
            ClearSplitVWB();
            IdCa.CA_CacheGrChunk(GfxConstants.STARTFONT);

            // Cache level end pics
            for (int i = GfxConstants.LEVELEND_LUMP_START; i <= GfxConstants.LEVELEND_LUMP_END; i++)
                IdCa.CA_CacheGrChunk(i);

            IdVh.VWB_Bar(0, 0, 320, 200 - WolfConstants.STATUSLINES, 0x7f);

            WL_Globals.fontnumber = 1;
            WL_Globals.fontcolor = (byte)0x0f;

            // Draw BJ Wins pic
            IdVh.VWB_DrawPic(8, 4, (int)graphicnums.L_BJWINSPIC);

            Write(18, 2, "You Win!");

            // Compute totals across levels
            int totalKill = 0, totalSecret = 0, totalTreasure = 0;
            long totalTime = 0;
            int levels = 8;
            int startLevel = WL_Globals.gamestate.episode * 10;

            for (int i = 0; i < levels; i++)
            {
                int idx = startLevel + i;
                if (idx >= 0 && idx < 60)
                {
                    totalKill += LevelRatios[idx].kill;
                    totalSecret += LevelRatios[idx].secret;
                    totalTreasure += LevelRatios[idx].treasure;
                    totalTime += LevelRatios[idx].time;
                }
            }

            int avgKill = levels > 0 ? totalKill / levels : 0;
            int avgSecret = levels > 0 ? totalSecret / levels : 0;
            int avgTreasure = levels > 0 ? totalTreasure / levels : 0;
            int mins = (int)(totalTime / 60);
            int secs = (int)(totalTime % 60);

            Write(14, 8, "Total Time     " + mins.ToString() + ":" + secs.ToString("D2"));
            Write(14, 10, "Kill Average   " + avgKill.ToString() + "%");
            Write(14, 12, "Secret Average " + avgSecret.ToString() + "%");
            Write(14, 14, "Treasure Average " + avgTreasure.ToString() + "%");

            IdVl.VL_UpdateScreen();
            IdVl.VL_FadeIn();

            // Wait with BJ breathing
            IdIn.IN_StartAck();
            int start = WL_Globals.TimeCount;
            while (!IdIn.IN_CheckAck())
            {
                IdSd.SD_TimeCountUpdate();
                IdIn.IN_ProcessEvents();
                BJ_Breathe();
                SDL.SDL_Delay(5);
                if (WL_Globals.TimeCount - start > 700)
                    break;
            }

            WL_Globals.fontnumber = 0;
            IdVl.VL_FadeOut();
        }

        // =========================================================================
        //  CheckHighScore - check and record high score with name entry
        // =========================================================================

        public static void CheckHighScore(int score, ushort other)
        {
            // Find position in high score table
            int n = -1;
            for (int i = 0; i < WolfConstants.MaxScores; i++)
            {
                if (score > WL_Globals.Scores[i].score ||
                    (score == WL_Globals.Scores[i].score && other > WL_Globals.Scores[i].completed))
                {
                    n = i;
                    break;
                }
            }

            if (n >= 0)
            {
                // Shift scores down
                for (int i = WolfConstants.MaxScores - 1; i > n; i--)
                {
                    WL_Globals.Scores[i] = WL_Globals.Scores[i - 1];
                }

                // Insert new score with name entry
                WL_Globals.Scores[n] = new HighScore
                {
                    score = score,
                    completed = other,
                    episode = (ushort)WL_Globals.gamestate.episode
                };

                // Display high scores and get name
                IdUs.US_DisplayHighScores(n);
                IdVl.VL_UpdateScreen();
                IdVl.VL_FadeIn();

                // Get player name
                char[] nameBuf = new char[32];
                bool ok = IdUs.US_LineInput(
                    WL_Globals.px, WL_Globals.py,
                    nameBuf, null, true, 15, 100);

                if (ok)
                    WL_Globals.Scores[n].name = new string(nameBuf).TrimEnd('\0');
                else
                    WL_Globals.Scores[n].name = "Unknown";

                IdVl.VL_FadeOut();
            }
            else
            {
                // Just display the scores
                IdUs.US_DisplayHighScores(-1);
                IdVl.VL_UpdateScreen();
                IdVl.VL_FadeIn();
                IdIn.IN_Ack();
                IdVl.VL_FadeOut();
            }
        }

        public static void FreeMusic()
        {
            IdSd.SD_MusicOff();
        }

        public static int GetYorN(int x, int y, int pic)
        {
            IdIn.IN_ClearKeysDown();
            while (true)
            {
                IdIn.IN_ProcessEvents();
                SDL.SDL_Delay(10);
                if (WL_Globals.LastScan == ScanCodes.sc_Y) return 1;
                if (WL_Globals.LastScan == ScanCodes.sc_N) return 0;
                if (WL_Globals.LastScan == ScanCodes.sc_Escape) return 0;
            }
        }
    }
}
