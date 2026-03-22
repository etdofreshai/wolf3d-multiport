// WL_SCALE.C -> WlScale.cs
// Sprite scaling routines - full ScaleShape/SimpleScaleShape with t_compshape parsing

using System;

namespace Wolf3D
{
    public static class WlScale
    {
        // ScaleLine state
        private static int slinex, slinewidth;
        private static int linecmds_offset;
        private static byte[] linecmds_data;
        private static t_compscale linescale;
        private static byte[] scaleline_shape_base;

        private static int stepbytwo;

        // =========================================================================
        //  SetupScaling
        // =========================================================================

        public static void SetupScaling(int maxscaleheight)
        {
            WL_Globals.insetupscaling = true;

            maxscaleheight /= 2;
            WL_Globals.maxscale = maxscaleheight - 1;
            WL_Globals.maxscaleshl2 = WL_Globals.maxscale << 2;

            // Free old scalers
            for (int i = 0; i <= WolfConstants.MAXSCALEHEIGHT; i++)
                WL_Globals.scaledirectory[i] = null;

            stepbytwo = WL_Globals.viewheight / 2;

            // Build scaling lookup tables
            for (int i = 1; i <= maxscaleheight; i++)
            {
                int height = i * 2;
                long step = ((long)height << 16) / 64;
                long fix = 0;
                int toppix = (WL_Globals.viewheight - height) / 2;

                var sc = new t_compscale();

                for (int src = 0; src <= 64; src++)
                {
                    int startpix = (int)(fix >> 16);
                    fix += step;
                    int endpix = (int)(fix >> 16);

                    if (endpix > startpix)
                        sc.width[src] = (ushort)(endpix - startpix);
                    else
                        sc.width[src] = 0;

                    sc.codeofs[src] = (ushort)(startpix + toppix);
                }

                WL_Globals.scaledirectory[i] = sc;

                if (i >= stepbytwo)
                {
                    if (i + 1 <= WolfConstants.MAXSCALEHEIGHT)
                        WL_Globals.scaledirectory[i + 1] = sc;
                    if (i + 2 <= WolfConstants.MAXSCALEHEIGHT)
                        WL_Globals.scaledirectory[i + 2] = sc;
                    i += 2;
                }
            }

            if (WL_Globals.scaledirectory[0] == null)
                WL_Globals.scaledirectory[0] = WL_Globals.scaledirectory[1];

            WL_Globals.insetupscaling = false;
        }

        // =========================================================================
        //  ScaleLine - draw one scaled column of a sprite
        // =========================================================================

        private static void ScaleLine()
        {
            var comptable = linescale;
            if (comptable == null || linecmds_data == null || scaleline_shape_base == null)
                return;

            int yofs = WL_Globals.screenofs / WolfConstants.SCREENWIDTH;
            int xofs = (WL_Globals.screenofs % WolfConstants.SCREENWIDTH) * 4;

            int cmdOfs = linecmds_offset;

            // Process each segment in the command list
            while (true)
            {
                if (cmdOfs + 5 >= linecmds_data.Length) break;

                int end_ofs = linecmds_data[cmdOfs] | (linecmds_data[cmdOfs + 1] << 8);
                if (end_ofs == 0) break;

                int src_offset = linecmds_data[cmdOfs + 2] | (linecmds_data[cmdOfs + 3] << 8);
                int start_ofs = linecmds_data[cmdOfs + 4] | (linecmds_data[cmdOfs + 5] << 8);
                cmdOfs += 6;

                int texel_start = start_ofs / 2;
                int texel_end = end_ofs / 2;

                if (texel_start > 64) texel_start = 64;
                if (texel_end > 64) texel_end = 64;

                for (int texel = texel_start; texel < texel_end; texel++)
                {
                    int width_pix = comptable.width[texel];
                    int screen_y_start = comptable.codeofs[texel];

                    if (width_pix <= 0) continue;

                    int srcIdx = src_offset + texel;
                    if (srcIdx < 0 || srcIdx >= scaleline_shape_base.Length) continue;
                    byte color = scaleline_shape_base[srcIdx];
                    if (color == 0) continue;

                    for (int dy = 0; dy < width_pix; dy++)
                    {
                        int sy = screen_y_start + dy;
                        if (sy < 0 || sy >= WL_Globals.viewheight) continue;
                        int screen_y = sy + yofs;
                        if (screen_y < 0 || screen_y >= 200) continue;

                        for (int x = slinex; x < slinex + slinewidth && (x + xofs) < 320; x++)
                        {
                            if ((x + xofs) >= 0)
                                WL_Globals.sdl_screenbuf[screen_y * 320 + x + xofs] = color;
                        }
                    }
                }
            }
        }

        // =========================================================================
        //  ParseCompShape - parse t_compshape from raw sprite data
        // =========================================================================

        private static t_compshape ParseCompShape(byte[] data)
        {
            if (data == null || data.Length < 4) return null;

            var shape = new t_compshape();
            shape.leftpix = (ushort)(data[0] | (data[1] << 8));
            shape.rightpix = (ushort)(data[2] | (data[3] << 8));

            // Read dataofs - one entry per column (up to 64 columns)
            int numCols = shape.rightpix - shape.leftpix + 1;
            if (numCols < 0) numCols = 0;
            if (numCols > 64) numCols = 64;

            for (int i = 0; i < numCols && (4 + i * 2 + 1) < data.Length; i++)
            {
                shape.dataofs[i] = (ushort)(data[4 + i * 2] | (data[4 + i * 2 + 1] << 8));
            }

            shape.data = data;
            return shape;
        }

        // =========================================================================
        //  ScaleShape - draw a compiled shape at [height] pixels high
        // =========================================================================

        public static void ScaleShape(int xcenter, int shapenum, uint height)
        {
            byte[] spriteData = null;
            if (shapenum >= 0 && shapenum < WL_Globals.ChunksInFile - WL_Globals.PMSpriteStart)
                spriteData = IdPm.PM_GetSpritePage(shapenum);

            if (spriteData == null) return;

            var shape = ParseCompShape(spriteData);
            if (shape == null) return;

            uint scale = height >> 3;
            if (scale == 0 || scale > (uint)WL_Globals.maxscale) return;

            var comptable = WL_Globals.scaledirectory[scale];
            if (comptable == null) return;

            linescale = comptable;
            scaleline_shape_base = spriteData;

            int srcx, stopx;
            int cmdptrIdx;

            // Scale to the left (from pixel 31 to shape.leftpix)
            srcx = 32;
            slinex = xcenter;
            stopx = shape.leftpix;
            cmdptrIdx = 31 - stopx;

            while (--srcx >= stopx && slinex > 0)
            {
                if (cmdptrIdx >= 0 && cmdptrIdx < shape.dataofs.Length)
                    linecmds_offset = shape.dataofs[cmdptrIdx];
                else
                    linecmds_offset = 0;
                linecmds_data = spriteData;
                cmdptrIdx--;

                slinewidth = comptable.width[srcx];
                if (slinewidth == 0) continue;

                if (slinewidth == 1)
                {
                    slinex--;
                    if (slinex < WL_Globals.viewwidth)
                    {
                        if (slinex >= 0 && WL_Globals.wallheight[slinex] >= (int)height)
                            continue;
                        ScaleLine();
                    }
                    continue;
                }

                // Multi-pixel lines
                if (slinex > WL_Globals.viewwidth)
                {
                    slinex -= slinewidth;
                    slinewidth = WL_Globals.viewwidth - slinex;
                    if (slinewidth < 1) continue;
                }
                else
                {
                    if (slinewidth > slinex) slinewidth = slinex;
                    slinex -= slinewidth;
                }

                bool leftvis = (slinex >= 0 && slinex < WL_Globals.wallheight.Length &&
                    WL_Globals.wallheight[slinex] < (int)height);
                bool rightvis = (slinex + slinewidth - 1 >= 0 &&
                    slinex + slinewidth - 1 < WL_Globals.wallheight.Length &&
                    WL_Globals.wallheight[slinex + slinewidth - 1] < (int)height);

                if (leftvis)
                {
                    if (rightvis)
                        ScaleLine();
                    else
                    {
                        while (slinewidth > 0 && slinex + slinewidth - 1 >= 0 &&
                            slinex + slinewidth - 1 < WL_Globals.wallheight.Length &&
                            WL_Globals.wallheight[slinex + slinewidth - 1] >= (int)height)
                            slinewidth--;
                        if (slinewidth > 0) ScaleLine();
                    }
                }
                else
                {
                    if (!rightvis) continue;
                    while (slinewidth > 0 && slinex >= 0 && slinex < WL_Globals.wallheight.Length &&
                        WL_Globals.wallheight[slinex] >= (int)height)
                    {
                        slinex++;
                        slinewidth--;
                    }
                    if (slinewidth > 0) ScaleLine();
                    break;
                }
            }

            // Scale to the right
            slinex = xcenter;
            stopx = shape.rightpix;
            if (shape.leftpix < 31)
            {
                srcx = 31;
                cmdptrIdx = 32 - shape.leftpix;
            }
            else
            {
                srcx = shape.leftpix - 1;
                cmdptrIdx = 0;
            }
            slinewidth = 0;

            while (++srcx <= stopx && (slinex += slinewidth) < WL_Globals.viewwidth)
            {
                if (cmdptrIdx >= 0 && cmdptrIdx < shape.dataofs.Length)
                    linecmds_offset = shape.dataofs[cmdptrIdx];
                else
                    linecmds_offset = 0;
                linecmds_data = spriteData;
                cmdptrIdx++;

                slinewidth = comptable.width[srcx];
                if (slinewidth == 0) continue;

                if (slinewidth == 1)
                {
                    if (slinex >= 0 && slinex < WL_Globals.wallheight.Length &&
                        WL_Globals.wallheight[slinex] < (int)height)
                        ScaleLine();
                    continue;
                }

                // Multi-pixel lines
                if (slinex < 0)
                {
                    if (slinewidth <= -slinex) continue;
                    slinewidth += slinex;
                    slinex = 0;
                }
                else
                {
                    if (slinex + slinewidth > WL_Globals.viewwidth)
                        slinewidth = WL_Globals.viewwidth - slinex;
                }

                bool leftvis = (slinex >= 0 && slinex < WL_Globals.wallheight.Length &&
                    WL_Globals.wallheight[slinex] < (int)height);
                bool rightvis = (slinex + slinewidth - 1 >= 0 &&
                    slinex + slinewidth - 1 < WL_Globals.wallheight.Length &&
                    WL_Globals.wallheight[slinex + slinewidth - 1] < (int)height);

                if (leftvis)
                {
                    if (rightvis)
                        ScaleLine();
                    else
                    {
                        while (slinewidth > 0 && slinex + slinewidth - 1 >= 0 &&
                            slinex + slinewidth - 1 < WL_Globals.wallheight.Length &&
                            WL_Globals.wallheight[slinex + slinewidth - 1] >= (int)height)
                            slinewidth--;
                        if (slinewidth > 0) ScaleLine();
                        break;
                    }
                }
                else
                {
                    if (rightvis)
                    {
                        while (slinewidth > 0 && slinex >= 0 && slinex < WL_Globals.wallheight.Length &&
                            WL_Globals.wallheight[slinex] >= (int)height)
                        {
                            slinex++;
                            slinewidth--;
                        }
                        if (slinewidth > 0) ScaleLine();
                    }
                    else
                        continue;
                }
            }
        }

        // =========================================================================
        //  SimpleScaleShape - no wall clipping, height in pixels
        // =========================================================================

        public static void SimpleScaleShape(int xcenter, int shapenum, uint height)
        {
            byte[] spriteData = null;
            if (shapenum >= 0 && shapenum < WL_Globals.ChunksInFile - WL_Globals.PMSpriteStart)
                spriteData = IdPm.PM_GetSpritePage(shapenum);

            if (spriteData == null) return;

            var shape = ParseCompShape(spriteData);
            if (shape == null) return;

            uint scale = height >> 1;
            if (scale == 0 || scale > (uint)WL_Globals.maxscale) return;

            var comptable = WL_Globals.scaledirectory[scale];
            if (comptable == null) return;

            linescale = comptable;
            scaleline_shape_base = spriteData;

            int srcx, stopx;
            int cmdptrIdx;

            // Scale to the left
            srcx = 32;
            slinex = xcenter;
            stopx = shape.leftpix;
            cmdptrIdx = 31 - stopx;

            while (--srcx >= stopx)
            {
                if (cmdptrIdx >= 0 && cmdptrIdx < shape.dataofs.Length)
                    linecmds_offset = shape.dataofs[cmdptrIdx];
                else
                    linecmds_offset = 0;
                linecmds_data = spriteData;
                cmdptrIdx--;

                slinewidth = comptable.width[srcx];
                if (slinewidth == 0) continue;

                slinex -= slinewidth;
                ScaleLine();
            }

            // Scale to the right
            slinex = xcenter;
            stopx = shape.rightpix;
            if (shape.leftpix < 31)
            {
                srcx = 31;
                cmdptrIdx = 32 - shape.leftpix;
            }
            else
            {
                srcx = shape.leftpix - 1;
                cmdptrIdx = 0;
            }
            slinewidth = 0;

            while (++srcx <= stopx)
            {
                if (cmdptrIdx >= 0 && cmdptrIdx < shape.dataofs.Length)
                    linecmds_offset = shape.dataofs[cmdptrIdx];
                else
                    linecmds_offset = 0;
                linecmds_data = spriteData;
                cmdptrIdx++;

                slinewidth = comptable.width[srcx];
                if (slinewidth == 0) continue;

                ScaleLine();
                slinex += slinewidth;
            }
        }
    }
}
