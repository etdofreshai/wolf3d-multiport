// WL_DEBUG.C -> WlDebug.cs
// Debug tools - god mode, level warping, memory display

using System;

namespace Wolf3D
{
    public static class WlDebug
    {
        public static int DebugKeys()
        {
            // Handle debug key combinations
            if (WL_Globals.Keyboard[ScanCodes.sc_G])
            {
                // God mode toggle
                WL_Globals.godmode = !WL_Globals.godmode;
                return 1;
            }
            return 0;
        }

        public static void PicturePause()
        {
            // Pause and show current frame
            IdIn.IN_Ack();
        }
    }
}
