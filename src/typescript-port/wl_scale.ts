// WL_SCALE.TS
// Ported from WL_SCALE.C - Sprite scaling routines
// SDL3 port: compiled scalers replaced with lookup-table-based scaling

import * as VL from './id_vl';
import * as PM from './id_pm';
import { MAXSCALEHEIGHT, MAXVIEWWIDTH, t_compshape } from './wl_def';
import { viewwidth, viewheight, screenofs, scale as mainScale } from './wl_main';
import { wallheight } from './wl_draw';

//===========================================================================
// Types
//===========================================================================

interface t_compscale {
    width: number[];    // [65] - how many screen pixels each source texel maps to
    codeofs: number[];  // [65] - starting screen row for each source texel
}

//===========================================================================
// Global variables
//===========================================================================

export let maxscale = 0;
export let maxscaleshl2 = 0;
export let insetupscaling = false;

const scaledirectory: (t_compscale | null)[] = new Array(MAXSCALEHEIGHT + 1).fill(null);
let stepbytwo = 0;

// ScaleLine globals
let slinex = 0;
let slinewidth = 0;
let linecmds: DataView | null = null;
let linecmdsOffset = 0;
let linescale: t_compscale | null = null;
let scaleline_shape_base: Uint8Array | null = null;

//===========================================================================
// SetupScaling
//===========================================================================

export function SetupScaling(maxscaleheight: number): void {
    insetupscaling = true;

    maxscaleheight = (maxscaleheight / 2) | 0;  // one scaler every two pixels
    maxscale = maxscaleheight - 1;
    maxscaleshl2 = maxscale << 2;

    // Clear old scalers
    for (let i = 0; i <= MAXSCALEHEIGHT; i++) {
        scaledirectory[i] = null;
    }

    stepbytwo = (viewheight / 2) | 0;

    // Build scaling lookup tables
    for (let i = 1; i <= maxscaleheight; i++) {
        const height = i * 2;
        const step = ((height << 16) / 64) | 0;
        let fix = 0;
        const toppix = ((viewheight - height) / 2) | 0;

        const sc: t_compscale = {
            width: new Array(65).fill(0),
            codeofs: new Array(65).fill(0),
        };

        for (let src = 0; src <= 64; src++) {
            const startpix = fix >> 16;
            fix += step;
            const endpix = fix >> 16;

            sc.width[src] = endpix > startpix ? endpix - startpix : 0;
            sc.codeofs[src] = startpix + toppix;
        }

        scaledirectory[i] = sc;

        if (i >= stepbytwo) {
            if (i + 1 <= MAXSCALEHEIGHT) scaledirectory[i + 1] = sc;
            if (i + 2 <= MAXSCALEHEIGHT) scaledirectory[i + 2] = sc;
            i += 2;
        }
    }

    scaledirectory[0] = scaledirectory[1];
    insetupscaling = false;
}

//===========================================================================
// ScaleLine - draws a single vertical column of a sprite
//===========================================================================

function ScaleLine(): void {
    const comptable = linescale;
    if (!comptable || !linecmds || !scaleline_shape_base) return;

    const yofs = ((200 - 40 - viewheight) >> 1);
    const xofs = ((320 - viewwidth) >> 1);

    // Process each segment in the command list
    let cmdIdx = linecmdsOffset;
    while (true) {
        const end_ofs = linecmds.getUint16(cmdIdx, true);
        if (end_ofs === 0) break;
        cmdIdx += 2;
        const src_offset = linecmds.getUint16(cmdIdx, true);
        cmdIdx += 2;
        const start_ofs = linecmds.getUint16(cmdIdx, true);
        cmdIdx += 2;

        const texel_start = Math.min((start_ofs / 2) | 0, 64);
        const texel_end = Math.min((end_ofs / 2) | 0, 64);

        for (let texel = texel_start; texel < texel_end; texel++) {
            const width_pix = comptable.width[texel];
            const screen_y_start = comptable.codeofs[texel];

            if (width_pix <= 0) continue;

            // src_offset is "corrected top of shape" - already adjusted
            // so shape_base[src_offset + texel] gives the color for absolute texel row
            const colorIdx = src_offset + texel;
            if (colorIdx >= scaleline_shape_base.length) continue;
            const color = scaleline_shape_base[colorIdx];
            if (color === 0) continue;

            for (let dy = 0; dy < width_pix; dy++) {
                const sy = screen_y_start + dy;
                if (sy < 0 || sy >= viewheight) continue;
                const screen_y = sy + yofs;
                if (screen_y < 0 || screen_y >= 200) continue;

                for (let x = slinex; x < slinex + slinewidth && (x + xofs) < 320; x++) {
                    if ((x + xofs) >= 0) {
                        VL.screenbuf[screen_y * 320 + x + xofs] = color;
                    }
                }
            }
        }
    }
}

//===========================================================================
// ScaleShape - draw a scaled sprite with wall occlusion
//===========================================================================

export function ScaleShape(xcenter: number, shapenum: number, height: number): void {
    const spriteData = PM.PM_GetSpritePage(shapenum);
    if (!spriteData || spriteData.length < 4) return;

    const scaleVal = height >> 3;
    if (!scaleVal || scaleVal > maxscale) return;

    const comptable = scaledirectory[scaleVal];
    if (!comptable) return;

    linescale = comptable;
    scaleline_shape_base = spriteData;

    // Parse shape header
    const shapeView = new DataView(spriteData.buffer, spriteData.byteOffset, spriteData.byteLength);
    const leftpix = shapeView.getUint16(0, true);
    const rightpix = shapeView.getUint16(2, true);

    const cmdView = new DataView(spriteData.buffer, spriteData.byteOffset, spriteData.byteLength);

    // Scale to the left (from pixel 31 to shape.leftpix)
    let srcx = 32;
    slinex = xcenter;
    const stopxL = leftpix;
    let cmdptrIdx = 31 - stopxL;  // index into dataofs array

    while (--srcx >= stopxL && slinex > 0) {
        const dataOfsIdx = 4 + cmdptrIdx * 2;
        if (dataOfsIdx >= 0 && dataOfsIdx + 2 <= spriteData.length) {
            const dataOfs = cmdView.getUint16(dataOfsIdx, true);
            linecmds = cmdView;
            linecmdsOffset = dataOfs;
        }
        cmdptrIdx--;

        slinewidth = comptable.width[srcx];
        if (!slinewidth) continue;

        if (slinewidth === 1) {
            slinex--;
            if (slinex < viewwidth) {
                if (slinex >= 0 && wallheight[slinex] >= height) continue;
                ScaleLine();
            }
            continue;
        }

        // Handle multi-pixel lines
        if (slinex > viewwidth) {
            slinex -= slinewidth;
            slinewidth = viewwidth - slinex;
            if (slinewidth < 1) continue;
        } else {
            if (slinewidth > slinex) slinewidth = slinex;
            slinex -= slinewidth;
        }

        if (slinex >= 0 && slinex < viewwidth) {
            const leftvis = wallheight[slinex] < height;
            const rightIdx = Math.min(slinex + slinewidth - 1, viewwidth - 1);
            const rightvis = rightIdx >= 0 ? wallheight[rightIdx] < height : false;

            if (leftvis) {
                if (rightvis) {
                    ScaleLine();
                } else {
                    while (slinewidth > 0 && wallheight[slinex + slinewidth - 1] >= height) slinewidth--;
                    if (slinewidth > 0) ScaleLine();
                }
            } else {
                if (!rightvis) continue;
                while (slinewidth > 0 && wallheight[slinex] >= height) {
                    slinex++;
                    slinewidth--;
                }
                if (slinewidth > 0) ScaleLine();
                break;
            }
        }
    }

    // Scale to the right
    slinex = xcenter;
    const stopxR = rightpix;
    if (leftpix < 31) {
        srcx = 31;
        cmdptrIdx = 32 - leftpix;
    } else {
        srcx = leftpix - 1;
        cmdptrIdx = 0;
    }
    slinewidth = 0;

    while (++srcx <= stopxR && (slinex += slinewidth) < viewwidth) {
        const dataOfsIdx = 4 + cmdptrIdx * 2;
        if (dataOfsIdx >= 0 && dataOfsIdx + 2 <= spriteData.length) {
            const dataOfs = cmdView.getUint16(dataOfsIdx, true);
            linecmds = cmdView;
            linecmdsOffset = dataOfs;
        }
        cmdptrIdx++;

        slinewidth = comptable.width[srcx];
        if (!slinewidth) continue;

        if (slinewidth === 1) {
            if (slinex >= 0 && slinex < viewwidth && wallheight[slinex] < height) {
                ScaleLine();
            }
            continue;
        }

        // Handle multi-pixel lines
        if (slinex < 0) {
            if (slinewidth <= -slinex) continue;
            slinewidth += slinex;
            slinex = 0;
        } else {
            if (slinex + slinewidth > viewwidth) {
                slinewidth = viewwidth - slinex;
            }
        }

        if (slinex >= 0 && slinex < viewwidth && slinewidth > 0) {
            const leftvis = wallheight[slinex] < height;
            const rightIdx = Math.min(slinex + slinewidth - 1, viewwidth - 1);
            const rightvis = rightIdx >= 0 ? wallheight[rightIdx] < height : false;

            if (leftvis) {
                if (rightvis) {
                    ScaleLine();
                } else {
                    while (slinewidth > 0 && wallheight[slinex + slinewidth - 1] >= height) slinewidth--;
                    if (slinewidth > 0) ScaleLine();
                    break;
                }
            } else {
                if (rightvis) {
                    while (slinewidth > 0 && wallheight[slinex] >= height) {
                        slinex++;
                        slinewidth--;
                    }
                    if (slinewidth > 0) ScaleLine();
                }
                // else totally obscured
            }
        }
    }
}

//===========================================================================
// SimpleScaleShape - NO CLIPPING, height in pixels
//===========================================================================

export function SimpleScaleShape(xcenter: number, shapenum: number, height: number): void {
    const spriteData = PM.PM_GetSpritePage(shapenum);
    if (!spriteData || spriteData.length < 4) return;

    const scaleVal = height >> 1;
    if (!scaleVal || scaleVal > maxscale) return;

    const comptable = scaledirectory[scaleVal];
    if (!comptable) return;

    linescale = comptable;
    scaleline_shape_base = spriteData;

    const shapeView = new DataView(spriteData.buffer, spriteData.byteOffset, spriteData.byteLength);
    const leftpix = shapeView.getUint16(0, true);
    const rightpix = shapeView.getUint16(2, true);

    const cmdView = new DataView(spriteData.buffer, spriteData.byteOffset, spriteData.byteLength);

    // Scale to the left
    let srcx = 32;
    slinex = xcenter;
    const stopxL = leftpix;
    let cmdptrIdx = 31 - stopxL;

    while (--srcx >= stopxL) {
        const dataOfsIdx = 4 + cmdptrIdx * 2;
        if (dataOfsIdx >= 0 && dataOfsIdx + 2 <= spriteData.length) {
            const dataOfs = cmdView.getUint16(dataOfsIdx, true);
            linecmds = cmdView;
            linecmdsOffset = dataOfs;
        }
        cmdptrIdx--;

        slinewidth = comptable.width[srcx];
        if (!slinewidth) continue;

        slinex -= slinewidth;
        ScaleLine();
    }

    // Scale to the right
    slinex = xcenter;
    const stopxR = rightpix;
    if (leftpix < 31) {
        srcx = 31;
        cmdptrIdx = 32 - leftpix;
    } else {
        srcx = leftpix - 1;
        cmdptrIdx = 0;
    }
    slinewidth = 0;

    while (++srcx <= stopxR) {
        const dataOfsIdx = 4 + cmdptrIdx * 2;
        if (dataOfsIdx >= 0 && dataOfsIdx + 2 <= spriteData.length) {
            const dataOfs = cmdView.getUint16(dataOfsIdx, true);
            linecmds = cmdView;
            linecmdsOffset = dataOfs;
        }
        cmdptrIdx++;

        slinewidth = comptable.width[srcx];
        if (!slinewidth) continue;

        ScaleLine();
        slinex += slinewidth;
    }
}
