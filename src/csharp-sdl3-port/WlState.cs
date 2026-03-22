// WL_STATE.C -> WlState.cs
// Actor state machine, movement, collision - full implementation

using System;

namespace Wolf3D
{
    public static class WlState
    {
        public static readonly dirtype[] opposite = {
            dirtype.west, dirtype.southwest, dirtype.south, dirtype.southeast,
            dirtype.east, dirtype.northeast, dirtype.north, dirtype.northwest,
            dirtype.nodir
        };

        public static readonly dirtype[,] diagonal = {
            // east
            {dirtype.nodir,dirtype.nodir,dirtype.northeast,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.southeast,dirtype.nodir,dirtype.nodir},
            {dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir},
            // north
            {dirtype.northeast,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.northwest,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir},
            {dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir},
            // west
            {dirtype.nodir,dirtype.nodir,dirtype.northwest,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.southwest,dirtype.nodir,dirtype.nodir},
            {dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir},
            // south
            {dirtype.southeast,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.southwest,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir},
            {dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir},
            {dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir,dirtype.nodir}
        };

        // =========================================================================
        //  InitHitRect
        // =========================================================================

        public static void InitHitRect(objtype ob, int radius)
        {
            // Collision rect based on radius - stored implicitly via tilex/tiley
        }

        // =========================================================================
        //  SpawnNewObj
        // =========================================================================

        public static void SpawnNewObj(int tilex, int tiley, statetype state)
        {
            WlPlay.GetNewActor();
            WL_Globals.new_.state = state;
            if (state != null && state.tictime != 0)
                WL_Globals.new_.ticcount = IdUs.US_RndT() % state.tictime;
            else
                WL_Globals.new_.ticcount = 0;

            WL_Globals.new_.tilex = tilex;
            WL_Globals.new_.tiley = tiley;
            WL_Globals.new_.x = (tilex << WolfConstants.TILESHIFT) + WolfConstants.TILEGLOBAL / 2;
            WL_Globals.new_.y = (tiley << WolfConstants.TILESHIFT) + WolfConstants.TILEGLOBAL / 2;
            WL_Globals.new_.dir = dirtype.nodir;
            WL_Globals.new_.active = activetype.ac_no;

            WL_Globals.actorat[tilex, tiley] = WL_Globals.new_;

            // Set area number
            if (WL_Globals.mapsegs[0] != null)
            {
                int mapIdx = WL_Globals.farmapylookup[tiley] + tilex;
                if (mapIdx >= 0 && mapIdx < WL_Globals.mapsegs[0].Length)
                {
                    int area = WL_Globals.mapsegs[0][mapIdx] - WolfConstants.AREATILE;
                    if (area >= 0 && area < WolfConstants.NUMAREAS)
                        WL_Globals.new_.areanumber = (byte)area;
                }
            }
        }

        // =========================================================================
        //  NewState
        // =========================================================================

        public static void NewState(objtype ob, statetype state)
        {
            ob.state = state;
            if (state != null)
                ob.ticcount = state.tictime;
        }

        // =========================================================================
        //  TryWalk - attempt to move actor in its current direction
        // =========================================================================

        public static bool TryWalk(objtype ob)
        {
            int doornum = -1;

            if (ob.obclass == classtype.inertobj)
            {
                switch (ob.dir)
                {
                    case dirtype.north: ob.tiley--; break;
                    case dirtype.northeast: ob.tilex++; ob.tiley--; break;
                    case dirtype.east: ob.tilex++; break;
                    case dirtype.southeast: ob.tilex++; ob.tiley++; break;
                    case dirtype.south: ob.tiley++; break;
                    case dirtype.southwest: ob.tilex--; ob.tiley++; break;
                    case dirtype.west: ob.tilex--; break;
                    case dirtype.northwest: ob.tilex--; ob.tiley--; break;
                }

                if (ob.tilex >= 0 && ob.tilex < WolfConstants.MAPSIZE &&
                    ob.tiley >= 0 && ob.tiley < WolfConstants.MAPSIZE)
                    ob.distance = WolfConstants.TILEGLOBAL;
                return true;
            }

            int dx = 0, dy = 0;
            switch (ob.dir)
            {
                case dirtype.north: dy = -1; break;
                case dirtype.east: dx = 1; break;
                case dirtype.south: dy = 1; break;
                case dirtype.west: dx = -1; break;
                case dirtype.northeast: dx = 1; dy = -1; break;
                case dirtype.northwest: dx = -1; dy = -1; break;
                case dirtype.southeast: dx = 1; dy = 1; break;
                case dirtype.southwest: dx = -1; dy = 1; break;
            }

            int tilex = ob.tilex + dx;
            int tiley = ob.tiley + dy;

            if (tilex < 0 || tilex >= WolfConstants.MAPSIZE || tiley < 0 || tiley >= WolfConstants.MAPSIZE)
                return false;

            // Check for walls/doors
            int tileVal = WL_Globals.tilemap[tilex, tiley];
            if (tileVal != 0)
            {
                if (tileVal < 128)
                    return false; // solid wall

                if (tileVal < 256)
                {
                    // Door
                    doornum = tileVal & 63;
                }
            }

            // Check for blocking actors
            if (WL_Globals.actorat[tilex, tiley] != null)
            {
                var blockobj = WL_Globals.actorat[tilex, tiley];
                if ((blockobj.flags & WolfConstants.FL_SHOOTABLE) != 0)
                    return false;
            }

            // For diagonal moves, check both adjacent sides
            if (dx != 0 && dy != 0)
            {
                if (WL_Globals.tilemap[ob.tilex + dx, ob.tiley] != 0)
                    return false;
                if (WL_Globals.tilemap[ob.tilex, ob.tiley + dy] != 0)
                    return false;
            }

            ob.tilex = tilex;
            ob.tiley = tiley;

            if (doornum != -1)
            {
                WlAct1.OpenDoor(doornum);
                ob.distance = -doornum - 1;
            }
            else
            {
                ob.distance = WolfConstants.TILEGLOBAL;
            }

            return true;
        }

        // =========================================================================
        //  SelectChaseDir
        // =========================================================================

        public static void SelectChaseDir(objtype ob)
        {
            int deltax = WL_Globals.player.tilex - ob.tilex;
            int deltay = WL_Globals.player.tiley - ob.tiley;

            dirtype d1, d2;
            dirtype tdir;

            if (deltax > 0) d1 = dirtype.east;
            else if (deltax < 0) d1 = dirtype.west;
            else d1 = dirtype.nodir;

            if (deltay > 0) d2 = dirtype.south;
            else if (deltay < 0) d2 = dirtype.north;
            else d2 = dirtype.nodir;

            if (Math.Abs(deltay) > Math.Abs(deltax))
            {
                tdir = d1; d1 = d2; d2 = tdir;
            }

            if (d1 != dirtype.nodir)
            {
                ob.dir = d1;
                if (TryWalk(ob)) return;
            }

            if (d2 != dirtype.nodir)
            {
                ob.dir = d2;
                if (TryWalk(ob)) return;
            }

            // Try other directions
            if (IdUs.US_RndT() > 128)
            {
                for (tdir = dirtype.north; tdir <= dirtype.west; tdir++)
                {
                    ob.dir = tdir;
                    if (TryWalk(ob)) return;
                }
            }
            else
            {
                for (tdir = dirtype.west; tdir >= dirtype.north; tdir--)
                {
                    ob.dir = tdir;
                    if (TryWalk(ob)) return;
                }
            }

            ob.dir = dirtype.nodir;
        }

        public static void SelectDodgeDir(objtype ob)
        {
            SelectChaseDir(ob);
        }

        public static void SelectRunDir(objtype ob)
        {
            int deltax = WL_Globals.player.tilex - ob.tilex;
            int deltay = WL_Globals.player.tiley - ob.tiley;

            // Run away
            if (deltax > 0) ob.dir = dirtype.west;
            else if (deltax < 0) ob.dir = dirtype.east;
            else if (deltay > 0) ob.dir = dirtype.north;
            else if (deltay < 0) ob.dir = dirtype.south;

            if (TryWalk(ob)) return;

            // Try other directions
            for (dirtype tdir = dirtype.north; tdir <= dirtype.west; tdir++)
            {
                ob.dir = tdir;
                if (TryWalk(ob)) return;
            }

            ob.dir = dirtype.nodir;
        }

        // =========================================================================
        //  MoveObj
        // =========================================================================

        public static void MoveObj(objtype ob, int move)
        {
            if (ob.dir == dirtype.nodir || move == 0) return;

            switch (ob.dir)
            {
                case dirtype.north: ob.y -= move; break;
                case dirtype.east: ob.x += move; break;
                case dirtype.south: ob.y += move; break;
                case dirtype.west: ob.x -= move; break;
                case dirtype.northeast: ob.x += move; ob.y -= move; break;
                case dirtype.northwest: ob.x -= move; ob.y -= move; break;
                case dirtype.southeast: ob.x += move; ob.y += move; break;
                case dirtype.southwest: ob.x -= move; ob.y += move; break;
            }

            ob.tilex = ob.x >> WolfConstants.TILESHIFT;
            ob.tiley = ob.y >> WolfConstants.TILESHIFT;

            ob.distance -= move;
        }

        // =========================================================================
        //  CheckLine - check line of sight from ob to player using tile raycasting
        // =========================================================================

        public static bool CheckLine(objtype ob)
        {
            int x1 = ob.tilex;
            int y1 = ob.tiley;
            int x2 = WL_Globals.player.tilex;
            int y2 = WL_Globals.player.tiley;

            int dx = Math.Abs(x2 - x1);
            int dy = Math.Abs(y2 - y1);
            int sx = x1 < x2 ? 1 : -1;
            int sy = y1 < y2 ? 1 : -1;

            // Bresenham line algorithm through tilemap
            int err = dx - dy;
            int cx = x1, cy = y1;

            while (cx != x2 || cy != y2)
            {
                int e2 = 2 * err;
                if (e2 > -dy) { err -= dy; cx += sx; }
                if (e2 < dx) { err += dx; cy += sy; }

                if (cx == x2 && cy == y2) break;

                if (cx < 0 || cx >= WolfConstants.MAPSIZE || cy < 0 || cy >= WolfConstants.MAPSIZE)
                    return false;

                byte tile = WL_Globals.tilemap[cx, cy];
                if (tile != 0)
                {
                    if ((tile & 0x80) != 0)
                    {
                        // Door - check if open
                        int doornum = tile & 0x7f;
                        if ((tile & 0x40) != 0) return false; // pushwall blocks
                        if (doornum >= 0 && doornum < WolfConstants.MAXDOORS &&
                            WL_Globals.doorposition[doornum] < 0x8000)
                            return false; // door not open enough
                    }
                    else
                        return false; // solid wall
                }
            }

            return true;
        }

        // =========================================================================
        //  SightPlayer
        // =========================================================================

        public static bool SightPlayer(objtype ob)
        {
            if ((ob.flags & WolfConstants.FL_ATTACKMODE) != 0)
                return true; // already chasing

            // Area check - player must be in same or connected area
            if (ob.areanumber >= 0 && ob.areanumber < WolfConstants.NUMAREAS)
            {
                if (!WL_Globals.areabyplayer[ob.areanumber])
                    return false;
            }

            // Range check
            int dx = Math.Abs(WL_Globals.player.tilex - ob.tilex);
            int dy = Math.Abs(WL_Globals.player.tiley - ob.tiley);
            if (dx > 15 || dy > 15) return false;

            return CheckLine(ob);
        }

        public static bool CheckSight(objtype ob)
        {
            return CheckLine(ob);
        }

        // =========================================================================
        //  FirstSighting
        // =========================================================================

        public static void FirstSighting(objtype ob)
        {
            ob.flags |= WolfConstants.FL_ATTACKMODE | WolfConstants.FL_FIRSTATTACK;
        }

        // =========================================================================
        //  Damage
        // =========================================================================

        public static void KillActor(objtype ob)
        {
            ob.flags &= unchecked((byte)~WolfConstants.FL_SHOOTABLE);
            ob.flags |= WolfConstants.FL_NONMARK;
            ob.active = activetype.ac_no;

            // Switch to death state based on class
            switch (ob.obclass)
            {
                case classtype.guardobj:
                    NewState(ob, WlAct2.s_grddie1);
                    break;
                case classtype.officerobj:
                    NewState(ob, WlAct2.s_ofcdie1);
                    break;
                case classtype.ssobj:
                    NewState(ob, WlAct2.s_ssdie1);
                    break;
                case classtype.dogobj:
                    NewState(ob, WlAct2.s_dogdie1);
                    break;
                case classtype.mutantobj:
                    NewState(ob, WlAct2.s_mutdie1);
                    break;
                case classtype.bossobj:
                    NewState(ob, WlAct2.s_bossdie1);
                    break;
                default:
                    NewState(ob, WlAct2.s_grddie1);
                    break;
            }

            WL_Globals.gamestate.killcount++;
            ob.flags &= unchecked((byte)~WolfConstants.FL_ATTACKMODE);

            WlAct2.A_DeathScream(ob);
        }

        public static void DamageActor(objtype ob, int damage)
        {
            ob.hitpoints -= damage;
            if (ob.hitpoints <= 0)
            {
                KillActor(ob);
            }
            else
            {
                // Switch to pain state if available
                if ((ob.flags & WolfConstants.FL_ATTACKMODE) == 0)
                    FirstSighting(ob);

                switch (ob.obclass)
                {
                    case classtype.guardobj:
                        NewState(ob, WlAct2.s_grdpain);
                        break;
                    case classtype.officerobj:
                        NewState(ob, WlAct2.s_ofcpain);
                        break;
                    case classtype.ssobj:
                        NewState(ob, WlAct2.s_sspain);
                        break;
                    case classtype.mutantobj:
                        NewState(ob, WlAct2.s_mutpain);
                        break;
                    default:
                        break;
                }
            }
        }
    }
}
