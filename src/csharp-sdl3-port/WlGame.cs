// WL_GAME.C -> WlGame.cs
// Game level setup, game loop, save/load

using System;

namespace Wolf3D
{
    public static class WlGame
    {
        // =========================================================================
        //  ClearMemory
        // =========================================================================

        public static void ClearMemory()
        {
            IdSd.SD_StopDigitized();
            IdPm.PM_NextFrame();
        }

        // =========================================================================
        //  ScanInfoPlane
        // =========================================================================

        public static void ScanInfoPlane()
        {
            // Scan the second map plane for actors/items
            if (WL_Globals.mapsegs[1] == null) return;

            for (int y = 0; y < WL_Globals.mapheight; y++)
            {
                for (int x = 0; x < WL_Globals.mapwidth; x++)
                {
                    int tile = WolfMacros.MAPSPOT(x, y, 1);
                    if (tile == 0) continue;

                    switch (tile)
                    {
                        case 19:
                        case 20:
                        case 21:
                        case 22:
                            WlAgent.SpawnPlayer(x, y, (tile - 19) * 90);
                            break;
                        // Static objects (23-70)
                        default:
                            if (tile >= 23 && tile < 71)
                                WlAct1.SpawnStatic(x, y, tile - 23);
                            else if (tile >= 90 && tile <= 101)
                                WlAct1.SpawnDoor(x, y, (tile & 1) != 0, tile / 2 - 45);
                            else if (tile >= 108 && tile <= 143)
                                SpawnEnemy(tile, x, y);
                            break;
                    }
                }
            }
        }

        private static void SpawnEnemy(int tile, int x, int y)
        {
            // Spawn enemies based on tile value
            int dir = tile >= 144 ? (tile - 144) % 4 : 0;
            // Simplified - would need full enemy spawn logic
        }

        // =========================================================================
        //  SetupGameLevel
        // =========================================================================

        public static void SetupGameLevel()
        {
            int mapnum = WL_Globals.gamestate.mapon;

            // Load the map
            IdCa.CA_CacheMap(mapnum);

            if (WL_Globals.mapsegs[0] == null) return;

            // Set map dimensions (always 64x64)
            WL_Globals.mapwidth = WolfConstants.MAPSIZE;
            WL_Globals.mapheight = WolfConstants.MAPSIZE;

            // Set up y lookup table
            for (int y = 0; y < WolfConstants.MAPSIZE; y++)
                WL_Globals.farmapylookup[y] = y * WL_Globals.mapwidth;

            // Clear tile and actor maps
            Array.Clear(WL_Globals.tilemap, 0, WL_Globals.tilemap.Length);
            Array.Clear(WL_Globals.spotvis, 0, WL_Globals.spotvis.Length);

            // Initialize object and static lists
            WlPlay.InitActorList();
            WlAct1.InitDoorList();
            WlAct1.InitStaticList();
            WlAct1.InitAreas();

            // Scan the first map plane for walls and doors
            for (int y = 0; y < WL_Globals.mapheight; y++)
            {
                for (int x = 0; x < WL_Globals.mapwidth; x++)
                {
                    int tile = WolfMacros.MAPSPOT(x, y, 0);
                    if (tile >= 1 && tile < 64)
                    {
                        // Wall tile
                        WL_Globals.tilemap[x, y] = (byte)tile;
                    }
                    else if (tile >= 90 && tile <= 101)
                    {
                        // Door
                        WlAct1.SpawnDoor(x, y, (tile & 1) != 0, tile / 2 - 45);
                    }
                }
            }

            // Scan info plane for actors
            ScanInfoPlane();
        }

        // =========================================================================
        //  GameLoop
        // =========================================================================

        public static void GameLoop()
        {
            WL_Globals.restartgame = GameDiff.gd_Continue;

            if (WL_Globals.loadedgame)
            {
                // Loaded game
                WL_Globals.loadedgame = false;
            }
            else
            {
                // New game
            }

            WL_Globals.ingame = true;

            while (true)
            {
                // Set up level
                SetupGameLevel();
                WL_Globals.ingame = true;

                // Draw play screen
                DrawPlayScreen();

                WL_Globals.startgame = false;
                WL_Globals.playstate = exit_t.ex_stillplaying;

                // Pre-load graphics
                if (!WL_Globals.loadedgame)
                    WlInter.PreloadGraphics();

                // Fizzle in if needed
                WL_Globals.fizzlein = true;

                // Play the level
                WlPlay.PlayLoop();

                // Handle exit state
                WL_Globals.ingame = false;

                switch (WL_Globals.playstate)
                {
                    case exit_t.ex_died:
                        WL_Globals.gamestate.lives--;
                        if (WL_Globals.gamestate.lives < 0)
                        {
                            // Game over
                            return;
                        }
                        break;

                    case exit_t.ex_completed:
                    case exit_t.ex_secretlevel:
                        WlInter.LevelCompleted();
                        WL_Globals.gamestate.mapon++;
                        break;

                    case exit_t.ex_warped:
                        break;

                    case exit_t.ex_abort:
                    case exit_t.ex_resetgame:
                    case exit_t.ex_demodone:
                        return;

                    case exit_t.ex_victorious:
                        WlInter.Victory();
                        return;
                }
            }
        }

        // =========================================================================
        //  DrawPlayScreen
        // =========================================================================

        public static void DrawPlayScreen()
        {
            // Clear screen
            IdVl.VL_Bar(0, 0, 320, 200 - WolfConstants.STATUSLINES, 0);

            // Draw status bar
            if (WL_Globals.grsegs[(int)graphicnums.STATUSBARPIC] != null)
            {
                IdVh.VWB_DrawPic(0, 200 - WolfConstants.STATUSLINES, (int)graphicnums.STATUSBARPIC);
            }

            // Draw level info
            WlAgent.DrawFace();
            WlAgent.DrawHealth();
            WlAgent.DrawLives();
            WlAgent.DrawLevel();
            WlAgent.DrawAmmo();
            WlAgent.DrawKeys();
            WlAgent.DrawWeapon();
            WlAgent.DrawScore();
        }

        public static void DrawPlayBorder()
        {
            // Draw play area border
        }

        public static void DrawAllPlayBorder()
        {
            DrawPlayBorder();
        }

        public static void DrawAllPlayBorderSides()
        {
        }

        // =========================================================================
        //  Sound localization
        // =========================================================================

        public static void PlaySoundLocGlobal(int s, int gx, int gy)
        {
            IdSd.SD_PlaySound((soundnames)s);
        }

        public static void UpdateSoundLoc()
        {
            // Update sound source positions
        }

        // =========================================================================
        //  Fizzle / music helpers
        // =========================================================================

        public static void FizzleOut()
        {
            IdVh.FizzleFade(0, 0, 320, 200, 70, false);
        }

        public static void NormalScreen()
        {
            // Restore normal screen settings
        }

        // =========================================================================
        //  Demo
        // =========================================================================

        public static void PlayDemo(int demonumber)
        {
            // Demo playback - stub
        }

        public static void RecordDemo()
        {
            // Demo recording - stub
        }

        public static void DrawHighScores()
        {
            IdUs.US_DisplayHighScores(-1);
        }
    }
}
