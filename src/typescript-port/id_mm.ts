// ID_MM.TS
// Ported from ID_MM.C - Memory Manager
// Simplified for browser: we just use JS allocation and let GC handle freeing.

export const BUFFERSIZE = 0x1000;

export interface mminfotype {
    nearheap: number;
    farheap: number;
    EMSmem: number;
    XMSmem: number;
    mainmem: number;
}

export const mminfo: mminfotype = {
    nearheap: 0,
    farheap: 0,
    EMSmem: 0,
    XMSmem: 0,
    mainmem: 0,
};

export let bufferseg: Uint8Array = new Uint8Array(BUFFERSIZE);
export let mmerror = false;

export function MM_Startup(): void {
    bufferseg = new Uint8Array(BUFFERSIZE);
    mminfo.mainmem = 4 * 1024 * 1024;  // Report 4MB available
    mminfo.farheap = 4 * 1024 * 1024;
}

export function MM_Shutdown(): void {
    // Nothing to do - GC handles it
}

export function MM_GetPtr(size: number): Uint8Array {
    return new Uint8Array(size);
}

export function MM_FreePtr(_ptr: Uint8Array | null): void {
    // GC handles it
}

export function MM_SetPurge(_ptr: Uint8Array | null, _purge: number): void {
    // No-op in browser
}

export function MM_SetLock(_ptr: Uint8Array | null, _locked: boolean): void {
    // No-op in browser
}

export function MM_SortMem(): void {
    // No-op
}

export function MM_UnusedMemory(): number {
    return 4 * 1024 * 1024;
}

export function MM_TotalFree(): number {
    return 4 * 1024 * 1024;
}

export function MM_BombOnError(_bomb: boolean): void {
    // No-op
}

export function MM_MapEMS(): void {
    // No-op
}
