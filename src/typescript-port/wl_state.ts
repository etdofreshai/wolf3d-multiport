// WL_STATE.TS
// Ported from WL_STATE.C - Actor state machine and movement

import {
    objtype, statetype, dirtype, classtype, activetype,
    MAPSIZE, TILEGLOBAL, TILESHIFT, GLOBAL1, MINDIST, MINACTORDIST,
    tilemap, actorat, spotvis, mapsegs, farmapylookup,
    AREATILE, FL_SHOOTABLE, FL_FIRSTATTACK, FL_AMBUSH, FL_ATTACKMODE,
    stat_t, tics,
} from './wl_def';
import { gamestate } from './wl_main';
import {
    player, GetNewActor, newobj, lastobj, areabyplayer, areaconnect,
    doorobjlist, madenoise,
} from './wl_play';
import { OpenDoor, PlaceItemType } from './wl_act1';
import { GivePoints, TakeDamage } from './wl_agent';
import * as US from './id_us_1';
import * as SD from './id_sd';
import {
    s_grddie1, s_ofcdie1, s_ssdie1, s_mutdie1, s_dogdie1,
    s_bossdie1, s_greteldie1, s_giftdie1, s_fatdie1,
    s_schabbdie1, s_fakedie1, s_mechadie1, s_hitlerdie1,
    s_schabbdeathcam, s_hitlerdeathcam, s_giftdeathcam, s_fatdeathcam,
    s_hitlerchase1,
    A_DeathScream,
} from './wl_act2';
import { soundnames } from './audiowl1';

//===========================================================================
// Constants
//===========================================================================

export const TURNTICS = 10;
// SPDPATROL and SPDDOG moved to wl_def.ts to break circular dependency
export { SPDPATROL, SPDDOG } from './wl_def';

//===========================================================================
// Direction tables
//===========================================================================

export const opposite: dirtype[] = [
    dirtype.west, dirtype.southwest, dirtype.south, dirtype.southeast,
    dirtype.east, dirtype.northeast, dirtype.north, dirtype.northwest,
    dirtype.nodir,
];

export const diagonal: dirtype[][] = [
    /* east */     [dirtype.nodir, dirtype.nodir, dirtype.northeast, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.southeast, dirtype.nodir, dirtype.nodir],
                   [dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir],
    /* north */    [dirtype.northeast, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.northwest, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir],
                   [dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir],
    /* west */     [dirtype.nodir, dirtype.nodir, dirtype.northwest, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.southwest, dirtype.nodir, dirtype.nodir],
                   [dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir],
    /* south */    [dirtype.southeast, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.southwest, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir],
                   [dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir],
                   [dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir, dirtype.nodir],
];

//===========================================================================
// SpawnNewObj
//===========================================================================

export function SpawnNewObj(tilex: number, tiley: number, state: statetype): void {
    const ob = GetNewActor();
    ob.state = state;
    if (state.tictime) {
        ob.ticcount = US.US_RndT() % state.tictime;
    } else {
        ob.ticcount = 0;
    }

    ob.tilex = tilex;
    ob.tiley = tiley;
    ob.x = (tilex << TILESHIFT) + (TILEGLOBAL / 2) | 0;
    ob.y = (tiley << TILESHIFT) + (TILEGLOBAL / 2) | 0;
    ob.dir = dirtype.nodir;

    actorat[tilex][tiley] = ob;
    ob.areanumber = (mapsegs[0][farmapylookup[ob.tiley] + ob.tilex] || 0) - AREATILE;
}

export function InitHitRect(ob: objtype, _radius: number): void {
    // In the original, this set up bounding box. Not needed with tile-based collision.
}

//===========================================================================
// NewState
//===========================================================================

export function NewState(ob: objtype, state: statetype): void {
    ob.state = state;
    ob.ticcount = state.tictime;
}

//===========================================================================
// TryWalk
//===========================================================================

function checkDiag(x: number, y: number): boolean {
    if (x < 0 || x >= MAPSIZE || y < 0 || y >= MAPSIZE) return false;
    const temp = actorat[x][y];
    if (temp) {
        if (typeof temp === 'number') return false;  // wall tile
        if ((temp as objtype).flags & FL_SHOOTABLE) return false;
    }
    return true;
}

function checkSide(x: number, y: number): { ok: boolean; doornum: number } {
    if (x < 0 || x >= MAPSIZE || y < 0 || y >= MAPSIZE) return { ok: false, doornum: -1 };
    const temp = actorat[x][y];
    if (temp) {
        if (typeof temp === 'number') {
            const val = temp as number;
            if (val < 128) return { ok: false, doornum: -1 };
            if (val < 256) return { ok: true, doornum: val & 63 };
        } else {
            if ((temp as objtype).flags & FL_SHOOTABLE) return { ok: false, doornum: -1 };
        }
    }
    return { ok: true, doornum: -1 };
}

export function TryWalk(ob: objtype): boolean {
    let doornum = -1;

    if (ob.obclass === classtype.inertobj) {
        switch (ob.dir) {
            case dirtype.north: ob.tiley--; break;
            case dirtype.northeast: ob.tilex++; ob.tiley--; break;
            case dirtype.east: ob.tilex++; break;
            case dirtype.southeast: ob.tilex++; ob.tiley++; break;
            case dirtype.south: ob.tiley++; break;
            case dirtype.southwest: ob.tilex--; ob.tiley++; break;
            case dirtype.west: ob.tilex--; break;
            case dirtype.northwest: ob.tilex--; ob.tiley--; break;
        }
    } else {
        switch (ob.dir) {
            case dirtype.north:
                if (ob.obclass === classtype.dogobj || ob.obclass === classtype.fakeobj) {
                    if (!checkDiag(ob.tilex, ob.tiley - 1)) return false;
                } else {
                    const r = checkSide(ob.tilex, ob.tiley - 1);
                    if (!r.ok) return false;
                    if (r.doornum >= 0) doornum = r.doornum;
                }
                ob.tiley--;
                break;

            case dirtype.northeast:
                if (!checkDiag(ob.tilex + 1, ob.tiley - 1)) return false;
                if (!checkDiag(ob.tilex + 1, ob.tiley)) return false;
                if (!checkDiag(ob.tilex, ob.tiley - 1)) return false;
                ob.tilex++; ob.tiley--;
                break;

            case dirtype.east:
                if (ob.obclass === classtype.dogobj || ob.obclass === classtype.fakeobj) {
                    if (!checkDiag(ob.tilex + 1, ob.tiley)) return false;
                } else {
                    const r = checkSide(ob.tilex + 1, ob.tiley);
                    if (!r.ok) return false;
                    if (r.doornum >= 0) doornum = r.doornum;
                }
                ob.tilex++;
                break;

            case dirtype.southeast:
                if (!checkDiag(ob.tilex + 1, ob.tiley + 1)) return false;
                if (!checkDiag(ob.tilex + 1, ob.tiley)) return false;
                if (!checkDiag(ob.tilex, ob.tiley + 1)) return false;
                ob.tilex++; ob.tiley++;
                break;

            case dirtype.south:
                if (ob.obclass === classtype.dogobj || ob.obclass === classtype.fakeobj) {
                    if (!checkDiag(ob.tilex, ob.tiley + 1)) return false;
                } else {
                    const r = checkSide(ob.tilex, ob.tiley + 1);
                    if (!r.ok) return false;
                    if (r.doornum >= 0) doornum = r.doornum;
                }
                ob.tiley++;
                break;

            case dirtype.southwest:
                if (!checkDiag(ob.tilex - 1, ob.tiley + 1)) return false;
                if (!checkDiag(ob.tilex - 1, ob.tiley)) return false;
                if (!checkDiag(ob.tilex, ob.tiley + 1)) return false;
                ob.tilex--; ob.tiley++;
                break;

            case dirtype.west:
                if (ob.obclass === classtype.dogobj || ob.obclass === classtype.fakeobj) {
                    if (!checkDiag(ob.tilex - 1, ob.tiley)) return false;
                } else {
                    const r = checkSide(ob.tilex - 1, ob.tiley);
                    if (!r.ok) return false;
                    if (r.doornum >= 0) doornum = r.doornum;
                }
                ob.tilex--;
                break;

            case dirtype.northwest:
                if (!checkDiag(ob.tilex - 1, ob.tiley - 1)) return false;
                if (!checkDiag(ob.tilex - 1, ob.tiley)) return false;
                if (!checkDiag(ob.tilex, ob.tiley - 1)) return false;
                ob.tilex--; ob.tiley--;
                break;

            case dirtype.nodir:
                return false;

            default:
                return false;
        }
    }

    if (doornum !== -1) {
        OpenDoor(doornum);
        ob.distance = -doornum - 1;
        return true;
    }

    ob.areanumber = (mapsegs[0][farmapylookup[ob.tiley] + ob.tilex] || 0) - AREATILE;
    ob.distance = TILEGLOBAL;
    return true;
}

//===========================================================================
// SelectDodgeDir
//===========================================================================

export function SelectDodgeDir(ob: objtype): void {
    if (!player) return;

    let turnaround: dirtype;
    if (ob.flags & FL_FIRSTATTACK) {
        turnaround = dirtype.nodir;
        ob.flags &= ~FL_FIRSTATTACK;
    } else {
        turnaround = opposite[ob.dir];
    }

    const deltax = player.tilex - ob.tilex;
    const deltay = player.tiley - ob.tiley;

    const dirtry: dirtype[] = new Array(5);

    dirtry[1] = deltax > 0 ? dirtype.east : dirtype.west;
    dirtry[3] = deltax > 0 ? dirtype.west : dirtype.east;
    dirtry[2] = deltay > 0 ? dirtype.south : dirtype.north;
    dirtry[4] = deltay > 0 ? dirtype.north : dirtype.south;

    const absdx = Math.abs(deltax);
    const absdy = Math.abs(deltay);

    if (absdx > absdy) {
        let t = dirtry[1]; dirtry[1] = dirtry[2]; dirtry[2] = t;
        t = dirtry[3]; dirtry[3] = dirtry[4]; dirtry[4] = t;
    }

    if (US.US_RndT() < 128) {
        let t = dirtry[1]; dirtry[1] = dirtry[2]; dirtry[2] = t;
        t = dirtry[3]; dirtry[3] = dirtry[4]; dirtry[4] = t;
    }

    dirtry[0] = diagonal[dirtry[1]] ? diagonal[dirtry[1]][dirtry[2]] : dirtype.nodir;

    for (let i = 0; i < 5; i++) {
        if (dirtry[i] === dirtype.nodir || dirtry[i] === turnaround) continue;
        ob.dir = dirtry[i];
        if (TryWalk(ob)) return;
    }

    if (turnaround !== dirtype.nodir) {
        ob.dir = turnaround;
        if (TryWalk(ob)) return;
    }

    ob.dir = dirtype.nodir;
}

//===========================================================================
// SelectChaseDir
//===========================================================================

export function SelectChaseDir(ob: objtype): void {
    if (!player) return;

    const olddir = ob.dir;
    const turnaround = opposite[olddir];

    const deltax = player.tilex - ob.tilex;
    const deltay = player.tiley - ob.tiley;

    const d: dirtype[] = [dirtype.nodir, dirtype.nodir, dirtype.nodir];

    if (deltax > 0) d[1] = dirtype.east;
    else if (deltax < 0) d[1] = dirtype.west;
    if (deltay > 0) d[2] = dirtype.south;
    else if (deltay < 0) d[2] = dirtype.north;

    if (Math.abs(deltay) > Math.abs(deltax)) {
        const t = d[1]; d[1] = d[2]; d[2] = t;
    }

    if (d[1] === turnaround) d[1] = dirtype.nodir;
    if (d[2] === turnaround) d[2] = dirtype.nodir;

    if (d[1] !== dirtype.nodir) {
        ob.dir = d[1];
        if (TryWalk(ob)) return;
    }

    if (d[2] !== dirtype.nodir) {
        ob.dir = d[2];
        if (TryWalk(ob)) return;
    }

    if (olddir !== dirtype.nodir) {
        ob.dir = olddir;
        if (TryWalk(ob)) return;
    }

    if (US.US_RndT() > 128) {
        for (let tdir = dirtype.north; tdir <= dirtype.west; tdir++) {
            if (tdir !== turnaround) {
                ob.dir = tdir;
                if (TryWalk(ob)) return;
            }
        }
    } else {
        for (let tdir = dirtype.west; tdir >= dirtype.north; tdir--) {
            if (tdir !== turnaround) {
                ob.dir = tdir;
                if (TryWalk(ob)) return;
            }
        }
    }

    if ((turnaround as number) !== (dirtype.nodir as number)) {
        ob.dir = turnaround;
        if ((ob.dir as number) !== (dirtype.nodir as number)) {
            if (TryWalk(ob)) return;
        }
    }

    ob.dir = dirtype.nodir;
}

//===========================================================================
// SelectRunDir
//===========================================================================

export function SelectRunDir(ob: objtype): void {
    if (!player) return;

    const deltax = player.tilex - ob.tilex;
    const deltay = player.tiley - ob.tiley;

    const d: dirtype[] = [dirtype.nodir, dirtype.nodir, dirtype.nodir];

    // Run AWAY - opposite direction
    d[1] = deltax < 0 ? dirtype.east : dirtype.west;
    d[2] = deltay < 0 ? dirtype.south : dirtype.north;

    if (Math.abs(deltay) > Math.abs(deltax)) {
        const t = d[1]; d[1] = d[2]; d[2] = t;
    }

    ob.dir = d[1];
    if (TryWalk(ob)) return;

    ob.dir = d[2];
    if (TryWalk(ob)) return;

    if (US.US_RndT() > 128) {
        for (let tdir = dirtype.north; tdir <= dirtype.west; tdir++) {
            ob.dir = tdir;
            if (TryWalk(ob)) return;
        }
    } else {
        for (let tdir = dirtype.west; tdir >= dirtype.north; tdir--) {
            ob.dir = tdir;
            if (TryWalk(ob)) return;
        }
    }

    ob.dir = dirtype.nodir;
}

//===========================================================================
// MoveObj
//===========================================================================

export function MoveObj(ob: objtype, move: number): void {
    switch (ob.dir) {
        case dirtype.north: ob.y -= move; break;
        case dirtype.northeast: ob.x += move; ob.y -= move; break;
        case dirtype.east: ob.x += move; break;
        case dirtype.southeast: ob.x += move; ob.y += move; break;
        case dirtype.south: ob.y += move; break;
        case dirtype.southwest: ob.x -= move; ob.y += move; break;
        case dirtype.west: ob.x -= move; break;
        case dirtype.northwest: ob.x -= move; ob.y -= move; break;
        case dirtype.nodir: return;
        default: return;
    }

    // Check to make sure it's not on top of player
    if (player && areabyplayer[ob.areanumber]) {
        const deltax = ob.x - player.x;
        const deltay = ob.y - player.y;

        if (!(deltax < -MINACTORDIST || deltax > MINACTORDIST) &&
            !(deltay < -MINACTORDIST || deltay > MINACTORDIST)) {
            // Ghost/spectre damage player
            if (ob.obclass === classtype.ghostobj || ob.obclass === classtype.spectreobj) {
                TakeDamage(tics * 2, ob);
            }

            // Back up
            switch (ob.dir) {
                case dirtype.north: ob.y += move; break;
                case dirtype.northeast: ob.x -= move; ob.y += move; break;
                case dirtype.east: ob.x -= move; break;
                case dirtype.southeast: ob.x -= move; ob.y -= move; break;
                case dirtype.south: ob.y -= move; break;
                case dirtype.southwest: ob.x += move; ob.y -= move; break;
                case dirtype.west: ob.x += move; break;
                case dirtype.northwest: ob.x += move; ob.y += move; break;
                default: return;  // nodir
            }
            return;
        }
    }

    ob.distance -= move;
}

//===========================================================================
// DropItem
//===========================================================================

export function DropItem(itemtype: stat_t, tilex: number, tiley: number): void {
    if (!actorat[tilex][tiley]) {
        PlaceItemType(itemtype, tilex, tiley);
        return;
    }

    for (let x = tilex - 1; x <= tilex + 1; x++) {
        for (let y = tiley - 1; y <= tiley + 1; y++) {
            if (x >= 0 && x < MAPSIZE && y >= 0 && y < MAPSIZE) {
                if (!actorat[x][y]) {
                    PlaceItemType(itemtype, x, y);
                    return;
                }
            }
        }
    }
}

//===========================================================================
// KillActor
//===========================================================================

export function KillActor(ob: objtype): void {
    const tilex = ob.tilex = ob.x >> TILESHIFT;
    const tiley = ob.tiley = ob.y >> TILESHIFT;

    switch (ob.obclass) {
        case classtype.guardobj:
            GivePoints(100);
            NewState(ob, s_grddie1);
            PlaceItemType(stat_t.bo_clip2, tilex, tiley);
            break;
        case classtype.officerobj:
            GivePoints(400);
            NewState(ob, s_ofcdie1);
            PlaceItemType(stat_t.bo_clip2, tilex, tiley);
            break;
        case classtype.mutantobj:
            GivePoints(700);
            NewState(ob, s_mutdie1);
            PlaceItemType(stat_t.bo_clip2, tilex, tiley);
            break;
        case classtype.ssobj:
            GivePoints(500);
            NewState(ob, s_ssdie1);
            if (gamestate.bestweapon < 2) // wp_machinegun
                PlaceItemType(stat_t.bo_machinegun, tilex, tiley);
            else
                PlaceItemType(stat_t.bo_clip2, tilex, tiley);
            break;
        case classtype.dogobj:
            GivePoints(200);
            NewState(ob, s_dogdie1);
            break;
        case classtype.bossobj:
            GivePoints(5000);
            NewState(ob, s_bossdie1);
            PlaceItemType(stat_t.bo_key1, tilex, tiley);
            break;
        case classtype.gretelobj:
            GivePoints(5000);
            NewState(ob, s_greteldie1);
            PlaceItemType(stat_t.bo_key1, tilex, tiley);
            break;
        case classtype.giftobj:
            GivePoints(5000);
            if (player) {
                gamestate.killx = player.x;
                gamestate.killy = player.y;
            }
            NewState(ob, s_giftdeathcam);
            break;
        case classtype.fatobj:
            GivePoints(5000);
            if (player) {
                gamestate.killx = player.x;
                gamestate.killy = player.y;
            }
            NewState(ob, s_fatdeathcam);
            break;
        case classtype.schabbobj:
            GivePoints(5000);
            if (player) {
                gamestate.killx = player.x;
                gamestate.killy = player.y;
            }
            NewState(ob, s_schabbdeathcam);
            break;
        case classtype.fakeobj:
            GivePoints(2000);
            NewState(ob, s_fakedie1);
            break;
        case classtype.mechahitlerobj:
            GivePoints(5000);
            NewState(ob, s_mechadie1);
            break;
        case classtype.realhitlerobj:
            GivePoints(5000);
            if (player) {
                gamestate.killx = player.x;
                gamestate.killy = player.y;
            }
            NewState(ob, s_hitlerdeathcam);
            break;
        default:
            break;
    }

    gamestate.killcount++;
    ob.flags &= ~FL_SHOOTABLE;
    actorat[ob.tilex][ob.tiley] = null;
    ob.flags |= 0;  // mark as dead (FL_NONMARK)
}

//===========================================================================
// DamageActor
//===========================================================================

export function DamageActor(ob: objtype, damage: number): void {
    if (!(ob.flags & FL_SHOOTABLE)) return;

    ob.hitpoints -= damage;

    if (ob.hitpoints <= 0) {
        KillActor(ob);
    } else {
        // React to damage
        if (!(ob.flags & FL_ATTACKMODE)) {
            FirstSighting(ob);
        }

        // Play pain sound based on enemy type
        switch (ob.obclass) {
            case classtype.guardobj:
                if (ob.hitpoints > 0) SD.SD_PlaySound(soundnames.DEATHSCREAM2SND);
                break;
            default:
                break;
        }
    }
}

//===========================================================================
// CheckLine - check if a clear line exists between two points
//===========================================================================

export function CheckLine(ob: objtype): boolean {
    if (!player) return false;

    let x1 = ob.tilex;
    let y1 = ob.tiley;
    const x2 = player.tilex;
    const y2 = player.tiley;

    const deltax = x2 - x1;
    const deltay = y2 - y1;

    let xstep: number, ystep: number;
    let partial: number;
    let delta: number;

    if (deltax > 0) { xstep = 1; partial = 1; } else if (deltax < 0) { xstep = -1; partial = 0; } else { xstep = 0; partial = 0; }
    if (deltay > 0) { ystep = 1; } else if (deltay < 0) { ystep = -1; } else { ystep = 0; }

    const absdx = Math.abs(deltax);
    const absdy = Math.abs(deltay);

    if (absdx > absdy) {
        // Step along x
        let intercept = y1 + 0.5;
        const step = deltay / absdx;
        for (let i = 0; i < absdx; i++) {
            x1 += xstep;
            intercept += step;
            const iy = Math.floor(intercept);
            if (x1 >= 0 && x1 < MAPSIZE && iy >= 0 && iy < MAPSIZE) {
                const t = tilemap[x1][iy];
                if (t && !(t & 0x80)) return false;
                if (t & 0x80 && !(t & 0x40)) {
                    // door - check if it blocks sight
                    return false;
                }
            }
        }
    } else {
        // Step along y
        let intercept = x1 + 0.5;
        const step = deltax / (absdy || 1);
        for (let i = 0; i < absdy; i++) {
            y1 += ystep;
            intercept += step;
            const ix = Math.floor(intercept);
            if (ix >= 0 && ix < MAPSIZE && y1 >= 0 && y1 < MAPSIZE) {
                const t = tilemap[ix][y1];
                if (t && !(t & 0x80)) return false;
                if (t & 0x80 && !(t & 0x40)) {
                    return false;
                }
            }
        }
    }

    return true;
}

//===========================================================================
// CheckSight
//===========================================================================

export function CheckSight(ob: objtype): boolean {
    if (!player) return false;

    // Don't bother checking if player is in different area unless connected
    if (!areabyplayer[ob.areanumber]) return false;

    return CheckLine(ob);
}

//===========================================================================
// FirstSighting - react to seeing the player
//===========================================================================

export function FirstSighting(ob: objtype): void {
    // Switch to attack mode
    ob.flags |= FL_ATTACKMODE | FL_FIRSTATTACK;

    switch (ob.obclass) {
        case classtype.guardobj:
            SD.SD_PlaySound(soundnames.HALTSND);
            break;
        case classtype.officerobj:
            SD.SD_PlaySound(soundnames.HALTSND);
            break;
        case classtype.ssobj:
            SD.SD_PlaySound(soundnames.HALTSND);
            break;
        case classtype.dogobj:
            SD.SD_PlaySound(soundnames.DOGBARKSND);
            break;
        case classtype.mutantobj:
            // mutants don't announce
            break;
        default:
            break;
    }
}

//===========================================================================
// SightPlayer
//===========================================================================

export function SightPlayer(ob: objtype): boolean {
    if (!player) return false;

    if (ob.flags & FL_ATTACKMODE) {
        // Already in attack mode
        return false;
    }

    if (ob.flags & FL_AMBUSH) {
        if (!CheckSight(ob)) return false;
        ob.flags &= ~FL_AMBUSH;
    } else {
        if (!areabyplayer[ob.areanumber]) return false;
        if (!CheckSight(ob)) return false;
    }

    FirstSighting(ob);
    return true;
}
