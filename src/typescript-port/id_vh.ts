// ID_VH.TS
// Ported from ID_VH.C / ID_VH.H - Video high-level routines

import * as VL from './id_vl';
import * as IN from './id_in';
import { grsegs, pictable } from './id_ca';
import { STARTPICS, STARTFONT } from './gfxv_wl1';
import { NUMLATCHPICS, SCREENSIZE } from './wl_def';
import { WOLF3D_PALETTE } from './gamepal';

//===========================================================================
// Constants
//===========================================================================

export const WHITE = 15;
export const BLACK = 0;
export const FIRSTCOLOR = 1;
export const SECONDCOLOR = 12;
export const F_WHITE = 15;
export const F_BLACK = 0;
export const F_FIRSTCOLOR = 1;
export const F_SECONDCOLOR = 12;
export const MAXSHIFTS = 1;

//===========================================================================
// Types
//===========================================================================

export interface pictabletype {
    width: number;
    height: number;
}

export interface fontstruct {
    height: number;
    location: Int16Array;  // [256]
    width: Uint8Array;     // [256] (char widths)
}

//===========================================================================
// Global variables
//===========================================================================

export let fontcolor: number = 0;
export let backcolor: number = 0;
export let fontnumber: number = 0;
export let px: number = 0;
export let py: number = 0;

export let gamepal: Uint8Array = new Uint8Array(WOLF3D_PALETTE);

export const latchpics: Uint32Array = new Uint32Array(NUMLATCHPICS);
export let freelatch: number = 0;

// Setter helpers
export function setFontColor(v: number): void { fontcolor = v; }
export function setBackColor(v: number): void { backcolor = v; }
export function setFontNumber(v: number): void { fontnumber = v; }
export function setPx(v: number): void { px = v; }
export function setPy(v: number): void { py = v; }

//===========================================================================
// Font parsing
//===========================================================================

function getFont(fontNum: number): fontstruct | null {
    const chunk = STARTFONT + fontNum;
    const data = grsegs[chunk];
    if (!data) return null;

    const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
    const font: fontstruct = {
        height: view.getInt16(0, true),
        location: new Int16Array(256),
        width: new Uint8Array(256),
    };

    for (let i = 0; i < 256; i++) {
        font.location[i] = view.getInt16(2 + i * 2, true);
    }
    for (let i = 0; i < 256; i++) {
        font.width[i] = data[2 + 256 * 2 + i];
    }

    return font;
}

//===========================================================================
// VW_MeasurePropString
//===========================================================================

export function VW_MeasurePropString(str: string): { width: number; height: number } {
    const font = getFont(fontnumber);
    if (!font) return { width: 0, height: 0 };

    let w = 0;
    let h = font.height;
    let maxW = 0;

    for (let i = 0; i < str.length; i++) {
        const ch = str.charCodeAt(i);
        if (ch === 10) {  // newline
            if (w > maxW) maxW = w;
            w = 0;
            h += font.height;
        } else {
            w += font.width[ch];
        }
    }
    if (w > maxW) maxW = w;

    return { width: maxW, height: h };
}

//===========================================================================
// VWB_DrawPropString
//===========================================================================

export function VWB_DrawPropString(str: string): void {
    const font = getFont(fontnumber);
    if (!font) return;

    const fontData = grsegs[STARTFONT + fontnumber];
    if (!fontData) return;

    for (let i = 0; i < str.length; i++) {
        const ch = str.charCodeAt(i);
        if (ch === 10) {  // newline
            px = 0;  // This is typically set by the caller
            py += font.height;
            continue;
        }

        const charW = font.width[ch];
        const charH = font.height;
        const loc = font.location[ch];

        if (charW === 0 || loc < 0) continue;

        // Draw character pixel by pixel
        for (let row = 0; row < charH; row++) {
            for (let col = 0; col < charW; col++) {
                const srcIdx = loc + row * charW + col;
                if (srcIdx < fontData.length) {
                    const pixel = fontData[srcIdx];
                    if (pixel !== 0) {
                        VL.VL_Plot(px + col, py + row, fontcolor);
                    } else if (backcolor !== 0xff) {
                        VL.VL_Plot(px + col, py + row, backcolor);
                    }
                }
            }
        }

        px += charW;
    }
}

//===========================================================================
// VWB_DrawMPropString (same but for masked font)
//===========================================================================

export function VWB_DrawMPropString(str: string): void {
    // Same as VWB_DrawPropString for now
    VWB_DrawPropString(str);
}

//===========================================================================
// VWB_Bar
//===========================================================================

export function VWB_Bar(x: number, y: number, width: number, height: number, color: number): void {
    VL.VL_Bar(x, y, width, height, color);
}

//===========================================================================
// VWB_Plot
//===========================================================================

export function VWB_Plot(x: number, y: number, color: number): void {
    VL.VL_Plot(x, y, color);
}

//===========================================================================
// VWB_Hlin / VWB_Vlin
//===========================================================================

export function VWB_Hlin(x1: number, x2: number, y: number, color: number): void {
    VL.VL_Hlin(x1, y, x2 - x1 + 1, color);
}

export function VWB_Vlin(y1: number, y2: number, x: number, color: number): void {
    VL.VL_Vlin(x, y1, y2 - y1 + 1, color);
}

//===========================================================================
// VWB_DrawPic - Draw a graphic chunk to the screen
//===========================================================================

let _drawPicDebug = 0;
export function VWB_DrawPic(x: number, y: number, chunknum: number): void {
    const picnum = chunknum - STARTPICS;
    if (picnum < 0 || picnum >= pictable.length) {
        if (_drawPicDebug < 20) { _drawPicDebug++; console.log(`[VWB_DrawPic] SKIP chunknum=${chunknum} picnum=${picnum} out of range (pictable.length=${pictable.length})`); }
        return;
    }

    const pic = pictable[picnum];
    const data = grsegs[chunknum];
    if (!data) {
        if (_drawPicDebug < 20) { _drawPicDebug++; console.log(`[VWB_DrawPic] SKIP chunknum=${chunknum} no data in grsegs`); }
        return;
    }

    if (_drawPicDebug < 20) { _drawPicDebug++; console.log(`[VWB_DrawPic] chunknum=${chunknum} pic=${pic.width}x${pic.height} data=${data.length}bytes at (${x},${y})`); }
    VL.VL_MemToScreen(data, pic.width, pic.height, x, y);
}

//===========================================================================
// VWB_DrawSprite (stub)
//===========================================================================

export function VWB_DrawSprite(_x: number, _y: number, _chunknum: number): void {
    // Sprite drawing stub - will be implemented with proper sprite format
}

//===========================================================================
// VWB_DrawTile8 / VWB_DrawTile8M
//===========================================================================

export function VWB_DrawTile8(x: number, y: number, tile: number): void {
    const data = grsegs[STARTFONT + 2];  // tile8 data (STARTTILE8 in some versions)
    if (!data) return;

    // Each tile is 64 bytes in plane-separated format
    const tileData = data.subarray(tile * 64, tile * 64 + 64);

    // De-plane and draw
    for (let plane = 0; plane < 4; plane++) {
        for (let row = 0; row < 8; row++) {
            const b0 = tileData[plane * 16 + row * 2];
            const b1 = tileData[plane * 16 + row * 2 + 1];
            const sx0 = x + plane;
            const sx1 = x + plane + 4;
            const sy = y + row;
            if (sy >= 0 && sy < 200) {
                if (sx0 >= 0 && sx0 < 320) VL.screenbuf[sy * 320 + sx0] = b0;
                if (sx1 >= 0 && sx1 < 320) VL.screenbuf[sy * 320 + sx1] = b1;
            }
        }
    }
}

export function VWB_DrawTile8M(_x: number, _y: number, _tile: number): void {
    // Masked tile drawing - stub
}

export function VWB_DrawTile16(_x: number, _y: number, _tile: number): void {
    // Stub
}

export function VWB_DrawTile16M(_x: number, _y: number, _tile: number): void {
    // Stub
}

export function VWB_DrawMPic(x: number, y: number, chunknum: number): void {
    const picnum = chunknum - STARTPICS;
    if (picnum < 0 || picnum >= pictable.length) return;

    const pic = pictable[picnum];
    const data = grsegs[chunknum];
    if (!data) return;

    VL.VL_MaskedToScreen(data, pic.width, pic.height, x, y);
}

//===========================================================================
// LatchDrawChar / LatchDrawTile / LatchDrawPic
//===========================================================================

export function LatchDrawChar(x: number, y: number, p: number): void {
    VL.VL_LatchToScreen(latchpics[0] + p * 16, 2, 8, x, y);
}

export function LatchDrawTile(x: number, y: number, p: number): void {
    VL.VL_LatchToScreen(latchpics[1] + p * 64, 4, 16, x, y);
}

export function LatchDrawPic(x: number, y: number, picnum: number): void {
    const picIdx = picnum - STARTPICS;
    if (picIdx < 0 || picIdx >= pictable.length) return;
    const width = (pictable[picIdx].width + 7) >> 3;
    const height = pictable[picIdx].height;
    // x is in tiles (x*8 = pixel), y is in pixels
    VL.VL_LatchToScreen(latchpics[2 + picnum], width, height, x * 8, y);
}

//===========================================================================
// VH_SetDefaultColors
//===========================================================================

export function VH_SetDefaultColors(): void {
    // gamepal is initialized at module level with the Wolf3D palette
    VL.VL_SetPalette(gamepal);
}

//===========================================================================
// VW_InitDoubleBuffer / VW_UpdateScreen / VW_MarkUpdateBlock
//===========================================================================

export function VW_InitDoubleBuffer(): void {
    // No-op in our implementation
}

export function VW_UpdateScreen(): void {
    VL.VL_UpdateScreen();
}

export function VW_MarkUpdateBlock(_x1: number, _y1: number, _x2: number, _y2: number): number {
    return 0;
}

//===========================================================================
// LoadLatchMem - load latch graphics into latch memory
//===========================================================================

export function LoadLatchMem(): void {
    // This loads tile8s and latch pics into VGA latch memory
    // For our implementation, we just track the offsets
    freelatch = 0;
    // Further implementation needed when game rendering is complete
}

//===========================================================================
// FizzleFade
//===========================================================================

export async function FizzleFade(
    _source: number, _dest: number,
    width: number, height: number,
    frames: number, abortable: boolean
): Promise<boolean> {
    // LFSR-based pseudo-random pixel reveal effect, matching the original C.
    // Save a snapshot of the current screenbuf as the "source" image.
    const fizzleSrc = new Uint8Array(320 * 200);
    fizzleSrc.set(VL.screenbuf);

    let rndval = 1;
    const pixperframe = ((64000 / frames) | 0) || 1;

    IN.IN_StartAck();
    const startTime = performance.now();
    let frame = 0;

    // eslint-disable-next-line no-constant-condition
    while (true) {
        if (abortable && IN.IN_CheckAck()) {
            // Copy remaining and finish
            VL.screenbuf.set(fizzleSrc);
            VL.VL_UpdateScreen();
            return true;
        }

        for (let p = 0; p < pixperframe; p++) {
            // Separate random value into x/y pair
            const y = (rndval & 0xFF) - 1;
            const x = ((rndval >> 8) & 0x1FF);

            // Advance LFSR
            const carry = rndval & 1;
            rndval >>= 1;
            if (carry) {
                rndval ^= 0x00012000;
            }

            // Copy pixel if in range
            if (x <= width && y <= height && x < 320 && y >= 0 && y < 200) {
                VL.screenbuf[y * 320 + x] = fizzleSrc[y * 320 + x];
            }

            // Check if LFSR has cycled back to 1 (all pixels visited)
            if (rndval === 1) {
                VL.screenbuf.set(fizzleSrc);
                VL.VL_UpdateScreen();
                return false;
            }
        }

        frame++;
        VL.VL_UpdateScreen();

        // Wait for frame timing (~70Hz)
        const elapsed = performance.now() - startTime;
        const target = frame * (1000 / 70);
        if (elapsed < target) {
            await new Promise(resolve => setTimeout(resolve, target - elapsed));
        } else {
            // Yield to browser at least once per frame
            await new Promise(resolve => setTimeout(resolve, 0));
        }
    }
}

//===========================================================================
// Compatibility macros as functions
//===========================================================================

export const VW_Startup = VL.VL_Startup;
export const VW_Shutdown = VL.VL_Shutdown;
export const VW_SetCRTC = VL.VL_SetCRTC;
export const VW_SetScreen = VL.VL_SetScreen;
export const VW_Bar = VL.VL_Bar;
export const VW_Plot = VL.VL_Plot;
export function VW_Hlin(x: number, z: number, y: number, c: number): void { VL.VL_Hlin(x, y, z - x + 1, c); }
export function VW_Vlin(y: number, z: number, x: number, c: number): void { VL.VL_Vlin(x, y, z - y + 1, c); }
export const VW_SetSplitScreen = VL.VL_SetSplitScreen;
export const VW_SetLineWidth = VL.VL_SetLineWidth;
export const VW_ColorBorder = VL.VL_ColorBorder;
export const VW_WaitVBL = VL.VL_WaitVBL;
export async function VW_FadeIn(): Promise<void> { await VL.VL_FadeIn(0, 255, gamepal, 10); }
export async function VW_FadeOut(): Promise<void> { await VL.VL_FadeOut(0, 255, 0, 0, 0, 30); }
export const VW_ScreenToScreen = VL.VL_ScreenToScreen;
export const VW_SetDefaultColors = VH_SetDefaultColors;
