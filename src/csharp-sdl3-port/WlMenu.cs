// WL_MENU.C -> WlMenu.cs
// Menu system - main menu, options, save/load, sound, control, etc.

using System;
using System.IO;

namespace Wolf3D
{
    public static class WlMenu
    {
        private static int[] SaveGamesAvail = new int[10];
        private static string[] SaveGameNames = new string[10];
        public static int StartGame;
        public static int SoundStatus = 1;
        private static int pickquick;

        private static string[] endStrings = {
            "Dost thou wish to\nleave with such hasty\nabandon?",
            "Chickening out...\nalready?",
            "Press N for more carnage.\nPress Y to be a weenie.",
            "So, you think you can\nquit this easily, huh?",
            "Press N to save the world.\nPress Y to abandon it in\nits hour of need.",
            "Press N if you are brave.\nPress Y to cower in shame.",
            "Heroes, press N.\nWimps, press Y.",
            "You are at an intersection.\nA sign says, 'Press Y to quit.'\n>",
            "For guns and glory, press N.\nFor work and worry, press Y."
        };

        // Menu items
        public static CP_iteminfo MainItems = new CP_iteminfo
        {
            x = MenuConstants.MENU_X, y = MenuConstants.MENU_Y,
            amount = 10, curpos = 0, indent = 24
        };
        public static CP_iteminfo SndItems = new CP_iteminfo
        {
            x = MenuConstants.SM_X, y = MenuConstants.SM_Y1,
            amount = 12, curpos = 0, indent = 52
        };
        public static CP_iteminfo LSItems = new CP_iteminfo
        {
            x = MenuConstants.LSM_X, y = MenuConstants.LSM_Y,
            amount = 10, curpos = 0, indent = 24
        };
        public static CP_iteminfo CtlItems = new CP_iteminfo
        {
            x = MenuConstants.CTL_X, y = MenuConstants.CTL_Y,
            amount = 6, curpos = -1, indent = 56
        };
        public static CP_iteminfo NewEitems = new CP_iteminfo
        {
            x = MenuConstants.NE_X, y = MenuConstants.NE_Y,
            amount = 11, curpos = 0, indent = 88
        };
        public static CP_iteminfo NewItems = new CP_iteminfo
        {
            x = MenuConstants.NM_X, y = MenuConstants.NM_Y,
            amount = 4, curpos = 2, indent = 24
        };

        public static CP_itemtype[] MainMenu;
        public static CP_itemtype[] SndMenu;
        public static CP_itemtype[] CtlMenu;
        public static CP_itemtype[] NewEMenu;
        public static CP_itemtype[] NewMenu;
        public static CP_itemtype[] LSMenu;

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

            SndMenu = new CP_itemtype[]
            {
                new CP_itemtype { active = 1, str = ForeignStrings.STR_NONE, routine = null },
                new CP_itemtype { active = 1, str = ForeignStrings.STR_PC, routine = null },
                new CP_itemtype { active = 1, str = ForeignStrings.STR_ALSB, routine = null },
                new CP_itemtype { active = 0, str = "", routine = null },
                new CP_itemtype { active = 0, str = "", routine = null },
                new CP_itemtype { active = 1, str = ForeignStrings.STR_NONE, routine = null },
                new CP_itemtype { active = 1, str = ForeignStrings.STR_DISNEY, routine = null },
                new CP_itemtype { active = 1, str = ForeignStrings.STR_SB, routine = null },
                new CP_itemtype { active = 0, str = "", routine = null },
                new CP_itemtype { active = 0, str = "", routine = null },
                new CP_itemtype { active = 1, str = ForeignStrings.STR_NONE, routine = null },
                new CP_itemtype { active = 1, str = ForeignStrings.STR_ALSB, routine = null },
            };

            CtlMenu = new CP_itemtype[]
            {
                new CP_itemtype { active = 0, str = ForeignStrings.STR_MOUSEEN, routine = null },
                new CP_itemtype { active = 0, str = ForeignStrings.STR_JOYEN, routine = null },
                new CP_itemtype { active = 0, str = ForeignStrings.STR_PORT2, routine = null },
                new CP_itemtype { active = 0, str = ForeignStrings.STR_GAMEPAD, routine = null },
                new CP_itemtype { active = 0, str = ForeignStrings.STR_SENS, routine = (x) => MouseSensitivity(0) },
                new CP_itemtype { active = 1, str = ForeignStrings.STR_CUSTOM, routine = (x) => CustomControls(0) },
            };

            NewEMenu = new CP_itemtype[]
            {
                new CP_itemtype { active = 1, str = "Episode 1\nEscape from Wolfenstein" },
                new CP_itemtype { active = 0, str = "" },
                new CP_itemtype { active = 1, str = "Episode 2\nOperation: Eisenfaust" },
                new CP_itemtype { active = 0, str = "" },
                new CP_itemtype { active = 1, str = "Episode 3\nDie, Fuhrer, Die!" },
                new CP_itemtype { active = 0, str = "" },
                new CP_itemtype { active = 1, str = "Episode 4\nA Dark Secret" },
                new CP_itemtype { active = 0, str = "" },
                new CP_itemtype { active = 1, str = "Episode 5\nTrail of the Madman" },
                new CP_itemtype { active = 0, str = "" },
                new CP_itemtype { active = 1, str = "Episode 6\nConfrontation" },
            };

            NewMenu = new CP_itemtype[]
            {
                new CP_itemtype { active = 1, str = ForeignStrings.STR_DADDY },
                new CP_itemtype { active = 1, str = ForeignStrings.STR_HURTME },
                new CP_itemtype { active = 1, str = ForeignStrings.STR_BRINGEM },
                new CP_itemtype { active = 1, str = ForeignStrings.STR_DEATH },
            };

            LSMenu = new CP_itemtype[10];
            for (int i = 0; i < 10; i++)
                LSMenu[i] = new CP_itemtype { active = 1, str = "", routine = null };

            for (int i = 0; i < SaveGameNames.Length; i++)
                SaveGameNames[i] = ForeignStrings.STR_EMPTY;
        }

        // =========================================================================
        //  US_ControlPanel - Main menu entry point
        // =========================================================================

        public static void US_ControlPanel(byte scancode)
        {
            if (WL_Globals.ingame)
            {
                if (CP_CheckQuick(scancode) != 0)
                    return;
            }

            StartCPMusic((int)musicnames.CORNER_MUS);
            SetupControlPanel();

            // F-KEYS FROM WITHIN GAME
            switch (scancode)
            {
                case ScanCodes.sc_F1:
                    WlText.HelpScreens();
                    CleanupControlPanel();
                    return;
                case ScanCodes.sc_F2:
                    CP_SaveGame(0);
                    CleanupControlPanel();
                    return;
                case ScanCodes.sc_F3:
                    CP_LoadGame(0);
                    CleanupControlPanel();
                    return;
                case ScanCodes.sc_F4:
                    CP_Sound(0);
                    CleanupControlPanel();
                    return;
                case ScanCodes.sc_F5:
                    CP_ChangeView(0);
                    CleanupControlPanel();
                    return;
                case ScanCodes.sc_F6:
                    CP_Control(0);
                    CleanupControlPanel();
                    return;
            }

            DrawMainMenu();
            IdVl.VL_UpdateScreen();

            StartGame = 0;

            int result = HandleMenu(MainItems, MainMenu, null);

            CleanupControlPanel();
        }

        // =========================================================================
        //  CP_CheckQuick - handle quick keys (F8=quicksave, F9=quickload, F10=quit)
        // =========================================================================

        public static int CP_CheckQuick(int scancode)
        {
            switch ((byte)scancode)
            {
                case ScanCodes.sc_F7:
                    // End game
                    WlPlay.CenterWindow(20, 3);
                    IdUs.US_PrintCentered(ForeignStrings.ENDGAMESTR);
                    IdVl.VL_UpdateScreen();
                    if (Confirm(ForeignStrings.ENDGAMESTR) != 0)
                    {
                        WL_Globals.playstate = exit_t.ex_died;
                        WL_Globals.killerobj = null;
                    }
                    return 1;

                case ScanCodes.sc_F8:
                    // Quick save
                    CP_SaveGame(1);
                    return 1;

                case ScanCodes.sc_F9:
                    // Quick load
                    CP_LoadGame(1);
                    return 1;

                case ScanCodes.sc_F10:
                    // Quit
                    CP_Quit(0);
                    return 1;
            }
            return 0;
        }

        // =========================================================================
        //  Setup / Cleanup
        // =========================================================================

        public static void SetupControlPanel()
        {
            for (int i = GfxConstants.CONTROLS_LUMP_START; i <= GfxConstants.CONTROLS_LUMP_END; i++)
                IdCa.CA_CacheGrChunk(i);

            WL_Globals.fontnumber = 1;

            // Enable save game option if in game
            if (WL_Globals.ingame)
                MainMenu[4].active = 1;
            else
                MainMenu[4].active = 0;

            // Scan for saved games
            for (int i = 0; i < 10; i++)
            {
                string name = IdUs.USL_GiveSaveName(i);
                if (File.Exists(name))
                {
                    SaveGamesAvail[i] = 1;
                    try
                    {
                        using (var br = new BinaryReader(File.OpenRead(name)))
                        {
                            byte[] nameBuf = br.ReadBytes(32);
                            SaveGameNames[i] = System.Text.Encoding.ASCII.GetString(nameBuf).TrimEnd('\0');
                        }
                    }
                    catch
                    {
                        SaveGameNames[i] = "Save " + i.ToString();
                    }
                }
                else
                {
                    SaveGamesAvail[i] = 0;
                    SaveGameNames[i] = ForeignStrings.STR_EMPTY;
                }
            }
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
                    WL_Globals.fontcolor = (byte)MenuConstants.TEXTCOLOR;
                else
                    WL_Globals.fontcolor = (byte)MenuConstants.DEACTIVE;

                if (items[i].str.Length > 0)
                    IdVh.VW_DrawPropString(items[i].str);
                y += 13;
            }
        }

        // =========================================================================
        //  HandleMenu - generic menu handler
        // =========================================================================

        public static int HandleMenu(CP_iteminfo item_i, CP_itemtype[] items, MenuRoutine routine)
        {
            int which = item_i.curpos;
            if (which < 0) which = 0;
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
                        which = -1;
                        IdSd.SD_PlaySound(soundnames.ESCPRESSEDSND);
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
                        IdSd.SD_PlaySound(soundnames.MOVEGUN1SND);
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
                        IdSd.SD_PlaySound(soundnames.MOVEGUN1SND);
                        break;

                    case ScanCodes.sc_Return:
                    case ScanCodes.sc_Space:
                        item_i.curpos = which;
                        if (which >= 0 && which < items.Length && items[which].routine != null)
                        {
                            IdSd.SD_PlaySound(soundnames.SHOOTSND);
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
            // Erase old cursor position
            IdVl.VL_Bar(item_i.x - 1, item_i.y, item_i.indent, item_i.amount * 13, MenuConstants.BKGDCOLOR);

            // Draw cursor at new position
            int x = item_i.x;
            int y = item_i.y + which * 13;
            IdVh.VWB_DrawPic(x, y, (int)graphicnums.C_CURSOR1PIC);
        }

        public static void DrawMenuGun(CP_iteminfo item_i)
        {
            DrawMenuGun(item_i, item_i.curpos);
        }

        // =========================================================================
        //  CP_NewGame - new game with episode/difficulty selection
        // =========================================================================

        public static void CP_NewGame(int _)
        {
            // Episode selection
            int episode = 0;

            ClearMScreen();
            DrawStripes(10);
            IdVh.VWB_DrawPic(80, 0, (int)graphicnums.C_OPTIONSPIC);

            // Draw episode menu
            WL_Globals.fontnumber = 1;
            for (int i = 0; i < 6; i++)
            {
                WL_Globals.px = (ushort)(MenuConstants.NE_X + 88);
                WL_Globals.py = (ushort)(MenuConstants.NE_Y + i * 26);
                WL_Globals.fontcolor = (byte)MenuConstants.TEXTCOLOR;
                IdVh.VW_DrawPropString("Episode " + (i + 1).ToString());
            }
            IdVl.VL_UpdateScreen();

            // Simple episode selection
            int ep = 0;
            bool done = false;
            while (!done)
            {
                IdIn.IN_ProcessEvents();
                SDL.SDL_Delay(10);
                byte scan = WL_Globals.LastScan;
                if (scan == ScanCodes.sc_None) continue;
                WL_Globals.LastScan = ScanCodes.sc_None;

                if (scan == ScanCodes.sc_Escape) return;
                if (scan == ScanCodes.sc_UpArrow) { ep--; if (ep < 0) ep = 5; }
                if (scan == ScanCodes.sc_DownArrow) { ep++; if (ep > 5) ep = 0; }
                if (scan == ScanCodes.sc_Return) { episode = ep; done = true; }
            }

            // Difficulty selection
            ClearMScreen();
            DrawStripes(10);

            WL_Globals.px = (ushort)(MenuConstants.NM_X + 24);
            WL_Globals.py = (ushort)(MenuConstants.NM_Y);
            WL_Globals.fontcolor = (byte)MenuConstants.TEXTCOLOR;

            // Draw difficulty pictures
            IdVh.VWB_DrawPic(MenuConstants.NM_X + 25, MenuConstants.NM_Y, (int)graphicnums.C_BABYMODEPIC);
            IdVh.VWB_DrawPic(MenuConstants.NM_X + 25, MenuConstants.NM_Y + 26, (int)graphicnums.C_EASYPIC);
            IdVh.VWB_DrawPic(MenuConstants.NM_X + 25, MenuConstants.NM_Y + 52, (int)graphicnums.C_NORMALPIC);
            IdVh.VWB_DrawPic(MenuConstants.NM_X + 25, MenuConstants.NM_Y + 78, (int)graphicnums.C_HARDPIC);
            IdVl.VL_UpdateScreen();

            int diff = 2;
            done = false;
            while (!done)
            {
                IdIn.IN_ProcessEvents();
                SDL.SDL_Delay(10);
                byte scan = WL_Globals.LastScan;
                if (scan == ScanCodes.sc_None) continue;
                WL_Globals.LastScan = ScanCodes.sc_None;

                if (scan == ScanCodes.sc_Escape) return;
                if (scan == ScanCodes.sc_UpArrow) { diff--; if (diff < 0) diff = 3; }
                if (scan == ScanCodes.sc_DownArrow) { diff++; if (diff > 3) diff = 0; }
                if (scan == ScanCodes.sc_Return) done = true;
            }

            WlMain.NewGame(diff, episode);
            WL_Globals.startgame = true;
        }

        // =========================================================================
        //  CP_Sound - sound configuration menu
        // =========================================================================

        public static void CP_Sound(int _)
        {
            ClearMScreen();
            DrawStripes(10);

            // Sound Effects section
            DrawWindow(MenuConstants.SM_X, MenuConstants.SM_Y1, MenuConstants.SM_W, MenuConstants.SM_H1, MenuConstants.BKGDCOLOR);
            DrawWindow(MenuConstants.SM_X, MenuConstants.SM_Y2, MenuConstants.SM_W, MenuConstants.SM_H2, MenuConstants.BKGDCOLOR);
            DrawWindow(MenuConstants.SM_X, MenuConstants.SM_Y3, MenuConstants.SM_W, MenuConstants.SM_H3, MenuConstants.BKGDCOLOR);

            IdVh.VWB_DrawPic(MenuConstants.SM_X + 2, MenuConstants.SM_Y1, (int)graphicnums.C_FXTITLEPIC);
            IdVh.VWB_DrawPic(MenuConstants.SM_X + 2, MenuConstants.SM_Y2, (int)graphicnums.C_DIGITITLEPIC);
            IdVh.VWB_DrawPic(MenuConstants.SM_X + 2, MenuConstants.SM_Y3, (int)graphicnums.C_MUSICTITLEPIC);

            // Draw current selections
            WL_Globals.fontcolor = (byte)MenuConstants.TEXTCOLOR;
            WL_Globals.px = (ushort)(MenuConstants.SM_X + 100);
            WL_Globals.py = (ushort)(MenuConstants.SM_Y1 + 5);
            IdVh.VW_DrawPropString("Sound: " + WL_Globals.SoundMode.ToString());

            WL_Globals.px = (ushort)(MenuConstants.SM_X + 100);
            WL_Globals.py = (ushort)(MenuConstants.SM_Y2 + 5);
            IdVh.VW_DrawPropString("Digi: " + WL_Globals.DigiMode.ToString());

            WL_Globals.px = (ushort)(MenuConstants.SM_X + 100);
            WL_Globals.py = (ushort)(MenuConstants.SM_Y3 + 5);
            IdVh.VW_DrawPropString("Music: " + WL_Globals.MusicMode.ToString());

            IdVl.VL_UpdateScreen();

            // Wait for key to toggle or escape
            while (true)
            {
                IdIn.IN_ProcessEvents();
                SDL.SDL_Delay(10);
                byte scan = WL_Globals.LastScan;
                if (scan == ScanCodes.sc_None) continue;
                WL_Globals.LastScan = ScanCodes.sc_None;

                if (scan == ScanCodes.sc_Escape) return;

                // Toggle sound modes with number keys
                if (scan == ScanCodes.sc_1)
                {
                    if (WL_Globals.SoundMode == SDMode.sdm_Off)
                        IdSd.SD_SetSoundMode(SDMode.sdm_AdLib);
                    else
                        IdSd.SD_SetSoundMode(SDMode.sdm_Off);
                }
                if (scan == ScanCodes.sc_2)
                {
                    if (WL_Globals.MusicMode == SMMode.smm_Off)
                        IdSd.SD_SetMusicMode(SMMode.smm_AdLib);
                    else
                        IdSd.SD_SetMusicMode(SMMode.smm_Off);
                }

                // Redraw
                IdVl.VL_Bar(MenuConstants.SM_X + 100, MenuConstants.SM_Y1 + 5, 140, 30, MenuConstants.BKGDCOLOR);
                IdVl.VL_Bar(MenuConstants.SM_X + 100, MenuConstants.SM_Y2 + 5, 140, 30, MenuConstants.BKGDCOLOR);
                IdVl.VL_Bar(MenuConstants.SM_X + 100, MenuConstants.SM_Y3 + 5, 140, 30, MenuConstants.BKGDCOLOR);

                WL_Globals.px = (ushort)(MenuConstants.SM_X + 100);
                WL_Globals.py = (ushort)(MenuConstants.SM_Y1 + 5);
                IdVh.VW_DrawPropString("Sound: " + WL_Globals.SoundMode.ToString());
                WL_Globals.px = (ushort)(MenuConstants.SM_X + 100);
                WL_Globals.py = (ushort)(MenuConstants.SM_Y2 + 5);
                IdVh.VW_DrawPropString("Digi: " + WL_Globals.DigiMode.ToString());
                WL_Globals.px = (ushort)(MenuConstants.SM_X + 100);
                WL_Globals.py = (ushort)(MenuConstants.SM_Y3 + 5);
                IdVh.VW_DrawPropString("Music: " + WL_Globals.MusicMode.ToString());
                IdVl.VL_UpdateScreen();
            }
        }

        // =========================================================================
        //  CP_LoadGame / CP_SaveGame - file I/O with BinaryReader/BinaryWriter
        // =========================================================================

        public static int CP_LoadGame(int quick)
        {
            if (quick != 0 && pickquick >= 0)
            {
                // Quick load from last used slot
                return LoadTheGame(pickquick) ? 1 : 0;
            }

            // Draw load game screen
            ClearMScreen();
            DrawStripes(10);
            IdVh.VWB_DrawPic(86, 0, (int)graphicnums.C_LOADGAMEPIC);

            for (int i = 0; i < 10; i++)
            {
                WL_Globals.px = (ushort)(MenuConstants.LSM_X + 24);
                WL_Globals.py = (ushort)(MenuConstants.LSM_Y + i * 13);
                WL_Globals.fontcolor = (byte)((SaveGamesAvail[i] != 0) ? MenuConstants.TEXTCOLOR : MenuConstants.DEACTIVE);
                IdVh.VW_DrawPropString(SaveGameNames[i]);
            }
            IdVl.VL_UpdateScreen();

            int slot = 0;
            while (true)
            {
                IdIn.IN_ProcessEvents();
                SDL.SDL_Delay(10);
                byte scan = WL_Globals.LastScan;
                if (scan == ScanCodes.sc_None) continue;
                WL_Globals.LastScan = ScanCodes.sc_None;

                if (scan == ScanCodes.sc_Escape) return 0;
                if (scan == ScanCodes.sc_UpArrow) { slot--; if (slot < 0) slot = 9; }
                if (scan == ScanCodes.sc_DownArrow) { slot++; if (slot > 9) slot = 0; }
                if (scan == ScanCodes.sc_Return && SaveGamesAvail[slot] != 0)
                {
                    pickquick = slot;
                    if (LoadTheGame(slot))
                    {
                        WL_Globals.loadedgame = true;
                        WL_Globals.startgame = true;
                        return 1;
                    }
                }
            }
        }

        public static int CP_SaveGame(int quick)
        {
            if (quick != 0 && pickquick >= 0)
            {
                return SaveTheGame(pickquick, SaveGameNames[pickquick]) ? 1 : 0;
            }

            // Draw save game screen
            ClearMScreen();
            DrawStripes(10);
            IdVh.VWB_DrawPic(86, 0, (int)graphicnums.C_SAVEGAMEPIC);

            for (int i = 0; i < 10; i++)
            {
                WL_Globals.px = (ushort)(MenuConstants.LSM_X + 24);
                WL_Globals.py = (ushort)(MenuConstants.LSM_Y + i * 13);
                WL_Globals.fontcolor = (byte)MenuConstants.TEXTCOLOR;
                IdVh.VW_DrawPropString(SaveGameNames[i]);
            }
            IdVl.VL_UpdateScreen();

            int slot = 0;
            while (true)
            {
                IdIn.IN_ProcessEvents();
                SDL.SDL_Delay(10);
                byte scan = WL_Globals.LastScan;
                if (scan == ScanCodes.sc_None) continue;
                WL_Globals.LastScan = ScanCodes.sc_None;

                if (scan == ScanCodes.sc_Escape) return 0;
                if (scan == ScanCodes.sc_UpArrow) { slot--; if (slot < 0) slot = 9; }
                if (scan == ScanCodes.sc_DownArrow) { slot++; if (slot > 9) slot = 0; }
                if (scan == ScanCodes.sc_Return)
                {
                    string saveName = "Save " + slot.ToString();
                    pickquick = slot;
                    if (SaveTheGame(slot, saveName))
                    {
                        SaveGamesAvail[slot] = 1;
                        SaveGameNames[slot] = saveName;
                        return 1;
                    }
                }
            }
        }

        private static bool SaveTheGame(int slot, string name)
        {
            try
            {
                string filename = IdUs.USL_GiveSaveName(slot);
                using (var bw = new BinaryWriter(File.Create(filename)))
                {
                    // Write save name (32 bytes)
                    byte[] nameBuf = new byte[32];
                    byte[] nameBytes = System.Text.Encoding.ASCII.GetBytes(name);
                    Array.Copy(nameBytes, nameBuf, Math.Min(nameBytes.Length, 31));
                    bw.Write(nameBuf);

                    // Write game state
                    bw.Write(WL_Globals.gamestate.difficulty);
                    bw.Write(WL_Globals.gamestate.mapon);
                    bw.Write(WL_Globals.gamestate.score);
                    bw.Write(WL_Globals.gamestate.nextextra);
                    bw.Write(WL_Globals.gamestate.lives);
                    bw.Write(WL_Globals.gamestate.health);
                    bw.Write(WL_Globals.gamestate.ammo);
                    bw.Write(WL_Globals.gamestate.keys);
                    bw.Write((int)WL_Globals.gamestate.bestweapon);
                    bw.Write((int)WL_Globals.gamestate.weapon);
                    bw.Write((int)WL_Globals.gamestate.chosenweapon);
                    bw.Write(WL_Globals.gamestate.episode);
                }

                Message(ForeignStrings.STR_SAVING + "...");
                IdVl.VL_UpdateScreen();
                SDL.SDL_Delay(500);
                return true;
            }
            catch
            {
                Message("Save failed!");
                IdVl.VL_UpdateScreen();
                SDL.SDL_Delay(1000);
                return false;
            }
        }

        private static bool LoadTheGame(int slot)
        {
            try
            {
                string filename = IdUs.USL_GiveSaveName(slot);
                using (var br = new BinaryReader(File.OpenRead(filename)))
                {
                    byte[] nameBuf = br.ReadBytes(32);

                    WL_Globals.gamestate.difficulty = br.ReadInt32();
                    WL_Globals.gamestate.mapon = br.ReadInt32();
                    WL_Globals.gamestate.score = br.ReadInt32();
                    WL_Globals.gamestate.nextextra = br.ReadInt32();
                    WL_Globals.gamestate.lives = br.ReadInt32();
                    WL_Globals.gamestate.health = br.ReadInt32();
                    WL_Globals.gamestate.ammo = br.ReadInt32();
                    WL_Globals.gamestate.keys = br.ReadInt32();
                    WL_Globals.gamestate.bestweapon = (weapontype)br.ReadInt32();
                    WL_Globals.gamestate.weapon = (weapontype)br.ReadInt32();
                    WL_Globals.gamestate.chosenweapon = (weapontype)br.ReadInt32();
                    WL_Globals.gamestate.episode = br.ReadInt32();
                }

                Message(ForeignStrings.STR_LOADING + "...");
                IdVl.VL_UpdateScreen();
                SDL.SDL_Delay(500);
                return true;
            }
            catch
            {
                Message("Load failed!");
                IdVl.VL_UpdateScreen();
                SDL.SDL_Delay(1000);
                return false;
            }
        }

        // =========================================================================
        //  CP_Control - control configuration menu
        // =========================================================================

        public static void CP_Control(int _)
        {
            ClearMScreen();
            DrawStripes(10);
            IdVh.VWB_DrawPic(80, 0, (int)graphicnums.C_CONTROLPIC);

            DrawWindow(MenuConstants.CTL_X, MenuConstants.CTL_Y, MenuConstants.CTL_W, MenuConstants.CTL_H, MenuConstants.BKGDCOLOR);

            WL_Globals.fontcolor = (byte)MenuConstants.TEXTCOLOR;

            WL_Globals.px = (ushort)(MenuConstants.CTL_X + 10);
            WL_Globals.py = (ushort)(MenuConstants.CTL_Y + 5);
            IdVh.VW_DrawPropString("Mouse: " + (WL_Globals.mouseenabled ? "ON" : "OFF"));

            WL_Globals.px = (ushort)(MenuConstants.CTL_X + 10);
            WL_Globals.py = (ushort)(MenuConstants.CTL_Y + 18);
            IdVh.VW_DrawPropString("Sensitivity: " + WL_Globals.mouseadjustment.ToString());

            WL_Globals.px = (ushort)(MenuConstants.CTL_X + 10);
            WL_Globals.py = (ushort)(MenuConstants.CTL_Y + 31);
            IdVh.VW_DrawPropString("Customize Controls (Enter)");

            IdVl.VL_UpdateScreen();

            while (true)
            {
                IdIn.IN_ProcessEvents();
                SDL.SDL_Delay(10);
                byte scan = WL_Globals.LastScan;
                if (scan == ScanCodes.sc_None) continue;
                WL_Globals.LastScan = ScanCodes.sc_None;

                if (scan == ScanCodes.sc_Escape) return;
                if (scan == ScanCodes.sc_M)
                {
                    WL_Globals.mouseenabled = !WL_Globals.mouseenabled;
                    // Redraw
                    IdVl.VL_Bar(MenuConstants.CTL_X + 10, MenuConstants.CTL_Y + 5, MenuConstants.CTL_W - 20, 12, MenuConstants.BKGDCOLOR);
                    WL_Globals.px = (ushort)(MenuConstants.CTL_X + 10);
                    WL_Globals.py = (ushort)(MenuConstants.CTL_Y + 5);
                    IdVh.VW_DrawPropString("Mouse: " + (WL_Globals.mouseenabled ? "ON" : "OFF"));
                    IdVl.VL_UpdateScreen();
                }
                if (scan == ScanCodes.sc_Return)
                {
                    CustomControls(0);
                    return;
                }
            }
        }

        // =========================================================================
        //  MouseSensitivity / CustomControls
        // =========================================================================

        public static void MouseSensitivity(int _)
        {
            ClearMScreen();
            DrawStripes(10);
            DrawWindow(MenuConstants.NM_X, MenuConstants.NM_Y, MenuConstants.NM_W, 60, MenuConstants.BKGDCOLOR);

            WL_Globals.fontcolor = (byte)MenuConstants.TEXTCOLOR;
            WL_Globals.px = (ushort)(MenuConstants.NM_X + 10);
            WL_Globals.py = (ushort)(MenuConstants.NM_Y + 10);
            IdVh.VW_DrawPropString("Mouse Sensitivity: " + WL_Globals.mouseadjustment.ToString());

            // Draw sensitivity bar
            int barx = MenuConstants.NM_X + 10;
            int bary = MenuConstants.NM_Y + 30;
            IdVl.VL_Bar(barx, bary, 200, 10, 0);
            int fill = WL_Globals.mouseadjustment * 20;
            if (fill > 0)
                IdVl.VL_Bar(barx, bary, fill, 10, MenuConstants.TEXTCOLOR);

            IdVl.VL_UpdateScreen();

            while (true)
            {
                IdIn.IN_ProcessEvents();
                SDL.SDL_Delay(10);
                byte scan = WL_Globals.LastScan;
                if (scan == ScanCodes.sc_None) continue;
                WL_Globals.LastScan = ScanCodes.sc_None;

                if (scan == ScanCodes.sc_Escape || scan == ScanCodes.sc_Return) return;
                if (scan == ScanCodes.sc_LeftArrow && WL_Globals.mouseadjustment > 0)
                    WL_Globals.mouseadjustment--;
                if (scan == ScanCodes.sc_RightArrow && WL_Globals.mouseadjustment < 9)
                    WL_Globals.mouseadjustment++;

                // Redraw
                IdVl.VL_Bar(barx, bary, 200, 10, 0);
                fill = WL_Globals.mouseadjustment * 20;
                if (fill > 0) IdVl.VL_Bar(barx, bary, fill, 10, MenuConstants.TEXTCOLOR);
                IdVl.VL_Bar(MenuConstants.NM_X + 10, MenuConstants.NM_Y + 10, MenuConstants.NM_W - 20, 12, MenuConstants.BKGDCOLOR);
                WL_Globals.px = (ushort)(MenuConstants.NM_X + 10);
                WL_Globals.py = (ushort)(MenuConstants.NM_Y + 10);
                IdVh.VW_DrawPropString("Mouse Sensitivity: " + WL_Globals.mouseadjustment.ToString());
                IdVl.VL_UpdateScreen();
            }
        }

        public static void CustomControls(int _)
        {
            ClearMScreen();
            DrawStripes(10);
            IdVh.VWB_DrawPic(80, 0, (int)graphicnums.C_CUSTOMIZEPIC);

            WL_Globals.fontcolor = (byte)MenuConstants.TEXTCOLOR;

            string[] btnNames = { "Attack", "Strafe", "Use", "Run" };
            for (int i = 0; i < 4 && i < WL_Globals.buttonscan.Length; i++)
            {
                WL_Globals.px = (ushort)(MenuConstants.CST_X);
                WL_Globals.py = (ushort)(MenuConstants.CST_Y + i * 13);
                IdVh.VW_DrawPropString(btnNames[i] + ": Scan " + WL_Globals.buttonscan[i].ToString());
            }

            IdVl.VL_UpdateScreen();

            while (true)
            {
                IdIn.IN_ProcessEvents();
                SDL.SDL_Delay(10);
                if (WL_Globals.LastScan == ScanCodes.sc_Escape)
                {
                    WL_Globals.LastScan = ScanCodes.sc_None;
                    return;
                }
                WL_Globals.LastScan = ScanCodes.sc_None;
            }
        }

        // =========================================================================
        //  CP_ChangeView - change view size
        // =========================================================================

        public static void CP_ChangeView(int _)
        {
            ClearMScreen();
            DrawStripes(10);
            DrawWindow(MenuConstants.NM_X, MenuConstants.NM_Y, MenuConstants.NM_W, 60, MenuConstants.BKGDCOLOR);

            WL_Globals.px = (ushort)(MenuConstants.NM_X + 10);
            WL_Globals.py = (ushort)(MenuConstants.NM_Y + 10);
            WL_Globals.fontcolor = (byte)MenuConstants.TEXTCOLOR;
            IdVh.VW_DrawPropString("View Size: " + WL_Globals.viewsize.ToString());

            // Draw view size bar
            int barx = MenuConstants.NM_X + 10;
            int bary = MenuConstants.NM_Y + 30;
            IdVl.VL_Bar(barx, bary, 200, 10, 0);
            int fill = (WL_Globals.viewsize - 4) * 12;
            if (fill > 0) IdVl.VL_Bar(barx, bary, fill, 10, MenuConstants.VIEWCOLOR);

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
                IdVl.VL_Bar(barx, bary, 200, 10, 0);
                fill = (WL_Globals.viewsize - 4) * 12;
                if (fill > 0) IdVl.VL_Bar(barx, bary, fill, 10, MenuConstants.VIEWCOLOR);
                IdVl.VL_UpdateScreen();
            }
        }

        // =========================================================================
        //  CP_ViewScores - display high scores
        // =========================================================================

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

        // =========================================================================
        //  CP_EndGame / CP_Quit
        // =========================================================================

        public static int CP_EndGame()
        {
            if (!WL_Globals.ingame) return 0;

            if (Confirm(ForeignStrings.ENDGAMESTR) != 0)
            {
                WL_Globals.playstate = exit_t.ex_died;
                return 1;
            }
            return 0;
        }

        public static void CP_Quit(int _)
        {
            int rnd = IdUs.US_RndT() % endStrings.Length;
            if (Confirm(endStrings[rnd]) != 0)
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
            int chunk = AudioConstants.STARTMUSIC + song;
            IdCa.CA_CacheAudioChunk(chunk);
            byte[] music = WL_Globals.audiosegs[chunk];
            if (music != null)
                IdSd.SD_StartMusic(music);
        }

        public static int Confirm(string str)
        {
            Message(str);
            IdVl.VL_UpdateScreen();

            IdIn.IN_ClearKeysDown();
            while (true)
            {
                IdIn.IN_ProcessEvents();
                SDL.SDL_Delay(10);
                byte scan = WL_Globals.LastScan;
                if (scan == ScanCodes.sc_None) continue;
                WL_Globals.LastScan = ScanCodes.sc_None;

                if (scan == ScanCodes.sc_Y) return 1;
                if (scan == ScanCodes.sc_Return) return 1;
                if (scan == ScanCodes.sc_N || scan == ScanCodes.sc_Escape) return 0;
            }
        }

        public static void Message(string str)
        {
            int w = str.Length + 2;
            if (w > 38) w = 38;
            IdUs.US_CenterWindow(w, 5);
            IdUs.US_Print(str);
            IdVl.VL_UpdateScreen();
        }

        public static void CheckPause() { }
        public static void ShootSnd() { IdSd.SD_PlaySound(soundnames.SHOOTSND); }
        public static void BossKey() { }
        public static void CheckSecretMissions() { }
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
