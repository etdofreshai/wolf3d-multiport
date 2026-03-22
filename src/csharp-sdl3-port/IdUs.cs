// ID_US_1.C -> IdUs.cs
// User Manager - printing, windows, scores, random numbers

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

        public static void US_Startup()
        {
            // Set up default print routines
            USL_MeasureString = (string s, out int w, out int h) =>
            {
                IdVh.VW_MeasurePropString(s, out w, out h);
            };
            USL_DrawString = (string s) =>
            {
                IdVh.VW_DrawPropString(s);
            };

            // Initialize scores
            for (int i = 0; i < WolfConstants.MaxScores; i++)
            {
                WL_Globals.Scores[i] = new HighScore
                {
                    name = "id software",
                    score = 10000 * (WolfConstants.MaxScores - i),
                    completed = 0,
                    episode = 0
                };
            }

            for (int i = 0; i < WolfConstants.MaxSaveGames; i++)
                WL_Globals.Games[i] = new SaveGame();
        }

        public static void US_Shutdown()
        {
        }

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

            foreach (char c in s)
            {
                if (c == '\n')
                {
                    WL_Globals.px = WL_Globals.WindowX;
                    WL_Globals.PrintX = (ushort)WL_Globals.px;
                    WL_Globals.py += 10;
                    WL_Globals.PrintY = (ushort)WL_Globals.py;
                    continue;
                }
            }

            // Draw the full string using current font
            string clean = s.Replace("\n", "");
            if (clean.Length > 0)
            {
                WL_Globals.px = WL_Globals.PrintX;
                WL_Globals.py = WL_Globals.PrintY;
                USL_DrawString?.Invoke(clean);
                WL_Globals.PrintX = (ushort)WL_Globals.px;
                WL_Globals.PrintY = (ushort)WL_Globals.py;
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

            int w = 0, h = 0;
            if (USL_MeasureString != null)
                USL_MeasureString(s, out w, out h);

            WL_Globals.px = (ushort)(WL_Globals.WindowX + (WL_Globals.WindowW - w) / 2);
            WL_Globals.PrintX = (ushort)WL_Globals.px;
            USL_DrawString?.Invoke(s);
        }

        public static void US_CPrintLine(string s)
        {
            US_CPrint(s);
            WL_Globals.PrintY += 10;
        }

        public static void US_PrintCentered(string s)
        {
            US_CPrint(s);
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
        //  Line input
        // =========================================================================

        public static bool US_LineInput(int x, int y, char[] buf, string def, bool escok, int maxchars, int maxwidth)
        {
            // Simplified line input
            if (def != null)
            {
                for (int i = 0; i < def.Length && i < buf.Length; i++)
                    buf[i] = def[i];
            }
            return true;
        }

        // =========================================================================
        //  Score display
        // =========================================================================

        public static void US_DisplayHighScores(int which)
        {
            // Draw high scores
        }

        public static void US_CheckHighScore(int score, ushort other)
        {
            // Check and record high score
        }

        public static string USL_GiveSaveName(int game)
        {
            return $"SAVEGAM{game}{WL_Globals.extension}";
        }
    }
}
