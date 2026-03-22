// WL_SCALE.C -> WlScale.cs
// Sprite scaling routines

using System;

namespace Wolf3D
{
    public static class WlScale
    {
        // =========================================================================
        //  SetupScaling
        // =========================================================================

        public static void SetupScaling(int maxscaleheight)
        {
            WL_Globals.maxscale = maxscaleheight;
            WL_Globals.maxscaleshl2 = maxscaleheight << 2;
            WL_Globals.insetupscaling = true;

            // Build scaled directory
            // In the original, this pre-compiled scaler code for each height
            // In our software renderer, we scale on the fly

            WL_Globals.insetupscaling = false;
        }

        // =========================================================================
        //  ScaleShape
        // =========================================================================

        public static void ScaleShape(int xcenter, int shapenum, uint height)
        {
            // Draw a scaled sprite centered at xcenter with given height
            // In full implementation, would decompress and scale sprite data from VSWAP
            if (height == 0) return;

            byte[] spriteData = null;
            if (shapenum >= 0 && shapenum < WL_Globals.ChunksInFile - WL_Globals.PMSpriteStart)
                spriteData = IdPm.PM_GetSpritePage(shapenum);

            if (spriteData == null) return;

            // Parse t_compshape header
            if (spriteData.Length < 4) return;

            int leftpix = spriteData[0] | (spriteData[1] << 8);
            int rightpix = spriteData[2] | (spriteData[3] << 8);

            // Simplified sprite drawing
            int swidth = rightpix - leftpix + 1;
            if (swidth <= 0) return;

            int scale = (int)height >> 1;
            int startx = xcenter - scale;
            int endx = xcenter + scale;

            int starty = (200 - WolfConstants.STATUSLINES) / 2 - scale;
            int endy = (200 - WolfConstants.STATUSLINES) / 2 + scale;

            // Clamp to view
            if (startx < 0) startx = 0;
            if (endx >= 320) endx = 319;
            if (starty < 0) starty = 0;
            if (endy >= 200 - WolfConstants.STATUSLINES)
                endy = 200 - WolfConstants.STATUSLINES - 1;

            // Would draw sprite columns here with proper scaling
        }

        // =========================================================================
        //  SimpleScaleShape
        // =========================================================================

        public static void SimpleScaleShape(int xcenter, int shapenum, uint height)
        {
            ScaleShape(xcenter, shapenum, height);
        }
    }
}
