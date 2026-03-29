// ID_VL.TS
// Ported from ID_VL.C - Video layer using HTML5 Canvas 2D

//===========================================================================
// Constants from ID_VL.H
//===========================================================================

export const SCREENWIDTH = 80;
export const MAXSCANLINES = 200;
export const CHARWIDTH = 2;
export const TILEWIDTH = 4;

//===========================================================================
// Canvas globals (replacing SDL3 globals)
//===========================================================================

let canvas: HTMLCanvasElement | null = null;
let ctx: CanvasRenderingContext2D | null = null;
let imageData: ImageData | null = null;

export const screenbuf = new Uint8Array(320 * 200);   // linear 8-bit framebuffer
export const palette = new Uint8Array(768);            // current palette R,G,B triples (6-bit VGA)

// Internal latch memory
const LATCH_MEM_SIZE = 256 * 1024;
const latchmem = new Uint8Array(LATCH_MEM_SIZE);

//===========================================================================
// State variables
//===========================================================================

export let bufferofs = 0;
export let displayofs = 0;
export let pelpan = 0;
export let screenseg = 0xa000;
export let linewidth = 0;
export const ylookup = new Uint32Array(MAXSCANLINES);
export let screenfaded = false;
export let bordercolor = 0;

let fastpalette = false;

const palette1 = new Uint8Array(768);
const palette2 = new Uint8Array(768);

// Setter helpers
export function setBufferOfs(v: number): void { bufferofs = v; }
export function setDisplayOfs(v: number): void { displayofs = v; }

//===========================================================================
// Formerly in ASM
//===========================================================================

export function VL_VideoID(): number {
    return 5;  // Always report VGA present
}

export function VL_SetCRTC(crtc: number): void {
    // No-op for Canvas
}

export function VL_SetScreen(crtc: number, pel: number): void {
    displayofs = crtc;
    pelpan = pel;
}

export function VL_WaitVBL(vbls: number): Promise<void> {
    // Wait for vbls vertical blanks (~14ms each at 70Hz)
    // Uses a busy-wait with yield to avoid browser setTimeout throttling
    if (vbls > 0) {
        const targetMs = vbls * 14;
        const start = performance.now();
        return new Promise(resolve => {
            const check = () => {
                if (performance.now() - start >= targetMs) {
                    resolve();
                } else {
                    setTimeout(check, 0);
                }
            };
            setTimeout(check, 0);
        });
    }
    return Promise.resolve();
}

// Synchronous no-op version for non-async contexts
export function VL_WaitVBL_sync(_vbls: number): void {
    // No-op in sync mode - actual waiting done via async game loop
}

//===========================================================================
// VL_Startup
//===========================================================================

export function VL_Startup(): void {
    if (canvas) return;  // idempotent

    canvas = document.getElementById('wolf3d-canvas') as HTMLCanvasElement;
    if (!canvas) {
        throw new Error('Canvas element #wolf3d-canvas not found');
    }

    ctx = canvas.getContext('2d');
    if (!ctx) {
        throw new Error('Failed to get 2D context');
    }

    // Scale canvas for display — fit within viewport
    canvas.width = 320;
    canvas.height = 200;
    const maxW = window.innerWidth;
    const maxH = window.innerHeight;
    const scale = Math.min(maxW / 320, maxH / 200, 3);
    canvas.style.width = `${Math.floor(320 * scale)}px`;
    canvas.style.height = `${Math.floor(200 * scale)}px`;

    imageData = ctx.createImageData(320, 200);

    screenbuf.fill(0);
    palette.fill(0);

    // Hide loading text
    const loadingEl = document.getElementById('loading');
    if (loadingEl) loadingEl.style.display = 'none';
}

//===========================================================================
// VL_Shutdown
//===========================================================================

export function VL_Shutdown(): void {
    canvas = null;
    ctx = null;
    imageData = null;
}

//===========================================================================
// VL_SetVGAPlaneMode
//===========================================================================

export function VL_SetVGAPlaneMode(): void {
    if (!canvas) VL_Startup();
    VL_DePlaneVGA();
    VL_SetLineWidth(40);
}

export function VL_SetVGAPlane(): void {
    // No-op
}

export function VL_SetTextMode(): void {
    // No-op
}

//===========================================================================
// VL_ClearVideo
//===========================================================================

export function VL_ClearVideo(color: number): void {
    screenbuf.fill(color);
    latchmem.fill(color);
}

//===========================================================================
// VL_DePlaneVGA
//===========================================================================

export function VL_DePlaneVGA(): void {
    VL_ClearVideo(0);
}

//===========================================================================
// VL_SetLineWidth
//===========================================================================

export function VL_SetLineWidth(width: number): void {
    linewidth = width * 2;
    let offset = 0;
    for (let i = 0; i < MAXSCANLINES; i++) {
        ylookup[i] = offset;
        offset += linewidth;
    }
}

//===========================================================================
// VL_SetSplitScreen
//===========================================================================

export function VL_SetSplitScreen(_linenum: number): void {
    // No-op
}

//===========================================================================
//                      PALETTE OPS
//===========================================================================

export function VL_FillPalette(red: number, green: number, blue: number): void {
    for (let i = 0; i < 256; i++) {
        palette[i * 3 + 0] = red;
        palette[i * 3 + 1] = green;
        palette[i * 3 + 2] = blue;
    }
}

export function VL_SetColor(color: number, red: number, green: number, blue: number): void {
    palette[color * 3 + 0] = red;
    palette[color * 3 + 1] = green;
    palette[color * 3 + 2] = blue;
}

export function VL_GetColor(color: number): { red: number; green: number; blue: number } {
    return {
        red: palette[color * 3 + 0],
        green: palette[color * 3 + 1],
        blue: palette[color * 3 + 2],
    };
}

export function VL_SetPalette(pal: Uint8Array): void {
    palette.set(pal.subarray(0, 768));
}

export function VL_GetPalette(pal: Uint8Array): void {
    pal.set(palette.subarray(0, 768));
}

//===========================================================================
// VL_FadeOut
//===========================================================================

export async function VL_FadeOut(start: number, end: number, red: number, green: number, blue: number, steps: number): Promise<void> {
    await VL_WaitVBL(1);
    VL_GetPalette(palette1);
    palette2.set(palette1);

    for (let i = 0; i < steps; i++) {
        for (let j = start; j <= end; j++) {
            for (let c = 0; c < 3; c++) {
                const target = c === 0 ? red : c === 1 ? green : blue;
                const orig = palette1[j * 3 + c];
                const delta = target - orig;
                palette2[j * 3 + c] = orig + ((delta * i / steps) | 0);
            }
        }
        await VL_WaitVBL(1);
        VL_SetPalette(palette2);
        VL_UpdateScreen();
    }

    VL_FillPalette(red, green, blue);
    screenfaded = true;
}

//===========================================================================
// VL_FadeIn
//===========================================================================

export async function VL_FadeIn(start: number, end: number, pal: Uint8Array, steps: number): Promise<void> {
    await VL_WaitVBL(1);
    VL_GetPalette(palette1);
    palette2.set(palette1);

    const s3 = start * 3;
    const e3 = end * 3 + 2;

    for (let i = 0; i < steps; i++) {
        for (let j = s3; j <= e3; j++) {
            const delta = pal[j] - palette1[j];
            palette2[j] = palette1[j] + ((delta * i / steps) | 0);
        }
        await VL_WaitVBL(1);
        VL_SetPalette(palette2);
        VL_UpdateScreen();
    }

    VL_SetPalette(pal);
    screenfaded = false;
}

//===========================================================================
// VL_TestPaletteSet
//===========================================================================

export function VL_TestPaletteSet(): void {
    fastpalette = true;
}

//===========================================================================
// VL_ColorBorder
//===========================================================================

export function VL_ColorBorder(color: number): void {
    bordercolor = color;
}

//===========================================================================
//                          PIXEL OPS
//===========================================================================

export function VL_Plot(x: number, y: number, color: number): void {
    if (x >= 0 && x < 320 && y >= 0 && y < 200)
        screenbuf[y * 320 + x] = color;
}

export function VL_Hlin(x: number, y: number, width: number, color: number): void {
    if (y >= 200 || y < 0) return;
    if (x >= 320) return;
    if (x < 0) { width += x; x = 0; }
    if (x + width > 320) width = 320 - x;
    if (width <= 0) return;
    screenbuf.fill(color, y * 320 + x, y * 320 + x + width);
}

export function VL_Vlin(x: number, y: number, height: number, color: number): void {
    if (x < 0 || x >= 320) return;
    if (y < 0) { height += y; y = 0; }
    if (y + height > 200) height = 200 - y;

    let offset = y * 320 + x;
    while (height-- > 0) {
        screenbuf[offset] = color;
        offset += 320;
    }
}

export function VL_Bar(x: number, y: number, width: number, height: number, color: number): void {
    if (x < 0) { width += x; x = 0; }
    if (y < 0) { height += y; y = 0; }
    if (x + width > 320) width = 320 - x;
    if (y + height > 200) height = 200 - y;
    if (width <= 0 || height <= 0) return;

    let offset = y * 320 + x;
    while (height-- > 0) {
        screenbuf.fill(color, offset, offset + width);
        offset += 320;
    }
}

//===========================================================================
//                          MEMORY OPS
//===========================================================================

export function VL_MemToLatch(source: Uint8Array, width: number, height: number, dest: number): void {
    const pwidth = ((width + 3) / 4) | 0;
    const linearbase = dest * 4;

    if (linearbase + width * height <= LATCH_MEM_SIZE)
        latchmem.fill(0, linearbase, linearbase + width * height);

    let srcIdx = 0;
    for (let plane = 0; plane < 4; plane++) {
        for (let y = 0; y < height; y++) {
            for (let x = 0; x < pwidth; x++) {
                const px = x * 4 + plane;
                const idx = linearbase + y * width + px;
                if (px < width && idx < LATCH_MEM_SIZE)
                    latchmem[idx] = source[srcIdx];
                srcIdx++;
            }
        }
    }
}

export function VL_MemToScreen(source: Uint8Array, width: number, height: number, x: number, y: number): void {
    const pwidth = width >> 2;
    const startplane = x & 3;
    let srcIdx = 0;

    for (let plane = 0; plane < 4; plane++) {
        const curplane = (startplane + plane) & 3;
        for (let py = 0; py < height; py++) {
            for (let px = 0; px < pwidth; px++) {
                const screenx = ((x >> 2) + px) * 4 + curplane;
                const screeny = y + py;
                if (screenx >= 0 && screenx < 320 && screeny >= 0 && screeny < 200)
                    screenbuf[screeny * 320 + screenx] = source[srcIdx];
                srcIdx++;
            }
        }
    }
}

export function VL_MaskedToScreen(source: Uint8Array, width: number, height: number, x: number, y: number): void {
    const pwidth = width >> 2;
    const startplane = x & 3;
    let srcIdx = 0;

    for (let plane = 0; plane < 4; plane++) {
        const curplane = (startplane + plane) & 3;
        for (let py = 0; py < height; py++) {
            for (let px = 0; px < pwidth; px++) {
                const screenx = ((x >> 2) + px) * 4 + curplane;
                const screeny = y + py;
                const val = source[srcIdx];
                if (val !== 0 && screenx >= 0 && screenx < 320 && screeny >= 0 && screeny < 200)
                    screenbuf[screeny * 320 + screenx] = val;
                srcIdx++;
            }
        }
    }
}

export function VL_LatchToScreen(source: number, width: number, height: number, x: number, y: number): void {
    const pixwidth = width * 4;
    const linearbase = source * 4;

    // Convert bufferofs to screen coordinates
    const within_page = bufferofs % (SCREENWIDTH * 208);
    const buf_y = (within_page / linewidth) | 0;
    const buf_x = (within_page % linewidth) * 4;

    x += buf_x;
    y += buf_y;

    let srcIdx = linearbase;
    for (let sy = 0; sy < height; sy++) {
        const screeny = y + sy;
        if (screeny < 0 || screeny >= 200) {
            srcIdx += pixwidth;
            continue;
        }
        for (let sx = 0; sx < pixwidth && (x + sx) < 320; sx++) {
            if (x + sx >= 0 && srcIdx + sx < LATCH_MEM_SIZE)
                screenbuf[screeny * 320 + x + sx] = latchmem[srcIdx + sx];
        }
        srcIdx += pixwidth;
    }
}

export function VL_ScreenToScreen(source: number, dest: number, width: number, height: number): void {
    for (let y = 0; y < height; y++) {
        const src_planar = source + y * linewidth;
        const dst_planar = dest + y * linewidth;

        const src_row = (src_planar / linewidth) | 0;
        const src_col = src_planar % linewidth;
        const dst_row = (dst_planar / linewidth) | 0;
        const dst_col = dst_planar % linewidth;

        const src_linear = src_row * 320 + src_col * 4;
        const dst_linear = dst_row * 320 + dst_col * 4;
        const pixwidth = width * 4;

        if (src_linear >= 0 && dst_linear >= 0 &&
            src_linear + pixwidth <= 320 * 200 &&
            dst_linear + pixwidth <= 320 * 200) {
            screenbuf.copyWithin(dst_linear, src_linear, src_linear + pixwidth);
        }
    }
}

//===========================================================================
//                      STRING OUTPUT ROUTINES
//===========================================================================

export function VL_DrawTile8String(str: string, tile8ptr: Uint8Array, printx: number, printy: number): void {
    for (let ch = 0; ch < str.length; ch++) {
        const charCode = str.charCodeAt(ch);
        let srcIdx = charCode << 6;  // 64 bytes per char

        for (let plane = 0; plane < 4; plane++) {
            for (let row = 0; row < 8; row++) {
                const screeny = printy + row;
                if (screeny >= 0 && screeny < 200) {
                    const x0 = printx + plane;
                    const x1 = printx + plane + 4;
                    if (x0 >= 0 && x0 < 320)
                        screenbuf[screeny * 320 + x0] = tile8ptr[srcIdx];
                    if (x1 >= 0 && x1 < 320)
                        screenbuf[screeny * 320 + x1] = tile8ptr[srcIdx + 1];
                }
                srcIdx += 2;
            }
        }
        printx += 8;
    }
}

export function VL_DrawLatch8String(str: string, tile8ptr: number, printx: number, printy: number): void {
    for (let ch = 0; ch < str.length; ch++) {
        const charCode = str.charCodeAt(ch);
        const planar_src = tile8ptr + (charCode << 4);
        const linear_src = planar_src * 4;

        for (let row = 0; row < 8; row++) {
            const screeny = printy + row;
            if (screeny >= 0 && screeny < 200) {
                for (let col = 0; col < 8; col++) {
                    const screenx = printx + col;
                    if (screenx >= 0 && screenx < 320) {
                        const idx = linear_src + row * 8 + col;
                        if (idx < LATCH_MEM_SIZE)
                            screenbuf[screeny * 320 + screenx] = latchmem[idx];
                    }
                }
            }
        }
        printx += 8;
    }
}

export function VL_SizeTile8String(str: string): { width: number; height: number } {
    return { width: 8 * str.length, height: 8 };
}

//===========================================================================
// VL_MungePic - reorder picture data from linear to VGA plane-separated format
//===========================================================================

export function VL_MungePic(source: Uint8Array, width: number, height: number): void {
    const size = width * height;
    const temp = new Uint8Array(size);
    const pwidth = (width + 3) >> 2;

    let destIdx = 0;
    for (let plane = 0; plane < 4; plane++) {
        for (let y = 0; y < height; y++) {
            for (let x = 0; x < pwidth; x++) {
                const srcx = x * 4 + plane;
                if (srcx < width)
                    temp[destIdx] = source[y * width + srcx];
                else
                    temp[destIdx] = 0;
                destIdx++;
            }
        }
    }
    source.set(temp.subarray(0, size));
}

//===========================================================================
// VL_UpdateScreen - upload screenbuf to Canvas
//===========================================================================

export function VL_UpdateScreen(): void {
    if (!ctx || !imageData) return;

    const pixels = imageData.data;

    for (let y = 0; y < 200; y++) {
        for (let x = 0; x < 320; x++) {
            const idx = screenbuf[y * 320 + x];
            // VGA palette values are 6-bit (0-63), scale to 8-bit (0-255)
            const r = (palette[idx * 3 + 0] * 255 / 63) | 0;
            const g = (palette[idx * 3 + 1] * 255 / 63) | 0;
            const b = (palette[idx * 3 + 2] * 255 / 63) | 0;
            const offset = (y * 320 + x) * 4;
            pixels[offset + 0] = r;
            pixels[offset + 1] = g;
            pixels[offset + 2] = b;
            pixels[offset + 3] = 255;
        }
    }

    ctx.putImageData(imageData, 0, 0);
}
