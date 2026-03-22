// WL_ACT1.C -> WlAct1.cs
// Door, static object, and push wall management

using System;

namespace Wolf3D
{
    public static class WlAct1
    {
        private const int OPENTICS = 300;
        private const int DOORSPEED = 2;

        // =========================================================================
        //  InitDoorList
        // =========================================================================

        public static void InitDoorList()
        {
            WL_Globals.doornum = 0;
            for (int i = 0; i < WolfConstants.MAXDOORS; i++)
                WL_Globals.doorobjlist[i] = new doorobj_t();
            WL_Globals.lastdoorobj = null;
        }

        // =========================================================================
        //  InitStaticList
        // =========================================================================

        public static void InitStaticList()
        {
            for (int i = 0; i < WolfConstants.MAXSTATS; i++)
                WL_Globals.statobjlist[i] = new statobj_t();
            WL_Globals.laststatobj = WL_Globals.statobjlist[0];
        }

        // =========================================================================
        //  InitAreas
        // =========================================================================

        public static void InitAreas()
        {
            Array.Clear(WL_Globals.areaconnect, 0, WL_Globals.areaconnect.Length);
            Array.Clear(WL_Globals.areabyplayer, 0, WL_Globals.areabyplayer.Length);
        }

        // =========================================================================
        //  SpawnStatic
        // =========================================================================

        public static void SpawnStatic(int tilex, int tiley, int type)
        {
            if (WL_Globals.laststatobj == null) return;

            // Find next free static slot
            int slot = 0;
            for (slot = 0; slot < WolfConstants.MAXSTATS; slot++)
            {
                if (WL_Globals.statobjlist[slot].shapenum == 0 ||
                    WL_Globals.statobjlist[slot].shapenum == -1)
                    break;
            }
            if (slot >= WolfConstants.MAXSTATS) return;

            var stat = WL_Globals.statobjlist[slot];
            stat.tilex = (byte)tilex;
            stat.tiley = (byte)tiley;
            stat.shapenum = type + (int)SpriteEnum.SPR_STAT_0;
            stat.flags = 0;
            stat.itemnumber = (byte)type;

            WL_Globals.laststatobj = stat;
        }

        // =========================================================================
        //  SpawnDoor
        // =========================================================================

        public static void SpawnDoor(int tilex, int tiley, bool vertical, int lockType)
        {
            if (WL_Globals.doornum >= WolfConstants.MAXDOORS)
                WlMain.Quit("SpawnDoor: Too many doors!");

            var door = WL_Globals.doorobjlist[WL_Globals.doornum];
            door.tilex = (byte)tilex;
            door.tiley = (byte)tiley;
            door.vertical = vertical;
            door.lock_ = (byte)lockType;
            door.action = dooraction_t.dr_closed;
            door.ticcount = 0;

            WL_Globals.doorposition[WL_Globals.doornum] = 0;
            WL_Globals.tilemap[tilex, tiley] = (byte)(WL_Globals.doornum | 0x80);

            WL_Globals.doornum++;
        }

        // =========================================================================
        //  OpenDoor / OperateDoor
        // =========================================================================

        public static void OpenDoor(int door)
        {
            if (door < 0 || door >= WolfConstants.MAXDOORS) return;
            if (WL_Globals.doorobjlist[door].action == dooraction_t.dr_open)
                return;

            WL_Globals.doorobjlist[door].action = dooraction_t.dr_opening;
            WL_Globals.doorobjlist[door].ticcount = 0;
        }

        public static void OperateDoor(int door)
        {
            if (door < 0 || door >= WolfConstants.MAXDOORS) return;

            var d = WL_Globals.doorobjlist[door];
            if (d.lock_ > 0)
            {
                // Check for key
                if ((WL_Globals.gamestate.keys & (1 << (d.lock_ - 1))) == 0)
                {
                    IdSd.SD_PlaySound(soundnames.NOWAYSND);
                    return;
                }
            }

            switch (d.action)
            {
                case dooraction_t.dr_closed:
                case dooraction_t.dr_closing:
                    OpenDoor(door);
                    break;
            }
        }

        // =========================================================================
        //  MoveDoors
        // =========================================================================

        public static void MoveDoors()
        {
            for (int door = 0; door < WL_Globals.doornum; door++)
            {
                var d = WL_Globals.doorobjlist[door];
                switch (d.action)
                {
                    case dooraction_t.dr_opening:
                        WL_Globals.doorposition[door] += DOORSPEED * WL_Globals.tics;
                        if (WL_Globals.doorposition[door] >= 0xFFFF)
                        {
                            WL_Globals.doorposition[door] = 0xFFFF;
                            d.action = dooraction_t.dr_open;
                            d.ticcount = OPENTICS;
                        }
                        break;

                    case dooraction_t.dr_open:
                        d.ticcount -= WL_Globals.tics;
                        if (d.ticcount <= 0)
                        {
                            d.action = dooraction_t.dr_closing;
                            d.ticcount = 0;
                        }
                        break;

                    case dooraction_t.dr_closing:
                        WL_Globals.doorposition[door] -= DOORSPEED * WL_Globals.tics;
                        if (WL_Globals.doorposition[door] <= 0)
                        {
                            WL_Globals.doorposition[door] = 0;
                            d.action = dooraction_t.dr_closed;
                        }
                        break;
                }
            }
        }

        // =========================================================================
        //  Push walls
        // =========================================================================

        public static void PushWall(int checkx, int checky, int dir)
        {
            if (WL_Globals.pwallstate != 0)
                return;

            WL_Globals.pwallstate = 1;
            WL_Globals.pwallx = checkx;
            WL_Globals.pwally = checky;
            WL_Globals.pwalldir = dir;
            WL_Globals.pwallpos = 0;

            IdSd.SD_PlaySound(soundnames.PUSHWALLSND);
        }

        public static void MovePWalls()
        {
            if (WL_Globals.pwallstate == 0) return;

            WL_Globals.pwallpos += DOORSPEED * WL_Globals.tics;

            if (WL_Globals.pwallpos >= 64)
            {
                WL_Globals.pwallpos = 64;

                // Move wall to next tile
                int dx = 0, dy = 0;
                switch (WL_Globals.pwalldir)
                {
                    case WolfConstants.NORTH: dy = -1; break;
                    case WolfConstants.EAST: dx = 1; break;
                    case WolfConstants.SOUTH: dy = 1; break;
                    case WolfConstants.WEST: dx = -1; break;
                }

                int newx = WL_Globals.pwallx + dx;
                int newy = WL_Globals.pwally + dy;

                if (newx >= 0 && newx < WolfConstants.MAPSIZE &&
                    newy >= 0 && newy < WolfConstants.MAPSIZE)
                {
                    byte tile = WL_Globals.tilemap[WL_Globals.pwallx, WL_Globals.pwally];
                    WL_Globals.tilemap[WL_Globals.pwallx, WL_Globals.pwally] = 0;

                    if (WL_Globals.tilemap[newx, newy] == 0)
                    {
                        WL_Globals.tilemap[newx, newy] = tile;
                        WL_Globals.pwallx = newx;
                        WL_Globals.pwally = newy;
                        WL_Globals.pwallpos = 0;
                        // Continue pushing
                    }
                    else
                    {
                        WL_Globals.tilemap[newx, newy] = tile;
                        WL_Globals.pwallstate = 0;
                    }
                }
                else
                {
                    WL_Globals.pwallstate = 0;
                }
            }
        }

        // =========================================================================
        //  PlaceItemType
        // =========================================================================

        public static void PlaceItemType(int itemtype, int tilex, int tiley)
        {
            SpawnStatic(tilex, tiley, itemtype);
        }
    }
}
