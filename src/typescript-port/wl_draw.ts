// WL_DRAW.TS
// Ported from WL_DRAW.C + WL_DR_A.C - 3D rendering engine (raycaster)

import * as VL from './id_vl';
import * as PM from './id_pm';
import * as SD from './id_sd';
import {
    MAXVIEWWIDTH, MAXSCALEHEIGHT, ANGLES, FINEANGLES, GLOBAL1, TILEGLOBAL,
    TILESHIFT, MAPSIZE, MINDIST, ANG90, ANG180, ANG270, ANG360,
    SCREENWIDTH, SCREENSIZE, MAXWALLTILES,
    objtype, statobj_t, classtype, activetype, FL_VISABLE, FL_BONUS,
    tilemap, spotvis, actorat,
    tics,
    SpriteEnum,
} from './wl_def';
import {
    viewwidth, viewheight, focallength, centerx,
    sintable, costable, finetangent, pixelangle,
    heightnumerator, screenloc, freelatch, scale,
    screenofs, gamestate, dirangle,
} from './wl_main';
import {
    player, statobjlist, laststatobj, doorobjlist,
    areabyplayer, demorecord, demoplayback,
} from './wl_play';
import { doorposition, pwallpos as act1_pwallpos } from './wl_act1';
import { ScaleShape, SimpleScaleShape, maxscale } from './wl_scale';
import { GetBonus } from './wl_agent';

//===========================================================================
// Constants
//===========================================================================

const DOORWALL = PM.PMSpriteStart - 8;
const ACTORSIZE = 0x4000;

const DEG90 = 900;
const DEG180 = 1800;
const DEG270 = 2700;
const DEG360 = 3600;

const MAXVISABLE = 50;

const NUMWEAPONS = 4;

//===========================================================================
// Global variables
//===========================================================================

export let lasttimecount: number = 0;
export let frameon: number = 0;
export let fizzlein = false;

export const wallheight: Uint32Array = new Uint32Array(MAXVIEWWIDTH);

// Refresh variables
export let viewx: number = 0;
export let viewy: number = 0;
export let viewangle: number = 0;
export let viewsin: number = 0;
export let viewcos: number = 0;

export let postsource: Uint8Array | null = null;
export let postx: number = 0;
export let postwidth: number = 0;

// Wall texture lookup (set by SetupGameLevel)
export const horizwall: number[] = new Array(MAXWALLTILES).fill(0);
export const vertwall: number[] = new Array(MAXWALLTILES).fill(0);

export let pwallpos: number = 0;

// Wall optimization variables
let lastside = -1;
let lastintercept = 0;
let lasttilehit = 0;

// Ray tracing variables
let focaltx = 0, focalty = 0, viewtx = 0, viewty = 0;
let midangle = 0;
let xpartialup = 0, xpartialdown = 0, ypartialup = 0, ypartialdown = 0;

let tilehit = 0;
let pixx = 0;
let xtile = 0, ytile = 0;
let xtilestep = 0, ytilestep = 0;
let xintercept = 0, yintercept = 0;
let xstep = 0, ystep = 0;

let posttexture = 0;
let postpage: Uint8Array | null = null;

// Ceiling color table
const vgaCeiling = [
    0x1d1d, 0x1d1d, 0x1d1d, 0x1d1d, 0x1d1d, 0x1d1d, 0x1d1d, 0x1d1d, 0x1d1d, 0xbfbf,
    0x4e4e, 0x4e4e, 0x4e4e, 0x1d1d, 0x8d8d, 0x4e4e, 0x1d1d, 0x2d2d, 0x1d1d, 0x8d8d,
    0x1d1d, 0x1d1d, 0x1d1d, 0x1d1d, 0x1d1d, 0x2d2d, 0xdddd, 0x1d1d, 0x1d1d, 0x9898,
    0x1d1d, 0x9d9d, 0x2d2d, 0xdddd, 0xdddd, 0x9d9d, 0x2d2d, 0x4d4d, 0x1d1d, 0xdddd,
    0x7d7d, 0x1d1d, 0x2d2d, 0x2d2d, 0xdddd, 0xd7d7, 0x1d1d, 0x1d1d, 0x1d1d, 0x2d2d,
    0x1d1d, 0x1d1d, 0x1d1d, 0x1d1d, 0xdddd, 0xdddd, 0x7d7d, 0xdddd, 0xdddd, 0xdddd,
];

const weaponscale = [
    SpriteEnum.SPR_KNIFEREADY,
    SpriteEnum.SPR_PISTOLREADY,
    SpriteEnum.SPR_MACHINEGUNREADY,
    SpriteEnum.SPR_CHAINREADY,
];

// Vis object for sorting sprites
interface visobj_t {
    viewx: number;
    viewheight: number;
    shapenum: number;
}

//===========================================================================
// FixedByFrac - fixed point multiply (signed magnitude)
//===========================================================================

export function FixedByFrac(a: number, b: number): number {
    // b is signed magnitude: bit 31 (top of high word) is sign, low 16 bits are magnitude fraction
    let sign = (b >> 16) & 0x8000;
    let ua: number, ub: number;

    if (a < 0) {
        ua = -a;
        sign ^= 0x8000;
    } else {
        ua = a;
    }

    ub = b & 0xFFFF;

    const lo = (ua & 0xFFFF) * ub;
    const hi = ((ua >>> 16) & 0xFFFF) * ub;
    let result = hi + (lo >>> 16);

    if (sign) return -(result | 0);
    return result | 0;
}

//===========================================================================
// TransformActor
//===========================================================================

export function TransformActor(ob: objtype): void {
    const gx = ob.x - viewx;
    const gy = ob.y - viewy;

    let gxt = FixedByFrac(gx, viewcos);
    let gyt = FixedByFrac(gy, viewsin);
    const nx = gxt - gyt - ACTORSIZE;

    gxt = FixedByFrac(gx, viewsin);
    gyt = FixedByFrac(gy, viewcos);
    const ny = gyt + gxt;

    ob.transx = nx;
    ob.transy = ny;

    if (nx < MINDIST) {
        ob.viewheight = 0;
        return;
    }

    ob.viewx = centerx + ((ny * scale / nx) | 0);

    const temp = (heightnumerator / (nx >> 8)) | 0;
    ob.viewheight = temp;
}

//===========================================================================
// TransformTile
//===========================================================================

function TransformTile(tx: number, ty: number): { dispx: number; dispheight: number; grabbed: boolean } {
    const gx = (tx << TILESHIFT) + 0x8000 - viewx;
    const gy = (ty << TILESHIFT) + 0x8000 - viewy;

    let gxt = FixedByFrac(gx, viewcos);
    let gyt = FixedByFrac(gy, viewsin);
    const nx = gxt - gyt - 0x2000;

    gxt = FixedByFrac(gx, viewsin);
    gyt = FixedByFrac(gy, viewcos);
    const ny = gyt + gxt;

    if (nx < MINDIST) {
        return { dispx: 0, dispheight: 0, grabbed: false };
    }

    const dispx = centerx + ((ny * scale / nx) | 0);
    const dispheight = (heightnumerator / (nx >> 8)) | 0;

    const grabbed = nx < TILEGLOBAL && ny > -TILEGLOBAL / 2 && ny < TILEGLOBAL / 2;
    return { dispx, dispheight, grabbed };
}

//===========================================================================
// CalcHeight
//===========================================================================

function CalcHeight(): number {
    const gx = xintercept - viewx;
    const gxt = FixedByFrac(gx, viewcos);

    const gy = yintercept - viewy;
    const gyt = FixedByFrac(gy, viewsin);

    let nx = gxt - gyt;
    if (nx < MINDIST) nx = MINDIST;

    return (heightnumerator / (nx >> 8)) | 0;
}

//===========================================================================
// BuildTables
//===========================================================================

export function BuildTables(): void {
    // Already built in wl_main.ts
}

//===========================================================================
// VGAClearScreen
//===========================================================================

export function ClearScreen(): void {
    const mapon = gamestate.mapon;
    const ceilIdx = gamestate.episode * 10 + mapon;
    const ceiling = (ceilIdx >= 0 && ceilIdx < vgaCeiling.length)
        ? (vgaCeiling[ceilIdx] & 0xFF) : 0x1d;
    const floor = 0x19;

    const yofs = ((200 - 40 - viewheight) >> 1);
    const xofs = ((320 - viewwidth) >> 1);

    for (let y = 0; y < (viewheight >> 1); y++) {
        const screeny = y + yofs;
        if (screeny >= 0 && screeny < 200) {
            VL.screenbuf.fill(ceiling, screeny * 320 + xofs, screeny * 320 + xofs + viewwidth);
        }
    }
    for (let y = (viewheight >> 1); y < viewheight; y++) {
        const screeny = y + yofs;
        if (screeny >= 0 && screeny < 200) {
            VL.screenbuf.fill(floor, screeny * 320 + xofs, screeny * 320 + xofs + viewwidth);
        }
    }
}

//===========================================================================
// ScalePost - draw a single vertical wall strip
//===========================================================================

function ScalePost(): void {
    if (!postsource) return;

    let ht = wallheight[postx] >> 3;
    if (ht <= 0) return;

    let toprow = ((viewheight - ht) / 2) | 0;
    let bottomrow = toprow + ht;
    let fracstep = ((64 << 16) / ht) | 0;
    let frac = 0;

    if (ht > viewheight) {
        const skip = ((ht - viewheight) / 2) | 0;
        frac = skip * fracstep;
        toprow = 0;
        bottomrow = viewheight;
    }

    const yofs = ((200 - 40 - viewheight) >> 1);
    const xofs = ((320 - viewwidth) >> 1);

    for (let x = postx; x < postx + postwidth && x < viewwidth; x++) {
        let f = frac;
        for (let y = toprow; y < bottomrow; y++) {
            const texel = (f >> 16) & 63;
            const screeny = y + yofs;
            const screenx = x + xofs;
            if (screeny >= 0 && screeny < 200 && screenx >= 0 && screenx < 320) {
                VL.screenbuf[screeny * 320 + screenx] = postsource[texel];
            }
            f += fracstep;
        }
    }
}

export function FarScalePost(): void {
    ScalePost();
}

//===========================================================================
// HitVertWall
//===========================================================================

function HitVertWall(): void {
    let wallpic: number;
    let texture = (yintercept >> 4) & 0xfc0;

    if (xtilestep === -1) {
        texture = 0xfc0 - texture;
        xintercept += TILEGLOBAL;
    }
    wallheight[pixx] = CalcHeight();

    if (lastside === 1 && lastintercept === xtile && lasttilehit === tilehit) {
        if (texture === posttexture) {
            postwidth++;
            wallheight[pixx] = wallheight[pixx - 1];
            return;
        } else {
            ScalePost();
            posttexture = texture;
            postsource = postpage ? new Uint8Array(postpage.buffer, postpage.byteOffset + texture, Math.min(64, postpage.length - texture)) : null;
            postwidth = 1;
            postx = pixx;
        }
    } else {
        if (lastside !== -1) ScalePost();

        lastside = 1;
        lastintercept = xtile;
        lasttilehit = tilehit;
        postx = pixx;
        postwidth = 1;

        if (tilehit & 0x40) {
            ytile = yintercept >> TILESHIFT;
            if (xtile - xtilestep >= 0 && xtile - xtilestep < MAPSIZE &&
                ytile >= 0 && ytile < MAPSIZE &&
                tilemap[xtile - xtilestep][ytile] & 0x80) {
                wallpic = getDoorWall() + 3;
            } else {
                wallpic = vertwall[tilehit & ~0x40] || 0;
            }
        } else {
            wallpic = vertwall[tilehit] || 0;
        }

        postpage = PM.PM_GetPage(wallpic);
        posttexture = texture;
        postsource = postpage ? new Uint8Array(postpage.buffer, postpage.byteOffset + texture, Math.min(64, postpage.length - texture)) : null;
    }
}

//===========================================================================
// HitHorizWall
//===========================================================================

function HitHorizWall(): void {
    let wallpic: number;
    let texture = (xintercept >> 4) & 0xfc0;

    if (ytilestep === -1) {
        yintercept += TILEGLOBAL;
    } else {
        texture = 0xfc0 - texture;
    }
    wallheight[pixx] = CalcHeight();

    if (lastside === 0 && lastintercept === ytile && lasttilehit === tilehit) {
        if (texture === posttexture) {
            postwidth++;
            wallheight[pixx] = wallheight[pixx - 1];
            return;
        } else {
            ScalePost();
            posttexture = texture;
            postsource = postpage ? new Uint8Array(postpage.buffer, postpage.byteOffset + texture, Math.min(64, postpage.length - texture)) : null;
            postwidth = 1;
            postx = pixx;
        }
    } else {
        if (lastside !== -1) ScalePost();

        lastside = 0;
        lastintercept = ytile;
        lasttilehit = tilehit;
        postx = pixx;
        postwidth = 1;

        if (tilehit & 0x40) {
            xtile = xintercept >> TILESHIFT;
            if (xtile >= 0 && xtile < MAPSIZE &&
                ytile - ytilestep >= 0 && ytile - ytilestep < MAPSIZE &&
                tilemap[xtile][ytile - ytilestep] & 0x80) {
                wallpic = getDoorWall() + 2;
            } else {
                wallpic = horizwall[tilehit & ~0x40] || 0;
            }
        } else {
            wallpic = horizwall[tilehit] || 0;
        }

        postpage = PM.PM_GetPage(wallpic);
        posttexture = texture;
        postsource = postpage ? new Uint8Array(postpage.buffer, postpage.byteOffset + texture, Math.min(64, postpage.length - texture)) : null;
    }
}

//===========================================================================
// HitHorizDoor / HitVertDoor
//===========================================================================

function getDoorWall(): number {
    return PM.PMSpriteStart - 8;
}

function HitHorizDoor(): void {
    const doornum = tilehit & 0x7f;
    const texture = ((xintercept - doorposition[doornum]) >> 4) & 0xfc0;

    wallheight[pixx] = CalcHeight();

    if (lasttilehit === tilehit) {
        if (texture === posttexture) {
            postwidth++;
            wallheight[pixx] = wallheight[pixx - 1];
            return;
        } else {
            ScalePost();
            posttexture = texture;
            postsource = postpage ? new Uint8Array(postpage.buffer, postpage.byteOffset + texture, Math.min(64, postpage.length - texture)) : null;
            postwidth = 1;
            postx = pixx;
        }
    } else {
        if (lastside !== -1) ScalePost();

        lastside = 2;
        lasttilehit = tilehit;
        postx = pixx;
        postwidth = 1;

        let doorpage: number;
        switch (doorobjlist[doornum].lock) {
            case 0: // dr_normal
                doorpage = getDoorWall();
                break;
            case 1: case 2: case 3: case 4: // dr_lock1-4
                doorpage = getDoorWall() + 6;
                break;
            case 5: // dr_elevator
                doorpage = getDoorWall() + 4;
                break;
            default:
                doorpage = getDoorWall();
        }

        postpage = PM.PM_GetPage(doorpage);
        posttexture = texture;
        postsource = postpage ? new Uint8Array(postpage.buffer, postpage.byteOffset + texture, Math.min(64, postpage.length - texture)) : null;
    }
}

function HitVertDoor(): void {
    const doornum = tilehit & 0x7f;
    const texture = ((yintercept - doorposition[doornum]) >> 4) & 0xfc0;

    wallheight[pixx] = CalcHeight();

    if (lasttilehit === tilehit) {
        if (texture === posttexture) {
            postwidth++;
            wallheight[pixx] = wallheight[pixx - 1];
            return;
        } else {
            ScalePost();
            posttexture = texture;
            postsource = postpage ? new Uint8Array(postpage.buffer, postpage.byteOffset + texture, Math.min(64, postpage.length - texture)) : null;
            postwidth = 1;
            postx = pixx;
        }
    } else {
        if (lastside !== -1) ScalePost();

        lastside = 2;
        lasttilehit = tilehit;
        postx = pixx;
        postwidth = 1;

        let doorpage: number;
        switch (doorobjlist[doornum].lock) {
            case 0: doorpage = getDoorWall(); break;
            case 1: case 2: case 3: case 4: doorpage = getDoorWall() + 6; break;
            case 5: doorpage = getDoorWall() + 4; break;
            default: doorpage = getDoorWall();
        }

        postpage = PM.PM_GetPage(doorpage + 1);
        posttexture = texture;
        postsource = postpage ? new Uint8Array(postpage.buffer, postpage.byteOffset + texture, Math.min(64, postpage.length - texture)) : null;
    }
}

//===========================================================================
// HitHorizPWall / HitVertPWall
//===========================================================================

function HitHorizPWall(): void {
    let texture = (xintercept >> 4) & 0xfc0;
    const offset = act1_pwallpos << 10;
    if (ytilestep === -1) {
        yintercept += TILEGLOBAL - offset;
    } else {
        texture = 0xfc0 - texture;
        yintercept += offset;
    }
    wallheight[pixx] = CalcHeight();

    if (lasttilehit === tilehit) {
        if (texture === posttexture) {
            postwidth++;
            wallheight[pixx] = wallheight[pixx - 1];
            return;
        } else {
            ScalePost();
            posttexture = texture;
            postsource = postpage ? new Uint8Array(postpage.buffer, postpage.byteOffset + texture, Math.min(64, postpage.length - texture)) : null;
            postwidth = 1;
            postx = pixx;
        }
    } else {
        if (lastside !== -1) ScalePost();
        lasttilehit = tilehit;
        postx = pixx;
        postwidth = 1;
        const wallpic = horizwall[tilehit & 63] || 0;
        postpage = PM.PM_GetPage(wallpic);
        posttexture = texture;
        postsource = postpage ? new Uint8Array(postpage.buffer, postpage.byteOffset + texture, Math.min(64, postpage.length - texture)) : null;
    }
}

function HitVertPWall(): void {
    let texture = (yintercept >> 4) & 0xfc0;
    const offset = act1_pwallpos << 10;
    if (xtilestep === -1) {
        xintercept += TILEGLOBAL - offset;
        texture = 0xfc0 - texture;
    } else {
        xintercept += offset;
    }
    wallheight[pixx] = CalcHeight();

    if (lasttilehit === tilehit) {
        if (texture === posttexture) {
            postwidth++;
            wallheight[pixx] = wallheight[pixx - 1];
            return;
        } else {
            ScalePost();
            posttexture = texture;
            postsource = postpage ? new Uint8Array(postpage.buffer, postpage.byteOffset + texture, Math.min(64, postpage.length - texture)) : null;
            postwidth = 1;
            postx = pixx;
        }
    } else {
        if (lastside !== -1) ScalePost();
        lasttilehit = tilehit;
        postx = pixx;
        postwidth = 1;
        const wallpic = vertwall[tilehit & 63] || 0;
        postpage = PM.PM_GetPage(wallpic);
        posttexture = texture;
        postsource = postpage ? new Uint8Array(postpage.buffer, postpage.byteOffset + texture, Math.min(64, postpage.length - texture)) : null;
    }
}

//===========================================================================
// xpartialbyystep / ypartialbyxstep
//===========================================================================

function xpartialbyystep(xpartial: number): number {
    // 64-bit multiply then shift right by 16
    const result = ystep * xpartial;
    return (result / 65536) | 0;
}

function ypartialbyxstep(ypartial: number): number {
    const result = xstep * ypartial;
    return (result / 65536) | 0;
}

//===========================================================================
// AsmRefresh - core ray casting loop (from WL_DR_A.C)
//===========================================================================

function AsmRefresh(): void {
    // Flat tilemap access helper
    const tilemapFlat = (tx: number, ty: number): number => {
        if (tx < 0 || tx >= MAPSIZE || ty < 0 || ty >= MAPSIZE) return 0;
        return tilemap[tx][ty];
    };
    const spotvisSet = (tx: number, ty: number): void => {
        if (tx >= 0 && tx < MAPSIZE && ty >= 0 && ty < MAPSIZE) {
            spotvis[tx][ty] = 1;
        }
    };

    for (pixx = 0; pixx < viewwidth; pixx++) {
        let angle_ray = midangle + pixelangle[pixx];

        if (angle_ray < 0) angle_ray += FINEANGLES;
        if (angle_ray >= FINEANGLES) angle_ray -= FINEANGLES;

        let xpar: number, ypar: number;

        if (angle_ray < DEG90) {
            xtilestep = 1;
            ytilestep = -1;
            xstep = finetangent[DEG90 - 1 - angle_ray];
            ystep = -finetangent[angle_ray];
            xpar = xpartialup;
            ypar = ypartialdown;
        } else if (angle_ray < DEG180) {
            xtilestep = -1;
            ytilestep = -1;
            xstep = -finetangent[angle_ray - DEG90];
            ystep = -finetangent[DEG180 - 1 - angle_ray];
            xpar = xpartialdown;
            ypar = ypartialdown;
        } else if (angle_ray < DEG270) {
            xtilestep = -1;
            ytilestep = 1;
            xstep = -finetangent[DEG270 - 1 - angle_ray];
            ystep = finetangent[angle_ray - DEG180];
            xpar = xpartialdown;
            ypar = ypartialup;
        } else if (angle_ray < DEG360) {
            xtilestep = 1;
            ytilestep = 1;
            xstep = finetangent[angle_ray - DEG270];
            ystep = finetangent[DEG360 - 1 - angle_ray];
            xpar = xpartialup;
            ypar = ypartialup;
        } else {
            angle_ray -= FINEANGLES;
            xtilestep = 1;
            ytilestep = -1;
            xstep = finetangent[DEG90 - 1 - angle_ray];
            ystep = -finetangent[angle_ray];
            xpar = xpartialup;
            ypar = ypartialdown;
        }

        // Initialize variables for intersection testing
        yintercept = viewy + xpartialbyystep(xpar);
        let xt = focaltx + xtilestep;
        xtile = xt;
        let yint_hi = (yintercept >> 16) | 0;

        xintercept = viewx + ypartialbyxstep(ypar);
        let yt = focalty + ytilestep;
        let xint_hi = (xintercept >> 16) | 0;

        // Trace along this angle until we hit a wall
        let hitWall = false;
        let maxIter = 256;

        while (!hitWall && maxIter-- > 0) {
            // Determine which intercept is closer
            let do_vert: boolean;
            if (ytilestep === -1) {
                do_vert = yint_hi > yt;
            } else {
                do_vert = yint_hi < yt;
            }

            // Boundary check for the direction we're about to test
            if (do_vert) {
                if (xt < 0 || xt >= MAPSIZE || yint_hi < 0 || yint_hi >= MAPSIZE) break;
            } else {
                if (yt < 0 || yt >= MAPSIZE || xint_hi < 0 || xint_hi >= MAPSIZE) break;
            }

            if (do_vert) {
                // Check vertical wall
                const tile = tilemapFlat(xt, yint_hi);
                if (tile) {
                    tilehit = tile;
                    if (tile & 0x80) {
                        if (tile & 0x40) {
                            // Pushable wall
                            const partial = ((ystep * act1_pwallpos) / 64) | 0;
                            const newy = yintercept + partial;
                            const newhi = (newy >> 16) | 0;
                            if (newhi !== yint_hi) {
                                // miss - pass through
                            } else {
                                yintercept = newy;
                                xintercept = xt << 16;
                                HitVertPWall();
                                hitWall = true;
                                continue;
                            }
                        } else {
                            // Vertical door
                            const doornum_local = tile & 0x7f;
                            const halfstep = (ystep >> 1) | 0;
                            const newy = yintercept + halfstep;
                            const newhi = (newy >> 16) | 0;
                            if (newhi !== ((yintercept >> 16) | 0)) {
                                // miss
                            } else if (((newy & 0xFFFF) >>> 0) < doorposition[doornum_local]) {
                                // door open past
                            } else {
                                yintercept = newy;
                                xintercept = (xt << 16) | 0x8000;
                                HitVertDoor();
                                hitWall = true;
                                continue;
                            }
                        }
                    } else {
                        // Solid wall
                        xintercept = xt << 16;
                        xtile = xt;
                        yintercept = (yintercept & 0xFFFF) | (yint_hi << 16);
                        ytile = yint_hi;
                        HitVertWall();
                        hitWall = true;
                        continue;
                    }
                }
                // Pass - mark visible and advance
                spotvisSet(xt, yint_hi);
                xt += xtilestep;
                yintercept += ystep;
                yint_hi = (yintercept >> 16) | 0;
                continue;
            }

            // Check horizontal wall
            let do_horiz: boolean;
            if (xtilestep === -1) {
                do_horiz = xint_hi > xt;
            } else {
                do_horiz = xint_hi < xt;
            }

            if (do_horiz) {
                const tile = tilemapFlat(xint_hi, yt);
                if (tile) {
                    tilehit = tile;
                    if (tile & 0x80) {
                        if (tile & 0x40) {
                            const partial = ((xstep * act1_pwallpos) / 64) | 0;
                            const newx = xintercept + partial;
                            const newhi = (newx >> 16) | 0;
                            if (newhi !== xint_hi) {
                                // miss
                            } else {
                                xintercept = newx;
                                yintercept = yt << 16;
                                HitHorizPWall();
                                hitWall = true;
                                continue;
                            }
                        } else {
                            const doornum_local = tile & 0x7f;
                            const halfstep = (xstep >> 1) | 0;
                            const newx = xintercept + halfstep;
                            const newhi = (newx >> 16) | 0;
                            if (newhi !== xint_hi) {
                                // miss
                            } else if (((newx & 0xFFFF) >>> 0) < doorposition[doornum_local]) {
                                // miss
                            } else {
                                xintercept = newx;
                                yintercept = (yt << 16) | 0x8000;
                                HitHorizDoor();
                                hitWall = true;
                                continue;
                            }
                        }
                    } else {
                        xintercept = (xintercept & 0xFFFF) | (xint_hi << 16);
                        xtile = xint_hi;
                        yintercept = yt << 16;
                        ytile = yt;
                        HitHorizWall();
                        hitWall = true;
                        continue;
                    }
                }
                // Pass - mark visible and advance
                spotvisSet(xint_hi, yt);
                yt += ytilestep;
                xintercept += xstep;
                xint_hi = (xintercept >> 16) | 0;
                continue;
            }

            // Tiebreak: both say check other direction. Check vertical first.
            {
                const tile = tilemapFlat(xt, yint_hi);
                if (tile) {
                    tilehit = tile;
                    if (tile & 0x80) {
                        if (tile & 0x40) {
                            const partial = ((ystep * act1_pwallpos) / 64) | 0;
                            const newy = yintercept + partial;
                            const newhi = (newy >> 16) | 0;
                            if (newhi === yint_hi) {
                                yintercept = newy;
                                xintercept = xt << 16;
                                HitVertPWall();
                                hitWall = true;
                                continue;
                            }
                        } else {
                            const doornum_local = tile & 0x7f;
                            const halfstep = (ystep >> 1) | 0;
                            const newy = yintercept + halfstep;
                            const newhi = (newy >> 16) | 0;
                            if (newhi === ((yintercept >> 16) | 0) &&
                                ((newy & 0xFFFF) >>> 0) >= doorposition[doornum_local]) {
                                yintercept = newy;
                                xintercept = (xt << 16) | 0x8000;
                                HitVertDoor();
                                hitWall = true;
                                continue;
                            }
                        }
                    } else {
                        xintercept = xt << 16;
                        xtile = xt;
                        yintercept = (yintercept & 0xFFFF) | (yint_hi << 16);
                        ytile = yint_hi;
                        HitVertWall();
                        hitWall = true;
                        continue;
                    }
                }
                // Tiebreak pass
                spotvisSet(xt, yint_hi);
                xt += xtilestep;
                yintercept += ystep;
                yint_hi = (yintercept >> 16) | 0;
            }
        }
    }
}

//===========================================================================
// CalcRotate
//===========================================================================

export function CalcRotate(ob: objtype): number {
    if (!player) return 0;

    let va = player.angle + ((centerx - ob.viewx) / 8) | 0;
    let angle: number;

    if (ob.obclass === classtype.rocketobj || ob.obclass === classtype.hrocketobj) {
        angle = (va - 180) - ob.angle;
    } else {
        angle = (va - 180) - dirangle[ob.dir];
    }

    angle += (ANGLES / 16) | 0;
    while (angle >= ANGLES) angle -= ANGLES;
    while (angle < 0) angle += ANGLES;

    if (ob.state && ob.state.rotate === true) {
        // Check for 2-rotation pain frame (rotate == 2 in C, but TS uses boolean)
        // Standard 8 rotation
        return ((angle / (ANGLES / 8)) | 0) & 7;
    }

    return ((angle / (ANGLES / 8)) | 0) & 7;
}

//===========================================================================
// DrawScaleds - draw all visible sprites
//===========================================================================

export function DrawScaleds(): void {
    if (!player) return;

    const vislist: visobj_t[] = [];

    // Place static objects
    for (let i = 0; i < statobjlist.length; i++) {
        const statptr = statobjlist[i];
        if (statptr.shapenum === -1) continue;

        // Check visibility via spotvis
        if (statptr.tilex >= 0 && statptr.tilex < MAPSIZE &&
            statptr.tiley >= 0 && statptr.tiley < MAPSIZE) {
            if (!spotvis[statptr.tilex][statptr.tiley]) continue;
        } else {
            continue;
        }

        const tf = TransformTile(statptr.tilex, statptr.tiley);
        if (tf.grabbed && (statptr.flags & FL_BONUS)) {
            GetBonus(statptr);
            continue;
        }
        if (!tf.dispheight) continue;

        if (vislist.length < MAXVISABLE) {
            vislist.push({
                viewx: tf.dispx,
                viewheight: tf.dispheight,
                shapenum: statptr.shapenum,
            });
        }
    }

    // Place active objects
    for (let obj = player.next; obj; obj = obj.next) {
        if (!obj.state || !obj.state.shapenum) continue;

        let shapenum = obj.state.shapenum;

        // Check visibility in 9 surrounding tiles
        const tx = obj.tilex;
        const ty = obj.tiley;
        let vis = false;
        for (let dx = -1; dx <= 1 && !vis; dx++) {
            for (let dy = -1; dy <= 1 && !vis; dy++) {
                const cx = tx + dx;
                const cy = ty + dy;
                if (cx >= 0 && cx < MAPSIZE && cy >= 0 && cy < MAPSIZE) {
                    if (spotvis[cx][cy] && (dx === 0 && dy === 0 || !tilemap[cx][cy])) {
                        vis = true;
                    }
                }
            }
        }

        if (vis) {
            obj.active = activetype.ac_yes;
            TransformActor(obj);
            if (!obj.viewheight) continue;

            let sn = shapenum;
            if (sn === -1) sn = obj.temp1;

            if (obj.state.rotate) {
                sn += CalcRotate(obj);
            }

            if (vislist.length < MAXVISABLE) {
                vislist.push({
                    viewx: obj.viewx,
                    viewheight: obj.viewheight,
                    shapenum: sn,
                });
            }
            obj.flags |= FL_VISABLE;
        } else {
            obj.flags &= ~FL_VISABLE;
        }
    }

    // Draw from back to front (painter's algorithm)
    const numvisable = vislist.length;
    if (!numvisable) return;

    for (let i = 0; i < numvisable; i++) {
        let least = 32000;
        let farthestIdx = 0;
        for (let j = 0; j < vislist.length; j++) {
            if (vislist[j].viewheight < least) {
                least = vislist[j].viewheight;
                farthestIdx = j;
            }
        }

        ScaleShape(vislist[farthestIdx].viewx, vislist[farthestIdx].shapenum, vislist[farthestIdx].viewheight);
        vislist[farthestIdx].viewheight = 32000;
    }
}

//===========================================================================
// DrawPlayerWeapon
//===========================================================================

let _weaponDebug = false;
function DrawPlayerWeapon(): void {
    if (!player) return;

    if (gamestate.victoryflag) {
        return;
    }

    if ((gamestate.weapon as number) !== -1 && gamestate.weapon < weaponscale.length) {
        const shapenum = weaponscale[gamestate.weapon] + gamestate.weaponframe;
        if (!_weaponDebug) {
            _weaponDebug = true;
            const spriteData = PM.PM_GetSpritePage(shapenum);
            console.log(`[DrawPlayerWeapon] weapon=${gamestate.weapon} shape=${shapenum} spriteData=${spriteData ? spriteData.length : 'null'} maxscale=${maxscale} viewheight=${viewheight}`);
        }
        SimpleScaleShape((viewwidth / 2) | 0, shapenum, viewheight + 1);
    }

    if (demorecord || demoplayback) {
        SimpleScaleShape((viewwidth / 2) | 0, SpriteEnum.SPR_DEMO, viewheight + 1);
    }
}

//===========================================================================
// FixOfs
//===========================================================================

export function FixOfs(): void {
    VL.setBufferOfs(screenloc[0]);
    VL.setDisplayOfs(screenloc[0]);
}

//===========================================================================
// WallRefresh - cast rays and draw walls
//===========================================================================

function WallRefresh(): void {
    if (!player) return;

    viewangle = player.angle;
    midangle = ((viewangle * FINEANGLES / ANGLES) | 0);
    viewsin = sintable[viewangle];
    viewcos = costable[viewangle];
    viewx = player.x - FixedByFrac(focallength, viewcos);
    viewy = player.y + FixedByFrac(focallength, viewsin);

    focaltx = viewx >> TILESHIFT;
    focalty = viewy >> TILESHIFT;

    viewtx = player.x >> TILESHIFT;
    viewty = player.y >> TILESHIFT;

    xpartialdown = viewx & (TILEGLOBAL - 1);
    xpartialup = TILEGLOBAL - xpartialdown;
    ypartialdown = viewy & (TILEGLOBAL - 1);
    ypartialup = TILEGLOBAL - ypartialdown;

    lastside = -1;
    AsmRefresh();
    ScalePost();  // flush last post
}

//===========================================================================
// ThreeDRefresh - main 3D rendering function
//===========================================================================

export function ThreeDRefresh(): void {
    if (!player) return;

    // Clear spotvis
    for (let y = 0; y < MAPSIZE; y++) {
        for (let x = 0; x < MAPSIZE; x++) {
            spotvis[x][y] = 0;
        }
    }

    // Clear screen (ceiling/floor)
    ClearScreen();

    // Cast rays and draw walls
    WallRefresh();

    // Draw sprites
    DrawScaleds();

    // Draw player weapon
    DrawPlayerWeapon();

    // Handle fizzle-in effect
    if (fizzlein) {
        fizzlein = false;
        lasttimecount = 0;
    }

    // Present
    VL.VL_UpdateScreen();

    frameon++;
    PM.PM_NextFrame();
}
