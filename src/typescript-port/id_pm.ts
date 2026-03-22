// ID_PM.TS
// Ported from ID_PM.C - Page Manager
// Loads VSWAP file and provides page-based access to wall textures, sprites, and sound pages.

export const PMPageSize = 4096;

export interface PageListStruct {
    offset: number;
    length: number;
    locked: number;     // PMLockType: 0=unlocked, 1=locked
    mainPage: number;
    lastHit: number;
}

export let ChunksInFile = 0;
export let PMSpriteStart = 0;
export let PMSoundStart = 0;
export let PMPages: PageListStruct[] = [];

let pageData: (Uint8Array | null)[] = [];
let vswapData: ArrayBuffer | null = null;

export let PageFileName = 'VSWAP.';

//===========================================================================
// PM_Startup - Loads the VSWAP file
//===========================================================================

export async function PM_Startup(): Promise<void> {
    const extension = 'WL6';
    const filename = PageFileName + extension;

    const response = await fetch(`/${filename}`);
    if (!response.ok) {
        throw new Error(`PM_Startup: Could not load ${filename}`);
    }

    vswapData = await response.arrayBuffer();
    const view = new DataView(vswapData);

    // VSWAP header:
    // Uint16: ChunksInFile
    // Uint16: PMSpriteStart
    // Uint16: PMSoundStart
    ChunksInFile = view.getUint16(0, true);
    PMSpriteStart = view.getUint16(2, true);
    PMSoundStart = view.getUint16(4, true);

    // Then ChunksInFile Uint32 page offsets, then ChunksInFile Uint16 page lengths
    const headerSize = 6;
    PMPages = [];
    pageData = [];

    for (let i = 0; i < ChunksInFile; i++) {
        const offset = view.getUint32(headerSize + i * 4, true);
        const length = view.getUint16(headerSize + ChunksInFile * 4 + i * 2, true);
        PMPages.push({
            offset,
            length,
            locked: 0,
            mainPage: -1,
            lastHit: 0,
        });
        pageData.push(null);
    }
}

//===========================================================================
// PM_Shutdown
//===========================================================================

export function PM_Shutdown(): void {
    pageData = [];
    PMPages = [];
    vswapData = null;
}

//===========================================================================
// PM_GetPage - Returns a page's data
//===========================================================================

export function PM_GetPage(pagenum: number): Uint8Array | null {
    if (pagenum < 0 || pagenum >= ChunksInFile) return null;

    if (!pageData[pagenum]) {
        // Load page on demand
        const page = PMPages[pagenum];
        if (!vswapData || page.offset === 0 || page.length === 0) return null;

        pageData[pagenum] = new Uint8Array(vswapData, page.offset, page.length);
    }

    PMPages[pagenum].lastHit++;
    return pageData[pagenum];
}

//===========================================================================
// PM_GetPageAddress - same as PM_GetPage for our purposes
//===========================================================================

export function PM_GetPageAddress(pagenum: number): Uint8Array | null {
    return pageData[pagenum] || null;
}

//===========================================================================
// Convenience functions matching C macros
//===========================================================================

export function PM_GetSoundPage(v: number): Uint8Array | null {
    return PM_GetPage(PMSoundStart + v);
}

export function PM_GetSpritePage(v: number): Uint8Array | null {
    return PM_GetPage(PMSpriteStart + v);
}

//===========================================================================
// Other PM functions
//===========================================================================

export function PM_Reset(): void {
    // Reload all pages
    for (let i = 0; i < pageData.length; i++) {
        if (PMPages[i].locked === 0) {
            pageData[i] = null;
        }
    }
}

export function PM_Preload(_update: (current: number, total: number) => boolean): void {
    // Preload all pages
    for (let i = 0; i < ChunksInFile; i++) {
        PM_GetPage(i);
    }
}

export function PM_NextFrame(): void {
    // No-op in browser
}

export function PM_SetPageLock(pagenum: number, lock: number): void {
    if (pagenum >= 0 && pagenum < ChunksInFile)
        PMPages[pagenum].locked = lock;
}

export function PM_SetMainMemPurge(_level: number): void {
    // No-op
}

export function PM_CheckMainMem(): void {
    // No-op
}

export function PM_SetMainPurge(_level: number): void {
    // No-op
}
