// WL_ACT1.TS
// Ported from WL_ACT1.C - Doors, static objects, pushwalls

import {
    MAXDOORS, MAXSTATS, NUMAREAS, MAPSIZE,
    TILEGLOBAL, TILESHIFT, MINDIST,
    objtype, statobj_t, doorobj_t, dooraction_t, stat_t,
    FL_BONUS, FL_SHOOTABLE,
    tilemap, actorat, spotvis, mapsegs, farmapylookup,
    AREATILE,
    SpriteEnum,
    tics,
} from './wl_def';
import {
    doorobjlist, statobjlist, areaconnect, areabyplayer,
    player, laststatobj,
} from './wl_play';
import { gamestate, loadedgame } from './wl_main';
import * as SD from './id_sd';
import { soundnames } from './audiowl1';

//===========================================================================
// Constants
//===========================================================================

const DOORWIDTH = 0x7800;
const OPENTICS = 300;

//===========================================================================
// Global variables
//===========================================================================

export let doornum = 0;
export const doorposition: Uint16Array = new Uint16Array(MAXDOORS);
export let pwallstate = 0;
export let pwallpos = 0;
export let pwallx = 0;
export let pwally = 0;
export let pwalldir = 0;
export let pwalltile = 0;

// Static objects info table
const statinfo: { picnum: number; type: stat_t }[] = [
    { picnum: SpriteEnum.SPR_STAT_0, type: stat_t.dressing },           // puddle
    { picnum: SpriteEnum.SPR_STAT_1, type: stat_t.block },             // Green Barrel
    { picnum: SpriteEnum.SPR_STAT_2, type: stat_t.block },             // Table/chairs
    { picnum: SpriteEnum.SPR_STAT_3, type: stat_t.block },             // Floor lamp
    { picnum: SpriteEnum.SPR_STAT_4, type: stat_t.dressing },          // Chandelier
    { picnum: SpriteEnum.SPR_STAT_5, type: stat_t.block },             // Hanged man
    { picnum: SpriteEnum.SPR_STAT_6, type: stat_t.bo_alpo },           // Bad food
    { picnum: SpriteEnum.SPR_STAT_7, type: stat_t.block },             // Red pillar
    { picnum: SpriteEnum.SPR_STAT_8, type: stat_t.block },             // Tree
    { picnum: SpriteEnum.SPR_STAT_9, type: stat_t.dressing },          // Skeleton flat
    { picnum: SpriteEnum.SPR_STAT_10, type: stat_t.block },            // Sink
    { picnum: SpriteEnum.SPR_STAT_11, type: stat_t.block },            // Potted plant
    { picnum: SpriteEnum.SPR_STAT_12, type: stat_t.block },            // Urn
    { picnum: SpriteEnum.SPR_STAT_13, type: stat_t.block },            // Bare table
    { picnum: SpriteEnum.SPR_STAT_14, type: stat_t.dressing },         // Ceiling light
    { picnum: SpriteEnum.SPR_STAT_15, type: stat_t.dressing },         // Kitchen stuff
    { picnum: SpriteEnum.SPR_STAT_16, type: stat_t.block },            // Armor
    { picnum: SpriteEnum.SPR_STAT_17, type: stat_t.block },            // Cage
    { picnum: SpriteEnum.SPR_STAT_18, type: stat_t.block },            // Skeleton in cage
    { picnum: SpriteEnum.SPR_STAT_19, type: stat_t.dressing },         // Skeleton relax
    { picnum: SpriteEnum.SPR_STAT_20, type: stat_t.bo_key1 },          // Key 1
    { picnum: SpriteEnum.SPR_STAT_21, type: stat_t.bo_key2 },          // Key 2
    { picnum: SpriteEnum.SPR_STAT_22, type: stat_t.block },            // Stuff
    { picnum: SpriteEnum.SPR_STAT_23, type: stat_t.dressing },         // Stuff
    { picnum: SpriteEnum.SPR_STAT_24, type: stat_t.bo_food },          // Good food
    { picnum: SpriteEnum.SPR_STAT_25, type: stat_t.bo_firstaid },      // First aid
    { picnum: SpriteEnum.SPR_STAT_26, type: stat_t.bo_clip },          // Clip
    { picnum: SpriteEnum.SPR_STAT_27, type: stat_t.bo_machinegun },    // Machine gun
    { picnum: SpriteEnum.SPR_STAT_28, type: stat_t.bo_chaingun },      // Gatling gun
    { picnum: SpriteEnum.SPR_STAT_29, type: stat_t.bo_cross },         // Cross
    { picnum: SpriteEnum.SPR_STAT_30, type: stat_t.bo_chalice },       // Chalice
    { picnum: SpriteEnum.SPR_STAT_31, type: stat_t.bo_bible },         // Bible
    { picnum: SpriteEnum.SPR_STAT_32, type: stat_t.bo_crown },         // Crown
    { picnum: SpriteEnum.SPR_STAT_33, type: stat_t.bo_fullheal },      // One up
    { picnum: SpriteEnum.SPR_STAT_34, type: stat_t.bo_gibs },          // Gibs
    { picnum: SpriteEnum.SPR_STAT_35, type: stat_t.block },            // Barrel
    { picnum: SpriteEnum.SPR_STAT_36, type: stat_t.block },            // Well
    { picnum: SpriteEnum.SPR_STAT_37, type: stat_t.block },            // Empty well
    { picnum: SpriteEnum.SPR_STAT_38, type: stat_t.bo_gibs },          // Gibs 2
    { picnum: SpriteEnum.SPR_STAT_39, type: stat_t.block },            // Flag
    { picnum: SpriteEnum.SPR_STAT_40, type: stat_t.block },            // Call Apogee
    { picnum: SpriteEnum.SPR_STAT_41, type: stat_t.dressing },         // Junk
    { picnum: SpriteEnum.SPR_STAT_42, type: stat_t.dressing },         // Junk
    { picnum: SpriteEnum.SPR_STAT_43, type: stat_t.dressing },         // Junk
    { picnum: SpriteEnum.SPR_STAT_44, type: stat_t.dressing },         // Pots
    { picnum: SpriteEnum.SPR_STAT_45, type: stat_t.block },            // Stove
    { picnum: SpriteEnum.SPR_STAT_46, type: stat_t.block },            // Spears
    { picnum: SpriteEnum.SPR_STAT_47, type: stat_t.dressing },         // Vines
    // clip2 entry
    { picnum: SpriteEnum.SPR_STAT_26, type: stat_t.bo_clip2 },         // Clip (dropped)
];

let laststatobjIdx = 0;

//===========================================================================
// InitDoorList
//===========================================================================

export function InitDoorList(): void {
    for (let i = 0; i < NUMAREAS; i++) {
        areabyplayer[i] = false;
        for (let j = 0; j < NUMAREAS; j++) {
            areaconnect[i][j] = 0;
        }
    }

    doornum = 0;
    for (let i = 0; i < MAXDOORS; i++) {
        doorobjlist[i].tilex = 0;
        doorobjlist[i].tiley = 0;
        doorobjlist[i].vertical = false;
        doorobjlist[i].lock = 0;
        doorobjlist[i].action = dooraction_t.dr_closed;
        doorobjlist[i].ticcount = 0;
        doorposition[i] = 0;
    }
}

//===========================================================================
// InitStaticList
//===========================================================================

export function InitStaticList(): void {
    laststatobjIdx = 0;
    for (let i = 0; i < statobjlist.length; i++) {
        statobjlist[i].shapenum = -1;
    }
}

//===========================================================================
// ConnectAreas / RecursiveConnect
//===========================================================================

function RecursiveConnect(areanumber: number): void {
    for (let i = 0; i < NUMAREAS; i++) {
        if (areaconnect[areanumber][i] && !areabyplayer[i]) {
            areabyplayer[i] = true;
            RecursiveConnect(i);
        }
    }
}

export function ConnectAreas(): void {
    if (!player) return;
    for (let i = 0; i < NUMAREAS; i++) areabyplayer[i] = false;
    areabyplayer[player.areanumber] = true;
    RecursiveConnect(player.areanumber);
}

export function InitAreas(): void {
    if (!player) return;
    for (let i = 0; i < NUMAREAS; i++) areabyplayer[i] = false;
    areabyplayer[player.areanumber] = true;
}

//===========================================================================
// SpawnStatic
//===========================================================================

export function SpawnStatic(tilex: number, tiley: number, type: number): void {
    if (laststatobjIdx >= MAXSTATS) {
        console.warn('Too many static objects!');
        return;
    }
    if (type < 0 || type >= statinfo.length) return;

    const stat = statobjlist[laststatobjIdx];
    stat.shapenum = statinfo[type].picnum;
    stat.tilex = tilex;
    stat.tiley = tiley;
    stat.visspot = 0;  // will be checked via spotvis directly

    switch (statinfo[type].type) {
        case stat_t.block:
            actorat[tilex][tiley] = 1 as any;  // blocking tile
            stat.flags = 0;
            break;
        case stat_t.dressing:
            stat.flags = 0;
            break;
        case stat_t.bo_cross:
        case stat_t.bo_chalice:
        case stat_t.bo_bible:
        case stat_t.bo_crown:
        case stat_t.bo_fullheal:
            if (!loadedgame) gamestate.treasuretotal++;
            stat.flags = FL_BONUS;
            stat.itemnumber = statinfo[type].type;
            break;
        case stat_t.bo_firstaid:
        case stat_t.bo_key1:
        case stat_t.bo_key2:
        case stat_t.bo_key3:
        case stat_t.bo_key4:
        case stat_t.bo_clip:
        case stat_t.bo_clip2:
        case stat_t.bo_machinegun:
        case stat_t.bo_chaingun:
        case stat_t.bo_food:
        case stat_t.bo_alpo:
        case stat_t.bo_gibs:
        case stat_t.bo_spear:
        case stat_t.bo_25clip:
            stat.flags = FL_BONUS;
            stat.itemnumber = statinfo[type].type;
            break;
        default:
            stat.flags = 0;
            break;
    }

    laststatobjIdx++;
}

//===========================================================================
// SpawnDoor
//===========================================================================

export function SpawnDoor(tilex: number, tiley: number, vertical: boolean, lock: number): void {
    if (doornum >= 64) {
        console.warn('64+ doors on level!');
        return;
    }

    doorposition[doornum] = 0;
    const door = doorobjlist[doornum];
    door.tilex = tilex;
    door.tiley = tiley;
    door.vertical = vertical;
    door.lock = lock;
    door.action = dooraction_t.dr_closed;

    actorat[tilex][tiley] = (doornum | 0x80) as any;
    tilemap[tilex][tiley] = doornum | 0x80;

    if (vertical) {
        if (tiley > 0) tilemap[tilex][tiley - 1] |= 0x40;
        if (tiley < MAPSIZE - 1) tilemap[tilex][tiley + 1] |= 0x40;
    } else {
        if (tilex > 0) tilemap[tilex - 1][tiley] |= 0x40;
        if (tilex < MAPSIZE - 1) tilemap[tilex + 1][tiley] |= 0x40;
    }

    doornum++;
}

//===========================================================================
// OpenDoor / CloseDoor / OperateDoor
//===========================================================================

export function OpenDoor(door: number): void {
    if (door < 0 || door >= doornum) return;
    if (doorobjlist[door].action === dooraction_t.dr_open) {
        doorobjlist[door].ticcount = 0;
    } else {
        doorobjlist[door].action = dooraction_t.dr_opening;
    }
}

export function CloseDoor(door: number): void {
    if (door < 0 || door >= doornum) return;
    if (!player) return;

    const tilex = doorobjlist[door].tilex;
    const tiley = doorobjlist[door].tiley;

    // Don't close on anything solid
    if (actorat[tilex][tiley] && typeof actorat[tilex][tiley] !== 'number') return;
    if (player.tilex === tilex && player.tiley === tiley) return;

    if (doorobjlist[door].vertical) {
        if (player.tiley === tiley) {
            if (((player.x + MINDIST) >> TILESHIFT) === tilex) return;
            if (((player.x - MINDIST) >> TILESHIFT) === tilex) return;
        }
    } else {
        if (player.tilex === tilex) {
            if (((player.y + MINDIST) >> TILESHIFT) === tiley) return;
            if (((player.y - MINDIST) >> TILESHIFT) === tiley) return;
        }
    }

    // Play close sound
    const area = (mapsegs[0][farmapylookup[tiley] + tilex] || 0) - AREATILE;
    if (area >= 0 && area < NUMAREAS && areabyplayer[area]) {
        SD.SD_PlaySound(soundnames.CLOSEDOORSND);
    }

    doorobjlist[door].action = dooraction_t.dr_closing;
    actorat[tilex][tiley] = (door | 0x80) as any;
}

export function OperateDoor(door: number): void {
    if (door < 0 || door >= doornum) return;

    const doorobj = doorobjlist[door];

    // Check key requirements
    if (doorobj.lock >= 1 && doorobj.lock <= 4) {
        if (!(gamestate.keys & (1 << (doorobj.lock - 1)))) {
            SD.SD_PlaySound(soundnames.NOWAYSND);
            return;
        }
    }

    switch (doorobj.action) {
        case dooraction_t.dr_closed:
        case dooraction_t.dr_closing:
            OpenDoor(door);
            break;
        case dooraction_t.dr_open:
        case dooraction_t.dr_opening:
            // Already open/opening
            break;
    }
}

//===========================================================================
// MoveDoors - process door animations each frame
//===========================================================================

export function MoveDoors(): void {
    for (let door = 0; door < doornum; door++) {
        switch (doorobjlist[door].action) {
            case dooraction_t.dr_opening: {
                let position = doorposition[door];
                position += tics * 256;
                if (position >= 0xFFFF) {
                    position = 0xFFFF;
                    doorobjlist[door].action = dooraction_t.dr_open;
                    doorobjlist[door].ticcount = 0;

                    // Connect areas
                    const tilex = doorobjlist[door].tilex;
                    const tiley = doorobjlist[door].tiley;
                    const area1 = (mapsegs[0][farmapylookup[tiley] + tilex] || 0) - AREATILE;

                    let area2: number;
                    if (doorobjlist[door].vertical) {
                        area2 = (mapsegs[0][farmapylookup[tiley - 1] + tilex] || 0) - AREATILE;
                    } else {
                        area2 = (mapsegs[0][farmapylookup[tiley] + tilex - 1] || 0) - AREATILE;
                    }
                    if (area1 >= 0 && area1 < NUMAREAS && area2 >= 0 && area2 < NUMAREAS) {
                        areaconnect[area1][area2]++;
                        areaconnect[area2][area1]++;
                    }

                    ConnectAreas();
                    actorat[tilex][tiley] = null;
                }
                doorposition[door] = position;
                break;
            }

            case dooraction_t.dr_closing: {
                let position = doorposition[door];
                position -= tics * 256;
                if (position <= 0) {
                    position = 0;
                    doorobjlist[door].action = dooraction_t.dr_closed;
                }
                doorposition[door] = Math.max(0, position);
                break;
            }

            case dooraction_t.dr_open: {
                doorobjlist[door].ticcount += tics;
                if (doorobjlist[door].ticcount >= OPENTICS) {
                    CloseDoor(door);
                }
                break;
            }
        }
    }
}

//===========================================================================
// PushWall / MovePWalls
//===========================================================================

export function PushWall(checkx: number, checky: number, dir: number): void {
    if (pwallstate) return;

    const oldtile = tilemap[checkx][checky];
    if (!oldtile) return;

    let dx = 0, dy = 0;
    switch (dir) {
        case 0: dy = -1; break; // north
        case 1: dx = 1; break;  // east
        case 2: dy = 1; break;  // south
        case 3: dx = -1; break; // west
    }

    const newx = checkx + dx;
    const newy = checky + dy;

    if (newx < 0 || newx >= MAPSIZE || newy < 0 || newy >= MAPSIZE) return;
    if (tilemap[newx][newy]) return;

    // Start the pushwall
    pwallstate = 1;
    pwallx = checkx;
    pwally = checky;
    pwalldir = dir;
    pwallpos = 0;
    pwalltile = tilemap[checkx][checky];

    SD.SD_PlaySound(soundnames.OPENDOORSND);
    gamestate.secretcount++;
}

export function MovePWalls(): void {
    if (!pwallstate) return;

    pwallpos += tics;

    if (pwallpos >= 64) {
        // Pushwall has moved one full tile
        pwallpos = 0;

        const dx = [0, 1, 0, -1][pwalldir];
        const dy = [-1, 0, 1, 0][pwalldir];

        const oldx = pwallx;
        const oldy = pwally;
        const newx = pwallx + dx;
        const newy = pwally + dy;

        // Move the wall tile
        tilemap[oldx][oldy] = 0;
        actorat[oldx][oldy] = null;

        if (newx >= 0 && newx < MAPSIZE && newy >= 0 && newy < MAPSIZE) {
            // Check if next tile is clear for continued movement
            const nextx = newx + dx;
            const nexty = newy + dy;
            if (nextx >= 0 && nextx < MAPSIZE && nexty >= 0 && nexty < MAPSIZE &&
                !tilemap[nextx][nexty]) {
                // Continue moving
                tilemap[newx][newy] = pwalltile;
                actorat[newx][newy] = pwalltile as any;
                pwallx = newx;
                pwally = newy;
                pwallstate = 2;
                return;
            }

            tilemap[newx][newy] = pwalltile;
            actorat[newx][newy] = pwalltile as any;
        }

        pwallstate = 0;
    }
}

//===========================================================================
// PlaceItemType
//===========================================================================

export function PlaceItemType(itemtype: number, tilex: number, tiley: number): void {
    // Find the item number in statinfo
    let type = -1;
    for (let i = 0; i < statinfo.length; i++) {
        if (statinfo[i].type === itemtype) {
            type = i;
            break;
        }
    }
    if (type === -1) return;

    // Find a free spot
    let spotIdx = -1;
    for (let i = 0; i < laststatobjIdx; i++) {
        if (statobjlist[i].shapenum === -1) {
            spotIdx = i;
            break;
        }
    }
    if (spotIdx === -1) {
        if (laststatobjIdx >= MAXSTATS) return;
        spotIdx = laststatobjIdx;
        laststatobjIdx++;
    }

    const spot = statobjlist[spotIdx];
    spot.shapenum = statinfo[type].picnum;
    spot.tilex = tilex;
    spot.tiley = tiley;
    spot.visspot = 0;
    spot.flags = FL_BONUS;
    spot.itemnumber = itemtype;
}
