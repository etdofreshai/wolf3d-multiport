// ID_CA.TS
// Ported from ID_CA.C - Cache Manager
// Loads WL6 files via fetch() and provides asset access

import { NUMCHUNKS, NUMPICS, STARTPICS, STARTFONT, STARTTILE8, STRUCTPIC } from './gfxv_wl1';
import { NUMSNDCHUNKS } from './audiowl1';
import { MAPSIZE } from './wl_def';
import { mapsegs } from './wl_def';
import { VL_MemToScreen } from './id_vl';

//===========================================================================
// Constants
//===========================================================================

export const NUMMAPS = 100;
export const MAPPLANES = 2;
const NEARTAG = 0xa7;
const FARTAG = 0xa8;
const FILEPOSSIZE = 3;  // THREEBYTEGRSTARTS

//===========================================================================
// Types
//===========================================================================

interface huffnode {
    bit0: number;
    bit1: number;
}

export interface maptype {
    planestart: Int32Array;     // [3]
    planelength: Uint16Array;   // [3]
    width: number;
    height: number;
    name: string;
}

export interface pictabletype {
    width: number;
    height: number;
}

//===========================================================================
// Global variables
//===========================================================================

export let tinf: Uint8Array | null = null;
export let mapon = -1;

export const mapheaderseg: (maptype | null)[] = new Array(NUMMAPS).fill(null);
export const audiosegs: (Uint8Array | null)[] = new Array(NUMSNDCHUNKS).fill(null);
export const grsegs: (Uint8Array | null)[] = new Array(NUMCHUNKS).fill(null);

export const grneeded: Uint8Array = new Uint8Array(NUMCHUNKS);
export let ca_levelbit = 1;
export let ca_levelnum = 0;

export let pictable: pictabletype[] = [];

let grstarts: Int32Array | null = null;
let audiostarts: Int32Array | null = null;
let grhuffman: huffnode[] = [];

// Raw file data (loaded via fetch)
let grData: Uint8Array | null = null;
let mapData: Uint8Array | null = null;
let audioData: Uint8Array | null = null;

// Map file header data
let mapheadData: Uint8Array | null = null;
let rlew_tag = 0;

const extension = 'WL1';

//===========================================================================
// GRFILEPOS - 3-byte file positions
//===========================================================================

function GRFILEPOS(c: number): number {
    if (!grstarts) return -1;
    // grstarts is stored as 3-byte packed values, but we've already
    // expanded them into a proper Int32Array during setup
    const value = grstarts[c];
    if (value === 0xffffff || value === -1) return -1;
    return value;
}

//===========================================================================
// Huffman decompression
//===========================================================================

function CAL_HuffExpand(source: Uint8Array, srcOffset: number, dest: Uint8Array, length: number, hufftable: huffnode[]): void {
    const headptr = 254;  // head node is always node 254
    let srcIdx = srcOffset;
    let destIdx = 0;
    let srcbyte = source[srcIdx++];
    let srcbit = 1;
    let nodeon = headptr;

    while (destIdx < length) {
        let val: number;
        if (srcbyte & srcbit)
            val = hufftable[nodeon].bit1;
        else
            val = hufftable[nodeon].bit0;

        srcbit <<= 1;
        if (srcbit === 256) {
            srcbyte = source[srcIdx++] || 0;
            srcbit = 1;
        }

        if (val < 256) {
            dest[destIdx++] = val;
            nodeon = headptr;
        } else {
            nodeon = val - 256;
        }
    }
}

//===========================================================================
// Carmack decompression
//===========================================================================

function CAL_CarmackExpand(source: Uint8Array, srcOffset: number, dest: Uint16Array, expandedLength: number): void {
    const wordLength = (expandedLength / 2) | 0;
    let inIdx = srcOffset;
    let outIdx = 0;

    const readWord = (): number => {
        const val = source[inIdx] | (source[inIdx + 1] << 8);
        inIdx += 2;
        return val;
    };

    let remaining = wordLength;
    while (remaining > 0) {
        const ch = readWord();
        const chhigh = (ch >> 8) & 0xff;

        if (chhigh === NEARTAG) {
            const count = ch & 0xff;
            if (count === 0) {
                const nextByte = source[inIdx++];
                dest[outIdx++] = (NEARTAG << 8) | nextByte;
                remaining--;
            } else {
                const offset = source[inIdx++];
                let copyIdx = outIdx - offset;
                remaining -= count;
                for (let i = 0; i < count; i++)
                    dest[outIdx++] = dest[copyIdx++];
            }
        } else if (chhigh === FARTAG) {
            const count = ch & 0xff;
            if (count === 0) {
                const nextByte = source[inIdx++];
                dest[outIdx++] = (FARTAG << 8) | nextByte;
                remaining--;
            } else {
                const offset = readWord();
                let copyIdx = offset;
                remaining -= count;
                for (let i = 0; i < count; i++)
                    dest[outIdx++] = dest[copyIdx++];
            }
        } else {
            dest[outIdx++] = ch;
            remaining--;
        }
    }
}

//===========================================================================
// RLEW expansion
//===========================================================================

export function CA_RLEWexpand(source: Uint16Array, srcOffset: number, dest: Uint16Array, expandedLength: number, rlewtag: number): void {
    const wordLength = (expandedLength / 2) | 0;
    let srcIdx = srcOffset;
    let destIdx = 0;

    while (destIdx < wordLength) {
        const value = source[srcIdx++];
        if (value !== rlewtag) {
            dest[destIdx++] = value;
        } else {
            const count = source[srcIdx++];
            const fillval = source[srcIdx++];
            for (let i = 0; i < count; i++)
                dest[destIdx++] = fillval;
        }
    }
}

//===========================================================================
// File loading helpers
//===========================================================================

async function loadFile(name: string): Promise<Uint8Array> {
    const base = (typeof import.meta !== 'undefined' && import.meta.env?.BASE_URL) || '/';
    const response = await fetch(`${base}${name}`);
    if (!response.ok) {
        throw new Error(`CA: Could not load ${name}`);
    }
    const buffer = await response.arrayBuffer();
    return new Uint8Array(buffer);
}

//===========================================================================
// CAL_SetupGrFile
//===========================================================================

async function CAL_SetupGrFile(): Promise<void> {
    // Load VGADICT (huffman dictionary)
    const dictData = await loadFile(`VGADICT.${extension}`);
    grhuffman = [];
    for (let i = 0; i < 255; i++) {
        grhuffman.push({
            bit0: dictData[i * 4] | (dictData[i * 4 + 1] << 8),
            bit1: dictData[i * 4 + 2] | (dictData[i * 4 + 3] << 8),
        });
    }

    // Load VGAHEAD (3-byte offsets)
    const headData = await loadFile(`VGAHEAD.${extension}`);
    const numPositions = ((headData.length / FILEPOSSIZE) | 0);
    grstarts = new Int32Array(numPositions);
    for (let i = 0; i < numPositions; i++) {
        let value = headData[i * 3] | (headData[i * 3 + 1] << 8) | (headData[i * 3 + 2] << 16);
        if (value === 0xffffff) value = -1;
        grstarts[i] = value;
    }

    // Load VGAGRAPH
    grData = await loadFile(`VGAGRAPH.${extension}`);

    // Load pictable (STRUCTPIC chunk)
    const pos = GRFILEPOS(STRUCTPIC);
    if (pos >= 0 && grData) {
        const view = new DataView(grData.buffer, grData.byteOffset + pos, 4);
        const expandedLen = view.getInt32(0, true);
        const nextPos = GRFILEPOS(STRUCTPIC + 1);
        const compLen = nextPos - pos - 4;

        const expanded = new Uint8Array(expandedLen);
        CAL_HuffExpand(grData, pos + 4, expanded, expandedLen, grhuffman);

        // Parse pictable: pairs of int16
        pictable = [];
        const ptView = new DataView(expanded.buffer);
        for (let i = 0; i < NUMPICS; i++) {
            pictable.push({
                width: ptView.getInt16(i * 4, true),
                height: ptView.getInt16(i * 4 + 2, true),
            });
        }
    }
}

//===========================================================================
// CAL_SetupMapFile
//===========================================================================

async function CAL_SetupMapFile(): Promise<void> {
    // Load MAPHEAD
    mapheadData = await loadFile(`MAPHEAD.${extension}`);
    tinf = mapheadData;

    // Parse RLEW tag (first 2 bytes of MAPHEAD)
    rlew_tag = mapheadData[0] | (mapheadData[1] << 8);

    // Load GAMEMAPS (Carmacized)
    mapData = await loadFile(`GAMEMAPS.${extension}`);

    // Parse map headers
    for (let i = 0; i < NUMMAPS; i++) {
        const offsetPos = 2 + i * 4;  // After 2-byte RLEW tag
        const headerOffset = new DataView(mapheadData.buffer, mapheadData.byteOffset + offsetPos, 4).getInt32(0, true);

        if (headerOffset < 0) continue;  // Sparse map

        const hView = new DataView(mapData.buffer, mapData.byteOffset + headerOffset);
        const mh: maptype = {
            planestart: new Int32Array(3),
            planelength: new Uint16Array(3),
            width: 0,
            height: 0,
            name: '',
        };

        for (let p = 0; p < 3; p++)
            mh.planestart[p] = hView.getInt32(p * 4, true);
        for (let p = 0; p < 3; p++)
            mh.planelength[p] = hView.getUint16(12 + p * 2, true);
        mh.width = hView.getUint16(18, true);
        mh.height = hView.getUint16(20, true);

        // name is 16 bytes starting at offset 22
        const nameBytes = new Uint8Array(mapData.buffer, mapData.byteOffset + headerOffset + 22, 16);
        mh.name = String.fromCharCode(...nameBytes).replace(/\0.*$/, '');

        mapheaderseg[i] = mh;
    }

    // Allocate map planes
    mapsegs[0] = new Uint16Array(MAPSIZE * MAPSIZE);
    mapsegs[1] = new Uint16Array(MAPSIZE * MAPSIZE);
}

//===========================================================================
// CAL_SetupAudioFile
//===========================================================================

async function CAL_SetupAudioFile(): Promise<void> {
    // Load AUDIOHED
    const ahedData = await loadFile(`AUDIOHED.${extension}`);
    const numOffsets = (ahedData.length / 4) | 0;
    audiostarts = new Int32Array(numOffsets);
    const ahedView = new DataView(ahedData.buffer, ahedData.byteOffset);
    for (let i = 0; i < numOffsets; i++) {
        audiostarts[i] = ahedView.getInt32(i * 4, true);
    }

    // Load AUDIOT
    audioData = await loadFile(`AUDIOT.${extension}`);
}

//===========================================================================
// CA_Startup
//===========================================================================

export async function CA_Startup(): Promise<void> {
    await CAL_SetupMapFile();
    await CAL_SetupGrFile();
    await CAL_SetupAudioFile();

    mapon = -1;
    ca_levelbit = 1;
    ca_levelnum = 0;
}

//===========================================================================
// CA_Shutdown
//===========================================================================

export function CA_Shutdown(): void {
    grData = null;
    mapData = null;
    audioData = null;
}

//===========================================================================
// CA_CacheGrChunk
//===========================================================================

export function CA_CacheGrChunk(chunk: number): void {
    if (grsegs[chunk]) return;  // Already cached

    const pos = GRFILEPOS(chunk);
    if (pos < 0 || !grData) return;

    const next = GRFILEPOS(chunk + 1);

    if (chunk >= STARTTILE8 && chunk < STARTTILE8 + 1) {
        // Tile8s are not individually compressed
        const compLen = next - pos;
        grsegs[chunk] = grData.slice(pos, pos + compLen);
    } else {
        // Read expanded length from first 4 bytes
        const view = new DataView(grData.buffer, grData.byteOffset + pos, 4);
        const expandedLen = view.getInt32(0, true);
        const compLen = next - pos - 4;

        if (expandedLen <= 0 || expandedLen > 1024 * 1024) {
            // Probably raw data
            grsegs[chunk] = grData.slice(pos, pos + (next - pos));
            return;
        }

        const expanded = new Uint8Array(expandedLen);
        CAL_HuffExpand(grData, pos + 4, expanded, expandedLen, grhuffman);
        grsegs[chunk] = expanded;
    }
}

//===========================================================================
// CA_CacheScreen - special case: decompress directly to screen-sized buffer
//===========================================================================

export function CA_CacheScreen(chunk: number): void {
    CA_CacheGrChunk(chunk);
    // Blit fullscreen image to screen buffer (like original C VGA direct write)
    if (grsegs[chunk]) {
        VL_MemToScreen(grsegs[chunk], 320, 200, 0, 0);
    }
}

//===========================================================================
// CA_CacheMap
//===========================================================================

export function CA_CacheMap(mapnum: number): void {
    mapon = mapnum;

    const header = mapheaderseg[mapnum];
    if (!header || !mapData) {
        throw new Error(`CA_CacheMap: map ${mapnum} not loaded`);
    }

    // Load and decompress each plane
    for (let plane = 0; plane < MAPPLANES; plane++) {
        const pos = header.planestart[plane];
        const compLength = header.planelength[plane];

        if (pos <= 0 || compLength <= 0) continue;

        // Read compressed data
        const compressed = mapData.slice(pos, pos + compLength);

        // First word of compressed data is the expanded size
        const expandedSize = compressed[0] | (compressed[1] << 8);

        // Carmack decompress
        const carmackDest = new Uint16Array(expandedSize / 2);
        CAL_CarmackExpand(compressed, 2, carmackDest, expandedSize);

        // RLEW decompress
        // First word of carmack output is the final expanded size
        const finalSize = carmackDest[0];
        const rlewDest = new Uint16Array(finalSize / 2);
        CA_RLEWexpand(carmackDest, 1, rlewDest, finalSize, rlew_tag);

        // Copy to mapsegs
        if (plane < 2) {
            mapsegs[plane] = rlewDest.slice(0, MAPSIZE * MAPSIZE);
        }
    }
}

//===========================================================================
// CA_CacheAudioChunk
//===========================================================================

export function CA_CacheAudioChunk(chunk: number): void {
    if (!audiostarts || !audioData) return;
    if (chunk < 0 || chunk >= audiostarts.length - 1) return;

    const pos = audiostarts[chunk];
    const nextPos = audiostarts[chunk + 1];
    if (pos < 0 || nextPos <= pos) return;

    audiosegs[chunk] = audioData.slice(pos, nextPos);
}

//===========================================================================
// CA_LoadAllSounds
//===========================================================================

export function CA_LoadAllSounds(): void {
    if (!audiostarts) return;
    for (let i = 0; i < NUMSNDCHUNKS && i < audiostarts.length - 1; i++) {
        CA_CacheAudioChunk(i);
    }
}

//===========================================================================
// CA_UpLevel / CA_DownLevel
//===========================================================================

export function CA_UpLevel(): void {
    if (ca_levelnum === 7) {
        throw new Error('CA_UpLevel: Too many levels!');
    }
    ca_levelnum++;
    ca_levelbit <<= 1;
}

export function CA_DownLevel(): void {
    if (ca_levelnum === 0) {
        throw new Error('CA_DownLevel: Already at lowest level!');
    }
    ca_levelnum--;
    ca_levelbit >>= 1;
}

//===========================================================================
// Other cache management
//===========================================================================

export function CA_SetGrPurge(): void {
    // No-op in browser - we don't purge
}

export function CA_SetAllPurge(): void {
    // No-op
}

export function CA_ClearMarks(): void {
    grneeded.fill(0);
}

export function CA_ClearAllMarks(): void {
    grneeded.fill(0);
}

export function CA_MarkGrChunk(chunk: number): void {
    grneeded[chunk] |= ca_levelbit;
}

export function CA_CacheMarks(): void {
    for (let i = 0; i < NUMCHUNKS; i++) {
        if (grneeded[i] & ca_levelbit) {
            CA_CacheGrChunk(i);
        }
    }
}

export function UNCACHEGRCHUNK(chunk: number): void {
    grsegs[chunk] = null;
    grneeded[chunk] &= ~ca_levelbit;
}
