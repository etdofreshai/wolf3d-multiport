// ID_US_1.C -> IdUs.cs
// User Manager - printing, windows, scores, random numbers, line input

using System;

namespace Wolf3D
{
    public static class IdUs
    {
        // Random table for US_RndT
        private static readonly byte[] rndtable = {
            0,   8, 109, 220, 222, 241, 149, 107,  75, 248, 254, 140,  16,  66,
            74,  21, 211,  47,  80, 242, 154,  27, 205, 128, 161,  89,  77,  36,
            95, 110,  85,  48, 212, 140, 211, 249,  22,  79, 200,  50,  28, 188,
            52, 140, 202, 120,  68, 145,  62,  70, 184, 190,  91, 197, 152, 224,
            149, 104,  25, 178, 252, 182, 202, 182, 141, 197,   4,  81, 181, 242,
            145,  42,  39, 227, 156, 198, 225, 193, 219,  93, 122,  68,  249, 208,
            116, 156, 234, 151,  17, 218, 204, 133,  13, 166,  57,  32, 164, 118,
            30,  94, 156, 196,  85,  16, 240, 152,  18, 174, 202, 105, 229,  36,
            247, 196,  74, 222,  50, 218,  14, 242, 218, 152, 225, 120, 142, 195,
            65,   8, 217, 171, 117, 228, 227, 134, 103, 215, 178, 133, 185,  23,
            109,  11, 216, 110, 118, 110, 225, 130, 206, 213, 187, 166, 189, 102,
            116,  27,  91, 208, 107, 145,  38, 153, 222, 197, 157, 175, 219, 159,
            174, 199, 202,  63, 182, 190, 222, 160, 106, 219, 140,  35,  69, 254,
            204,  43, 235, 140, 198, 191, 129, 152,  85,  42,  53, 181, 115, 183,
            219,  75, 186,  83, 196, 165,  91, 191, 120, 102, 246, 156, 213, 133,
            131, 113,  71, 228, 246, 142, 148,  44, 155,  63,  84, 128,  21,  67,
            121, 155, 241, 173,  31, 178, 190,  91, 117, 211, 104, 236, 132, 153,
            252, 228,  54, 248, 116,  41,  25,  52, 217,  54, 250,  33, 193, 110,
            176, 187,  43, 122
        };

        private static int rndindex;

        // Print routine function pointers
        public delegate void MeasureStringFunc(string s, out int width, out int height);
        public delegate void DrawStringFunc(string s);

        public static MeasureStringFunc USL_MeasureString;
        public static DrawStringFunc USL_DrawString;

        private static bool US_Started;

        public static void US_Startup()
        {
            if (US_Started) return;

            // Set up default print routines
            USL_MeasureString = (string s, out int w, out int h) =>
            {
                IdVh.VW_MeasurePropString(s, out w, out h);
            };
            USL_DrawString = (string s) =>
            {
                IdVh.VW_DrawPropString(s);
            };

            US_InitRndT(true);

            // Initialize scores
            string[] defaultNames = {
                "id software-'92", "Adrian Carmack", "John Carmack",
                "Kevin Cloud", "Tom Hall", "John Romero", "Jay Wilbur"
            };
            for (int i = 0; i < WolfConstants.MaxScores; i++)
            {
                WL_Globals.Scores[i] = new HighScore
                {
                    name = (i < defaultNames.Length) ? defaultNames[i] : "id software",
                    score = 10000 * (WolfConstants.MaxScores - i),
                    completed = 1,
                    episode = 0
                };
            }

            for (int i = 0; i < WolfConstants.MaxSaveGames; i++)
                WL_Globals.Games[i] = new SaveGame();

            US_Started = true;
        }

        public static void US_Shutdown()
        {
            if (!US_Started) return;
            US_Started = false;
        }

        // =========================================================================
        //  USL_HardError - fatal error handler
        // =========================================================================

        public static void USL_HardError(string errstr)
        {
            WlMain.ShutdownId();
            Console.Error.WriteLine("Terminal Error: " + errstr);
            Environment.Exit(1);
        }

        // =========================================================================
        //  Random number generator
        // =========================================================================

        public static void US_InitRndT(bool randomize)
        {
            if (randomize)
                rndindex = (int)(SDL.SDL_GetTicks() & 0xFF);
            else
                rndindex = 0;
        }

        public static int US_RndT()
        {
            rndindex = (rndindex + 1) & 0xFF;
            return rndtable[rndindex];
        }

        public static void US_SetLoadSaveHooks(Func<int, bool> load, Func<int, bool> save, Action reset)
        {
            // Store hooks for save/load game
        }

        public static void US_SetPrintRoutines(MeasureStringFunc measure, DrawStringFunc print)
        {
            USL_MeasureString = measure;
            USL_DrawString = print;
        }

        // =========================================================================
        //  Printing
        // =========================================================================

        public static void US_Print(string s)
        {
            if (s == null) return;

            // Split on newlines and print each segment
            int start = 0;
            for (int i = 0; i <= s.Length; i++)
            {
                if (i == s.Length || s[i] == '\n')
                {
                    string segment = s.Substring(start, i - start);
                    if (segment.Length > 0)
                    {
                        int w = 0, h = 0;
                        USL_MeasureString?.Invoke(segment, out w, out h);
                        WL_Globals.px = WL_Globals.PrintX;
                        WL_Globals.py = WL_Globals.PrintY;
                        USL_DrawString?.Invoke(segment);
                        WL_Globals.PrintX += (ushort)w;
                    }

                    if (i < s.Length && s[i] == '\n')
                    {
                        WL_Globals.PrintX = WL_Globals.WindowX;
                        int h2 = 0, w2 = 0;
                        USL_MeasureString?.Invoke("X", out w2, out h2);
                        WL_Globals.PrintY += (ushort)h2;
                    }
                    start = i + 1;
                }
            }
        }

        public static void US_PrintUnsigned(uint n)
        {
            US_Print(n.ToString());
        }

        public static void US_PrintSigned(int n)
        {
            US_Print(n.ToString());
        }

        public static void US_CPrint(string s)
        {
            if (s == null) return;

            // Split on newlines and center each line
            string[] lines = s.Split('\n');
            foreach (string line in lines)
            {
                if (line.Length == 0)
                {
                    int h2 = 0, w2 = 0;
                    USL_MeasureString?.Invoke("X", out w2, out h2);
                    WL_Globals.PrintY += (ushort)h2;
                    continue;
                }

                int w = 0, h = 0;
                USL_MeasureString?.Invoke(line, out w, out h);
                WL_Globals.px = (ushort)(WL_Globals.WindowX + (WL_Globals.WindowW - w) / 2);
                WL_Globals.py = WL_Globals.PrintY;
                WL_Globals.PrintX = (ushort)WL_Globals.px;
                USL_DrawString?.Invoke(line);
                WL_Globals.PrintY += (ushort)h;
            }
        }

        public static void US_CPrintLine(string s)
        {
            if (s == null) return;
            int w = 0, h = 0;
            USL_MeasureString?.Invoke(s, out w, out h);
            WL_Globals.px = (ushort)(WL_Globals.WindowX + (WL_Globals.WindowW - w) / 2);
            WL_Globals.py = WL_Globals.PrintY;
            USL_DrawString?.Invoke(s);
            WL_Globals.PrintY += (ushort)h;
        }

        public static void US_PrintCentered(string s)
        {
            if (s == null) return;
            int w = 0, h = 0;
            USL_MeasureString?.Invoke(s, out w, out h);
            WL_Globals.px = (ushort)(WL_Globals.WindowX + (WL_Globals.WindowW - w) / 2);
            WL_Globals.py = (ushort)(WL_Globals.WindowY + (WL_Globals.WindowH - h) / 2);
            USL_DrawString?.Invoke(s);
        }

        // =========================================================================
        //  Windows
        // =========================================================================

        public static void US_DrawWindow(int x, int y, int w, int h)
        {
            WL_Globals.WindowX = (ushort)(x * 8);
            WL_Globals.WindowY = (ushort)(y * 8);
            WL_Globals.WindowW = (ushort)(w * 8);
            WL_Globals.WindowH = (ushort)(h * 8);

            WL_Globals.PrintX = WL_Globals.WindowX;
            WL_Globals.PrintY = WL_Globals.WindowY;

            // Draw window background
            IdVl.VL_Bar(WL_Globals.WindowX, WL_Globals.WindowY,
                       WL_Globals.WindowW, WL_Globals.WindowH, WolfConstants.WHITE);
        }

        public static void US_CenterWindow(int w, int h)
        {
            int x = (WolfConstants.MaxX / 8 - w) / 2;
            int y = (WolfConstants.MaxY / 8 - h) / 2;
            US_DrawWindow(x, y, w, h);
        }

        public static void US_ClearWindow()
        {
            IdVl.VL_Bar(WL_Globals.WindowX, WL_Globals.WindowY,
                       WL_Globals.WindowW, WL_Globals.WindowH, WolfConstants.WHITE);
            WL_Globals.PrintX = WL_Globals.WindowX;
            WL_Globals.PrintY = WL_Globals.WindowY;
        }

        public static void US_SaveWindow(ref WindowRec win)
        {
            win.x = WL_Globals.WindowX;
            win.y = WL_Globals.WindowY;
            win.w = WL_Globals.WindowW;
            win.h = WL_Globals.WindowH;
            win.px = WL_Globals.PrintX;
            win.py = WL_Globals.PrintY;
        }

        public static void US_RestoreWindow(ref WindowRec win)
        {
            WL_Globals.WindowX = (ushort)win.x;
            WL_Globals.WindowY = (ushort)win.y;
            WL_Globals.WindowW = (ushort)win.w;
            WL_Globals.WindowH = (ushort)win.h;
            WL_Globals.PrintX = (ushort)win.px;
            WL_Globals.PrintY = (ushort)win.py;
        }

        // =========================================================================
        //  Parameter checking
        // =========================================================================

        public static int US_CheckParm(string parm, string[] strings)
        {
            if (parm == null || strings == null) return -1;

            string p = parm.TrimStart('-', '/').ToLowerInvariant();
            for (int i = 0; i < strings.Length; i++)
            {
                if (strings[i] != null && p == strings[i].ToLowerInvariant())
                    return i;
            }
            return -1;
        }

        // =========================================================================
        //  US_LineInput - full line input with cursor, editing, esc/return
        // =========================================================================

        public static bool US_LineInput(int x, int y, char[] buf, string def, bool escok, int maxchars, int maxwidth)
        {
            string s = def ?? "";
            int cursor = s.Length;
            bool done = false;
            bool result = false;
            bool cursorvis = false;
            int lasttime = WL_Globals.TimeCount;

            WL_Globals.LastASCII = '\0';
            WL_Globals.LastScan = ScanCodes.sc_None;

            while (!done)
            {
                IdIn.IN_ProcessEvents();
                IdSd.SD_TimeCountUpdate();

                byte sc = WL_Globals.LastScan;
                char c = WL_Globals.LastASCII;
                WL_Globals.LastScan = ScanCodes.sc_None;
                WL_Globals.LastASCII = '\0';

                switch (sc)
                {
                    case ScanCodes.sc_LeftArrow:
                        if (cursor > 0) cursor--;
                        c = '\0';
                        break;
                    case ScanCodes.sc_RightArrow:
                        if (cursor < s.Length) cursor++;
                        c = '\0';
                        break;
                    case ScanCodes.sc_Home:
                        cursor = 0;
                        c = '\0';
                        break;
                    case ScanCodes.sc_End:
                        cursor = s.Length;
                        c = '\0';
                        break;
                    case ScanCodes.sc_Return:
                        done = true;
                        result = true;
                        c = '\0';
                        break;
                    case ScanCodes.sc_Escape:
                        if (escok)
                        {
                            done = true;
                            result = false;
                        }
                        c = '\0';
                        break;
                    case ScanCodes.sc_BackSpace:
                        if (cursor > 0 && s.Length > 0)
                        {
                            s = s.Remove(cursor - 1, 1);
                            cursor--;
                        }
                        c = '\0';
                        break;
                }

                // Printable character input
                if (c >= 32 && c < 127 && s.Length < maxchars)
                {
                    // Check width if maxwidth > 0
                    string test = s.Insert(cursor, c.ToString());
                    if (maxwidth > 0)
                    {
                        int tw = 0, th = 0;
                        USL_MeasureString?.Invoke(test, out tw, out th);
                        if (tw <= maxwidth)
                        {
                            s = test;
                            cursor++;
                        }
                    }
                    else
                    {
                        s = test;
                        cursor++;
                    }
                }

                // Draw the input field
                // Clear area
                IdVl.VL_Bar(x, y, maxwidth > 0 ? maxwidth + 10 : 200, 12, WolfConstants.WHITE);

                // Draw text
                WL_Globals.px = (ushort)x;
                WL_Globals.py = (ushort)y;
                USL_DrawString?.Invoke(s);

                // Blink cursor
                if (WL_Globals.TimeCount - lasttime > 35)
                {
                    cursorvis = !cursorvis;
                    lasttime = WL_Globals.TimeCount;
                }
                if (cursorvis)
                {
                    int cw = 0, ch = 0;
                    string pre = s.Substring(0, cursor);
                    USL_MeasureString?.Invoke(pre, out cw, out ch);
                    IdVl.VL_Bar(x + cw, y, 2, 10, 0);
                }

                IdVl.VL_UpdateScreen();
                SDL.SDL_Delay(10);
            }

            if (result)
            {
                for (int i = 0; i < buf.Length; i++)
                    buf[i] = (i < s.Length) ? s[i] : '\0';
            }

            return result;
        }

        // =========================================================================
        //  High score display and entry
        // =========================================================================

        public static void US_DisplayHighScores(int which)
        {
            // Draw high scores background
            IdCa.CA_CacheGrChunk((int)graphicnums.HIGHSCORESPIC);
            IdVh.VWB_DrawPic(0, 0, (int)graphicnums.HIGHSCORESPIC);

            WL_Globals.fontnumber = 0;
            WL_Globals.fontcolor = (byte)15;

            int y = 68;
            for (int i = 0; i < WolfConstants.MaxScores; i++)
            {
                // Highlight the player's entry
                if (i == which)
                    WL_Globals.fontcolor = (byte)0x0f;
                else
                    WL_Globals.fontcolor = (byte)15;

                // Name
                WL_Globals.px = 32;
                WL_Globals.py = (ushort)y;
                USL_DrawString?.Invoke(WL_Globals.Scores[i].name);

                // Score
                string scoreStr = WL_Globals.Scores[i].score.ToString();
                int sw = 0, sh = 0;
                USL_MeasureString?.Invoke(scoreStr, out sw, out sh);
                WL_Globals.px = (ushort)(224 - sw);
                WL_Globals.py = (ushort)y;
                USL_DrawString?.Invoke(scoreStr);

                // Level completed
                WL_Globals.px = 240;
                WL_Globals.py = (ushort)y;
                if (WL_Globals.Scores[i].completed > 0)
                    USL_DrawString?.Invoke("E" + (WL_Globals.Scores[i].episode + 1).ToString() +
                        "/L" + WL_Globals.Scores[i].completed.ToString());

                y += 16;
            }

            // Set PrintX/PrintY for potential name entry
            if (which >= 0 && which < WolfConstants.MaxScores)
            {
                WL_Globals.PrintX = 32;
                WL_Globals.PrintY = (ushort)(68 + which * 16);
                WL_Globals.px = WL_Globals.PrintX;
                WL_Globals.py = WL_Globals.PrintY;
            }
        }

        public static void US_CheckHighScore(int score, ushort other)
        {
            WlInter.CheckHighScore(score, other);
        }

        public static string USL_GiveSaveName(int game)
        {
            return $"SAVEGAM{game}{WL_Globals.extension}";
        }
    }
}
