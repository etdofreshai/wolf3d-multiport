// ID_IN.C -> IdIn.cs
// Input Manager - SDL3 keyboard, mouse, joystick handling

using System;

namespace Wolf3D
{
    public static class IdIn
    {
        private const int JoyScaleMax = 32768;
        private const int JoyScaleShift = 8;
        private const int MaxJoyValue = 5000;

        private static bool IN_Started;
        private static bool CapsLock;
        private static byte CurCode, LastCode;
        private static Action INL_KeyHook;

        // Unshifted ASCII for scan codes
        private static readonly byte[] ASCIINames = {
            0, 27,(byte)'1',(byte)'2',(byte)'3',(byte)'4',(byte)'5',(byte)'6',(byte)'7',(byte)'8',(byte)'9',(byte)'0',(byte)'-',(byte)'=',8,9,
            (byte)'q',(byte)'w',(byte)'e',(byte)'r',(byte)'t',(byte)'y',(byte)'u',(byte)'i',(byte)'o',(byte)'p',(byte)'[',(byte)']',13,0,(byte)'a',(byte)'s',
            (byte)'d',(byte)'f',(byte)'g',(byte)'h',(byte)'j',(byte)'k',(byte)'l',(byte)';',39,(byte)'`',0,92,(byte)'z',(byte)'x',(byte)'c',(byte)'v',
            (byte)'b',(byte)'n',(byte)'m',(byte)',',(byte)'.',(byte)'/',0,(byte)'*',0,(byte)' ',0,0,0,0,0,0,
            0,0,0,0,0,0,0,(byte)'7',(byte)'8',(byte)'9',(byte)'-',(byte)'4',(byte)'5',(byte)'6',(byte)'+',(byte)'1',
            (byte)'2',(byte)'3',(byte)'0',127,0,0,0,0,0,0,0,0,0,0,0,0,
            0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
            0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        };

        private static readonly byte[] ShiftNames = {
            0,27,(byte)'!',(byte)'@',(byte)'#',(byte)'$',(byte)'%',(byte)'^',(byte)'&',(byte)'*',(byte)'(',(byte)')',(byte)'_',(byte)'+',8,9,
            (byte)'Q',(byte)'W',(byte)'E',(byte)'R',(byte)'T',(byte)'Y',(byte)'U',(byte)'I',(byte)'O',(byte)'P',(byte)'{',(byte)'}',13,0,(byte)'A',(byte)'S',
            (byte)'D',(byte)'F',(byte)'G',(byte)'H',(byte)'J',(byte)'K',(byte)'L',(byte)':',34,(byte)'~',0,(byte)'|',(byte)'Z',(byte)'X',(byte)'C',(byte)'V',
            (byte)'B',(byte)'N',(byte)'M',(byte)'<',(byte)'>',(byte)'?',0,(byte)'*',0,(byte)' ',0,0,0,0,0,0,
            0,0,0,0,0,0,0,(byte)'7',(byte)'8',(byte)'9',(byte)'-',(byte)'4',(byte)'5',(byte)'6',(byte)'+',(byte)'1',
            (byte)'2',(byte)'3',(byte)'0',127,0,0,0,0,0,0,0,0,0,0,0,0,
            0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
            0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        };

        private static readonly Direction[] DirTable = {
            Direction.dir_NorthWest, Direction.dir_North, Direction.dir_NorthEast,
            Direction.dir_West,      Direction.dir_None,  Direction.dir_East,
            Direction.dir_SouthWest, Direction.dir_South, Direction.dir_SouthEast
        };

        // Scancode to acknowledge tracking
        private static bool ack_started;
        private static bool[] ack_keyboard = new bool[WolfConstants.NumCodes];
        private static bool ack_mousebuttons;

        // =========================================================================
        //  SDL scancode to DOS scancode mapping
        // =========================================================================

        private static byte INL_SDLScanCodeToScanCode(int sdl_sc)
        {
            // SDL3 scancode values (from SDL_scancode.h)
            switch (sdl_sc)
            {
                case 41: return ScanCodes.sc_Escape;
                case 30: return ScanCodes.sc_1;    // SDL_SCANCODE_1 = 30
                case 31: return ScanCodes.sc_2;
                case 32: return ScanCodes.sc_3;
                case 33: return ScanCodes.sc_4;
                case 34: return ScanCodes.sc_5;
                case 35: return ScanCodes.sc_6;
                case 36: return ScanCodes.sc_7;
                case 37: return ScanCodes.sc_8;
                case 38: return ScanCodes.sc_9;
                case 39: return ScanCodes.sc_0;
                case 45: return 0x0c; // minus
                case 46: return 0x0d; // equals
                case 42: return ScanCodes.sc_BackSpace;
                case 43: return ScanCodes.sc_Tab;
                case 20: return ScanCodes.sc_Q;
                case 26: return ScanCodes.sc_W;
                case 8:  return ScanCodes.sc_E;
                case 21: return ScanCodes.sc_R;
                case 23: return ScanCodes.sc_T;
                case 28: return ScanCodes.sc_Y;
                case 24: return ScanCodes.sc_U;
                case 12: return ScanCodes.sc_I;
                case 18: return ScanCodes.sc_O;
                case 19: return ScanCodes.sc_P;
                case 47: return 0x1a; // left bracket
                case 48: return 0x1b; // right bracket
                case 40: return ScanCodes.sc_Return;
                case 224: return ScanCodes.sc_Control; // LCTRL
                case 228: return ScanCodes.sc_Control; // RCTRL
                case 4:  return ScanCodes.sc_A;
                case 22: return ScanCodes.sc_S;
                case 7:  return ScanCodes.sc_D;
                case 9:  return ScanCodes.sc_F;
                case 10: return ScanCodes.sc_G;
                case 11: return ScanCodes.sc_H;
                case 13: return ScanCodes.sc_J;
                case 14: return ScanCodes.sc_K;
                case 15: return ScanCodes.sc_L;
                case 51: return 0x27; // semicolon
                case 52: return 0x28; // apostrophe
                case 53: return 0x29; // grave
                case 225: return ScanCodes.sc_LShift;
                case 49: return 0x2b; // backslash
                case 29: return ScanCodes.sc_Z;
                case 27: return ScanCodes.sc_X;
                case 6:  return ScanCodes.sc_C;
                case 25: return ScanCodes.sc_V;
                case 5:  return ScanCodes.sc_B;
                case 17: return ScanCodes.sc_N;
                case 16: return ScanCodes.sc_M;
                case 54: return 0x33; // comma
                case 55: return 0x34; // period
                case 56: return 0x35; // slash
                case 229: return ScanCodes.sc_RShift;
                case 226: return ScanCodes.sc_Alt;  // LALT
                case 230: return ScanCodes.sc_Alt;  // RALT
                case 44: return ScanCodes.sc_Space;
                case 57: return ScanCodes.sc_CapsLock;
                case 58: return ScanCodes.sc_F1;
                case 59: return ScanCodes.sc_F2;
                case 60: return ScanCodes.sc_F3;
                case 61: return ScanCodes.sc_F4;
                case 62: return ScanCodes.sc_F5;
                case 63: return ScanCodes.sc_F6;
                case 64: return ScanCodes.sc_F7;
                case 65: return ScanCodes.sc_F8;
                case 66: return ScanCodes.sc_F9;
                case 67: return ScanCodes.sc_F10;
                case 68: return ScanCodes.sc_F11;
                case 69: return ScanCodes.sc_F12;
                case 74: return ScanCodes.sc_Home;
                case 82: return ScanCodes.sc_UpArrow;
                case 75: return ScanCodes.sc_PgUp;
                case 80: return ScanCodes.sc_LeftArrow;
                case 79: return ScanCodes.sc_RightArrow;
                case 77: return ScanCodes.sc_End;
                case 81: return ScanCodes.sc_DownArrow;
                case 78: return ScanCodes.sc_PgDn;
                case 73: return ScanCodes.sc_Insert;
                case 76: return ScanCodes.sc_Delete;
                // Keypad
                case 95: return ScanCodes.sc_Home;
                case 96: return ScanCodes.sc_UpArrow;
                case 97: return ScanCodes.sc_PgUp;
                case 92: return ScanCodes.sc_LeftArrow;
                case 94: return ScanCodes.sc_RightArrow;
                case 89: return ScanCodes.sc_End;
                case 90: return ScanCodes.sc_DownArrow;
                case 91: return ScanCodes.sc_PgDn;
                case 98: return ScanCodes.sc_Return; // KP_ENTER
                default: return ScanCodes.sc_None;
            }
        }

        // =========================================================================
        //  Event processing
        // =========================================================================

        public static void IN_ProcessEvents()
        {
            SDL.SDL_Event ev;

            while (SDL.SDL_PollEvent(out ev))
            {
                switch (ev.type)
                {
                    case SDL.SDL_EVENT_KEY_DOWN:
                        if (ev.key.repeat_ != 0)
                            break;

                        byte k = INL_SDLScanCodeToScanCode(ev.key.scancode);

                        if (k != ScanCodes.sc_None && k < WolfConstants.NumCodes)
                        {
                            LastCode = CurCode;
                            CurCode = k;
                            WL_Globals.LastScan = k;
                            WL_Globals.Keyboard[k] = true;

                            if (k == ScanCodes.sc_CapsLock)
                                CapsLock = !CapsLock;

                            byte c;
                            if (WL_Globals.Keyboard[ScanCodes.sc_LShift] || WL_Globals.Keyboard[ScanCodes.sc_RShift])
                            {
                                c = k < ShiftNames.Length ? ShiftNames[k] : (byte)0;
                                if (c >= 'A' && c <= 'Z' && CapsLock) c += (byte)('a' - 'A');
                            }
                            else
                            {
                                c = k < ASCIINames.Length ? ASCIINames[k] : (byte)0;
                                if (c >= 'a' && c <= 'z' && CapsLock) c -= (byte)('a' - 'A');
                            }
                            if (c != 0) WL_Globals.LastASCII = (char)c;
                        }

                        INL_KeyHook?.Invoke();
                        break;

                    case SDL.SDL_EVENT_KEY_UP:
                        k = INL_SDLScanCodeToScanCode(ev.key.scancode);
                        if (k != ScanCodes.sc_None && k < WolfConstants.NumCodes)
                            WL_Globals.Keyboard[k] = false;

                        INL_KeyHook?.Invoke();
                        break;

                    case SDL.SDL_EVENT_QUIT:
                        WlMain.Quit(null);
                        break;
                }
            }

            IdSd.SD_TimeCountUpdate();

            // Inject test-sequence events during event processing too
            // (not just during VL_UpdateScreen) so they're picked up by IN_UserInput
            IdVl.VL_CheckTestSequence();
        }

        public static void IN_WaitAndProcessEvents()
        {
            SDL.SDL_Delay(1);
            IN_ProcessEvents();
        }

        // =========================================================================
        //  Startup / Shutdown
        // =========================================================================

        public static void IN_Startup()
        {
            if (IN_Started) return;
            IN_Started = true;

            IN_ClearKeysDown();
            WL_Globals.MousePresent = true;

            WL_Globals.KbdDefs = new KeyboardDef
            {
                button0 = ScanCodes.sc_Control,
                button1 = ScanCodes.sc_Alt,
                upleft = ScanCodes.sc_Home,
                up = ScanCodes.sc_UpArrow,
                upright = ScanCodes.sc_PgUp,
                left = ScanCodes.sc_LeftArrow,
                right = ScanCodes.sc_RightArrow,
                downleft = ScanCodes.sc_End,
                down = ScanCodes.sc_DownArrow,
                downright = ScanCodes.sc_PgDn
            };
        }

        public static void IN_Shutdown()
        {
            if (!IN_Started) return;
            IN_Started = false;
        }

        public static void IN_Default(bool gotit, ControlType type)
        {
            if (gotit)
                WL_Globals.Controls[0] = type;
            else
                WL_Globals.Controls[0] = ControlType.ctrl_Keyboard;
        }

        public static void IN_SetKeyHook(Action hook)
        {
            INL_KeyHook = hook;
        }

        public static void IN_ClearKeysDown()
        {
            WL_Globals.LastScan = ScanCodes.sc_None;
            WL_Globals.LastASCII = '\0';
            Array.Clear(WL_Globals.Keyboard, 0, WL_Globals.Keyboard.Length);
        }

        // =========================================================================
        //  Mouse
        // =========================================================================

        public static byte IN_MouseButtons()
        {
            float fx, fy;
            uint state = SDL.SDL_GetMouseState(out fx, out fy);
            byte buttons = 0;
            if ((state & 1) != 0) buttons |= 1;
            if ((state & 4) != 0) buttons |= 2; // right button = SDL bit 2
            if ((state & 2) != 0) buttons |= 4; // middle button = SDL bit 1
            return buttons;
        }

        public static void IN_GetMouseDelta(out int x, out int y)
        {
            float fx, fy;
            SDL.SDL_GetRelativeMouseState(out fx, out fy);
            x = (int)fx;
            y = (int)fy;
        }

        // =========================================================================
        //  Joystick stubs
        // =========================================================================

        public static byte IN_JoyButtons()
        {
            return 0;
        }

        public static void IN_GetJoyAbs(int joy, out int xp, out int yp)
        {
            xp = 0; yp = 0;
        }

        public static void INL_GetJoyDelta(int joy, out int dx, out int dy)
        {
            dx = 0; dy = 0;
        }

        public static void IN_SetupJoy(int joy, int minx, int maxx, int miny, int maxy)
        {
        }

        public static ushort IN_GetJoyButtonsDB(int joy)
        {
            return 0;
        }

        // =========================================================================
        //  Control reading
        // =========================================================================

        public static void IN_ReadControl(int player, ControlInfo ci)
        {
            bool realdelta = false;
            int dx = 0, dy = 0;

            IN_ProcessEvents();

            // Keyboard
            var def = WL_Globals.KbdDefs;
            if (WL_Globals.Keyboard[def.upleft]) { dx = -1; dy = -1; }
            if (WL_Globals.Keyboard[def.up]) { dy = -1; }
            if (WL_Globals.Keyboard[def.upright]) { dx = 1; dy = -1; }
            if (WL_Globals.Keyboard[def.left]) { dx = -1; }
            if (WL_Globals.Keyboard[def.right]) { dx = 1; }
            if (WL_Globals.Keyboard[def.downleft]) { dx = -1; dy = 1; }
            if (WL_Globals.Keyboard[def.down]) { dy = 1; }
            if (WL_Globals.Keyboard[def.downright]) { dx = 1; dy = 1; }

            ci.button0 = WL_Globals.Keyboard[def.button0];
            ci.button1 = WL_Globals.Keyboard[def.button1];
            ci.button2 = false;
            ci.button3 = false;

            ci.x = dx;
            ci.y = dy;

            // Direction from dx/dy
            int dirIdx = (dy + 1) * 3 + (dx + 1);
            if (dirIdx >= 0 && dirIdx < DirTable.Length)
                ci.dir = DirTable[dirIdx];
            else
                ci.dir = Direction.dir_None;
        }

        public static void IN_ReadCursor(ControlInfo ci)
        {
            IN_ReadControl(0, ci);
        }

        // =========================================================================
        //  Acknowledge/wait functions
        // =========================================================================

        public static void IN_StartAck()
        {
            IN_ProcessEvents();
            Array.Copy(WL_Globals.Keyboard, ack_keyboard, WolfConstants.NumCodes);
            ack_mousebuttons = IN_MouseButtons() != 0;
            ack_started = true;
        }

        public static bool IN_CheckAck()
        {
            IN_ProcessEvents();

            // Check if any new key was pressed
            for (int i = 0; i < WolfConstants.NumCodes; i++)
            {
                if (WL_Globals.Keyboard[i] && !ack_keyboard[i])
                    return true;
            }

            // Check if mouse button was pressed (newly)
            if (!ack_mousebuttons && IN_MouseButtons() != 0)
                return true;

            return false;
        }

        public static void IN_Ack()
        {
            IN_StartAck();
            while (!IN_CheckAck())
            {
                SDL.SDL_Delay(1);
            }
        }

        public static void IN_AckBack()
        {
            // Wait for acknowledgement then clear
            IN_Ack();
            IN_ClearKeysDown();
        }

        public static bool IN_UserInput(uint delay)
        {
            ulong startTime = SDL.SDL_GetTicks();

            IN_StartAck();
            do
            {
                if (IN_CheckAck())
                    return true;
                SDL.SDL_Delay(1);
            } while (SDL.SDL_GetTicks() - startTime < delay);

            return false;
        }

        public static char IN_WaitForASCII()
        {
            WL_Globals.LastASCII = '\0';
            while (WL_Globals.LastASCII == '\0')
            {
                IN_WaitAndProcessEvents();
            }
            char c = WL_Globals.LastASCII;
            WL_Globals.LastASCII = '\0';
            return c;
        }

        public static byte IN_WaitForKey()
        {
            WL_Globals.LastScan = ScanCodes.sc_None;
            while (WL_Globals.LastScan == ScanCodes.sc_None)
            {
                IN_WaitAndProcessEvents();
            }
            byte k = WL_Globals.LastScan;
            WL_Globals.LastScan = ScanCodes.sc_None;
            return k;
        }

        public static byte[] IN_GetScanName(byte scancode)
        {
            // Return scan code name - stub
            return new byte[] { (byte)'?', 0 };
        }

        public static void IN_SetControlType(int player, ControlType type)
        {
            WL_Globals.Controls[player] = type;
        }

        public static void IN_StopDemo()
        {
            if (WL_Globals.DemoMode == Demo.demo_Playback || WL_Globals.DemoMode == Demo.demo_PlayDone)
                WL_Globals.DemoMode = Demo.demo_PlayDone;
        }

        public static void IN_FreeDemoBuffer()
        {
            WL_Globals.DemoBuffer = null;
        }
    }
}
