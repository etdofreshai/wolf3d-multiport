// ID_US_1.TS
// Ported from ID_US_1.C - User Manager

import * as VL from './id_vl';
import * as VH from './id_vh';
import * as IN from './id_in';
import { TimeCount } from './id_sd';

//===========================================================================
// Constants
//===========================================================================

export const MaxX = 320;
export const MaxY = 200;
export const MaxHighName = 57;
export const MaxScores = 7;
export const MaxGameName = 32;
export const MaxSaveGames = 6;
export const MaxString = 128;

//===========================================================================
// Types
//===========================================================================

export interface HighScore {
    name: string;
    score: number;
    completed: number;
    episode: number;
}

export interface SaveGame {
    signature: string;
    present: boolean;
    name: string;
}

export interface WindowRec {
    x: number; y: number;
    w: number; h: number;
    px: number; py: number;
}

export enum GameDiff {
    gd_Continue,
    gd_Easy,
    gd_Normal,
    gd_Hard
}

//===========================================================================
// Global variables
//===========================================================================

export let ingame = false;
export let abortgame = false;
export let loadedgame = false;
export let NoWait = false;
export let HighScoresDirty = false;
export let abortprogram: string | null = null;
export let restartgame: GameDiff = GameDiff.gd_Continue;

export let PrintX = 0;
export let PrintY = 0;
export let WindowX = 0;
export let WindowY = 0;
export let WindowW = 0;
export let WindowH = 0;

export let Button0 = false;
export let Button1 = false;
export let CursorBad = false;
export let CursorX = 0;
export let CursorY = 0;

// Function pointers
export let USL_MeasureString: (str: string) => { width: number; height: number } = (str) => VH.VW_MeasurePropString(str);
export let USL_DrawString: (str: string) => void = (str) => VH.VWB_DrawPropString(str);

export let USL_SaveGame: ((which: number) => boolean) | null = null;
export let USL_LoadGame: ((which: number) => boolean) | null = null;
export let USL_ResetGame: (() => void) | null = null;

export const Games: SaveGame[] = Array.from({ length: MaxSaveGames }, () => ({
    signature: '', present: false, name: '',
}));

export const Scores: HighScore[] = Array.from({ length: MaxScores }, () => ({
    name: '', score: 0, completed: 0, episode: 0,
}));

// Setter helpers
export function setIngame(v: boolean): void { ingame = v; }
export function setLoadedGame(v: boolean): void { loadedgame = v; }
export function setRestartGame(v: GameDiff): void { restartgame = v; }

// Random number table
let rndindex = 0;
const rndtable: number[] = [
      0,   8, 109, 220, 222, 241, 149, 107,  75, 248, 254, 140,  16,  66,
     74,  21, 211,  47,  80, 242, 154,  27, 205, 128, 161,  89,  77,  36,
     95, 110,  85,  48, 212, 140, 211, 249,  22,  79, 200,  50,  28, 188,
     52, 140, 202, 120,  68, 145,  62,  70, 184, 190,  91, 197, 152, 224,
    149, 104,  25, 178, 252, 182, 202, 182, 141, 197,   4,  81, 181, 242,
    145,  42,  39, 227, 156, 198, 225, 193, 219,  93, 122,  68, 249, 208,
    116, 184,  57,  82,   7,  92, 135, 104,  45, 167, 221,  80,  46, 101,
    229, 140, 170, 222, 202, 172, 100, 177, 122, 142, 144, 174, 153, 129,
    247,  50,  58,  70, 201, 248, 253, 108,  57, 229,  44,  40, 178, 128,
     17, 155,  31, 249, 178, 185,  23, 105, 154,  23, 238,  12,  36, 219,
    104, 233, 184, 198, 195,  45, 172, 173,  34,  62, 147,  58, 124, 209,
     36, 232, 201,  57, 147, 245, 241, 123, 233, 176, 222, 191, 234, 159,
     18, 136, 100, 114, 109,  61, 254,  30,  43,  69, 230, 187, 104,  72,
    167, 136,  33,  32, 113, 204,  27,  74, 242,  16,  33, 139, 176, 214,
    191,  45, 195, 200, 236,  78,  18, 227, 193, 131, 163,  78,  89,  39,
    186, 201, 132, 122, 199, 195, 131, 170, 134, 126,  47, 171, 135,  93,
    155, 153,  96, 136,  33,  93,  36,  43,  73, 102, 199,  97, 116, 126,
    205, 200,  42, 183, 203,   0,  78, 143,  33,  62, 148, 228, 166, 128
];

//===========================================================================
// US_Startup
//===========================================================================

export function US_Startup(): void {
    // Initialize default scores
    const defaultScores: [string, number, number, number][] = [
        ['id software-'+'Adrian', 10000, 1, 0],
        ['id software-'+'John', 10000, 1, 0],
        ['id software-'+'Kevin', 10000, 1, 0],
        ['id software-'+'Tom', 10000, 1, 0],
        ['id software-'+'Jay', 10000, 1, 0],
        ['id software-'+'Bobby', 10000, 1, 0],
        ['id software-'+'John2', 10000, 1, 0],
    ];

    for (let i = 0; i < MaxScores && i < defaultScores.length; i++) {
        Scores[i].name = defaultScores[i][0];
        Scores[i].score = defaultScores[i][1];
        Scores[i].completed = defaultScores[i][2];
        Scores[i].episode = defaultScores[i][3];
    }
}

export function US_Setup(): void {
    // Additional setup
}

export function US_Shutdown(): void {
    // Cleanup
}

//===========================================================================
// US_InitRndT
//===========================================================================

export function US_InitRndT(randomize: boolean): void {
    if (randomize) {
        rndindex = (Date.now() & 0xff);
    } else {
        rndindex = 0;
    }
}

//===========================================================================
// US_RndT - table-based random number
//===========================================================================

export function US_RndT(): number {
    rndindex = (rndindex + 1) & 0xff;
    return rndtable[rndindex] || 0;
}

//===========================================================================
// US_SetLoadSaveHooks
//===========================================================================

export function US_SetLoadSaveHooks(
    load: (which: number) => boolean,
    save: (which: number) => boolean,
    reset: () => void
): void {
    USL_LoadGame = load;
    USL_SaveGame = save;
    USL_ResetGame = reset;
}

//===========================================================================
// Window routines
//===========================================================================

export function US_DrawWindow(x: number, y: number, w: number, h: number): void {
    WindowX = x * 8;
    WindowY = y * 8;
    WindowW = w * 8;
    WindowH = h * 8;

    VH.VWB_Bar(WindowX, WindowY, WindowW, WindowH, VH.WHITE);
    VH.VWB_Hlin(WindowX - 1, WindowX + WindowW, WindowY - 1, 0);
    VH.VWB_Hlin(WindowX - 1, WindowX + WindowW, WindowY + WindowH, 0);
    VH.VWB_Vlin(WindowY - 1, WindowY + WindowH, WindowX - 1, 0);
    VH.VWB_Vlin(WindowY - 1, WindowY + WindowH, WindowX + WindowW, 0);

    PrintX = WindowX;
    PrintY = WindowY;
}

export function US_CenterWindow(w: number, h: number): void {
    US_DrawWindow(((MaxX / 8) - w) / 2, ((MaxY / 8) - h) / 2, w, h);
}

export function US_SaveWindow(win: WindowRec): void {
    win.x = WindowX;
    win.y = WindowY;
    win.w = WindowW;
    win.h = WindowH;
    win.px = PrintX;
    win.py = PrintY;
}

export function US_RestoreWindow(win: WindowRec): void {
    WindowX = win.x;
    WindowY = win.y;
    WindowW = win.w;
    WindowH = win.h;
    PrintX = win.px;
    PrintY = win.py;
}

export function US_ClearWindow(): void {
    VH.VWB_Bar(WindowX, WindowY, WindowW, WindowH, VH.WHITE);
    PrintX = WindowX;
    PrintY = WindowY;
}

//===========================================================================
// US_SetPrintRoutines
//===========================================================================

export function US_SetPrintRoutines(
    measure: (str: string) => { width: number; height: number },
    print: (str: string) => void
): void {
    USL_MeasureString = measure;
    USL_DrawString = print;
}

//===========================================================================
// US_Print
//===========================================================================

export function US_Print(str: string): void {
    const lines = str.split('\n');
    for (let i = 0; i < lines.length; i++) {
        if (i > 0) {
            PrintX = WindowX;
            PrintY += 10;  // Approximate line height
        }
        VH.setPx(PrintX);
        VH.setPy(PrintY);
        USL_DrawString(lines[i]);
        PrintX = VH.px;
    }
}

export function US_PrintCentered(s: string): void {
    const m = USL_MeasureString(s);
    PrintX = WindowX + ((WindowW - m.width) >> 1);
    VH.setPx(PrintX);
    VH.setPy(PrintY);
    USL_DrawString(s);
}

export function US_CPrint(s: string): void {
    const m = USL_MeasureString(s);
    PrintX = (MaxX - m.width) >> 1;
    VH.setPx(PrintX);
    VH.setPy(PrintY);
    USL_DrawString(s);
    PrintY += m.height;
}

export function US_CPrintLine(s: string): void {
    const m = USL_MeasureString(s);
    PrintX = WindowX + ((WindowW - m.width) >> 1);
    VH.setPx(PrintX);
    VH.setPy(PrintY);
    USL_DrawString(s);
    PrintY += m.height;
}

export function US_PrintUnsigned(n: number): void {
    US_Print(n.toString());
}

export function US_PrintSigned(n: number): void {
    US_Print(n.toString());
}

//===========================================================================
// US_HomeWindow
//===========================================================================

export function US_HomeWindow(): void {
    PrintX = WindowX;
    PrintY = WindowY;
}

//===========================================================================
// US_CheckParm
//===========================================================================

export function US_CheckParm(parm: string, strings: string[]): number {
    const p = parm.toLowerCase();
    for (let i = 0; i < strings.length; i++) {
        if (p === strings[i].toLowerCase()) return i;
    }
    return -1;
}

//===========================================================================
// US_LineInput
//===========================================================================

export async function US_LineInput(
    x: number, y: number, buf: { value: string }, def: string,
    escok: boolean, maxchars: number, maxwidth: number
): Promise<boolean> {
    buf.value = def;
    // Simple stub - real implementation would handle character-by-character input
    return true;
}

//===========================================================================
// Cursor routines (stubs)
//===========================================================================

export function US_StartCursor(): void {}
export function US_ShutCursor(): void {}
export function US_UpdateCursor(): boolean { return false; }

//===========================================================================
// Text screen routines (stubs for intro sequence)
//===========================================================================

export function US_TextScreen(): void {}
export function US_UpdateTextScreen(): void {}
export function US_FinishTextScreen(): void {}

//===========================================================================
// USL helpers
//===========================================================================

export function USL_GiveSaveName(game: number): string {
    return `SAVEGAM${game}.WL6`;
}
