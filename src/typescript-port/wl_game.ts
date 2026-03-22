// WL_GAME.TS
// Ported from WL_GAME.C - Game loop and level setup

import * as VL from './id_vl';
import * as VH from './id_vh';
import * as CA from './id_ca';
import * as SD from './id_sd';
import * as IN from './id_in';
import * as PM from './id_pm';
import * as US from './id_us_1';
import {
    NUMLATCHPICS, MAPSIZE, NUMAREAS, MAXACTORS, MAXSTATS, MAXDOORS,
    STATUSLINES, SCREENBWIDE,
    gametype, objtype, statobj_t, doorobj_t, newObjtype,
    exit_t, classtype, activetype, dirtype,
    tilemap, spotvis, actorat, mapsegs, farmapylookup,
    AREATILE, AMBUSHTILE, ICONARROWS, PUSHABLETILE, EXITTILE,
    ELEVATORTILE, ALTELEVATORTILE,
    setMapWidth, setMapHeight,
} from './wl_def';
import { STARTPICS, LATCHPICS_LUMP_START, LATCHPICS_LUMP_END } from './gfxv_wl6';
import { gamestate, viewsize, screenloc, freelatch, SetViewSize, NewViewSize } from './wl_main';

//===========================================================================
// Global variables
//===========================================================================

export let ingame = false;
export let fizzlein = false;
export const latchpics: Uint32Array = new Uint32Array(NUMLATCHPICS);
export let doornum = 0;

export let demoname = 'DEMO0.';

export let spearx: number = 0;
export let speary: number = 0;
export let spearangle: number = 0;
export let spearflag = false;

//===========================================================================
// SetupGameLevel
//===========================================================================

export function SetupGameLevel(): void {
    // Load the map
    CA.CA_CacheMap(gamestate.mapon);

    setMapWidth(64);
    setMapHeight(64);

    // Initialize lookup tables
    for (let y = 0; y < MAPSIZE; y++) {
        farmapylookup[y] = y * MAPSIZE;
    }

    // Clear the tile and actor maps
    for (let y = 0; y < MAPSIZE; y++) {
        for (let x = 0; x < MAPSIZE; x++) {
            tilemap[x][y] = 0;
            spotvis[x][y] = 0;
            actorat[x][y] = null;
        }
    }

    // Scan plane 0 for wall tiles and doors
    for (let y = 0; y < MAPSIZE; y++) {
        for (let x = 0; x < MAPSIZE; x++) {
            const tile = mapsegs[0][y * MAPSIZE + x];
            if (tile >= 1 && tile <= 89) {
                // It's a wall tile
                tilemap[x][y] = tile;
                actorat[x][y] = tile;  // Store as number for walls
            }
        }
    }
}

//===========================================================================
// ScanInfoPlane - Scan plane 1 for actors, items, etc.
//===========================================================================

export function ScanInfoPlane(): void {
    // This would scan mapsegs[1] for:
    // - Player start position (values 19-22)
    // - Enemy spawn positions
    // - Item/decoration spawn positions
    // - Door definitions
    // - Secret walls
    // For now this is a stub
}

//===========================================================================
// DrawPlayBorder / DrawPlayScreen
//===========================================================================

export function DrawPlayBorder(): void {
    VL.VL_Bar(0, 0, 320, 200 - STATUSLINES, 0x2d);
}

export function DrawPlayScreen(): void {
    DrawPlayBorder();
    DrawAllPlayBorder();
}

export function DrawAllPlayBorder(): void {
    // Draw the border around the 3D view window
}

export function DrawAllPlayBorderSides(): void {
    // Draw just the sides
}

export function NormalScreen(): void {
    // Switch back to normal screen layout
}

//===========================================================================
// GameLoop
//===========================================================================

export async function GameLoop(): Promise<void> {
    ingame = true;

    // Set up the level
    SetupGameLevel();
    ScanInfoPlane();

    // Main game loop would go here
    // PlayLoop() handles the actual frame-by-frame gameplay

    ingame = false;
}

//===========================================================================
// FizzleOut
//===========================================================================

export function FizzleOut(): void {
    // Fizzle fade effect
}

//===========================================================================
// ClearMemory
//===========================================================================

export function ClearMemory(): void {
    // Free cached graphics and sounds
    CA.CA_SetAllPurge();
    PM.PM_Reset();
}

//===========================================================================
// PlayDemo / RecordDemo
//===========================================================================

export function PlayDemo(_demonumber: number): void {
    // Stub
}

export function RecordDemo(): void {
    // Stub
}

//===========================================================================
// DrawHighScores / CheckHighScore
//===========================================================================

export function DrawHighScores(): void {
    // Draw high score screen
}

export function CheckHighScore(_score: number, _other: number): void {
    // Check if score qualifies for high score table
}
