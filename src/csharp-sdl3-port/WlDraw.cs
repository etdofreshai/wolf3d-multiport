// WL_DRAW.C -> WlDraw.cs
// 3D raycasting renderer

using System;

namespace Wolf3D
{
    public static class WlDraw
    {
        private const int MAXVISABLE = 50;

        private static int midangle;
        private static int focallength;

        // Visible sprites
        private struct visobj_t
        {
            public int viewx, viewheight;
            public int shapenum;
        }

        private static visobj_t[] vislist = new visobj_t[MAXVISABLE];
        private static int viscount;

        // =========================================================================
        //  BuildTables
        // =========================================================================

        public static void BuildTables()
        {
            // Tables already built in WlMain.BuildTables and CalcProjection
        }

        // =========================================================================
        //  CalcTics
        // =========================================================================

        public static void CalcTics()
        {
            int newtime = WL_Globals.TimeCount;
            WL_Globals.tics = newtime - WL_Globals.lasttimecount;
            WL_Globals.lasttimecount = newtime;

            if (WL_Globals.tics > WolfConstants.MAXTICS)
                WL_Globals.tics = WolfConstants.MAXTICS;

            if (WL_Globals.tics < 1)
                WL_Globals.tics = 1;
        }

        // =========================================================================
        //  FixOfs
        // =========================================================================

        public static void FixOfs()
        {
            WL_Globals.bufferofs = WolfConstants.PAGE1START;
            WL_Globals.displayofs = WolfConstants.PAGE1START;
        }

        // =========================================================================
        //  FixedByFrac
        // =========================================================================

        public static int FixedByFrac(int a, int b)
        {
            return (int)(((long)a * b) >> 16);
        }

        // =========================================================================
        //  TransformActor
        // =========================================================================

        public static void TransformActor(objtype ob)
        {
            int gx = ob.x - WL_Globals.viewx;
            int gy = ob.y - WL_Globals.viewy;

            // Rotate around viewangle
            int gxt = FixedByFrac(gx, WL_Globals.viewcos);
            int gyt = FixedByFrac(gy, WL_Globals.viewsin);
            ob.transx = gxt - gyt;

            gxt = FixedByFrac(gx, WL_Globals.viewsin);
            gyt = FixedByFrac(gy, WL_Globals.viewcos);
            ob.transy = gxt + gyt;

            if (ob.transx < WolfConstants.MINDIST)
            {
                ob.viewheight = 0;
                return;
            }

            ob.viewx = WL_Globals.centerx + ob.transy * WL_Globals.scale / ob.transx;
            ob.viewheight = WL_Globals.heightnumerator / (ob.transx >> 8);
        }

        // =========================================================================
        //  CalcRotate
        // =========================================================================

        public static int CalcRotate(objtype ob)
        {
            int angle = ob.angle;
            // Simplified rotation calculation
            return ob.state != null ? ob.state.shapenum : 0;
        }

        // =========================================================================
        //  DrawScaleds - draw visible sprites
        // =========================================================================

        public static void DrawScaleds()
        {
            viscount = 0;

            var obj = WL_Globals.player.next;
            while (obj != null)
            {
                if (obj.active != activetype.ac_no && (obj.flags & WolfConstants.FL_VISABLE) != 0)
                {
                    TransformActor(obj);
                    if (obj.viewheight > 0 && viscount < MAXVISABLE)
                    {
                        vislist[viscount].viewx = obj.viewx;
                        vislist[viscount].viewheight = obj.viewheight;
                        vislist[viscount].shapenum = CalcRotate(obj);
                        viscount++;
                    }
                }
                obj = obj.next;
            }

            // Sort and draw sprites
            // (Full implementation would sort by distance and draw back-to-front)
            for (int i = 0; i < viscount; i++)
            {
                if (vislist[i].viewheight > 0)
                    WlScale.ScaleShape(vislist[i].viewx, vislist[i].shapenum,
                        (uint)vislist[i].viewheight);
            }
        }

        // =========================================================================
        //  ClearScreen
        // =========================================================================

        public static void ClearScreen()
        {
            int vieww = WL_Globals.viewwidth;
            int viewh = WL_Globals.viewheight;
            int startx = (320 - vieww) / 2;
            int starty = (200 - WolfConstants.STATUSLINES - viewh) / 2;

            // Ceiling
            IdVl.VL_Bar(startx, starty, vieww, viewh / 2, 0x1d);
            // Floor
            IdVl.VL_Bar(startx, starty + viewh / 2, vieww, viewh / 2, 0x19);
        }

        // =========================================================================
        //  WallRefresh - cast rays for walls
        // =========================================================================

        private static void WallRefresh()
        {
            // Full raycasting implementation
            // For each column, cast a ray and determine wall hit
            int vieww = WL_Globals.viewwidth;

            for (int pixx = 0; pixx < vieww; pixx++)
            {
                int angle = WL_Globals.viewangle + WL_Globals.pixelangle[pixx];
                while (angle < 0) angle += WolfConstants.FINEANGLES;
                while (angle >= WolfConstants.FINEANGLES) angle -= WolfConstants.FINEANGLES;

                // Cast ray and find wall intersection
                // This is a simplified version - full implementation would do DDA raycasting
                WL_Globals.wallheight[pixx] = 64; // placeholder
            }
        }

        // =========================================================================
        //  ThreeDRefresh - Main 3D rendering call
        // =========================================================================

        public static void ThreeDRefresh()
        {
            // Clear spotvis
            Array.Clear(WL_Globals.spotvis, 0, WL_Globals.spotvis.Length);

            // Set up view
            WL_Globals.viewangle = WL_Globals.player.angle;
            WL_Globals.viewx = WL_Globals.player.x;
            WL_Globals.viewy = WL_Globals.player.y;

            int idx = WL_Globals.viewangle;
            if (idx >= 0 && idx < WL_Globals.sintable.Length)
                WL_Globals.viewsin = WL_Globals.sintable[idx];
            if (WL_Globals.costable != null && idx >= 0 && idx < WL_Globals.costable.Length)
                WL_Globals.viewcos = WL_Globals.costable[idx];

            // Clear screen
            ClearScreen();

            // Cast walls
            WallRefresh();

            // Draw walls (render wall columns based on wallheight[])
            // Full implementation here

            // Draw sprites
            DrawScaleds();

            // Update screen
            IdVl.VL_UpdateScreen();

            IdPm.PM_NextFrame();
        }

        // =========================================================================
        //  FarScalePost
        // =========================================================================

        public static void FarScalePost()
        {
            // Scale and draw a single wall post column
        }
    }
}
