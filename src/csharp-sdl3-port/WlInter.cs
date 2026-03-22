// WL_INTER.C -> WlInter.cs
// Intermission screens - level complete, victory, intro, PG13

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
            // Cache needed graphics for current level
            IdCa.CA_CacheMarks();
        }

        public static void LevelCompleted()
        {
            // Show level complete tally screen
            IdVl.VL_Bar(0, 0, 320, 200, 0);
            IdVl.VL_UpdateScreen();

            // Would show kill/secret/treasure ratios here
            SDL.SDL_Delay(2000);
        }

        public static void Victory()
        {
            // Victory sequence
            IdVl.VL_Bar(0, 0, 320, 200, 0);
            IdVl.VL_UpdateScreen();
            SDL.SDL_Delay(3000);
        }

        public static void CheckHighScore(int score, ushort other)
        {
            IdUs.US_CheckHighScore(score, other);
        }

        public static void ClearSplitVWB()
        {
            // Clear VWB for split screen
        }

        public static void FreeMusic()
        {
            // Free cached music
        }

        public static void Write(int x, int y, string str)
        {
            WL_Globals.px = (ushort)x;
            WL_Globals.py = (ushort)y;
            IdVh.VW_DrawPropString(str);
        }

        public static int GetYorN(int x, int y, int pic)
        {
            return 1;
        }
    }
}
