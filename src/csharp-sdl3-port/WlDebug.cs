// WL_DEBUG.C -> WlDebug.cs
// Debug tools - god mode, level warping, memory display, item cheats

using System;

namespace Wolf3D
{
    public static class WlDebug
    {
        private static int maporgx;
        private static int maporgy;

        // =========================================================================
        //  DebugMemory - show memory usage
        // =========================================================================

        public static void DebugMemory()
        {
            WlPlay.CenterWindow(16, 4);

            IdUs.US_CPrint("Memory Usage");
            IdUs.US_CPrint("------------");
            IdUs.US_Print("Free      :");
            IdUs.US_PrintUnsigned((uint)(IdMm.MM_UnusedMemory() / 1024));
            IdUs.US_Print("k\nWith purge:");
            IdUs.US_PrintUnsigned((uint)(IdMm.MM_TotalFree() / 1024));
            IdUs.US_Print("k\n");
            IdVl.VL_UpdateScreen();
            IdIn.IN_Ack();
        }

        // =========================================================================
        //  CountObjects - count active/inactive objects
        // =========================================================================

        public static void CountObjects()
        {
            WlPlay.CenterWindow(16, 7);
            int active = 0, inactive = 0, count = 0;

            IdUs.US_Print("Total statics :");
            int total = 0;
            for (int t = 0; t < WolfConstants.MAXSTATS; t++)
                if (WL_Globals.statobjlist[t] != null) total++;
            IdUs.US_PrintUnsigned((uint)total);

            IdUs.US_Print("\nIn use statics:");
            for (int i = 0; i < total; i++)
            {
                if (WL_Globals.statobjlist[i] != null && WL_Globals.statobjlist[i].shapenum != -1)
                    count++;
            }
            IdUs.US_PrintUnsigned((uint)count);

            IdUs.US_Print("\nDoors         :");
            IdUs.US_PrintUnsigned((uint)WL_Globals.doornum);

            var obj = WL_Globals.player.next;
            while (obj != null)
            {
                if (obj.active != activetype.ac_no)
                    active++;
                else
                    inactive++;
                obj = obj.next;
            }

            IdUs.US_Print("\nTotal actors  :");
            IdUs.US_PrintUnsigned((uint)(active + inactive));

            IdUs.US_Print("\nActive actors :");
            IdUs.US_PrintUnsigned((uint)active);

            IdVl.VL_UpdateScreen();
            IdIn.IN_Ack();
        }

        // =========================================================================
        //  PicturePause - pause and show current frame
        // =========================================================================

        public static void PicturePause()
        {
            WL_Globals.LastScan = ScanCodes.sc_None;
            while (WL_Globals.LastScan == ScanCodes.sc_None)
            {
                IdIn.IN_ProcessEvents();
                SDL.SDL_Delay(5);
            }
            if (WL_Globals.LastScan != ScanCodes.sc_Return)
                return;

            IdVl.VL_UpdateScreen();
            IdIn.IN_Ack();
        }

        // =========================================================================
        //  DebugKeys - handle debug key combinations (Tab + key)
        // =========================================================================

        public static int DebugKeys()
        {
            // B = border color
            if (WL_Globals.Keyboard[ScanCodes.sc_B])
            {
                WlPlay.CenterWindow(24, 3);
                WL_Globals.PrintY += 6;
                IdUs.US_Print(" Border color (0-15):");
                IdVl.VL_UpdateScreen();
                // Simplified: just acknowledge
                IdIn.IN_Ack();
                return 1;
            }

            // C = count objects
            if (WL_Globals.Keyboard[ScanCodes.sc_C])
            {
                CountObjects();
                return 1;
            }

            // E = quit level (complete it)
            if (WL_Globals.Keyboard[ScanCodes.sc_E])
            {
                WL_Globals.playstate = exit_t.ex_completed;
                return 1;
            }

            // F = facing spot (show player position)
            if (WL_Globals.Keyboard[ScanCodes.sc_F])
            {
                WlPlay.CenterWindow(14, 4);
                IdUs.US_Print("X:");
                IdUs.US_PrintUnsigned((uint)WL_Globals.player.x);
                IdUs.US_Print("\nY:");
                IdUs.US_PrintUnsigned((uint)WL_Globals.player.y);
                IdUs.US_Print("\nA:");
                IdUs.US_PrintUnsigned((uint)WL_Globals.player.angle);
                IdVl.VL_UpdateScreen();
                IdIn.IN_Ack();
                return 1;
            }

            // G = god mode toggle
            if (WL_Globals.Keyboard[ScanCodes.sc_G])
            {
                WlPlay.CenterWindow(12, 2);
                if (WL_Globals.godmode)
                    IdUs.US_PrintCentered("God mode OFF");
                else
                    IdUs.US_PrintCentered("God mode ON");
                IdVl.VL_UpdateScreen();
                IdIn.IN_Ack();
                WL_Globals.godmode = !WL_Globals.godmode;
                return 1;
            }

            // H = hurt self
            if (WL_Globals.Keyboard[ScanCodes.sc_H])
            {
                IdIn.IN_ClearKeysDown();
                WlAgent.TakeDamage(16, null);
                return 1;
            }

            // I = item cheat (give items)
            if (WL_Globals.Keyboard[ScanCodes.sc_I])
            {
                WlPlay.CenterWindow(12, 3);
                IdUs.US_PrintCentered("Free items!");
                IdVl.VL_UpdateScreen();
                WlAgent.GivePoints(100000);
                WlAgent.HealSelf(99);
                if (WL_Globals.gamestate.bestweapon < weapontype.wp_chaingun)
                    WlAgent.GiveWeapon((int)WL_Globals.gamestate.bestweapon + 1);
                WL_Globals.gamestate.ammo += 50;
                if (WL_Globals.gamestate.ammo > 99)
                    WL_Globals.gamestate.ammo = 99;
                WlAgent.DrawAmmo();
                IdIn.IN_Ack();
                return 1;
            }

            // M = memory info
            if (WL_Globals.Keyboard[ScanCodes.sc_M])
            {
                DebugMemory();
                return 1;
            }

            // N = no clip toggle
            if (WL_Globals.Keyboard[ScanCodes.sc_N])
            {
                WL_Globals.noclip = !WL_Globals.noclip;
                WlPlay.CenterWindow(18, 3);
                if (WL_Globals.noclip)
                    IdUs.US_PrintCentered("No clipping ON");
                else
                    IdUs.US_PrintCentered("No clipping OFF");
                IdVl.VL_UpdateScreen();
                IdIn.IN_Ack();
                return 1;
            }

            // P = pause with no screen disruption
            if (WL_Globals.Keyboard[ScanCodes.sc_P])
            {
                PicturePause();
                return 1;
            }

            // Q = fast quit
            if (WL_Globals.Keyboard[ScanCodes.sc_Q])
            {
                WlMain.Quit(null);
                return 1;
            }

            // S = slow motion toggle
            if (WL_Globals.Keyboard[ScanCodes.sc_S])
            {
                WL_Globals.singlestep = !WL_Globals.singlestep;
                WlPlay.CenterWindow(18, 3);
                if (WL_Globals.singlestep)
                    IdUs.US_PrintCentered("Slow motion ON");
                else
                    IdUs.US_PrintCentered("Slow motion OFF");
                IdVl.VL_UpdateScreen();
                IdIn.IN_Ack();
                return 1;
            }

            // T = shape test
            if (WL_Globals.Keyboard[ScanCodes.sc_T])
            {
                ShapeTest();
                return 1;
            }

            // V = extra VBLs
            if (WL_Globals.Keyboard[ScanCodes.sc_V])
            {
                WlPlay.CenterWindow(30, 3);
                WL_Globals.PrintY += 6;
                IdUs.US_Print("  Add how many extra VBLs(0-8):");
                IdVl.VL_UpdateScreen();
                IdIn.IN_Ack();
                return 1;
            }

            // W = warp to level
            if (WL_Globals.Keyboard[ScanCodes.sc_W])
            {
                WlPlay.CenterWindow(26, 3);
                WL_Globals.PrintY += 6;
                IdUs.US_Print("  Warp to which level(1-10):");
                IdVl.VL_UpdateScreen();

                // Simple warp: wait for a digit key
                IdIn.IN_ClearKeysDown();
                while (WL_Globals.LastScan == ScanCodes.sc_None)
                {
                    IdIn.IN_ProcessEvents();
                    SDL.SDL_Delay(5);
                }
                byte scan = WL_Globals.LastScan;
                int level = -1;
                // sc_1 through sc_9 map to levels 1-9
                if (scan >= ScanCodes.sc_1 && scan <= ScanCodes.sc_9)
                    level = scan - ScanCodes.sc_1 + 1;
                else if (scan == ScanCodes.sc_0)
                    level = 10;

                if (level > 0 && level < 11)
                {
                    WL_Globals.gamestate.mapon = level - 1;
                    WL_Globals.playstate = exit_t.ex_warped;
                }
                IdIn.IN_ClearKeysDown();
                return 1;
            }

            // X = extra stuff
            if (WL_Globals.Keyboard[ScanCodes.sc_X])
            {
                WlPlay.CenterWindow(12, 3);
                IdUs.US_PrintCentered("Extra stuff!");
                IdVl.VL_UpdateScreen();
                IdIn.IN_Ack();
                return 1;
            }

            return 0;
        }

        // =========================================================================
        //  ShapeTest - display PM pages (walls, sprites, sounds)
        // =========================================================================

        public static void ShapeTest()
        {
            int i = 0;
            bool done = false;

            WlPlay.CenterWindow(20, 16);
            IdVl.VL_UpdateScreen();

            while (!done)
            {
                IdUs.US_ClearWindow();
                IdUs.US_Print(" Page #");
                IdUs.US_PrintUnsigned((uint)i);

                if (i < WL_Globals.PMSpriteStart)
                    IdUs.US_Print(" (Wall)");
                else if (i < WL_Globals.PMSoundStart)
                    IdUs.US_Print(" (Sprite)");
                else
                    IdUs.US_Print(" (Sound)");

                IdVl.VL_UpdateScreen();

                WL_Globals.LastScan = ScanCodes.sc_None;
                while (WL_Globals.LastScan == ScanCodes.sc_None)
                {
                    IdIn.IN_ProcessEvents();
                    IdSd.SD_Poll();
                    SDL.SDL_Delay(5);
                }

                byte scan = WL_Globals.LastScan;
                if (scan < WL_Globals.Keyboard.Length) { WL_Globals.Keyboard[scan] = false; if (scan == WL_Globals.LastScan) WL_Globals.LastScan = ScanCodes.sc_None; }

                switch (scan)
                {
                    case ScanCodes.sc_LeftArrow:
                        if (i > 0) i--;
                        break;
                    case ScanCodes.sc_RightArrow:
                        if (i + 1 < WL_Globals.ChunksInFile) i++;
                        break;
                    case ScanCodes.sc_W:
                        i = 0;
                        break;
                    case ScanCodes.sc_S:
                        i = WL_Globals.PMSpriteStart;
                        break;
                    case ScanCodes.sc_D:
                        i = WL_Globals.PMSoundStart;
                        break;
                    case ScanCodes.sc_Escape:
                        done = true;
                        break;
                }
            }

            IdSd.SD_StopDigitized();
        }
    }
}
