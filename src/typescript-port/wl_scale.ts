// WL_SCALE.TS
// Ported from WL_SCALE.C - Sprite scaling routines

import * as VL from './id_vl';
import * as PM from './id_pm';
import { MAXSCALEHEIGHT, MAXVIEWWIDTH, t_compshape } from './wl_def';
import { viewwidth, viewheight } from './wl_main';
import { wallheight } from './wl_draw';

//===========================================================================
// Global variables
//===========================================================================

export let maxscale = 0;
export let maxscaleshl2 = 0;
export let insetupscaling = false;

//===========================================================================
// SetupScaling
//===========================================================================

export function SetupScaling(maxscaleheight: number): void {
    maxscale = maxscaleheight;
    maxscaleshl2 = maxscaleheight << 2;
    insetupscaling = false;
}

//===========================================================================
// ScaleShape - draw a scaled sprite
//===========================================================================

export function ScaleShape(xcenter: number, shapenum: number, height: number): void {
    if (height <= 0 || height > maxscaleshl2) return;

    const spriteData = PM.PM_GetSpritePage(shapenum);
    if (!spriteData || spriteData.length < 4) return;

    // Parse compressed shape header
    const view = new DataView(spriteData.buffer, spriteData.byteOffset);
    const leftpix = view.getUint16(0, true);
    const rightpix = view.getUint16(2, true);

    const numColumns = rightpix - leftpix + 1;
    if (numColumns <= 0) return;

    // Calculate scaled width
    const scaleFactor = height / 64;
    const scaledWidth = (numColumns * scaleFactor) | 0;
    const startX = xcenter - (scaledWidth >> 1);

    // Simple sprite rendering
    const baseScreenX = (320 - viewwidth) >> 1;
    const startY = ((200 - 40 - height) >> 1);

    for (let col = 0; col < scaledWidth; col++) {
        const screenX = startX + col;
        if (screenX < 0 || screenX >= viewwidth) continue;

        // Check if behind a wall
        if (height < wallheight[screenX]) continue;

        const srcCol = ((col / scaleFactor) | 0) + leftpix;
        if (srcCol < leftpix || srcCol > rightpix) continue;

        // Read column data offset
        const colIdx = srcCol - leftpix;
        if (4 + colIdx * 2 + 2 > spriteData.length) continue;
        const dataOfs = view.getUint16(4 + colIdx * 2, true);
        if (dataOfs === 0 || dataOfs >= spriteData.length) continue;

        // Draw the column (simplified - actual format has post commands)
        const step = 64.0 / height;
        let texPos = 0;

        for (let y = Math.max(0, startY); y < Math.min(200, startY + height); y++) {
            const texY = (texPos | 0) & 63;
            texPos += step;
            if (dataOfs + texY < spriteData.length) {
                const pixel = spriteData[dataOfs + texY];
                if (pixel !== 0) {
                    VL.screenbuf[y * 320 + baseScreenX + screenX] = pixel;
                }
            }
        }
    }
}

//===========================================================================
// SimpleScaleShape
//===========================================================================

export function SimpleScaleShape(xcenter: number, shapenum: number, height: number): void {
    ScaleShape(xcenter, shapenum, height);
}
