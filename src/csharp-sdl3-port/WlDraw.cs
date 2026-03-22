// WL_DRAW.C + WL_DR_A.C -> WlDraw.cs
// 3D raycasting renderer - full DDA raycaster, wall/door/pushwall rendering

using System;

namespace Wolf3D
{
    public static class WlDraw
    {
        private const int MAXVISABLE = 50;
        private const int DOORWALL = 0; // computed at runtime: PMSpriteStart - 8
        private const int ACTORSIZE = 0x4000;

        private const int DEG90 = 900;
        private const int DEG180 = 1800;
        private const int DEG270 = 2700;
        private const int DEG360 = 3600;

        // Visible sprites
        private struct visobj_t
        {
            public int viewx, viewheight;
            public int shapenum;
        }

        private static visobj_t[] vislist = new visobj_t[MAXVISABLE];
        private static int viscount;

        // Ray tracing variables
        private static int midangle;
        private static int focaltx, focalty, viewtx, viewty;
        private static uint xpartialup, xpartialdown, ypartialup, ypartialdown;
        private static int xtilestep, ytilestep;
        private static long xstep, ystep;
        private static long xintercept, yintercept;
        private static int xtile, ytile;
        private static uint tilehit;
        private static uint pixx;

        // Wall optimization
        private static int lastside;
        private static long lastintercept;
        private static int lasttilehit;

        // ScalePost state
        private static byte[] postsource;
        private static uint postx;
        private static uint postwidth;
        private static uint posttexture;
        private static byte[] postpage;

        // Ceiling colors per level
        private static uint[] vgaCeiling = {
            0x1d1d,0x1d1d,0x1d1d,0x1d1d,0x1d1d,0x1d1d,0x1d1d,0x1d1d,0x1d1d,0xbfbf,
            0x4e4e,0x4e4e,0x4e4e,0x1d1d,0x8d8d,0x4e4e,0x1d1d,0x2d2d,0x1d1d,0x8d8d,
            0x1d1d,0x1d1d,0x1d1d,0x1d1d,0x1d1d,0x2d2d,0xdddd,0x1d1d,0x1d1d,0x9898,
            0x1d1d,0x9d9d,0x2d2d,0xdddd,0xdddd,0x9d9d,0x2d2d,0x4d4d,0x1d1d,0xdddd,
            0x7d7d,0x1d1d,0x2d2d,0x2d2d,0xdddd,0xd7d7,0x1d1d,0x1d1d,0x1d1d,0x2d2d,
            0x1d1d,0x1d1d,0x1d1d,0x1d1d,0xdddd,0xdddd,0x7d7d,0xdddd,0xdddd,0xdddd
        };

        // Weapon sprite table
        private static int[] weaponscale = {
            (int)SpriteEnum.SPR_KNIFEREADY, (int)SpriteEnum.SPR_PISTOLREADY,
            (int)SpriteEnum.SPR_MACHINEGUNREADY, (int)SpriteEnum.SPR_CHAINREADY
        };

        private static int DoorWall
        {
            get { return WL_Globals.PMSpriteStart - 8; }
        }

        // =========================================================================
        //  BuildTables
        // =========================================================================

        public static void BuildTables()
        {
            // Tables built in WlMain.BuildTables and CalcProjection
        }

        // =========================================================================
        //  CalcTics
        // =========================================================================

        public static void CalcTics()
        {
            int newtime;

            if (WL_Globals.lasttimecount > WL_Globals.TimeCount)
                WL_Globals.TimeCount = WL_Globals.lasttimecount;

            do
            {
                newtime = WL_Globals.TimeCount;
                WL_Globals.tics = newtime - WL_Globals.lasttimecount;
                if (WL_Globals.tics == 0)
                {
                    IdIn.IN_ProcessEvents();
                    SDL.SDL_Delay(1);
                }
            } while (WL_Globals.tics == 0);

            WL_Globals.lasttimecount = newtime;

            if (WL_Globals.tics > WolfConstants.MAXTICS)
            {
                WL_Globals.TimeCount -= (WL_Globals.tics - WolfConstants.MAXTICS);
                WL_Globals.tics = WolfConstants.MAXTICS;
            }
        }

        // =========================================================================
        //  FixOfs
        // =========================================================================

        public static void FixOfs()
        {
            IdVl.VL_ScreenToScreen(WL_Globals.displayofs, WL_Globals.bufferofs,
                WL_Globals.viewwidth / 8, WL_Globals.viewheight);
        }

        // =========================================================================
        //  FixedByFrac
        // =========================================================================

        public static int FixedByFrac(int a, int b)
        {
            // b is signed magnitude: bit 15 of high word is sign, low 16 bits are magnitude
            int sign = (b >> 16) & 0x8000;
            ulong ua;
            ulong ub;
            ulong result;

            if (a < 0)
            {
                ua = (ulong)(-(long)a);
                sign ^= 0x8000;
            }
            else
                ua = (ulong)a;

            ub = (ulong)(b & 0xFFFF);

            {
                ulong lo = (ua & 0xFFFF) * ub;
                ulong hi = (ua >> 16) * ub;
                result = hi + (lo >> 16);
            }

            if (sign != 0)
                return -(int)result;
            else
                return (int)result;
        }

        // =========================================================================
        //  TransformActor
        // =========================================================================

        public static void TransformActor(objtype ob)
        {
            int gx, gy, gxt, gyt, nx, ny;
            long temp;

            gx = ob.x - WL_Globals.viewx;
            gy = ob.y - WL_Globals.viewy;

            gxt = FixedByFrac(gx, WL_Globals.viewcos);
            gyt = FixedByFrac(gy, WL_Globals.viewsin);
            nx = gxt - gyt - ACTORSIZE;

            gxt = FixedByFrac(gx, WL_Globals.viewsin);
            gyt = FixedByFrac(gy, WL_Globals.viewcos);
            ny = gyt + gxt;

            ob.transx = nx;
            ob.transy = ny;

            if (nx < WolfConstants.MINDIST)
            {
                ob.viewheight = 0;
                return;
            }

            ob.viewx = WL_Globals.centerx + (int)((long)ny * WL_Globals.scale / nx);

            temp = WL_Globals.heightnumerator / (nx >> 8);
            ob.viewheight = (int)temp;
        }

        // =========================================================================
        //  TransformTile
        // =========================================================================

        public static bool TransformTile(int tx, int ty, out int dispx, out int dispheight)
        {
            int gx, gy, gxt, gyt, nx, ny;
            long temp;

            gx = (tx << WolfConstants.TILESHIFT) + 0x8000 - WL_Globals.viewx;
            gy = (ty << WolfConstants.TILESHIFT) + 0x8000 - WL_Globals.viewy;

            gxt = FixedByFrac(gx, WL_Globals.viewcos);
            gyt = FixedByFrac(gy, WL_Globals.viewsin);
            nx = gxt - gyt - 0x2000;

            gxt = FixedByFrac(gx, WL_Globals.viewsin);
            gyt = FixedByFrac(gy, WL_Globals.viewcos);
            ny = gyt + gxt;

            if (nx < WolfConstants.MINDIST)
            {
                dispx = 0;
                dispheight = 0;
                return false;
            }

            dispx = WL_Globals.centerx + (int)((long)ny * WL_Globals.scale / nx);
            temp = WL_Globals.heightnumerator / (nx >> 8);
            dispheight = (int)temp;

            if (nx < WolfConstants.TILEGLOBAL && ny > -WolfConstants.TILEGLOBAL / 2 && ny < WolfConstants.TILEGLOBAL / 2)
                return true;
            return false;
        }

        // =========================================================================
        //  CalcHeight
        // =========================================================================

        public static int CalcHeight()
        {
            int gxt, gyt, nx;
            long gx, gy;

            gx = xintercept - WL_Globals.viewx;
            gxt = FixedByFrac((int)gx, WL_Globals.viewcos);

            gy = yintercept - WL_Globals.viewy;
            gyt = FixedByFrac((int)gy, WL_Globals.viewsin);

            nx = gxt - gyt;

            if (nx < WolfConstants.MINDIST)
                nx = WolfConstants.MINDIST;

            return (int)(WL_Globals.heightnumerator / (nx >> 8));
        }

        // =========================================================================
        //  ScalePost - draw a vertical wall column
        // =========================================================================

        public static void ScalePost()
        {
            if (postsource == null) return;

            int ht = (int)(WL_Globals.wallheight[postx] >> 3);
            if (ht <= 0) return;

            int viewh = WL_Globals.viewheight;
            int toprow = (viewh - ht) / 2;
            int bottomrow = toprow + ht;
            long fracstep = (64L << 16) / ht;
            long frac = 0;

            if (ht > viewh)
            {
                int skip = (ht - viewh) / 2;
                frac = (long)skip * fracstep;
                toprow = 0;
                bottomrow = viewh;
            }

            int yofs = WL_Globals.screenofs / WolfConstants.SCREENWIDTH;
            int xofs = (WL_Globals.screenofs % WolfConstants.SCREENWIDTH) * 4;

            for (int x = (int)postx; x < (int)(postx + postwidth) && x < WL_Globals.viewwidth; x++)
            {
                long f = frac;
                for (int y = toprow; y < bottomrow; y++)
                {
                    int texel = (int)((f >> 16) & 63);
                    int screeny = y + yofs;
                    int screenx = x + xofs;
                    if (screeny >= 0 && screeny < 200 && screenx >= 0 && screenx < 320)
                    {
                        int srcIdx = (int)posttexture + texel;
                        if (postsource != null && srcIdx >= 0 && srcIdx < postsource.Length)
                            WL_Globals.sdl_screenbuf[screeny * 320 + screenx] = postsource[srcIdx];
                    }
                    f += fracstep;
                }
            }
        }

        public static void FarScalePost()
        {
            ScalePost();
        }

        // =========================================================================
        //  HitVertWall
        // =========================================================================

        private static void HitVertWall()
        {
            int wallpic;
            uint texture;

            texture = (uint)((yintercept >> 4) & 0xfc0);
            if (xtilestep == -1)
            {
                texture = 0xfc0 - texture;
                xintercept += WolfConstants.TILEGLOBAL;
            }
            WL_Globals.wallheight[pixx] = CalcHeight();

            if (lastside == 1 && lastintercept == xtile && lasttilehit == (int)tilehit)
            {
                if (texture == posttexture)
                {
                    postwidth++;
                    WL_Globals.wallheight[pixx] = WL_Globals.wallheight[pixx - 1];
                    return;
                }
                else
                {
                    ScalePost();
                    posttexture = texture;
                    postpage = null; // use postsource directly
                    postwidth = 1;
                    postx = pixx;
                }
            }
            else
            {
                if (lastside != -1)
                    ScalePost();

                lastside = 1;
                lastintercept = xtile;
                lasttilehit = (int)tilehit;
                postx = pixx;
                postwidth = 1;

                if ((tilehit & 0x40) != 0)
                {
                    ytile = (int)(yintercept >> WolfConstants.TILESHIFT);
                    if (xtile - xtilestep >= 0 && xtile - xtilestep < WolfConstants.MAPSIZE &&
                        ytile >= 0 && ytile < WolfConstants.MAPSIZE &&
                        (WL_Globals.tilemap[xtile - xtilestep, ytile] & 0x80) != 0)
                        wallpic = DoorWall + 3;
                    else
                        wallpic = WL_Globals.vertwall[tilehit & ~0x40u];
                }
                else
                    wallpic = WL_Globals.vertwall[tilehit];

                postpage = IdPm.PM_GetPage(wallpic);
            }

            postsource = postpage;
            posttexture = texture;
        }

        // =========================================================================
        //  HitHorizWall
        // =========================================================================

        private static void HitHorizWall()
        {
            int wallpic;
            uint texture;

            texture = (uint)((xintercept >> 4) & 0xfc0);
            if (ytilestep == -1)
                yintercept += WolfConstants.TILEGLOBAL;
            else
                texture = 0xfc0 - texture;
            WL_Globals.wallheight[pixx] = CalcHeight();

            if (lastside == 0 && lastintercept == ytile && lasttilehit == (int)tilehit)
            {
                if (texture == posttexture)
                {
                    postwidth++;
                    WL_Globals.wallheight[pixx] = WL_Globals.wallheight[pixx - 1];
                    return;
                }
                else
                {
                    ScalePost();
                    posttexture = texture;
                    postpage = null;
                    postwidth = 1;
                    postx = pixx;
                }
            }
            else
            {
                if (lastside != -1)
                    ScalePost();

                lastside = 0;
                lastintercept = ytile;
                lasttilehit = (int)tilehit;
                postx = pixx;
                postwidth = 1;

                if ((tilehit & 0x40) != 0)
                {
                    xtile = (int)(xintercept >> WolfConstants.TILESHIFT);
                    if (xtile >= 0 && xtile < WolfConstants.MAPSIZE &&
                        ytile - ytilestep >= 0 && ytile - ytilestep < WolfConstants.MAPSIZE &&
                        (WL_Globals.tilemap[xtile, ytile - ytilestep] & 0x80) != 0)
                        wallpic = DoorWall + 2;
                    else
                        wallpic = WL_Globals.horizwall[tilehit & ~0x40u];
                }
                else
                    wallpic = WL_Globals.horizwall[tilehit];

                postpage = IdPm.PM_GetPage(wallpic);
            }

            postsource = postpage;
            posttexture = texture;
        }

        // =========================================================================
        //  HitHorizDoor
        // =========================================================================

        private static void HitHorizDoor()
        {
            uint texture, doorpage_num, doornum;

            doornum = tilehit & 0x7f;
            texture = (uint)(((xintercept - WL_Globals.doorposition[doornum]) >> 4) & 0xfc0);

            WL_Globals.wallheight[pixx] = CalcHeight();

            if (lasttilehit == (int)tilehit)
            {
                if (texture == posttexture)
                {
                    postwidth++;
                    WL_Globals.wallheight[pixx] = WL_Globals.wallheight[pixx - 1];
                    return;
                }
                else
                {
                    ScalePost();
                    posttexture = texture;
                    postwidth = 1;
                    postx = pixx;
                }
            }
            else
            {
                if (lastside != -1)
                    ScalePost();

                lastside = 2;
                lasttilehit = (int)tilehit;
                postx = pixx;
                postwidth = 1;

                switch (WL_Globals.doorobjlist[doornum].lock_)
                {
                    case 0: // dr_normal
                        doorpage_num = (uint)DoorWall;
                        break;
                    case 1: case 2: case 3: case 4: // locked doors
                        doorpage_num = (uint)(DoorWall + 6);
                        break;
                    case 5: // elevator
                        doorpage_num = (uint)(DoorWall + 4);
                        break;
                    default:
                        doorpage_num = (uint)DoorWall;
                        break;
                }

                postpage = IdPm.PM_GetPage((int)doorpage_num);
            }

            postsource = postpage;
            posttexture = texture;
        }

        // =========================================================================
        //  HitVertDoor
        // =========================================================================

        private static void HitVertDoor()
        {
            uint texture, doorpage_num, doornum;

            doornum = tilehit & 0x7f;
            texture = (uint)(((yintercept - WL_Globals.doorposition[doornum]) >> 4) & 0xfc0);

            WL_Globals.wallheight[pixx] = CalcHeight();

            if (lasttilehit == (int)tilehit)
            {
                if (texture == posttexture)
                {
                    postwidth++;
                    WL_Globals.wallheight[pixx] = WL_Globals.wallheight[pixx - 1];
                    return;
                }
                else
                {
                    ScalePost();
                    posttexture = texture;
                    postwidth = 1;
                    postx = pixx;
                }
            }
            else
            {
                if (lastside != -1)
                    ScalePost();

                lastside = 2;
                lasttilehit = (int)tilehit;
                postx = pixx;
                postwidth = 1;

                switch (WL_Globals.doorobjlist[doornum].lock_)
                {
                    case 0:
                        doorpage_num = (uint)DoorWall;
                        break;
                    case 1: case 2: case 3: case 4:
                        doorpage_num = (uint)(DoorWall + 6);
                        break;
                    case 5:
                        doorpage_num = (uint)(DoorWall + 4);
                        break;
                    default:
                        doorpage_num = (uint)DoorWall;
                        break;
                }

                postpage = IdPm.PM_GetPage((int)doorpage_num + 1);
            }

            postsource = postpage;
            posttexture = texture;
        }

        // =========================================================================
        //  HitHorizPWall
        // =========================================================================

        private static void HitHorizPWall()
        {
            int wallpic;
            uint texture;
            uint offset;

            texture = (uint)((xintercept >> 4) & 0xfc0);
            offset = (uint)(WL_Globals.pwallpos << 10);
            if (ytilestep == -1)
                yintercept += WolfConstants.TILEGLOBAL - (int)offset;
            else
            {
                texture = 0xfc0 - texture;
                yintercept += (int)offset;
            }

            WL_Globals.wallheight[pixx] = CalcHeight();

            if (lasttilehit == (int)tilehit)
            {
                if (texture == posttexture)
                {
                    postwidth++;
                    WL_Globals.wallheight[pixx] = WL_Globals.wallheight[pixx - 1];
                    return;
                }
                else
                {
                    ScalePost();
                    posttexture = texture;
                    postwidth = 1;
                    postx = pixx;
                }
            }
            else
            {
                if (lastside != -1)
                    ScalePost();

                lasttilehit = (int)tilehit;
                postx = pixx;
                postwidth = 1;

                wallpic = WL_Globals.horizwall[tilehit & 63];
                postpage = IdPm.PM_GetPage(wallpic);
            }

            postsource = postpage;
            posttexture = texture;
        }

        // =========================================================================
        //  HitVertPWall
        // =========================================================================

        private static void HitVertPWall()
        {
            int wallpic;
            uint texture;
            uint offset;

            texture = (uint)((yintercept >> 4) & 0xfc0);
            offset = (uint)(WL_Globals.pwallpos << 10);
            if (xtilestep == -1)
            {
                xintercept += WolfConstants.TILEGLOBAL - (int)offset;
                texture = 0xfc0 - texture;
            }
            else
                xintercept += (int)offset;

            WL_Globals.wallheight[pixx] = CalcHeight();

            if (lasttilehit == (int)tilehit)
            {
                if (texture == posttexture)
                {
                    postwidth++;
                    WL_Globals.wallheight[pixx] = WL_Globals.wallheight[pixx - 1];
                    return;
                }
                else
                {
                    ScalePost();
                    posttexture = texture;
                    postwidth = 1;
                    postx = pixx;
                }
            }
            else
            {
                if (lastside != -1)
                    ScalePost();

                lasttilehit = (int)tilehit;
                postx = pixx;
                postwidth = 1;

                wallpic = WL_Globals.vertwall[tilehit & 63];
                postpage = IdPm.PM_GetPage(wallpic);
            }

            postsource = postpage;
            posttexture = texture;
        }

        // =========================================================================
        //  xpartialbyystep / ypartialbyxstep
        // =========================================================================

        private static long xpartialbyystep(uint xpartial)
        {
            long result = (long)ystep * (long)xpartial;
            return (long)(result >> 16);
        }

        private static long ypartialbyxstep(uint ypartial)
        {
            long result = (long)xstep * (long)ypartial;
            return (long)(result >> 16);
        }

        // =========================================================================
        //  AsmRefresh - Core DDA raycaster
        // =========================================================================

        private static void AsmRefresh()
        {
            int angle_ray;
            int xspot, yspot;
            int xt, yt;
            int xint_hi, yint_hi;
            uint xpar, ypar;

            for (pixx = 0; pixx < (uint)WL_Globals.viewwidth; pixx++)
            {
                angle_ray = midangle + WL_Globals.pixelangle[pixx];

                if (angle_ray < 0) angle_ray += WolfConstants.FINEANGLES;
                if (angle_ray >= WolfConstants.FINEANGLES) angle_ray -= WolfConstants.FINEANGLES;

                if (angle_ray < DEG90)
                {
                    xtilestep = 1;
                    ytilestep = -1;
                    xstep = WL_Globals.finetangent[DEG90 - 1 - angle_ray];
                    ystep = -WL_Globals.finetangent[angle_ray];
                    xpar = xpartialup;
                    ypar = ypartialdown;
                }
                else if (angle_ray < DEG180)
                {
                    xtilestep = -1;
                    ytilestep = -1;
                    xstep = -WL_Globals.finetangent[angle_ray - DEG90];
                    ystep = -WL_Globals.finetangent[DEG180 - 1 - angle_ray];
                    xpar = xpartialdown;
                    ypar = ypartialdown;
                }
                else if (angle_ray < DEG270)
                {
                    xtilestep = -1;
                    ytilestep = 1;
                    xstep = -WL_Globals.finetangent[DEG270 - 1 - angle_ray];
                    ystep = WL_Globals.finetangent[angle_ray - DEG180];
                    xpar = xpartialdown;
                    ypar = ypartialup;
                }
                else if (angle_ray < DEG360)
                {
                    xtilestep = 1;
                    ytilestep = 1;
                    xstep = WL_Globals.finetangent[angle_ray - DEG270];
                    ystep = WL_Globals.finetangent[DEG360 - 1 - angle_ray];
                    xpar = xpartialup;
                    ypar = ypartialup;
                }
                else
                {
                    angle_ray -= WolfConstants.FINEANGLES;
                    xtilestep = 1;
                    ytilestep = -1;
                    xstep = WL_Globals.finetangent[DEG90 - 1 - angle_ray];
                    ystep = -WL_Globals.finetangent[angle_ray];
                    xpar = xpartialup;
                    ypar = ypartialdown;
                }

                yintercept = WL_Globals.viewy + xpartialbyystep(xpar);
                xt = focaltx + xtilestep;
                xtile = xt;
                yint_hi = (int)(yintercept >> 16);
                xspot = (xt << 6) + yint_hi;

                xintercept = WL_Globals.viewx + ypartialbyxstep(ypar);
                yt = focalty + ytilestep;
                xint_hi = (int)(xintercept >> 16);
                yspot = (xint_hi << 6) + yt;

                bool done = false;
                while (!done)
                {
                    bool do_vert;

                    if (ytilestep == -1)
                        do_vert = (yint_hi > yt);
                    else
                        do_vert = (yint_hi < yt);

                    if (do_vert)
                    {
                        // Check vertical wall
                        int tx = (xspot >> 6) & 63;
                        int ty = xspot & 63;
                        byte tile = 0;
                        if (tx >= 0 && tx < WolfConstants.MAPSIZE && ty >= 0 && ty < WolfConstants.MAPSIZE)
                            tile = WL_Globals.tilemap[tx, ty];

                        if (tile != 0)
                        {
                            tilehit = tile;
                            if ((tile & 0x80) != 0)
                            {
                                if ((tile & 0x40) != 0)
                                {
                                    // Pushable wall
                                    long tmp = (long)ystep * (long)WL_Globals.pwallpos;
                                    long partial = tmp >> 6;
                                    long newy = yintercept + partial;
                                    int newhi = (int)(newy >> 16);

                                    if (newhi != yint_hi)
                                        goto vert_pass;

                                    yintercept = newy;
                                    xintercept = ((long)xt << 16);
                                    HitVertPWall();
                                    done = true; continue;
                                }
                                else
                                {
                                    // Vertical door
                                    int doornum_local = tile & 0x7f;
                                    long halfstep = ystep >> 1;
                                    long newy = yintercept + halfstep;
                                    int newhi = (int)(newy >> 16);

                                    if (newhi != (int)(yintercept >> 16))
                                        goto vert_pass;

                                    if (doornum_local >= 0 && doornum_local < WolfConstants.MAXDOORS &&
                                        (uint)(newy & 0xFFFF) < (uint)WL_Globals.doorposition[doornum_local])
                                        goto vert_pass;

                                    yintercept = newy;
                                    xintercept = ((long)xt << 16) | 0x8000;
                                    HitVertDoor();
                                    done = true; continue;
                                }
                            }
                            else
                            {
                                // Solid wall
                                xintercept = ((long)xt << 16);
                                xtile = xt;
                                yintercept = (yintercept & 0xFFFF) | ((long)yint_hi << 16);
                                ytile = yint_hi;
                                HitVertWall();
                                done = true; continue;
                            }
                        }

                    vert_pass:
                        if (tx >= 0 && tx < WolfConstants.MAPSIZE && ty >= 0 && ty < WolfConstants.MAPSIZE)
                            WL_Globals.spotvis[tx, ty] = 1;
                        xt += xtilestep;
                        yintercept += ystep;
                        yint_hi = (int)(yintercept >> 16);
                        xspot = (xt << 6) + yint_hi;
                        continue;
                    }

                    // Horizontal check
                    bool do_horiz;
                    if (xtilestep == -1)
                        do_horiz = (xint_hi > xt);
                    else
                        do_horiz = (xint_hi < xt);

                    if (do_horiz)
                    {
                        // Check horizontal wall
                        int tx = (yspot >> 6) & 63;
                        int ty = yspot & 63;
                        byte tile = 0;
                        if (tx >= 0 && tx < WolfConstants.MAPSIZE && ty >= 0 && ty < WolfConstants.MAPSIZE)
                            tile = WL_Globals.tilemap[tx, ty];

                        if (tile != 0)
                        {
                            tilehit = tile;
                            if ((tile & 0x80) != 0)
                            {
                                if ((tile & 0x40) != 0)
                                {
                                    // Pushable wall
                                    long tmp = (long)xstep * (long)WL_Globals.pwallpos;
                                    long partial = tmp >> 6;
                                    long newx = xintercept + partial;
                                    int newhi = (int)(newx >> 16);

                                    if (newhi != xint_hi)
                                        goto horiz_pass;

                                    xintercept = newx;
                                    yintercept = ((long)yt << 16);
                                    HitHorizPWall();
                                    done = true; continue;
                                }
                                else
                                {
                                    // Horizontal door
                                    int doornum_local = tile & 0x7f;
                                    long halfstep = xstep >> 1;
                                    long newx = xintercept + halfstep;
                                    int newhi = (int)(newx >> 16);

                                    if (newhi != xint_hi)
                                        goto horiz_pass;

                                    if (doornum_local >= 0 && doornum_local < WolfConstants.MAXDOORS &&
                                        (uint)(newx & 0xFFFF) < (uint)WL_Globals.doorposition[doornum_local])
                                        goto horiz_pass;

                                    xintercept = newx;
                                    yintercept = ((long)yt << 16) | 0x8000;
                                    HitHorizDoor();
                                    done = true; continue;
                                }
                            }
                            else
                            {
                                // Solid wall
                                xintercept = (xintercept & 0xFFFF) | ((long)xint_hi << 16);
                                xtile = xint_hi;
                                yintercept = ((long)yt << 16);
                                ytile = yt;
                                HitHorizWall();
                                done = true; continue;
                            }
                        }

                    horiz_pass:
                        if (tx >= 0 && tx < WolfConstants.MAPSIZE && ty >= 0 && ty < WolfConstants.MAPSIZE)
                            WL_Globals.spotvis[tx, ty] = 1;
                        yt += ytilestep;
                        xintercept += xstep;
                        xint_hi = (int)(xintercept >> 16);
                        yspot = (xint_hi << 6) + yt;
                        continue;
                    }

                    // Tiebreak: both checks say to check the other. Check vertical first.
                    {
                        int tx = (xspot >> 6) & 63;
                        int ty = xspot & 63;
                        byte tile = 0;
                        if (tx >= 0 && tx < WolfConstants.MAPSIZE && ty >= 0 && ty < WolfConstants.MAPSIZE)
                            tile = WL_Globals.tilemap[tx, ty];

                        if (tile != 0)
                        {
                            tilehit = tile;
                            if ((tile & 0x80) != 0)
                            {
                                if ((tile & 0x40) != 0)
                                {
                                    long tmp = (long)ystep * (long)WL_Globals.pwallpos;
                                    long partial = tmp >> 6;
                                    long newy = yintercept + partial;
                                    int newhi = (int)(newy >> 16);

                                    if (newhi != yint_hi)
                                        goto tiebreak_vert_pass;

                                    yintercept = newy;
                                    xintercept = ((long)xt << 16);
                                    HitVertPWall();
                                    done = true; continue;
                                }
                                else
                                {
                                    int doornum_local = tile & 0x7f;
                                    long halfstep = ystep >> 1;
                                    long newy = yintercept + halfstep;
                                    int newhi = (int)(newy >> 16);

                                    if (newhi != (int)(yintercept >> 16))
                                        goto tiebreak_vert_pass;
                                    if (doornum_local >= 0 && doornum_local < WolfConstants.MAXDOORS &&
                                        (uint)(newy & 0xFFFF) < (uint)WL_Globals.doorposition[doornum_local])
                                        goto tiebreak_vert_pass;

                                    yintercept = newy;
                                    xintercept = ((long)xt << 16) | 0x8000;
                                    HitVertDoor();
                                    done = true; continue;
                                }
                            }
                            else
                            {
                                xintercept = ((long)xt << 16);
                                xtile = xt;
                                yintercept = (yintercept & 0xFFFF) | ((long)yint_hi << 16);
                                ytile = yint_hi;
                                HitVertWall();
                                done = true; continue;
                            }
                        }

                    tiebreak_vert_pass:
                        if (tx >= 0 && tx < WolfConstants.MAPSIZE && ty >= 0 && ty < WolfConstants.MAPSIZE)
                            WL_Globals.spotvis[tx, ty] = 1;
                        xt += xtilestep;
                        yintercept += ystep;
                        yint_hi = (int)(yintercept >> 16);
                        xspot = (xt << 6) + yint_hi;
                    }
                }
            }
        }

        // =========================================================================
        //  VGAClearScreen
        // =========================================================================

        public static void VGAClearScreen()
        {
            int ceilIdx = WL_Globals.gamestate.episode * 10 + WL_Globals.gamestate.mapon;
            byte ceilcolor = 0x1d;
            if (ceilIdx >= 0 && ceilIdx < vgaCeiling.Length)
                ceilcolor = (byte)(vgaCeiling[ceilIdx] & 0xFF);
            byte floorcolor = 0x19;

            int yofs = WL_Globals.screenofs / WolfConstants.SCREENWIDTH;
            int xofs = (WL_Globals.screenofs % WolfConstants.SCREENWIDTH) * 4;

            for (int y = 0; y < WL_Globals.viewheight / 2; y++)
            {
                int screeny = y + yofs;
                if (screeny >= 0 && screeny < 200)
                {
                    int off = screeny * 320 + xofs;
                    for (int x = 0; x < WL_Globals.viewwidth && (x + xofs) < 320; x++)
                        WL_Globals.sdl_screenbuf[off + x] = ceilcolor;
                }
            }

            for (int y = WL_Globals.viewheight / 2; y < WL_Globals.viewheight; y++)
            {
                int screeny = y + yofs;
                if (screeny >= 0 && screeny < 200)
                {
                    int off = screeny * 320 + xofs;
                    for (int x = 0; x < WL_Globals.viewwidth && (x + xofs) < 320; x++)
                        WL_Globals.sdl_screenbuf[off + x] = floorcolor;
                }
            }
        }

        // =========================================================================
        //  ClearScreen
        // =========================================================================

        public static void ClearScreen()
        {
            VGAClearScreen();
        }

        // =========================================================================
        //  CalcRotate
        // =========================================================================

        public static int CalcRotate(objtype ob)
        {
            int angle, viewang;

            viewang = WL_Globals.player.angle + (WL_Globals.centerx - ob.viewx) / 8;

            if (ob.obclass == classtype.rocketobj || ob.obclass == classtype.hrocketobj)
                angle = (viewang - 180) - ob.angle;
            else
                angle = (viewang - 180) - WL_Globals.dirangle[(int)ob.dir];

            angle += WolfConstants.ANGLES / 16;
            while (angle >= WolfConstants.ANGLES) angle -= WolfConstants.ANGLES;
            while (angle < 0) angle += WolfConstants.ANGLES;

            if (ob.state != null && ob.state.rotate)
            {
                // Check for 2-rotation pain frame (rotate value of 2 encoded as true in C#)
                // In the original, rotate can be 0,1,2 - we only have bool, so standard 8-dir
                return angle / (WolfConstants.ANGLES / 8);
            }

            return 0;
        }

        // =========================================================================
        //  DrawScaleds - draw visible sprites
        // =========================================================================

        public static void DrawScaleds()
        {
            int numvisable;
            viscount = 0;

            // Place static objects
            for (int si = 0; si < WolfConstants.MAXSTATS; si++)
            {
                var statptr = WL_Globals.statobjlist[si];
                if (statptr == WL_Globals.laststatobj && si > 0) break;
                if (statptr.shapenum == -1) continue;
                if (statptr.shapenum == 0) continue;

                // Check visibility via spotvis
                int stx = statptr.tilex;
                int sty = statptr.tiley;
                if (stx < 0 || stx >= WolfConstants.MAPSIZE || sty < 0 || sty >= WolfConstants.MAPSIZE)
                    continue;
                if (WL_Globals.spotvis[stx, sty] == 0) continue;

                int vx, vh;
                bool grabbed = TransformTile(stx, sty, out vx, out vh);

                if (grabbed && (statptr.flags & WolfConstants.FL_BONUS) != 0)
                {
                    WlAgent.GetBonus(statptr);
                    continue;
                }

                if (vh == 0) continue;

                if (viscount < MAXVISABLE)
                {
                    vislist[viscount].viewx = vx;
                    vislist[viscount].viewheight = vh;
                    vislist[viscount].shapenum = statptr.shapenum;
                    viscount++;
                }
            }

            // Place active objects
            var obj = WL_Globals.player.next;
            while (obj != null)
            {
                if (obj.state == null || obj.state.shapenum == 0)
                {
                    obj = obj.next;
                    continue;
                }

                int shapenum = obj.state.shapenum;

                // Check 9-tile visibility
                int otx = obj.tilex;
                int oty = obj.tiley;
                bool visible = false;

                for (int dy = -1; dy <= 1 && !visible; dy++)
                {
                    for (int dx = -1; dx <= 1 && !visible; dx++)
                    {
                        int cx = otx + dx;
                        int cy = oty + dy;
                        if (cx >= 0 && cx < WolfConstants.MAPSIZE && cy >= 0 && cy < WolfConstants.MAPSIZE)
                        {
                            if (WL_Globals.spotvis[cx, cy] != 0)
                            {
                                if (dx == 0 && dy == 0)
                                    visible = true;
                                else if (WL_Globals.tilemap[cx, cy] == 0)
                                    visible = true;
                            }
                        }
                    }
                }

                if (visible)
                {
                    obj.active = activetype.ac_yes;
                    TransformActor(obj);
                    if (obj.viewheight == 0)
                    {
                        obj = obj.next;
                        continue;
                    }

                    if (viscount < MAXVISABLE)
                    {
                        vislist[viscount].viewx = obj.viewx;
                        vislist[viscount].viewheight = obj.viewheight;
                        vislist[viscount].shapenum = shapenum;

                        if (shapenum == -1)
                            vislist[viscount].shapenum = obj.temp1;

                        if (obj.state.rotate)
                            vislist[viscount].shapenum += CalcRotate(obj);

                        viscount++;
                    }
                    obj.flags |= WolfConstants.FL_VISABLE;
                }
                else
                    obj.flags &= unchecked((byte)~WolfConstants.FL_VISABLE);

                obj = obj.next;
            }

            numvisable = viscount;
            if (numvisable == 0) return;

            // Sort and draw back-to-front (farthest first)
            for (int i = 0; i < numvisable; i++)
            {
                int least = 32000;
                int farthestIdx = 0;
                for (int j = 0; j < numvisable; j++)
                {
                    if (vislist[j].viewheight < least)
                    {
                        least = vislist[j].viewheight;
                        farthestIdx = j;
                    }
                }

                WlScale.ScaleShape(vislist[farthestIdx].viewx,
                    vislist[farthestIdx].shapenum,
                    (uint)vislist[farthestIdx].viewheight);

                vislist[farthestIdx].viewheight = 32000;
            }
        }

        // =========================================================================
        //  DrawPlayerWeapon
        // =========================================================================

        public static void DrawPlayerWeapon()
        {
            int shapenum;

            if (WL_Globals.gamestate.victoryflag)
            {
                if (WL_Globals.player.state != null &&
                    (WL_Globals.TimeCount & 32) != 0)
                    WlScale.SimpleScaleShape(WL_Globals.viewwidth / 2,
                        (int)SpriteEnum.SPR_DEATHCAM, (uint)(WL_Globals.viewheight + 1));
                return;
            }

            if ((int)WL_Globals.gamestate.weapon != -1)
            {
                shapenum = weaponscale[(int)WL_Globals.gamestate.weapon] +
                    WL_Globals.gamestate.weaponframe;
                WlScale.SimpleScaleShape(WL_Globals.viewwidth / 2, shapenum,
                    (uint)(WL_Globals.viewheight + 1));
            }

            if (WL_Globals.demorecord || WL_Globals.demoplayback)
                WlScale.SimpleScaleShape(WL_Globals.viewwidth / 2,
                    (int)SpriteEnum.SPR_DEMO, (uint)(WL_Globals.viewheight + 1));
        }

        // =========================================================================
        //  WallRefresh - set up view and cast all rays
        // =========================================================================

        private static void WallRefresh()
        {
            WL_Globals.viewangle = WL_Globals.player.angle;
            midangle = WL_Globals.viewangle * (WolfConstants.FINEANGLES / WolfConstants.ANGLES);
            WL_Globals.viewsin = WL_Globals.sintable[WL_Globals.viewangle];
            WL_Globals.viewcos = WL_Globals.costable[WL_Globals.viewangle];
            WL_Globals.viewx = WL_Globals.player.x - FixedByFrac(WL_Globals.focallength, WL_Globals.viewcos);
            WL_Globals.viewy = WL_Globals.player.y + FixedByFrac(WL_Globals.focallength, WL_Globals.viewsin);

            focaltx = WL_Globals.viewx >> WolfConstants.TILESHIFT;
            focalty = WL_Globals.viewy >> WolfConstants.TILESHIFT;

            viewtx = WL_Globals.player.x >> WolfConstants.TILESHIFT;
            viewty = WL_Globals.player.y >> WolfConstants.TILESHIFT;

            xpartialdown = (uint)(WL_Globals.viewx & (WolfConstants.TILEGLOBAL - 1));
            xpartialup = (uint)(WolfConstants.TILEGLOBAL - xpartialdown);
            ypartialdown = (uint)(WL_Globals.viewy & (WolfConstants.TILEGLOBAL - 1));
            ypartialup = (uint)(WolfConstants.TILEGLOBAL - ypartialdown);

            lastside = -1;
            AsmRefresh();
            ScalePost();  // flush last post
        }

        // =========================================================================
        //  ThreeDRefresh - Main 3D rendering call
        // =========================================================================

        public static void ThreeDRefresh()
        {
            // Clear spotvis
            Array.Clear(WL_Globals.spotvis, 0, WL_Globals.spotvis.Length);

            WL_Globals.bufferofs += WL_Globals.screenofs;

            VGAClearScreen();
            WallRefresh();
            DrawScaleds();
            DrawPlayerWeapon();

            if (WL_Globals.fizzlein)
            {
                IdVh.FizzleFade(WL_Globals.bufferofs,
                    WL_Globals.displayofs + WL_Globals.screenofs,
                    WL_Globals.viewwidth, WL_Globals.viewheight, 20, false);
                WL_Globals.fizzlein = false;
                WL_Globals.lasttimecount = WL_Globals.TimeCount = 0;
            }

            WL_Globals.bufferofs -= WL_Globals.screenofs;
            WL_Globals.displayofs = WL_Globals.bufferofs;

            IdVl.VL_UpdateScreen();

            WL_Globals.frameon++;
            IdPm.PM_NextFrame();
        }
    }
}
