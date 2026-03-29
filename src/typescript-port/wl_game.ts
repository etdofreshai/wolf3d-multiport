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
    enemy_t, gamedifficulty_t,
    setMapWidth, setMapHeight,
} from './wl_def';
import { STARTPICS, LATCHPICS_LUMP_START, LATCHPICS_LUMP_END, graphicnums } from './gfxv_wl1';
import { gamestate, viewsize, screenloc, freelatch, SetViewSize, NewViewSize, loadedgame } from './wl_main';
import {
    InitActorList, PlayLoop, playstate, player,
    demorecord, demoplayback,
} from './wl_play';
import {
    SpawnDoor, InitDoorList, InitStaticList, SpawnStatic, InitAreas,
    MoveDoors, MovePWalls,
} from './wl_act1';
import {
    SpawnStand, SpawnPatrol, SpawnDeadGuard,
    SpawnBoss, SpawnGretel, SpawnTrans, SpawnUber, SpawnWill,
    SpawnDeath, SpawnAngel, SpawnSpectre, SpawnGhosts,
    SpawnSchabbs, SpawnGift, SpawnFat, SpawnFakeHitler, SpawnHitler,
} from './wl_act2';
import { SpawnPlayer, DrawFace, DrawHealth, DrawLevel, DrawLives, DrawScore, DrawWeapon, DrawKeys, DrawAmmo } from './wl_agent';
import { ThreeDRefresh } from './wl_draw';
import { soundnames } from './audiowl1';
import { horizwall, vertwall } from './wl_draw';

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

const ElevatorBackTo = [1, 1, 7, 3, 5, 3];

//===========================================================================
// ScanInfoPlane - scan plane 1 for actors, items, etc.
//===========================================================================

export function ScanInfoPlane(): void {
    let idx = 0;
    for (let y = 0; y < MAPSIZE; y++) {
        for (let x = 0; x < MAPSIZE; x++) {
            let tile = mapsegs[1][idx++];
            if (!tile) continue;

            switch (true) {
                // Player start positions
                case (tile >= 19 && tile <= 22):
                    SpawnPlayer(x, y, tile - 19);
                    break;

                // Static objects (23-74)
                case (tile >= 23 && tile <= 74):
                    SpawnStatic(x, y, tile - 23);
                    break;

                // Secret wall marker
                case (tile === 98):
                    if (!loadedgame) gamestate.secrettotal++;
                    break;

                // Guards
                case (tile >= 180 && tile <= 183):
                    if (gamestate.difficulty < gamedifficulty_t.gd_hard) break;
                    tile -= 36;
                    // fall through
                case (tile >= 144 && tile <= 147):
                    if (gamestate.difficulty < gamedifficulty_t.gd_medium) break;
                    tile -= 36;
                    // fall through
                case (tile >= 108 && tile <= 111):
                    SpawnStand(enemy_t.en_guard, x, y, tile - 108);
                    break;

                case (tile >= 184 && tile <= 187):
                    if (gamestate.difficulty < gamedifficulty_t.gd_hard) break;
                    tile -= 36;
                case (tile >= 148 && tile <= 151):
                    if (gamestate.difficulty < gamedifficulty_t.gd_medium) break;
                    tile -= 36;
                case (tile >= 112 && tile <= 115):
                    SpawnPatrol(enemy_t.en_guard, x, y, tile - 112);
                    break;

                case (tile === 124):
                    SpawnDeadGuard(x, y);
                    break;

                // Officers
                case (tile >= 188 && tile <= 191):
                    if (gamestate.difficulty < gamedifficulty_t.gd_hard) break;
                    tile -= 36;
                case (tile >= 152 && tile <= 155):
                    if (gamestate.difficulty < gamedifficulty_t.gd_medium) break;
                    tile -= 36;
                case (tile >= 116 && tile <= 119):
                    SpawnStand(enemy_t.en_officer, x, y, tile - 116);
                    break;

                case (tile >= 192 && tile <= 195):
                    if (gamestate.difficulty < gamedifficulty_t.gd_hard) break;
                    tile -= 36;
                case (tile >= 156 && tile <= 159):
                    if (gamestate.difficulty < gamedifficulty_t.gd_medium) break;
                    tile -= 36;
                case (tile >= 120 && tile <= 123):
                    SpawnPatrol(enemy_t.en_officer, x, y, tile - 120);
                    break;

                // SS
                case (tile >= 198 && tile <= 201):
                    if (gamestate.difficulty < gamedifficulty_t.gd_hard) break;
                    tile -= 36;
                case (tile >= 162 && tile <= 165):
                    if (gamestate.difficulty < gamedifficulty_t.gd_medium) break;
                    tile -= 36;
                case (tile >= 126 && tile <= 129):
                    SpawnStand(enemy_t.en_ss, x, y, tile - 126);
                    break;

                case (tile >= 202 && tile <= 205):
                    if (gamestate.difficulty < gamedifficulty_t.gd_hard) break;
                    tile -= 36;
                case (tile >= 166 && tile <= 169):
                    if (gamestate.difficulty < gamedifficulty_t.gd_medium) break;
                    tile -= 36;
                case (tile >= 130 && tile <= 133):
                    SpawnPatrol(enemy_t.en_ss, x, y, tile - 130);
                    break;

                // Dogs
                case (tile >= 206 && tile <= 209):
                    if (gamestate.difficulty < gamedifficulty_t.gd_hard) break;
                    tile -= 36;
                case (tile >= 170 && tile <= 173):
                    if (gamestate.difficulty < gamedifficulty_t.gd_medium) break;
                    tile -= 36;
                case (tile >= 134 && tile <= 137):
                    SpawnStand(enemy_t.en_dog, x, y, tile - 134);
                    break;

                case (tile >= 210 && tile <= 213):
                    if (gamestate.difficulty < gamedifficulty_t.gd_hard) break;
                    tile -= 36;
                case (tile >= 174 && tile <= 177):
                    if (gamestate.difficulty < gamedifficulty_t.gd_medium) break;
                    tile -= 36;
                case (tile >= 138 && tile <= 141):
                    SpawnPatrol(enemy_t.en_dog, x, y, tile - 138);
                    break;

                // Bosses
                case (tile === 214): SpawnBoss(x, y); break;
                case (tile === 197): SpawnGretel(x, y); break;
                case (tile === 215): SpawnGift(x, y); break;
                case (tile === 179): SpawnFat(x, y); break;
                case (tile === 196): SpawnSchabbs(x, y); break;
                case (tile === 160): SpawnFakeHitler(x, y); break;
                case (tile === 178): SpawnHitler(x, y); break;

                // Mutants
                case (tile >= 252 && tile <= 255):
                    if (gamestate.difficulty < gamedifficulty_t.gd_hard) break;
                    tile -= 18;
                case (tile >= 234 && tile <= 237):
                    if (gamestate.difficulty < gamedifficulty_t.gd_medium) break;
                    tile -= 18;
                case (tile >= 216 && tile <= 219):
                    SpawnStand(enemy_t.en_mutant, x, y, tile - 216);
                    break;

                case (tile >= 256 && tile <= 259):
                    if (gamestate.difficulty < gamedifficulty_t.gd_hard) break;
                    tile -= 18;
                case (tile >= 238 && tile <= 241):
                    if (gamestate.difficulty < gamedifficulty_t.gd_medium) break;
                    tile -= 18;
                case (tile >= 220 && tile <= 223):
                    SpawnPatrol(enemy_t.en_mutant, x, y, tile - 220);
                    break;

                // Ghosts
                case (tile === 224): SpawnGhosts(enemy_t.en_blinky, x, y); break;
                case (tile === 225): SpawnGhosts(enemy_t.en_clyde, x, y); break;
                case (tile === 226): SpawnGhosts(enemy_t.en_pinky, x, y); break;
                case (tile === 227): SpawnGhosts(enemy_t.en_inky, x, y); break;
            }
        }
    }
}

//===========================================================================
// SetupGameLevel
//===========================================================================

export function SetupGameLevel(): void {
    if (!loadedgame) {
        gamestate.TimeCount = 0;
        gamestate.secrettotal = 0;
        gamestate.killtotal = 0;
        gamestate.treasuretotal = 0;
        gamestate.secretcount = 0;
        gamestate.killcount = 0;
        gamestate.treasurecount = 0;
    }

    if (demoplayback || demorecord) {
        US.US_InitRndT(false);
    } else {
        US.US_InitRndT(true);
    }

    // Load the level
    CA.CA_CacheMap(gamestate.mapon + 10 * gamestate.episode);

    setMapWidth(64);
    setMapHeight(64);

    // Initialize lookup tables
    for (let y = 0; y < MAPSIZE; y++) {
        farmapylookup[y] = y * MAPSIZE;
    }

    // Initialize wall texture lookup tables
    for (let i = 1; i < 90; i++) {
        horizwall[i] = (i - 1) * 2;
        vertwall[i] = (i - 1) * 2 + 1;
    }

    // Clear tile and actor maps, copy wall data
    for (let y = 0; y < MAPSIZE; y++) {
        for (let x = 0; x < MAPSIZE; x++) {
            tilemap[x][y] = 0;
            spotvis[x][y] = 0;
            actorat[x][y] = null;
        }
    }

    // Copy wall data from plane 0
    let mapIdx = 0;
    let wallCount = 0;
    for (let y = 0; y < MAPSIZE; y++) {
        for (let x = 0; x < MAPSIZE; x++) {
            const tile = mapsegs[0][mapIdx++];
            if (tile < AREATILE) {
                tilemap[x][y] = tile;
                actorat[x][y] = tile as any;
                if (tile > 0) wallCount++;
            }
        }
    }

    // Spawn doors, actors, items
    InitActorList();
    InitDoorList();
    InitStaticList();

    // Spawn doors from plane 0
    mapIdx = 0;
    for (let y = 0; y < MAPSIZE; y++) {
        for (let x = 0; x < MAPSIZE; x++) {
            const tile = mapsegs[0][mapIdx++];
            if (tile >= 90 && tile <= 101) {
                switch (tile) {
                    case 90: case 92: case 94: case 96: case 98: case 100:
                        SpawnDoor(x, y, true, ((tile - 90) / 2) | 0);
                        break;
                    case 91: case 93: case 95: case 97: case 99: case 101:
                        SpawnDoor(x, y, false, ((tile - 91) / 2) | 0);
                        break;
                }
            }
        }
    }

    // Spawn actors from plane 1
    ScanInfoPlane();

    // Take out ambush markers
    mapIdx = 0;
    for (let y = 0; y < MAPSIZE; y++) {
        for (let x = 0; x < MAPSIZE; x++) {
            const tile = mapsegs[0][mapIdx];
            if (tile === AMBUSHTILE) {
                tilemap[x][y] = 0;
                if (actorat[x][y] === AMBUSHTILE as any) {
                    actorat[x][y] = null;
                }
            }
            mapIdx++;
        }
    }

    CA.CA_LoadAllSounds();
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

    // Cache all latch pics (weapons, keys, numbers, faces)
    for (let i = LATCHPICS_LUMP_START; i <= LATCHPICS_LUMP_END; i++) {
        CA.CA_CacheGrChunk(i);
    }

    // Draw status bar background
    CA.CA_CacheGrChunk(graphicnums.STATUSBARPIC);
    VH.VWB_DrawPic(0, 160, graphicnums.STATUSBARPIC);

    // Draw status bar elements
    DrawFace();
    DrawHealth();
    DrawLevel();
    DrawLives();
    DrawScore();
    DrawWeapon();
    DrawKeys();
    DrawAmmo();
}

export function DrawAllPlayBorder(): void {
    // Draw border around 3D view window
    const xl = ((160 - viewsize * 8) | 0);
    const yl = ((200 - STATUSLINES - viewsize * 8 * 0.5) / 2) | 0;
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

    SetupGameLevel();
    DrawPlayScreen();

    fizzlein = true;

    // Cache status bar and HUD graphics
    CA.CA_CacheGrChunk(STARTPICS + 0);  // Ensure fonts are loaded
    CA.CA_CacheGrChunk(STARTPICS + 1);

    VL.VL_UpdateScreen();
    await VH.VW_FadeIn();

    await PlayLoop();

    ingame = false;
}

//===========================================================================
// FizzleOut
//===========================================================================

export function FizzleOut(): void {
    // Fizzle fade effect (randomized pixel fill)
}

//===========================================================================
// ClearMemory
//===========================================================================

export function ClearMemory(): void {
    CA.CA_SetAllPurge();
    PM.PM_Reset();
}

//===========================================================================
// PlayDemo / RecordDemo
//===========================================================================

export function PlayDemo(_demonumber: number): void {
    // Demo playback stub
}

export function RecordDemo(): void {
    // Demo recording stub
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
