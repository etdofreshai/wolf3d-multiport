// WL_MENU.C -> WlMenu.cs
// Menu system - main menu, options, save/load, etc.

using System;

namespace Wolf3D
{
    public static class WlMenu
    {
        private static int[] SaveGamesAvail = new int[10];
        private static string[,] SaveGameNames = new string[10, 1];
        public static int StartGame;
        public static int SoundStatus = 1;

        // Menu items
        public static CP_iteminfo MainItems = new CP_iteminfo
        {
            x = MenuConstants.MENU_X, y = MenuConstants.MENU_Y,
            amount = 10, curpos = 0, indent = 24
        };

        public static CP_itemtype[] MainMenu;
        public static CP_itemtype[] NewEMenu;

        static WlMenu()
        {
            MainMenu = new CP_itemtype[]
            {
                new CP_itemtype { active = 1, str = ForeignStrings.STR_NG, routine = CP_NewGame },
                new CP_itemtype { active = 1, str = ForeignStrings.STR_SD, routine = CP_Sound },
                new CP_itemtype { active = 1, str = ForeignStrings.STR_CL, routine = CP_Control },
                new CP_itemtype { active = 1, str = ForeignStrings.STR_LG, routine = (x) => CP_LoadGame(0) },
                new CP_itemtype { active = 0, str = ForeignStrings.STR_SG, routine = (x) => CP_SaveGame(0) },
                new CP_itemtype { active = 1, str = ForeignStrings.STR_CV, routine = CP_ChangeView },
                new CP_itemtype { active = 1, str = ForeignStrings.STR_VS, routine = CP_ViewScores },
                new CP_itemtype { active = 1, str = ForeignStrings.STR_BD, routine = null },
                new CP_itemtype { active = 1, str = ForeignStrings.STR_QT, routine = CP_Quit },
            };

            NewEMenu = new CP_itemtype[]
            {
                new CP_itemtype { active = 1, str = "Episode 1\nEscape from Wolfenstein" },
                new CP_itemtype { active = 1, str = "Episode 2\nOperation: Eisenfaust" },
                new CP_itemtype { active = 1, str = "Episode 3\nDie, Fuhrer, Die!" },
                new CP_itemtype { active = 1, str = "Episode 4\nA Dark Secret" },
                new CP_itemtype { active = 1, str = "Episode 5\nTrail of the Madman" },
                new CP_itemtype { active = 1, str = "Episode 6\nConfrontation" },
            };
        }

        // =========================================================================
        //  US_ControlPanel - Main menu entry point
        // =========================================================================

        public static void US_ControlPanel(byte scancode)
        {
            SetupControlPanel();

            if (scancode == ScanCodes.sc_Escape || scancode == 0)
            {
                // Show main menu
                DrawMainMenu();
                IdVl.VL_UpdateScreen();

                int result = HandleMenu(MainItems, MainMenu, null);
            }

            CleanupControlPanel();
        }

        // =========================================================================
        //  Setup / Cleanup
        // =========================================================================

        public static void SetupControlPanel()
        {
            // Cache menu graphics
            for (int i = GfxConstants.CONTROLS_LUMP_START; i <= GfxConstants.CONTROLS_LUMP_END; i++)
                IdCa.CA_CacheGrChunk(i);

            WL_Globals.fontnumber = 1;
        }

        public static void CleanupControlPanel()
        {
            WL_Globals.fontnumber = 0;
        }

        // =========================================================================
        //  Drawing
        // =========================================================================

        public static void ClearMScreen()
        {
            IdVl.VL_Bar(0, 0, 320, 200, MenuConstants.BKGDCOLOR);
        }

        public static void DrawWindow(int x, int y, int w, int h, int wcolor)
        {
            IdVl.VL_Bar(x, y, w, h, wcolor);
        }

        public static void DrawOutline(int x, int y, int w, int h, int color1, int color2)
        {
            IdVl.VL_Hlin(x, y, w, color1);
            IdVl.VL_Hlin(x, y + h, w, color2);
            IdVl.VL_Vlin(x, y, h, color1);
            IdVl.VL_Vlin(x + w, y, h, color2);
        }

        public static void DrawMainMenu()
        {
            ClearMScreen();
            IdVh.VWB_DrawPic(112, 184, (int)graphicnums.C_MOUSELBACKPIC);
            DrawStripes(10);
            IdVh.VWB_DrawPic(84, 0, (int)graphicnums.C_OPTIONSPIC);

            DrawMenu(MainItems, MainMenu);
        }

        public static void DrawStripes(int y)
        {
            IdVl.VL_Bar(0, y, 320, 24, 0);
            IdVl.VL_Hlin(0, y + 22, 320, MenuConstants.STRIPE);
        }

        public static void DrawMenu(CP_iteminfo item_i, CP_itemtype[] items)
        {
            int x = item_i.x + item_i.indent;
            int y = item_i.y;

            for (int i = 0; i < item_i.amount && i < items.Length; i++)
            {
                WL_Globals.px = (ushort)x;
                WL_Globals.py = (ushort)y;

                if (items[i].active != 0)
                    WL_Globals.fontcolor = MenuConstants.TEXTCOLOR;
                else
                    WL_Globals.fontcolor = MenuConstants.DEACTIVE;

                IdVh.VW_DrawPropString(items[i].str);
                y += 13;
            }
        }

        // =========================================================================
        //  HandleMenu
        // =========================================================================

        public static int HandleMenu(CP_iteminfo item_i, CP_itemtype[] items, MenuRoutine routine)
        {
            int which = item_i.curpos;
            bool exit = false;

            DrawMenuGun(item_i, which);
            IdVl.VL_UpdateScreen();

            while (!exit)
            {
                IdIn.IN_ProcessEvents();
                SDL.SDL_Delay(10);

                byte scan = WL_Globals.LastScan;
                if (scan == ScanCodes.sc_None) continue;

                WL_Globals.LastScan = ScanCodes.sc_None;

                switch (scan)
                {
                    case ScanCodes.sc_Escape:
                        exit = true;
                        break;

                    case ScanCodes.sc_UpArrow:
                        which--;
                        if (which < 0) which = item_i.amount - 1;
                        while (which >= 0 && which < items.Length && items[which].active == 0)
                        {
                            which--;
                            if (which < 0) which = item_i.amount - 1;
                        }
                        DrawMenuGun(item_i, which);
                        IdVl.VL_UpdateScreen();
                        break;

                    case ScanCodes.sc_DownArrow:
                        which++;
                        if (which >= item_i.amount) which = 0;
                        while (which >= 0 && which < items.Length && items[which].active == 0)
                        {
                            which++;
                            if (which >= item_i.amount) which = 0;
                        }
                        DrawMenuGun(item_i, which);
                        IdVl.VL_UpdateScreen();
                        break;

                    case ScanCodes.sc_Return:
                    case ScanCodes.sc_Space:
                        item_i.curpos = which;
                        if (which >= 0 && which < items.Length && items[which].routine != null)
                        {
                            items[which].routine(0);
                        }
                        exit = true;
                        break;
                }
            }

            return which;
        }

        private static void DrawMenuGun(CP_iteminfo item_i, int which)
        {
            int x = item_i.x;
            int y = item_i.y + which * 13;

            // Draw cursor
            IdVh.VWB_DrawPic(x, y, (int)graphicnums.C_CURSOR1PIC);
        }

        public static void DrawMenuGun(CP_iteminfo item_i)
        {
            DrawMenuGun(item_i, item_i.curpos);
        }

        // =========================================================================
        //  Menu action functions
        // =========================================================================

        public static void CP_NewGame(int _)
        {
            WlMain.NewGame(1, 0);  // Default: easy, episode 1
        }

        public static void CP_Sound(int _)
        {
            // Sound menu - toggle PC/AdLib/SoundBlaster
            ClearMScreen();
            DrawWindow(MenuConstants.SM_X, MenuConstants.SM_Y1, MenuConstants.SM_W, MenuConstants.SM_H1, MenuConstants.BKGDCOLOR);

            WL_Globals.px = (ushort)(MenuConstants.SM_X + 10);
            WL_Globals.py = (ushort)(MenuConstants.SM_Y1 + 5);
            WL_Globals.fontcolor = MenuConstants.TEXTCOLOR;
            IdVh.VW_DrawPropString("Sound Effects");

            IdVl.VL_UpdateScreen();

            // Wait for key
            while (true)
            {
                IdIn.IN_ProcessEvents();
                SDL.SDL_Delay(10);
                if (WL_Globals.LastScan != ScanCodes.sc_None)
                {
                    WL_Globals.LastScan = ScanCodes.sc_None;
                    return;
                }
            }
        }

        public static int CP_LoadGame(int quick)
        {
            // Load game menu - stub
            Message("Load Game\nnot implemented");
            IdVl.VL_UpdateScreen();
            SDL.SDL_Delay(1000);
            return 0;
        }

        public static int CP_SaveGame(int quick)
        {
            // Save game menu - stub
            Message("Save Game\nnot implemented");
            IdVl.VL_UpdateScreen();
            SDL.SDL_Delay(1000);
            return 0;
        }

        public static void CP_Control(int _)
        {
            // Control menu
            ClearMScreen();
            DrawWindow(MenuConstants.CTL_X, MenuConstants.CTL_Y, MenuConstants.CTL_W, MenuConstants.CTL_H, MenuConstants.BKGDCOLOR);

            WL_Globals.px = (ushort)(MenuConstants.CTL_X + 10);
            WL_Globals.py = (ushort)(MenuConstants.CTL_Y + 5);
            WL_Globals.fontcolor = MenuConstants.TEXTCOLOR;
            IdVh.VW_DrawPropString("Controls");

            WL_Globals.px = (ushort)(MenuConstants.CTL_X + 10);
            WL_Globals.py = (ushort)(MenuConstants.CTL_Y + 25);
            IdVh.VW_DrawPropString("Mouse: " + (WL_Globals.mouseenabled ? "Enabled" : "Disabled"));

            IdVl.VL_UpdateScreen();

            while (true)
            {
                IdIn.IN_ProcessEvents();
                SDL.SDL_Delay(10);
                if (WL_Globals.LastScan != ScanCodes.sc_None)
                {
                    WL_Globals.LastScan = ScanCodes.sc_None;
                    return;
                }
            }
        }

        public static void CP_ChangeView(int _)
        {
            // Change view size
            ClearMScreen();
            DrawWindow(MenuConstants.NM_X, MenuConstants.NM_Y, MenuConstants.NM_W, 60, MenuConstants.BKGDCOLOR);

            WL_Globals.px = (ushort)(MenuConstants.NM_X + 10);
            WL_Globals.py = (ushort)(MenuConstants.NM_Y + 10);
            WL_Globals.fontcolor = MenuConstants.TEXTCOLOR;
            IdVh.VW_DrawPropString("View Size: " + WL_Globals.viewsize.ToString());

            IdVl.VL_UpdateScreen();

            while (true)
            {
                IdIn.IN_ProcessEvents();
                SDL.SDL_Delay(10);
                byte scan = WL_Globals.LastScan;
                if (scan == ScanCodes.sc_None) continue;
                WL_Globals.LastScan = ScanCodes.sc_None;

                if (scan == ScanCodes.sc_LeftArrow && WL_Globals.viewsize > 4)
                    WL_Globals.viewsize -= 2;
                else if (scan == ScanCodes.sc_RightArrow && WL_Globals.viewsize < 20)
                    WL_Globals.viewsize += 2;
                else if (scan == ScanCodes.sc_Escape || scan == ScanCodes.sc_Return)
                    return;

                // Redraw
                DrawWindow(MenuConstants.NM_X, MenuConstants.NM_Y, MenuConstants.NM_W, 60, MenuConstants.BKGDCOLOR);
                WL_Globals.px = (ushort)(MenuConstants.NM_X + 10);
                WL_Globals.py = (ushort)(MenuConstants.NM_Y + 10);
                IdVh.VW_DrawPropString("View Size: " + WL_Globals.viewsize.ToString());
                IdVl.VL_UpdateScreen();
            }
        }

        public static void CP_ViewScores(int _)
        {
            IdUs.US_DisplayHighScores(-1);
            IdVl.VL_UpdateScreen();

            while (true)
            {
                IdIn.IN_ProcessEvents();
                SDL.SDL_Delay(10);
                if (WL_Globals.LastScan != ScanCodes.sc_None)
                {
                    WL_Globals.LastScan = ScanCodes.sc_None;
                    return;
                }
            }
        }

        public static int CP_EndGame()
        {
            return 0;
        }

        public static void CP_Quit(int _)
        {
            WlMain.Quit(null);
        }

        public static void CP_ExitOptions(int _) { }

        // =========================================================================
        //  Utility
        // =========================================================================

        public static void WaitKeyUp()
        {
            while (WL_Globals.LastScan != ScanCodes.sc_None || IdIn.IN_MouseButtons() != 0)
            {
                IdIn.IN_ProcessEvents();
                SDL.SDL_Delay(5);
            }
        }

        public static void ReadAnyControl(ControlInfo ci)
        {
            IdIn.IN_ReadControl(0, ci);
        }

        public static void TicDelay(int count)
        {
            int start = WL_Globals.TimeCount;
            while (WL_Globals.TimeCount - start < count)
            {
                IdSd.SD_TimeCountUpdate();
                SDL.SDL_Delay(5);
            }
        }

        public static void StartCPMusic(int song)
        {
            // Start menu music
        }

        public static int Confirm(string str)
        {
            return 1; // stub
        }

        public static void Message(string str)
        {
            IdUs.US_CenterWindow(str.Length + 2, 3);
            IdUs.US_Print(str);
            IdVl.VL_UpdateScreen();
        }

        public static void CheckPause() { }
        public static void ShootSnd() { IdSd.SD_PlaySound(soundnames.SHOOTSND); }
        public static void BossKey() { }
        public static void CheckSecretMissions() { }
        public static int CP_CheckQuick(int scancode) { return 0; }
        public static void CheckForEpisodes() { }

        public static void SetTextColor(CP_itemtype[] items, int hlight) { }
        public static void DrawHalfStep(int x, int y) { }
        public static void EraseGun(CP_iteminfo item_i, CP_itemtype[] items, int x, int y, int which) { }
        public static void DrawGun(CP_iteminfo item_i, CP_itemtype[] items, int x, ref int y, int which, int basey, MenuRoutine routine) { }
        public static void CacheLump(int lumpstart, int lumpend) { }
        public static void UnCacheLump(int lumpstart, int lumpend) { }
        public static void NonShareware() { }
    }
}
