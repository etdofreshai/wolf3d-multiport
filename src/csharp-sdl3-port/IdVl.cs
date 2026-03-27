// ID_VL.C -> IdVl.cs
// Video Layer - SDL3 rendering backend

using System;
using System.Runtime.InteropServices;

namespace Wolf3D
{
    public static class IdVl
    {
        private static bool fastpalette;
        private static byte[,] palette1 = new byte[256, 3];
        private static byte[,] palette2 = new byte[256, 3];

        // Test sequence support
        private static ulong test_start_time;
        private static int test_next_event;

        // Test sequence event definition
        private struct TestEvent
        {
            public ulong time_ms;
            public int scancode;
            public bool is_press;
            public TestEvent(ulong t, int sc, bool press) { time_ms = t; scancode = sc; is_press = press; }
        }

        // Time-based test events matching the C port
        private static TestEvent[] test_events = new TestEvent[]
        {
            // ~1s: Press SPACE (acknowledge signon "Press a key")
            new TestEvent( 1000, SDL.SDL_SCANCODE_SPACE, true),
            new TestEvent( 1200, SDL.SDL_SCANCODE_SPACE, false),
            // ~4s: Press SPACE (acknowledge PC-13 screen)
            new TestEvent( 4000, SDL.SDL_SCANCODE_SPACE, true),
            new TestEvent( 4200, SDL.SDL_SCANCODE_SPACE, false),
            // ~9s: Press SPACE (dismiss title, should go to menu)
            new TestEvent( 9000, SDL.SDL_SCANCODE_SPACE, true),
            new TestEvent( 9200, SDL.SDL_SCANCODE_SPACE, false),
            // ~13s: Press RETURN (select "New Game" in menu)
            new TestEvent(13000, SDL.SDL_SCANCODE_RETURN, true),
            new TestEvent(13200, SDL.SDL_SCANCODE_RETURN, false),
            // ~16s: Press RETURN (select episode)
            new TestEvent(16000, SDL.SDL_SCANCODE_RETURN, true),
            new TestEvent(16200, SDL.SDL_SCANCODE_RETURN, false),
            // ~19s: Press RETURN (select difficulty)
            new TestEvent(19000, SDL.SDL_SCANCODE_RETURN, true),
            new TestEvent(19200, SDL.SDL_SCANCODE_RETURN, false),
            // Sentinel
            new TestEvent(0, SDL.SDL_SCANCODE_UNKNOWN, false),
        };

        public static void VL_CheckTestSequence()
        {
            if (WL_Globals.test_sequence_enabled == 0)
                return;

            if (test_start_time == 0)
                test_start_time = SDL.SDL_GetTicks();

            ulong now = SDL.SDL_GetTicks();
            ulong elapsed = now - test_start_time;

            while (test_next_event < test_events.Length &&
                   (test_events[test_next_event].time_ms > 0 ||
                    test_events[test_next_event].scancode != SDL.SDL_SCANCODE_UNKNOWN))
            {
                if (test_events[test_next_event].time_ms > elapsed)
                    break;

                SDL.SDL_Event ev = new SDL.SDL_Event();
                if (test_events[test_next_event].is_press)
                {
                    ev.key.type = SDL.SDL_EVENT_KEY_DOWN;
                    ev.key.scancode = test_events[test_next_event].scancode;
                    ev.key.key = SDL.SDL_GetKeyFromScancode(test_events[test_next_event].scancode, 0, false);
                    ev.key.down = 1;
                    ev.key.repeat_ = 0;
                }
                else
                {
                    ev.key.type = SDL.SDL_EVENT_KEY_UP;
                    ev.key.scancode = test_events[test_next_event].scancode;
                    ev.key.key = SDL.SDL_GetKeyFromScancode(test_events[test_next_event].scancode, 0, false);
                    ev.key.down = 0;
                    ev.key.repeat_ = 0;
                }
                SDL.SDL_PushEvent(ref ev);
                test_next_event++;
            }
        }

        public static int VL_VideoID()
        {
            return 5;   // Always report VGA present
        }

        public static void VL_SetCRTC(int crtc)
        {
            // No-op for SDL3
        }

        public static void VL_SetScreen(int crtc, int pel)
        {
            WL_Globals.displayofs = crtc;
            WL_Globals.pelpan = pel;
        }

        public static void VL_WaitVBL(int vbls)
        {
            if (vbls > 0)
                SDL.SDL_Delay((uint)(vbls * 14));

            if (WL_Globals.quit_after_ms > 0 && WL_Globals.quit_after_start > 0)
            {
                if (SDL.SDL_GetTicks() - WL_Globals.quit_after_start >= WL_Globals.quit_after_ms)
                {
                    VL_Shutdown();
                    Environment.Exit(0);
                }
            }
        }

        public static void VL_Startup()
        {
            if (WL_Globals.sdl_window != IntPtr.Zero)
                return;

            if (!SDL.SDL_Init(SDL.SDL_INIT_VIDEO | SDL.SDL_INIT_AUDIO))
            {
                WlMain.Quit("SDL_Init(VIDEO|AUDIO) failed!");
            }

            WL_Globals.sdl_window = SDL.SDL_CreateWindow("Wolfenstein 3-D",
                320 * 3, 200 * 3, 0);
            if (WL_Globals.sdl_window == IntPtr.Zero)
                WlMain.Quit("SDL_CreateWindow failed!");

            WL_Globals.sdl_renderer = SDL.SDL_CreateRenderer(WL_Globals.sdl_window, IntPtr.Zero);
            if (WL_Globals.sdl_renderer == IntPtr.Zero)
                WlMain.Quit("SDL_CreateRenderer failed!");

            SDL.SDL_SetRenderLogicalPresentation(WL_Globals.sdl_renderer, 320, 200,
                SDL.SDL_LOGICAL_PRESENTATION_LETTERBOX);

            WL_Globals.sdl_texture = SDL.SDL_CreateTexture(WL_Globals.sdl_renderer,
                SDL.SDL_PIXELFORMAT_XRGB8888, SDL.SDL_TEXTUREACCESS_STREAMING,
                320, 200);
            if (WL_Globals.sdl_texture == IntPtr.Zero)
                WlMain.Quit("SDL_CreateTexture failed!");

            SDL.SDL_SetTextureScaleMode(WL_Globals.sdl_texture, SDL.SDL_SCALEMODE_NEAREST);

            Array.Clear(WL_Globals.sdl_screenbuf, 0, WL_Globals.sdl_screenbuf.Length);
            Array.Clear(WL_Globals.sdl_palette, 0, WL_Globals.sdl_palette.Length);

            if (WL_Globals.quit_after_ms > 0)
            {
                WL_Globals.quit_after_start = SDL.SDL_GetTicks();
            }
        }

        public static void VL_Shutdown()
        {
            if (WL_Globals.sdl_texture != IntPtr.Zero)
            {
                SDL.SDL_DestroyTexture(WL_Globals.sdl_texture);
                WL_Globals.sdl_texture = IntPtr.Zero;
            }
            if (WL_Globals.sdl_renderer != IntPtr.Zero)
            {
                SDL.SDL_DestroyRenderer(WL_Globals.sdl_renderer);
                WL_Globals.sdl_renderer = IntPtr.Zero;
            }
            if (WL_Globals.sdl_window != IntPtr.Zero)
            {
                SDL.SDL_DestroyWindow(WL_Globals.sdl_window);
                WL_Globals.sdl_window = IntPtr.Zero;
            }
            SDL.SDL_Quit();
        }

        public static void VL_SetVGAPlaneMode()
        {
            if (WL_Globals.sdl_window == IntPtr.Zero)
                VL_Startup();
            VL_DePlaneVGA();
            VL_SetLineWidth(40);
        }

        public static void VL_SetVGAPlane()
        {
            // No-op
        }

        public static void VL_SetTextMode()
        {
            // No-op
        }

        public static void VL_ClearVideo(byte color)
        {
            for (int i = 0; i < WL_Globals.sdl_screenbuf.Length; i++)
                WL_Globals.sdl_screenbuf[i] = color;
            for (int i = 0; i < WL_Globals.latchmem.Length; i++)
                WL_Globals.latchmem[i] = color;
        }

        public static void VL_DePlaneVGA()
        {
            VL_ClearVideo(0);
        }

        public static void VL_SetLineWidth(int width)
        {
            WL_Globals.linewidth = width * 2;
            int offset = 0;
            for (int i = 0; i < WolfConstants.MAXSCANLINES; i++)
            {
                WL_Globals.ylookup[i] = offset;
                offset += WL_Globals.linewidth;
            }
        }

        public static void VL_SetSplitScreen(int linenum)
        {
            // No-op
        }

        // =========================================================================
        //  Palette operations
        // =========================================================================

        public static void VL_FillPalette(int red, int green, int blue)
        {
            for (int i = 0; i < 256; i++)
            {
                WL_Globals.sdl_palette[i * 3 + 0] = (byte)red;
                WL_Globals.sdl_palette[i * 3 + 1] = (byte)green;
                WL_Globals.sdl_palette[i * 3 + 2] = (byte)blue;
            }
        }

        public static void VL_SetColor(int color, int red, int green, int blue)
        {
            WL_Globals.sdl_palette[color * 3 + 0] = (byte)red;
            WL_Globals.sdl_palette[color * 3 + 1] = (byte)green;
            WL_Globals.sdl_palette[color * 3 + 2] = (byte)blue;
        }

        public static void VL_GetColor(int color, out int red, out int green, out int blue)
        {
            red = WL_Globals.sdl_palette[color * 3 + 0];
            green = WL_Globals.sdl_palette[color * 3 + 1];
            blue = WL_Globals.sdl_palette[color * 3 + 2];
        }

        public static void VL_SetPalette(byte[] palette)
        {
            Array.Copy(palette, 0, WL_Globals.sdl_palette, 0, 768);
        }

        public static void VL_GetPalette(byte[] palette)
        {
            Array.Copy(WL_Globals.sdl_palette, 0, palette, 0, 768);
        }

        public static void VL_FadeOut(int start, int end, int red, int green, int blue, int steps)
        {
            int i, j, orig, delta;

            VL_WaitVBL(1);
            VL_GetPalette(Flatten2D(palette1));
            Copy2D(palette1, palette2);

            for (i = 0; i < steps; i++)
            {
                for (j = start; j <= end; j++)
                {
                    orig = palette1[j, 0];
                    delta = red - orig;
                    palette2[j, 0] = (byte)(orig + delta * i / steps);

                    orig = palette1[j, 1];
                    delta = green - orig;
                    palette2[j, 1] = (byte)(orig + delta * i / steps);

                    orig = palette1[j, 2];
                    delta = blue - orig;
                    palette2[j, 2] = (byte)(orig + delta * i / steps);
                }

                VL_WaitVBL(1);
                VL_SetPalette(Flatten2D(palette2));
                VL_UpdateScreen();
            }

            VL_FillPalette(red, green, blue);
            WL_Globals.screenfaded = true;
        }

        public static void VL_FadeIn(int start, int end, byte[] palette, int steps)
        {
            int i, j, delta;

            VL_WaitVBL(1);
            byte[] flat1 = Flatten2D(palette1);
            VL_GetPalette(flat1);
            Unflatten2D(flat1, palette1);
            Copy2D(palette1, palette2);

            int s3 = start * 3;
            int e3 = end * 3 + 2;

            for (i = 0; i < steps; i++)
            {
                for (j = s3; j <= e3; j++)
                {
                    byte p1val = palette1[j / 3, j % 3];
                    delta = palette[j] - p1val;
                    palette2[j / 3, j % 3] = (byte)(p1val + delta * i / steps);
                }

                VL_WaitVBL(1);
                VL_SetPalette(Flatten2D(palette2));
                VL_UpdateScreen();
            }

            VL_SetPalette(palette);
            WL_Globals.screenfaded = false;
        }

        // Convenience overloads for VL_FadeOut/VL_FadeIn with no args
        public static void VL_FadeOut()
        {
            VL_FadeOut(0, 255, 0, 0, 0, 30);
        }

        public static void VL_FadeIn()
        {
            VL_FadeIn(0, 255, IdVh.gamepal, 30);
        }

        public static void VL_TestPaletteSet()
        {
            fastpalette = true;
        }

        public static void VL_ColorBorder(int color)
        {
            WL_Globals.bordercolor = color;
        }

        // =========================================================================
        //  Pixel operations
        // =========================================================================

        public static void VL_Plot(int x, int y, int color)
        {
            if (x >= 0 && x < 320 && y >= 0 && y < 200)
                WL_Globals.sdl_screenbuf[y * 320 + x] = (byte)color;
        }

        public static void VL_Hlin(int x, int y, int width, int color)
        {
            if (y < 0 || y >= 200) return;
            if (x < 0) { width += x; x = 0; }
            if (x >= 320) return;
            if (x + width > 320) width = 320 - x;
            if (width <= 0) return;
            for (int i = 0; i < width; i++)
                WL_Globals.sdl_screenbuf[y * 320 + x + i] = (byte)color;
        }

        public static void VL_Vlin(int x, int y, int height, int color)
        {
            if (x < 0 || x >= 320) return;
            if (y < 0) { height += y; y = 0; }
            if (y + height > 200) height = 200 - y;

            int offset = y * 320 + x;
            while (height-- > 0)
            {
                WL_Globals.sdl_screenbuf[offset] = (byte)color;
                offset += 320;
            }
        }

        public static void VL_Bar(int x, int y, int width, int height, int color)
        {
            if (x < 0) { width += x; x = 0; }
            if (y < 0) { height += y; y = 0; }
            if (x + width > 320) width = 320 - x;
            if (y + height > 200) height = 200 - y;
            if (width <= 0 || height <= 0) return;

            int offset = y * 320 + x;
            for (int row = 0; row < height; row++)
            {
                for (int col = 0; col < width; col++)
                    WL_Globals.sdl_screenbuf[offset + col] = (byte)color;
                offset += 320;
            }
        }

        // =========================================================================
        //  Memory operations
        // =========================================================================

        public static void VL_MemToLatch(byte[] source, int srcOffset, int width, int height, int dest)
        {
            int pwidth = (width + 3) / 4;
            int linearbase = dest * 4;

            if (linearbase + width * height <= WL_Globals.LATCH_MEM_SIZE)
                Array.Clear(WL_Globals.latchmem, linearbase, width * height);

            int si = srcOffset;
            for (int plane = 0; plane < 4; plane++)
            {
                for (int y = 0; y < height; y++)
                {
                    for (int x = 0; x < pwidth; x++)
                    {
                        int px = x * 4 + plane;
                        int idx = linearbase + y * width + px;
                        if (px < width && idx >= 0 && idx < WL_Globals.LATCH_MEM_SIZE && si >= 0 && si < source.Length)
                            WL_Globals.latchmem[idx] = source[si];
                        si++;
                    }
                }
            }
        }

        public static void VL_MemToScreen(byte[] source, int width, int height, int x, int y)
        {
            VL_MemToScreen(source, 0, width, height, x, y);
        }

        public static void VL_MemToScreen(byte[] source, int srcOffset, int width, int height, int x, int y)
        {
            int pwidth = width >> 2;
            int si = srcOffset;
            int startplane = x & 3;

            for (int plane = 0; plane < 4; plane++)
            {
                int curplane = (startplane + plane) & 3;
                for (int py = 0; py < height; py++)
                {
                    for (int px = 0; px < pwidth; px++)
                    {
                        int screenx = ((x >> 2) + px) * 4 + curplane;
                        int screeny = y + py;
                        if (screenx >= 0 && screenx < 320 && screeny >= 0 && screeny < 200)
                            WL_Globals.sdl_screenbuf[screeny * 320 + screenx] = source[si + px];
                    }
                    si += pwidth;
                }
            }
        }

        public static void VL_MaskedToScreen(byte[] source, int width, int height, int x, int y)
        {
            int pwidth = width >> 2;
            int si = 0;
            int startplane = x & 3;

            for (int plane = 0; plane < 4; plane++)
            {
                int curplane = (startplane + plane) & 3;
                for (int py = 0; py < height; py++)
                {
                    for (int px = 0; px < pwidth; px++)
                    {
                        int screenx = ((x >> 2) + px) * 4 + curplane;
                        int screeny = y + py;
                        byte val = source[si + px];
                        if (val != 0 && screenx >= 0 && screenx < 320 && screeny >= 0 && screeny < 200)
                            WL_Globals.sdl_screenbuf[screeny * 320 + screenx] = val;
                    }
                    si += pwidth;
                }
            }
        }

        public static void VL_LatchToScreen(int source, int width, int height, int x, int y)
        {
            int pixwidth = width * 4;
            int linearbase = source * 4;

            int within_page = WL_Globals.bufferofs % (WolfConstants.SCREENWIDTH * 208);
            int buf_y = (WL_Globals.linewidth > 0) ? within_page / WL_Globals.linewidth : 0;
            int buf_x = (WL_Globals.linewidth > 0) ? (within_page % WL_Globals.linewidth) * 4 : 0;

            x += buf_x;
            y += buf_y;

            int si = linearbase;
            for (int sy = 0; sy < height; sy++)
            {
                int screeny = y + sy;
                if (screeny < 0 || screeny >= 200)
                {
                    si += pixwidth;
                    continue;
                }
                for (int sx = 0; sx < pixwidth && (x + sx) < 320; sx++)
                {
                    if (x + sx >= 0 && si + sx < WL_Globals.LATCH_MEM_SIZE)
                        WL_Globals.sdl_screenbuf[screeny * 320 + x + sx] = WL_Globals.latchmem[si + sx];
                }
                si += pixwidth;
            }
        }

        public static void VL_ScreenToScreen(int source, int dest, int width, int height)
        {
            for (int y = 0; y < height; y++)
            {
                int src_planar = source + y * WL_Globals.linewidth;
                int dst_planar = dest + y * WL_Globals.linewidth;

                int src_row = (WL_Globals.linewidth > 0) ? src_planar / WL_Globals.linewidth : 0;
                int src_col = (WL_Globals.linewidth > 0) ? src_planar % WL_Globals.linewidth : 0;
                int dst_row = (WL_Globals.linewidth > 0) ? dst_planar / WL_Globals.linewidth : 0;
                int dst_col = (WL_Globals.linewidth > 0) ? dst_planar % WL_Globals.linewidth : 0;

                int src_linear = src_row * 320 + src_col * 4;
                int dst_linear = dst_row * 320 + dst_col * 4;
                int pixwidth = width * 4;

                if (src_linear >= 0 && dst_linear >= 0 &&
                    src_linear + pixwidth <= 320 * 200 &&
                    dst_linear + pixwidth <= 320 * 200)
                {
                    Array.Copy(WL_Globals.sdl_screenbuf, src_linear,
                              WL_Globals.sdl_screenbuf, dst_linear, pixwidth);
                }
            }
        }

        // =========================================================================
        //  String output
        // =========================================================================

        public static void VL_DrawTile8String(string str, byte[] tile8ptr, int printx, int printy)
        {
            foreach (char ch in str)
            {
                int si = ch << 6;  // 64 bytes per char

                for (int plane = 0; plane < 4; plane++)
                {
                    for (int row = 0; row < 8; row++)
                    {
                        int screeny = printy + row;
                        if (screeny >= 0 && screeny < 200)
                        {
                            int x0 = printx + plane;
                            int x1 = printx + plane + 4;

                            if (x0 >= 0 && x0 < 320 && si < tile8ptr.Length)
                                WL_Globals.sdl_screenbuf[screeny * 320 + x0] = tile8ptr[si];
                            if (x1 >= 0 && x1 < 320 && si + 1 < tile8ptr.Length)
                                WL_Globals.sdl_screenbuf[screeny * 320 + x1] = tile8ptr[si + 1];
                        }
                        si += 2;
                    }
                }
                printx += 8;
            }
        }

        public static void VL_DrawLatch8String(string str, int tile8ptr, int printx, int printy)
        {
            foreach (char ch in str)
            {
                int planar_src = tile8ptr + (ch << 4);
                int linear_src = planar_src * 4;

                for (int row = 0; row < 8; row++)
                {
                    int screeny = printy + row;
                    if (screeny >= 0 && screeny < 200)
                    {
                        for (int col = 0; col < 8; col++)
                        {
                            int screenx = printx + col;
                            if (screenx >= 0 && screenx < 320)
                            {
                                int idx = linear_src + row * 8 + col;
                                if (idx >= 0 && idx < WL_Globals.LATCH_MEM_SIZE)
                                    WL_Globals.sdl_screenbuf[screeny * 320 + screenx] = WL_Globals.latchmem[idx];
                            }
                        }
                    }
                }
                printx += 8;
            }
        }

        public static void VL_SizeTile8String(string str, out int width, out int height)
        {
            height = 8;
            width = 8 * str.Length;
        }

        // =========================================================================
        //  MungePic
        // =========================================================================

        public static void VL_MungePic(byte[] source, int width, int height)
        {
            int size = width * height;
            if ((width & 3) != 0)
                WlMain.Quit("VL_MungePic: Not divisable by 4!");

            byte[] temp = new byte[size];
            Array.Copy(source, temp, size);

            int dest = 0;
            int pwidth = width / 4;

            for (int plane = 0; plane < 4; plane++)
            {
                int srcline = 0;
                for (int y = 0; y < height; y++)
                {
                    for (int x = 0; x < pwidth; x++)
                        source[dest++] = temp[srcline + x * 4 + plane];
                    srcline += width;
                }
            }
        }

        // =========================================================================
        //  Screen update - upload sdl_screenbuf to texture
        // =========================================================================

        public static unsafe void VL_UpdateScreen()
        {
            if (WL_Globals.sdl_texture == IntPtr.Zero || WL_Globals.sdl_renderer == IntPtr.Zero)
                return;

            IntPtr rawpixels;
            int pitch;

            if (!SDL.SDL_LockTexture(WL_Globals.sdl_texture, IntPtr.Zero, out rawpixels, out pitch))
                return;

            // Convert 8-bit indexed color to XRGB8888
            byte* pixPtr = (byte*)rawpixels;
            for (int y = 0; y < 200; y++)
            {
                uint* row = (uint*)(pixPtr + y * pitch);
                for (int x = 0; x < 320; x++)
                {
                    byte idx = WL_Globals.sdl_screenbuf[y * 320 + x];
                    byte r = (byte)(WL_Globals.sdl_palette[idx * 3 + 0] * 255 / 63);
                    byte g = (byte)(WL_Globals.sdl_palette[idx * 3 + 1] * 255 / 63);
                    byte b = (byte)(WL_Globals.sdl_palette[idx * 3 + 2] * 255 / 63);
                    row[x] = ((uint)r << 16) | ((uint)g << 8) | (uint)b;
                }
            }

            SDL.SDL_UnlockTexture(WL_Globals.sdl_texture);
            SDL.SDL_RenderClear(WL_Globals.sdl_renderer);
            SDL.SDL_RenderTexture(WL_Globals.sdl_renderer, WL_Globals.sdl_texture, IntPtr.Zero, IntPtr.Zero);
            SDL.SDL_RenderPresent(WL_Globals.sdl_renderer);

            // Frame capture: save current frame as BMP if enabled
            if (WL_Globals.capture_enabled == 1)
            {
                IntPtr surf = SDL.SDL_CreateSurface(320, 200, SDL.SDL_PIXELFORMAT_XRGB8888);
                if (surf != IntPtr.Zero)
                {
                    // Read the SDL_Surface struct to get pixels pointer and pitch
                    SDL.SDL_Surface surfStruct = Marshal.PtrToStructure<SDL.SDL_Surface>(surf);

                    SDL.SDL_LockSurface(surf);
                    for (int sy = 0; sy < 200; sy++)
                    {
                        uint* dst = (uint*)((byte*)surfStruct.pixels + sy * surfStruct.pitch);
                        for (int sx = 0; sx < 320; sx++)
                        {
                            byte idx2 = WL_Globals.sdl_screenbuf[sy * 320 + sx];
                            byte cr = (byte)(WL_Globals.sdl_palette[idx2 * 3 + 0] * 255 / 63);
                            byte cg = (byte)(WL_Globals.sdl_palette[idx2 * 3 + 1] * 255 / 63);
                            byte cb = (byte)(WL_Globals.sdl_palette[idx2 * 3 + 2] * 255 / 63);
                            dst[sx] = ((uint)cr << 16) | ((uint)cg << 8) | (uint)cb;
                        }
                    }
                    SDL.SDL_UnlockSurface(surf);

                    string path = string.Format("captures/frame_{0:D5}.bmp", WL_Globals.capture_frame);
                    SDL.SDL_SaveBMP(surf, path);
                    SDL.SDL_DestroySurface(surf);

                    if (WL_Globals.capture_limit > 0 && (WL_Globals.capture_frame + 1) >= WL_Globals.capture_limit)
                    {
                        WL_Globals.capture_frame++;
                        VL_Shutdown();
                        Environment.Exit(0);
                    }
                }
            }

            // Always increment frame counter
            WL_Globals.capture_frame++;

            // Inject test sequence key events (time-based)
            VL_CheckTestSequence();

            // Auto-quit timer
            if (WL_Globals.quit_after_ms > 0)
            {
                if (WL_Globals.quit_after_start == 0)
                    WL_Globals.quit_after_start = SDL.SDL_GetTicks();
                else if (SDL.SDL_GetTicks() - WL_Globals.quit_after_start >= WL_Globals.quit_after_ms)
                {
                    VL_Shutdown();
                    Environment.Exit(0);
                }
            }
        }

        // =========================================================================
        //  Helper methods for palette 2D arrays
        // =========================================================================

        private static byte[] Flatten2D(byte[,] arr)
        {
            byte[] flat = new byte[768];
            for (int i = 0; i < 256; i++)
            {
                flat[i * 3 + 0] = arr[i, 0];
                flat[i * 3 + 1] = arr[i, 1];
                flat[i * 3 + 2] = arr[i, 2];
            }
            return flat;
        }

        private static void Unflatten2D(byte[] flat, byte[,] arr)
        {
            for (int i = 0; i < 256; i++)
            {
                arr[i, 0] = flat[i * 3 + 0];
                arr[i, 1] = flat[i * 3 + 1];
                arr[i, 2] = flat[i * 3 + 2];
            }
        }

        private static void Copy2D(byte[,] src, byte[,] dst)
        {
            Array.Copy(src, dst, src.Length);
        }
    }
}
