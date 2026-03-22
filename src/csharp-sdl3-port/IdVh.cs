// ID_VH.C -> IdVh.cs
// Video Hardware abstraction layer

using System;

namespace Wolf3D
{
    public static class IdVh
    {
        public static byte gamepal;  // extern in C header

        public static void VH_SetDefaultColors()
        {
            // Load the game palette from grsegs[GFXV] if available
        }

        public static void VW_DrawPropString(string str)
        {
            if (WL_Globals.grsegs[GfxConstants.STARTFONT + WL_Globals.fontnumber] == null)
                return;

            var font = DeserializeFont(WL_Globals.grsegs[GfxConstants.STARTFONT + WL_Globals.fontnumber]);
            int height = font.height;
            WL_Globals.bufferheight = height;
            int startpx = WL_Globals.px;

            foreach (char ch in str)
            {
                byte bch = (byte)ch;
                int width = font.width[bch];
                int step = width;
                int srcOffset = font.location[bch];

                byte[] fontData = WL_Globals.grsegs[GfxConstants.STARTFONT + WL_Globals.fontnumber];

                int si = srcOffset;
                while (width-- > 0)
                {
                    for (int row = 0; row < height; row++)
                    {
                        int dataIdx = si + row * step;
                        if (dataIdx >= 0 && dataIdx < fontData.Length)
                        {
                            byte val = fontData[dataIdx];
                            if (val != 0)
                            {
                                if (WL_Globals.px >= 0 && WL_Globals.px < 320 &&
                                    (WL_Globals.py + row) >= 0 && (WL_Globals.py + row) < 200)
                                    WL_Globals.sdl_screenbuf[(WL_Globals.py + row) * 320 + WL_Globals.px] = WL_Globals.fontcolor;
                            }
                        }
                    }
                    si++;
                    WL_Globals.px++;
                }
            }
            WL_Globals.bufferheight = height;
            WL_Globals.bufferwidth = WL_Globals.px - startpx;
        }

        public static void VW_DrawColorPropString(string str)
        {
            // Same as VW_DrawPropString but with color cycling
            VW_DrawPropString(str);
        }

        public static void VWL_MeasureString(string str, out int width, out int height, fontstruct font)
        {
            height = font.height;
            width = 0;
            foreach (char c in str)
                width += font.width[(byte)c];
        }

        public static void VW_MeasurePropString(string str, out int width, out int height)
        {
            if (WL_Globals.grsegs[GfxConstants.STARTFONT + WL_Globals.fontnumber] == null)
            {
                width = 0;
                height = 0;
                return;
            }
            var font = DeserializeFont(WL_Globals.grsegs[GfxConstants.STARTFONT + WL_Globals.fontnumber]);
            VWL_MeasureString(str, out width, out height, font);
        }

        public static void VW_MeasureMPropString(string str, out int width, out int height)
        {
            width = 0; height = 0;
            // STARTFONTM not used in WL6
        }

        // =========================================================================
        //  Double buffer management
        // =========================================================================

        public static int VW_MarkUpdateBlock(int x1, int y1, int x2, int y2)
        {
            int xt1 = x1 >> 4;
            int yt1 = y1 >> 4;
            int xt2 = x2 >> 4;
            int yt2 = y2 >> 4;

            if (xt1 < 0) xt1 = 0;
            else if (xt1 >= WolfConstants.UPDATEWIDE) return 0;
            if (yt1 < 0) yt1 = 0;
            else if (yt1 > WolfConstants.UPDATEHIGH) return 0;
            if (xt2 < 0) return 0;
            else if (xt2 >= WolfConstants.UPDATEWIDE) xt2 = WolfConstants.UPDATEWIDE - 1;
            if (yt2 < 0) return 0;
            else if (yt2 >= WolfConstants.UPDATEHIGH) yt2 = WolfConstants.UPDATEHIGH - 1;

            int nextline = WolfConstants.UPDATEWIDE - (xt2 - xt1) - 1;
            int mark = WL_Globals.uwidthtable[yt1] + xt1;

            for (int y = yt1; y <= yt2; y++)
            {
                for (int x = xt1; x <= xt2; x++)
                {
                    if (mark >= 0 && mark < WL_Globals.update.Length)
                        WL_Globals.update[mark] = 1;
                    mark++;
                }
                mark += nextline;
            }
            return 1;
        }

        public static void VWB_DrawTile8(int x, int y, int tile)
        {
            if (VW_MarkUpdateBlock(x, y, x + 7, y + 7) != 0)
                LatchDrawChar(x, y, tile);
        }

        public static void VWB_DrawPic(int x, int y, int chunknum)
        {
            int picnum = chunknum - GfxConstants.STARTPICS;
            x &= ~7;

            if (WL_Globals.pictable == null || picnum < 0 || picnum >= WL_Globals.pictable.Length)
                return;

            int width = WL_Globals.pictable[picnum].width;
            int height = WL_Globals.pictable[picnum].height;

            if (VW_MarkUpdateBlock(x, y, x + width - 1, y + height - 1) != 0)
            {
                if (WL_Globals.grsegs[chunknum] != null)
                    IdVl.VL_MemToScreen(WL_Globals.grsegs[chunknum], width, height, x, y);
            }
        }

        public static void VWB_DrawPropString(string str)
        {
            int x = WL_Globals.px;
            VW_DrawPropString(str);
            VW_MarkUpdateBlock(x, WL_Globals.py, WL_Globals.px - 1, WL_Globals.py + WL_Globals.bufferheight - 1);
        }

        public static void VWB_Bar(int x, int y, int width, int height, int color)
        {
            if (VW_MarkUpdateBlock(x, y, x + width, y + height - 1) != 0)
                IdVl.VL_Bar(x, y, width, height, color);
        }

        public static void VWB_Plot(int x, int y, int color)
        {
            if (VW_MarkUpdateBlock(x, y, x, y) != 0)
                IdVl.VL_Plot(x, y, color);
        }

        public static void VWB_Hlin(int x1, int x2, int y, int color)
        {
            if (VW_MarkUpdateBlock(x1, y, x2, y) != 0)
                IdVl.VL_Hlin(x1, y, x2 - x1 + 1, color);
        }

        public static void VWB_Vlin(int y1, int y2, int x, int color)
        {
            if (VW_MarkUpdateBlock(x, y1, x, y2) != 0)
                IdVl.VL_Vlin(x, y1, y2 - y1 + 1, color);
        }

        public static void VH_UpdateScreen()
        {
            IdVl.VL_UpdateScreen();
        }

        public static void VW_UpdateScreen()
        {
            VH_UpdateScreen();
        }

        // =========================================================================
        //  Wolfenstein specific
        // =========================================================================

        public static void LatchDrawChar(int x, int y, int p)
        {
            IdVl.VL_LatchToScreen(WL_Globals.latchpics[0] + p * 16, 2, 8, x, y);
        }

        public static void LatchDrawTile(int x, int y, int p)
        {
            IdVl.VL_LatchToScreen(WL_Globals.latchpics[1] + p * 64, 4, 16, x, y);
        }

        public static void LatchDrawPic(int x, int y, int picnum)
        {
            if (WL_Globals.pictable == null) return;
            int idx = picnum - GfxConstants.STARTPICS;
            if (idx < 0 || idx >= WL_Globals.pictable.Length) return;

            int wide = WL_Globals.pictable[idx].width;
            int height = WL_Globals.pictable[idx].height;
            int source = WL_Globals.latchpics[2 + picnum - GfxConstants.LATCHPICS_LUMP_START];

            IdVl.VL_LatchToScreen(source, wide / 4, height, x * 8, y);
        }

        public static void LoadLatchMem()
        {
            int i;
            int destoff;

            // tile 8s
            WL_Globals.latchpics[0] = WL_Globals.freelatch;
            IdCa.CA_CacheGrChunk(GfxConstants.STARTTILE8);
            byte[] src = WL_Globals.grsegs[GfxConstants.STARTTILE8];
            destoff = WL_Globals.freelatch;

            if (src != null)
            {
                int si = 0;
                for (i = 0; i < GfxConstants.NUMTILE8; i++)
                {
                    IdVl.VL_MemToLatch(src, si, 8, 8, destoff);
                    si += 64;
                    destoff += 16;
                }
            }
            WolfMacros.UNCACHEGRCHUNK(GfxConstants.STARTTILE8);

            // pics
            int start = GfxConstants.LATCHPICS_LUMP_START;
            int end = GfxConstants.LATCHPICS_LUMP_END;

            for (i = start; i <= end; i++)
            {
                WL_Globals.latchpics[2 + i - start] = destoff;
                IdCa.CA_CacheGrChunk(i);
                if (WL_Globals.pictable == null) continue;
                int idx = i - GfxConstants.STARTPICS;
                if (idx < 0 || idx >= WL_Globals.pictable.Length) continue;

                int width = WL_Globals.pictable[idx].width;
                int height = WL_Globals.pictable[idx].height;
                if (WL_Globals.grsegs[i] != null)
                    IdVl.VL_MemToLatch(WL_Globals.grsegs[i], 0, width, height, destoff);
                destoff += width / 4 * height;
                WolfMacros.UNCACHEGRCHUNK(i);
            }
        }

        // =========================================================================
        //  FizzleFade
        // =========================================================================

        public static bool FizzleFade(int source, int dest, int width, int height,
            int frames, bool abortable)
        {
            int pixperframe;
            int x, y, frame;
            int rndval;

            byte[] fizzle_src = new byte[320 * 200];
            Array.Copy(WL_Globals.sdl_screenbuf, fizzle_src, 320 * 200);

            rndval = 1;
            pixperframe = 64000 / frames;

            IdIn.IN_StartAck();

            WL_Globals.TimeCount = 0;
            frame = 0;

            do
            {
                if (abortable && IdIn.IN_CheckAck())
                    return true;

                for (int p = 0; p < pixperframe; p++)
                {
                    y = (rndval & 0xFF) - 1;
                    x = ((rndval >> 8) & 0x1FF);

                    int carry = rndval & 1;
                    rndval >>= 1;
                    if (carry != 0)
                        rndval ^= 0x00012000;

                    if (x > width || y > height)
                        continue;

                    if (x >= 0 && x < 320 && y >= 0 && y < 200)
                        WL_Globals.sdl_screenbuf[y * 320 + x] = fizzle_src[y * 320 + x];

                    if (rndval == 1)
                    {
                        Array.Copy(fizzle_src, WL_Globals.sdl_screenbuf, 320 * 200);
                        IdVl.VL_UpdateScreen();
                        return false;
                    }
                }
                frame++;
                IdVl.VL_UpdateScreen();
                while (WL_Globals.TimeCount < frame)
                {
                    IdSd.SD_TimeCountUpdate();
                    SDL.SDL_Delay(1);
                }
            } while (true);
        }

        // =========================================================================
        //  Font deserialization helper
        // =========================================================================

        public static fontstruct DeserializeFont(byte[] data)
        {
            if (data == null || data.Length < 2 + 512 + 256)
                return new fontstruct { height = 0 };

            var font = new fontstruct();
            font.height = (short)(data[0] | (data[1] << 8));

            for (int i = 0; i < 256; i++)
            {
                font.location[i] = (short)(data[2 + i * 2] | (data[2 + i * 2 + 1] << 8));
            }

            for (int i = 0; i < 256; i++)
            {
                font.width[i] = data[2 + 512 + i];
            }

            return font;
        }
    }
}
