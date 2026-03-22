// SDL3.cs - Minimal SDL3 P/Invoke bindings for Wolf3D
// Only the functions actually used by the game are bound here.

using System;
using System.Runtime.InteropServices;

namespace Wolf3D
{
    public static class SDL
    {
        private const string lib = "SDL3";

        // --- Init ---
        public const uint SDL_INIT_VIDEO = 0x00000020;
        public const uint SDL_INIT_AUDIO = 0x00000010;

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool SDL_Init(uint flags);

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern void SDL_Quit();

        // --- Window ---
        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern IntPtr SDL_CreateWindow(
            [MarshalAs(UnmanagedType.LPUTF8Str)] string title,
            int w, int h, uint flags);

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern void SDL_DestroyWindow(IntPtr window);

        // --- Renderer ---
        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern IntPtr SDL_CreateRenderer(IntPtr window, IntPtr name);

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern void SDL_DestroyRenderer(IntPtr renderer);

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool SDL_SetRenderLogicalPresentation(
            IntPtr renderer, int w, int h, int mode);

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool SDL_RenderClear(IntPtr renderer);

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool SDL_RenderTexture(
            IntPtr renderer, IntPtr texture, IntPtr srcrect, IntPtr dstrect);

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool SDL_RenderPresent(IntPtr renderer);

        // Logical presentation modes
        public const int SDL_LOGICAL_PRESENTATION_LETTERBOX = 1;

        // --- Texture ---
        public const uint SDL_PIXELFORMAT_XRGB8888 = 0x16161804; // SDL_PIXELFORMAT_XRGB8888
        public const int SDL_TEXTUREACCESS_STREAMING = 1;

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern IntPtr SDL_CreateTexture(
            IntPtr renderer, uint format, int access, int w, int h);

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern void SDL_DestroyTexture(IntPtr texture);

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool SDL_SetTextureScaleMode(IntPtr texture, int scaleMode);

        public const int SDL_SCALEMODE_NEAREST = 0;

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool SDL_LockTexture(
            IntPtr texture, IntPtr rect, out IntPtr pixels, out int pitch);

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern void SDL_UnlockTexture(IntPtr texture);

        // --- Events ---
        public const uint SDL_EVENT_QUIT = 0x100;
        public const uint SDL_EVENT_KEY_DOWN = 0x300;
        public const uint SDL_EVENT_KEY_UP = 0x301;
        public const uint SDL_EVENT_MOUSE_MOTION = 0x400;
        public const uint SDL_EVENT_MOUSE_BUTTON_DOWN = 0x401;
        public const uint SDL_EVENT_MOUSE_BUTTON_UP = 0x402;

        // SDL_Scancode values (DOS scancode mapping done in ID_IN)
        public const int SDL_SCANCODE_UNKNOWN = 0;
        public const int SDL_SCANCODE_A = 4;
        public const int SDL_SCANCODE_RETURN = 40;
        public const int SDL_SCANCODE_ESCAPE = 41;
        public const int SDL_SCANCODE_SPACE = 44;

        [StructLayout(LayoutKind.Sequential)]
        public struct SDL_KeyboardEvent
        {
            public uint type;
            public uint reserved;
            public ulong timestamp;
            public uint windowID;
            public uint which;
            public int scancode;
            public uint key;
            public ushort mod;
            public ushort raw;
            public byte down;
            public byte repeat_;
        }

        // Generic event - we'll use a byte array and reinterpret
        [StructLayout(LayoutKind.Explicit, Size = 128)]
        public struct SDL_Event
        {
            [FieldOffset(0)] public uint type;
            [FieldOffset(0)] public SDL_KeyboardEvent key;
        }

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool SDL_PollEvent(out SDL_Event e);

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool SDL_PushEvent(ref SDL_Event e);

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern uint SDL_GetKeyFromScancode(int scancode, ushort modstate, bool key_event);

        // --- Timer ---
        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern ulong SDL_GetTicks();

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern void SDL_Delay(uint ms);

        // --- Mouse ---
        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern uint SDL_GetMouseState(out float x, out float y);

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern uint SDL_GetRelativeMouseState(out float x, out float y);

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool SDL_SetRelativeMouseMode(bool enabled);

        // --- Audio ---
        public const int SDL_AUDIO_S16 = 0x8010;

        [StructLayout(LayoutKind.Sequential)]
        public struct SDL_AudioSpec
        {
            public int format;
            public int channels;
            public int freq;
        }

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern uint SDL_OpenAudioDevice(uint devid, ref SDL_AudioSpec spec);

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern IntPtr SDL_CreateAudioStream(ref SDL_AudioSpec src_spec, ref SDL_AudioSpec dst_spec);

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool SDL_PutAudioStreamData(IntPtr stream, IntPtr buf, int len);

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool SDL_BindAudioStream(uint devid, IntPtr stream);

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern void SDL_DestroyAudioStream(IntPtr stream);

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern int SDL_GetAudioStreamQueued(IntPtr stream);

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool SDL_ResumeAudioDevice(uint dev);

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern void SDL_CloseAudioDevice(uint dev);

        // --- Surface (for frame capture) ---
        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern IntPtr SDL_CreateSurface(int width, int height, uint format);

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool SDL_LockSurface(IntPtr surface);

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern void SDL_UnlockSurface(IntPtr surface);

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern bool SDL_SaveBMP(IntPtr surface, [MarshalAs(UnmanagedType.LPUTF8Str)] string file);

        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern void SDL_DestroySurface(IntPtr surface);

        [StructLayout(LayoutKind.Sequential)]
        public struct SDL_Surface
        {
            public uint flags;
            public uint format;
            public int w;
            public int h;
            public int pitch;
            public IntPtr pixels;
        }

        // --- Error ---
        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern IntPtr SDL_GetError();

        public static string GetError()
        {
            return Marshal.PtrToStringUTF8(SDL_GetError()) ?? "";
        }

        // --- Log ---
        [DllImport(lib, CallingConvention = CallingConvention.Cdecl)]
        public static extern void SDL_Log([MarshalAs(UnmanagedType.LPUTF8Str)] string fmt);
    }
}
