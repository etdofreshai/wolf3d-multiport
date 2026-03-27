// ID_VH.C -> IdVh.cs
// Video Hardware abstraction layer

using System;

namespace Wolf3D
{
    public static class IdVh
    {
        // Game palette - 768 bytes, VGA 6-bit RGB triples (0-63)
        // Correct Wolf3D palette from wolfpal.inc (256 RGB triples, 6-bit VGA values)
        public static byte[] gamepal = new byte[768]
        {
              0,  0,  0,   0,  0, 42,   0, 42,  0,   0, 42, 42,  42,  0,  0,  42,
              0, 42,  42, 21,  0,  42, 42, 42,  21, 21, 21,  21, 21, 63,  21, 63,
             21,  21, 63, 63,  63, 21, 21,  63, 21, 63,  63, 63, 21,  63, 63, 63,
             59, 59, 59,  55, 55, 55,  52, 52, 52,  48, 48, 48,  45, 45, 45,  42,
             42, 42,  38, 38, 38,  35, 35, 35,  31, 31, 31,  28, 28, 28,  25, 25,
             25,  21, 21, 21,  18, 18, 18,  14, 14, 14,  11, 11, 11,   8,  8,  8,
             63,  0,  0,  59,  0,  0,  56,  0,  0,  53,  0,  0,  50,  0,  0,  47,
              0,  0,  44,  0,  0,  41,  0,  0,  38,  0,  0,  34,  0,  0,  31,  0,
              0,  28,  0,  0,  25,  0,  0,  22,  0,  0,  19,  0,  0,  16,  0,  0,
             63, 54, 54,  63, 46, 46,  63, 39, 39,  63, 31, 31,  63, 23, 23,  63,
             16, 16,  63,  8,  8,  63,  0,  0,  63, 42, 23,  63, 38, 16,  63, 34,
              8,  63, 30,  0,  57, 27,  0,  51, 24,  0,  45, 21,  0,  39, 19,  0,
             63, 63, 54,  63, 63, 46,  63, 63, 39,  63, 63, 31,  63, 62, 23,  63,
             61, 16,  63, 61,  8,  63, 61,  0,  57, 54,  0,  51, 49,  0,  45, 43,
              0,  39, 39,  0,  33, 33,  0,  28, 27,  0,  22, 21,  0,  16, 16,  0,
             52, 63, 23,  49, 63, 16,  45, 63,  8,  40, 63,  0,  36, 57,  0,  32,
             51,  0,  29, 45,  0,  24, 39,  0,  54, 63, 54,  47, 63, 46,  39, 63,
             39,  32, 63, 31,  24, 63, 23,  16, 63, 16,   8, 63,  8,   0, 63,  0,
              0, 63,  0,   0, 59,  0,   0, 56,  0,   0, 53,  0,   1, 50,  0,   1,
             47,  0,   1, 44,  0,   1, 41,  0,   1, 38,  0,   1, 34,  0,   1, 31,
              0,   1, 28,  0,   1, 25,  0,   1, 22,  0,   1, 19,  0,   1, 16,  0,
             54, 63, 63,  46, 63, 63,  39, 63, 63,  31, 63, 62,  23, 63, 63,  16,
             63, 63,   8, 63, 63,   0, 63, 63,   0, 57, 57,   0, 51, 51,   0, 45,
             45,   0, 39, 39,   0, 33, 33,   0, 28, 28,   0, 22, 22,   0, 16, 16,
             23, 47, 63,  16, 44, 63,   8, 42, 63,   0, 39, 63,   0, 35, 57,   0,
             31, 51,   0, 27, 45,   0, 23, 39,  54, 54, 63,  46, 47, 63,  39, 39,
             63,  31, 32, 63,  23, 24, 63,  16, 16, 63,   8,  9, 63,   0,  1, 63,
              0,  0, 63,   0,  0, 59,   0,  0, 56,   0,  0, 53,   0,  0, 50,   0,
              0, 47,   0,  0, 44,   0,  0, 41,   0,  0, 38,   0,  0, 34,   0,  0,
             31,   0,  0, 28,   0,  0, 25,   0,  0, 22,   0,  0, 19,   0,  0, 16,
             10, 10, 10,  63, 56, 13,  63, 53,  9,  63, 51,  6,  63, 48,  2,  63,
             45,  0,  45,  8, 63,  42,  0, 63,  38,  0, 57,  32,  0, 51,  29,  0,
             45,  24,  0, 39,  20,  0, 33,  17,  0, 28,  13,  0, 22,  10,  0, 16,
             63, 54, 63,  63, 46, 63,  63, 39, 63,  63, 31, 63,  63, 23, 63,  63,
             16, 63,  63,  8, 63,  63,  0, 63,  56,  0, 57,  50,  0, 51,  45,  0,
             45,  39,  0, 39,  33,  0, 33,  27,  0, 28,  22,  0, 22,  16,  0, 16,
             63, 58, 55,  63, 56, 52,  63, 54, 49,  63, 53, 47,  63, 51, 44,  63,
             49, 41,  63, 47, 39,  63, 46, 36,  63, 44, 32,  63, 41, 28,  63, 39,
             24,  60, 37, 23,  58, 35, 22,  55, 34, 21,  52, 32, 20,  50, 31, 19,
             47, 30, 18,  45, 28, 17,  42, 26, 16,  40, 25, 15,  39, 24, 14,  36,
             23, 13,  34, 22, 12,  32, 20, 11,  29, 19, 10,  27, 18,  9,  23, 16,
              8,  21, 15,  7,  18, 14,  6,  16, 12,  6,  14, 11,  5,  10,  8,  3,
             24,  0, 25,   0, 25, 25,   0, 24, 24,   0,  0,  7,   0,  0, 11,  12,
              9,  4,  18,  0, 18,  20,  0, 20,   0,  0, 13,   7,  7,  7,  19, 19,
             19,  23, 23, 23,  16, 16, 16,  12, 12, 12,  13, 13, 13,  54, 61, 61,
             46, 58, 58,  39, 55, 55,  29, 50, 50,  18, 48, 48,   8, 45, 45,   8,
             44, 44,   0, 41, 41,   0, 38, 38,   0, 35, 35,   0, 33, 33,   0, 31,
             31,   0, 30, 30,   0, 29, 29,   0, 28, 28,   0, 27, 27,  38,  0, 34
        };

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
