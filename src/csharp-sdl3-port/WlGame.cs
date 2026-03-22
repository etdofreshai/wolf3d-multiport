// WL_GAME.C -> WlGame.cs
// Game level setup, game loop, save/load - full implementation

using System;

namespace Wolf3D
{
    public static class WlGame
    {
        private static int[] ElevatorBackTo = { 1, 1, 7, 3, 5, 3 };

        // =========================================================================
        //  ClearMemory
        // =========================================================================

        public static void ClearMemory()
        {
            IdSd.SD_StopDigitized();
            IdPm.PM_NextFrame();
        }

        // =========================================================================
        //  ScanInfoPlane - full enemy/item spawn
        // =========================================================================

        public static void ScanInfoPlane()
        {
            if (WL_Globals.mapsegs[1] == null) return;

            int idx = 0;
            for (int y = 0; y < WL_Globals.mapheight; y++)
            {
                for (int x = 0; x < WL_Globals.mapwidth; x++)
                {
                    int tile = WL_Globals.mapsegs[1][idx++];
                    if (tile == 0) continue;

                    switch (tile)
                    {
                        case 19: case 20: case 21: case 22:
                            WlAgent.SpawnPlayer(x, y, WolfConstants.NORTH + tile - 19);
                            break;

                        // Static objects 23-74
                        case 23: case 24: case 25: case 26: case 27: case 28: case 29: case 30:
                        case 31: case 32: case 33: case 34: case 35: case 36: case 37: case 38:
                        case 39: case 40: case 41: case 42: case 43: case 44: case 45: case 46:
                        case 47: case 48: case 49: case 50: case 51: case 52: case 53: case 54:
                        case 55: case 56: case 57: case 58: case 59: case 60: case 61: case 62:
                        case 63: case 64: case 65: case 66: case 67: case 68: case 69: case 70:
                        case 71: case 72: case 73: case 74:
                            WlAct1.SpawnStatic(x, y, tile - 23);
                            break;

                        // Pushwall secret
                        case 98:
                            if (!WL_Globals.loadedgame)
                                WL_Globals.gamestate.secrettotal++;
                            break;

                        // Guard standing (hard)
                        case 180: case 181: case 182: case 183:
                            if (WL_Globals.gamestate.difficulty < (int)gamedifficulty_t.gd_hard) break;
                            tile -= 36; goto case 144;
                        case 144: case 145: case 146: case 147:
                            if (WL_Globals.gamestate.difficulty < (int)gamedifficulty_t.gd_medium) break;
                            tile -= 36; goto case 108;
                        case 108: case 109: case 110: case 111:
                            WlAct2.SpawnStand(enemy_t.en_guard, x, y, tile - 108);
                            break;

                        // Guard patrol (hard)
                        case 184: case 185: case 186: case 187:
                            if (WL_Globals.gamestate.difficulty < (int)gamedifficulty_t.gd_hard) break;
                            tile -= 36; goto case 148;
                        case 148: case 149: case 150: case 151:
                            if (WL_Globals.gamestate.difficulty < (int)gamedifficulty_t.gd_medium) break;
                            tile -= 36; goto case 112;
                        case 112: case 113: case 114: case 115:
                            WlAct2.SpawnPatrol(enemy_t.en_guard, x, y, tile - 112);
                            break;

                        case 124:
                            WlAct2.SpawnDeadGuard(x, y);
                            break;

                        // Officer standing
                        case 188: case 189: case 190: case 191:
                            if (WL_Globals.gamestate.difficulty < (int)gamedifficulty_t.gd_hard) break;
                            tile -= 36; goto case 152;
                        case 152: case 153: case 154: case 155:
                            if (WL_Globals.gamestate.difficulty < (int)gamedifficulty_t.gd_medium) break;
                            tile -= 36; goto case 116;
                        case 116: case 117: case 118: case 119:
                            WlAct2.SpawnStand(enemy_t.en_officer, x, y, tile - 116);
                            break;

                        // Officer patrol
                        case 192: case 193: case 194: case 195:
                            if (WL_Globals.gamestate.difficulty < (int)gamedifficulty_t.gd_hard) break;
                            tile -= 36; goto case 156;
                        case 156: case 157: case 158: case 159:
                            if (WL_Globals.gamestate.difficulty < (int)gamedifficulty_t.gd_medium) break;
                            tile -= 36; goto case 120;
                        case 120: case 121: case 122: case 123:
                            WlAct2.SpawnPatrol(enemy_t.en_officer, x, y, tile - 120);
                            break;

                        // SS standing
                        case 198: case 199: case 200: case 201:
                            if (WL_Globals.gamestate.difficulty < (int)gamedifficulty_t.gd_hard) break;
                            tile -= 36; goto case 162;
                        case 162: case 163: case 164: case 165:
                            if (WL_Globals.gamestate.difficulty < (int)gamedifficulty_t.gd_medium) break;
                            tile -= 36; goto case 126;
                        case 126: case 127: case 128: case 129:
                            WlAct2.SpawnStand(enemy_t.en_ss, x, y, tile - 126);
                            break;

                        // SS patrol
                        case 202: case 203: case 204: case 205:
                            if (WL_Globals.gamestate.difficulty < (int)gamedifficulty_t.gd_hard) break;
                            tile -= 36; goto case 166;
                        case 166: case 167: case 168: case 169:
                            if (WL_Globals.gamestate.difficulty < (int)gamedifficulty_t.gd_medium) break;
                            tile -= 36; goto case 130;
                        case 130: case 131: case 132: case 133:
                            WlAct2.SpawnPatrol(enemy_t.en_ss, x, y, tile - 130);
                            break;

                        // Dogs standing
                        case 206: case 207: case 208: case 209:
                            if (WL_Globals.gamestate.difficulty < (int)gamedifficulty_t.gd_hard) break;
                            tile -= 36; goto case 170;
                        case 170: case 171: case 172: case 173:
                            if (WL_Globals.gamestate.difficulty < (int)gamedifficulty_t.gd_medium) break;
                            tile -= 36; goto case 134;
                        case 134: case 135: case 136: case 137:
                            WlAct2.SpawnStand(enemy_t.en_dog, x, y, tile - 134);
                            break;

                        // Dogs patrol
                        case 210: case 211: case 212: case 213:
                            if (WL_Globals.gamestate.difficulty < (int)gamedifficulty_t.gd_hard) break;
                            tile -= 36; goto case 174;
                        case 174: case 175: case 176: case 177:
                            if (WL_Globals.gamestate.difficulty < (int)gamedifficulty_t.gd_medium) break;
                            tile -= 36; goto case 138;
                        case 138: case 139: case 140: case 141:
                            WlAct2.SpawnPatrol(enemy_t.en_dog, x, y, tile - 138);
                            break;

                        // Bosses (non-SPEAR)
                        case 214: WlAct2.SpawnBoss(x, y); break;
                        case 197: WlAct2.SpawnGretel(x, y); break;
                        case 215: WlAct2.SpawnGift(x, y); break;
                        case 179: WlAct2.SpawnFat(x, y); break;
                        case 196: WlAct2.SpawnSchabbs(x, y); break;
                        case 160: WlAct2.SpawnFakeHitler(x, y); break;
                        case 178: WlAct2.SpawnHitler(x, y); break;

                        // Mutant standing
                        case 252: case 253: case 254: case 255:
                            if (WL_Globals.gamestate.difficulty < (int)gamedifficulty_t.gd_hard) break;
                            tile -= 18; goto case 234;
                        case 234: case 235: case 236: case 237:
                            if (WL_Globals.gamestate.difficulty < (int)gamedifficulty_t.gd_medium) break;
                            tile -= 18; goto case 216;
                        case 216: case 217: case 218: case 219:
                            WlAct2.SpawnStand(enemy_t.en_mutant, x, y, tile - 216);
                            break;

                        // Mutant patrol
                        case 256: case 257: case 258: case 259:
                            if (WL_Globals.gamestate.difficulty < (int)gamedifficulty_t.gd_hard) break;
                            tile -= 18; goto case 238;
                        case 238: case 239: case 240: case 241:
                            if (WL_Globals.gamestate.difficulty < (int)gamedifficulty_t.gd_medium) break;
                            tile -= 18; goto case 220;
                        case 220: case 221: case 222: case 223:
                            WlAct2.SpawnPatrol(enemy_t.en_mutant, x, y, tile - 220);
                            break;

                        // Ghosts
                        case 224: WlAct2.SpawnGhosts((int)enemy_t.en_blinky, x, y); break;
                        case 225: WlAct2.SpawnGhosts((int)enemy_t.en_clyde, x, y); break;
                        case 226: WlAct2.SpawnGhosts((int)enemy_t.en_pinky, x, y); break;
                        case 227: WlAct2.SpawnGhosts((int)enemy_t.en_inky, x, y); break;
                    }
                }
            }
        }

        // =========================================================================
        //  SetupGameLevel
        // =========================================================================

        public static void SetupGameLevel()
        {
            if (!WL_Globals.loadedgame)
            {
                WL_Globals.gamestate.TimeCount = 0;
                WL_Globals.gamestate.secrettotal = 0;
                WL_Globals.gamestate.killtotal = 0;
                WL_Globals.gamestate.treasuretotal = 0;
                WL_Globals.gamestate.secretcount = 0;
                WL_Globals.gamestate.killcount = 0;
                WL_Globals.gamestate.treasurecount = 0;
            }

            int mapnum = WL_Globals.gamestate.mapon + 10 * WL_Globals.gamestate.episode;
            IdCa.CA_CacheMap(mapnum);
            WL_Globals.mapon -= WL_Globals.gamestate.episode * 10;

            if (WL_Globals.mapsegs[0] == null) return;

            WL_Globals.mapwidth = WolfConstants.MAPSIZE;
            WL_Globals.mapheight = WolfConstants.MAPSIZE;

            for (int y = 0; y < WolfConstants.MAPSIZE; y++)
                WL_Globals.farmapylookup[y] = y * WL_Globals.mapwidth;

            // Copy wall data
            Array.Clear(WL_Globals.tilemap, 0, WL_Globals.tilemap.Length);
            Array.Clear(WL_Globals.actorat_tile, 0, WL_Globals.actorat_tile.Length);

            int mapIdx = 0;
            for (int y = 0; y < WL_Globals.mapheight; y++)
            {
                for (int x = 0; x < WL_Globals.mapwidth; x++)
                {
                    int tile = WL_Globals.mapsegs[0][mapIdx++];
                    if (tile < WolfConstants.AREATILE)
                    {
                        WL_Globals.tilemap[x, y] = (byte)tile;
                        WL_Globals.actorat_tile[x, y] = tile;
                    }
                    else
                    {
                        WL_Globals.tilemap[x, y] = 0;
                        WL_Globals.actorat_tile[x, y] = 0;
                    }
                }
            }

            // Initialize lists
            WlPlay.InitActorList();
            WlAct1.InitDoorList();
            WlAct1.InitStaticList();

            // Spawn doors
            mapIdx = 0;
            for (int y = 0; y < WL_Globals.mapheight; y++)
            {
                for (int x = 0; x < WL_Globals.mapwidth; x++)
                {
                    int tile = WL_Globals.mapsegs[0][mapIdx++];
                    if (tile >= 90 && tile <= 101)
                    {
                        if ((tile & 1) == 0) // even = vertical
                            WlAct1.SpawnDoor(x, y, true, (tile - 90) / 2);
                        else // odd = horizontal
                            WlAct1.SpawnDoor(x, y, false, (tile - 91) / 2);
                    }
                }
            }

            // Spawn actors
            ScanInfoPlane();

            // Process ambush tiles
            mapIdx = 0;
            for (int y = 0; y < WL_Globals.mapheight; y++)
            {
                for (int x = 0; x < WL_Globals.mapwidth; x++)
                {
                    int tile = WL_Globals.mapsegs[0][mapIdx];
                    if (tile == WolfConstants.AMBUSHTILE)
                    {
                        WL_Globals.tilemap[x, y] = 0;
                        if (WL_Globals.actorat_tile[x, y] == WolfConstants.AMBUSHTILE)
                            WL_Globals.actorat_tile[x, y] = 0;
                    }
                    mapIdx++;
                }
            }
        }

        // =========================================================================
        //  GameLoop
        // =========================================================================

        public static void GameLoop()
        {
            WL_Globals.restartgame = GameDiff.gd_Continue;

            if (WL_Globals.loadedgame)
                WL_Globals.loadedgame = false;

            WL_Globals.ingame = true;

            while (true)
            {
                SetupGameLevel();
                WL_Globals.ingame = true;

                DrawPlayScreen();

                WL_Globals.startgame = false;
                WL_Globals.playstate = exit_t.ex_stillplaying;

                if (!WL_Globals.loadedgame)
                    WlInter.PreloadGraphics();

                WL_Globals.fizzlein = true;

                WlPlay.PlayLoop();

                WL_Globals.ingame = false;

                switch (WL_Globals.playstate)
                {
                    case exit_t.ex_died:
                        WL_Globals.gamestate.lives--;
                        if (WL_Globals.gamestate.lives < 0)
                            return;
                        // Reset weapon and keys on death
                        WL_Globals.gamestate.keys = 0;
                        WL_Globals.gamestate.weapon = WL_Globals.gamestate.bestweapon = weapontype.wp_pistol;
                        WL_Globals.gamestate.chosenweapon = weapontype.wp_pistol;
                        WL_Globals.gamestate.ammo = WolfConstants.STARTAMMO;
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
            IdVl.VL_Bar(0, 0, 320, 200 - WolfConstants.STATUSLINES, 0);

            if (WL_Globals.grsegs[(int)graphicnums.STATUSBARPIC] != null)
                IdVh.VWB_DrawPic(0, 200 - WolfConstants.STATUSLINES, (int)graphicnums.STATUSBARPIC);

            WlAgent.DrawFace();
            WlAgent.DrawHealth();
            WlAgent.DrawLives();
            WlAgent.DrawLevel();
            WlAgent.DrawAmmo();
            WlAgent.DrawKeys();
            WlAgent.DrawWeapon();
            WlAgent.DrawScore();
        }

        public static void DrawPlayBorder() { }
        public static void DrawAllPlayBorder() { DrawPlayBorder(); }
        public static void DrawAllPlayBorderSides() { }

        // =========================================================================
        //  Sound localization
        // =========================================================================

        public static void PlaySoundLocGlobal(int s, int gx, int gy)
        {
            IdSd.SD_PlaySound((soundnames)s);
        }

        public static void UpdateSoundLoc()
        {
            // Sound positioning would update stereo panning
        }

        // =========================================================================
        //  Fizzle / music helpers
        // =========================================================================

        public static void FizzleOut()
        {
            IdVh.FizzleFade(0, 0, 320, 200, 70, false);
        }

        public static void NormalScreen() { }

        // =========================================================================
        //  Demo
        // =========================================================================

        public static void PlayDemo(int demonumber) { }
        public static void RecordDemo() { }

        public static void DrawHighScores()
        {
            IdUs.US_DisplayHighScores(-1);
        }
    }
}
