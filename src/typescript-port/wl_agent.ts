// WL_AGENT.TS
// Ported from WL_AGENT.C - Player movement, weapons, HUD

import * as VL from './id_vl';
import * as VH from './id_vh';
import * as SD from './id_sd';
import * as IN from './id_in';
import * as US from './id_us_1';
import {
    objtype, statetype, statobj_t, stat_t,
    ANGLES, GLOBAL1, TILEGLOBAL, TILESHIFT, MINDIST, MAPSIZE, AREATILE,
    FL_BONUS, FL_NEVERMARK, FL_SHOOTABLE,
    weapontype, classtype, dirtype, activetype, exit_t,
    tilemap, actorat, tics, mapsegs, farmapylookup,
} from './wl_def';
import { gamestate, sintable, costable, viewwidth, viewheight } from './wl_main';
import {
    player, controlx, controly, buttonstate, buttonheld,
    statobjlist, godmode, noclip,
} from './wl_play';
import * as Play from './wl_play';
import { OperateDoor, PushWall, ConnectAreas } from './wl_act1';
import { soundnames } from './audiowl1';
import { graphicnums } from './gfxv_wl1';
import { bt } from './wl_def';

//===========================================================================
// Constants
//===========================================================================

const MAXMOUSETURN = 10;
const MOVESCALE = 150;
const BACKMOVESCALE = 100;
const ANGLESCALE = 20;
const FACETICS = 70;

const attackinfo = [
    [{ tics: 6, attack: 0, frame: 1 }, { tics: 6, attack: 2, frame: 2 }, { tics: 6, attack: 0, frame: 3 }, { tics: 6, attack: -1, frame: 4 }],
    [{ tics: 6, attack: 0, frame: 1 }, { tics: 6, attack: 1, frame: 2 }, { tics: 6, attack: 0, frame: 3 }, { tics: 6, attack: -1, frame: 4 }],
    [{ tics: 6, attack: 0, frame: 1 }, { tics: 6, attack: 1, frame: 2 }, { tics: 6, attack: 3, frame: 3 }, { tics: 6, attack: -1, frame: 4 }],
    [{ tics: 6, attack: 0, frame: 1 }, { tics: 6, attack: 1, frame: 2 }, { tics: 6, attack: 4, frame: 3 }, { tics: 6, attack: -1, frame: 4 }],
];

//===========================================================================
// Global variables
//===========================================================================

export let running = false;
export let thrustspeed: number = 0;
export let plux = 0;
export let pluy = 0;
export let anglefrac = 0;
export let facecount = 0;
let LastAttacker: objtype | null = null;
let playerxmove = 0;
let playerymove = 0;
let gotgatgun = 0;

// Player states
export const s_player: statetype = { rotate: false, shapenum: 0, tictime: 0, think: T_Player, action: null, next: null };
export const s_attack: statetype = { rotate: false, shapenum: 0, tictime: 0, think: T_Attack, action: null, next: null };

//===========================================================================
// SpawnPlayer
//===========================================================================

export function SpawnPlayer(tilex: number, tiley: number, dir: number): void {
    if (!player) return;
    player.obclass = classtype.playerobj;
    player.active = activetype.ac_allways;
    player.tilex = tilex;
    player.tiley = tiley;
    player.x = ((tilex << TILESHIFT) + (TILEGLOBAL / 2)) | 0;
    player.y = ((tiley << TILESHIFT) + (TILEGLOBAL / 2)) | 0;
    player.angle = (1 - dir) * 90;
    if (player.angle < 0) player.angle += ANGLES;
    player.state = s_player;
}

//===========================================================================
// Thrust - push player in a direction
//===========================================================================

export function Thrust(angle: number, speed: number): void {
    if (!player) return;

    let a = angle;
    if (a < 0) a += ANGLES;
    if (a >= ANGLES) a -= ANGLES;

    const xmove = ((speed * costable[a]) / GLOBAL1) | 0;
    const ymove = -((speed * sintable[a]) / GLOBAL1) | 0;

    playerxmove = xmove;
    playerymove = ymove;

    ClipMove(player, xmove, ymove);
    player.tilex = (player.x >> TILESHIFT) | 0;
    player.tiley = (player.y >> TILESHIFT) | 0;

    thrustspeed += speed;
}

//===========================================================================
// ClipMove - move object and clip against walls
//===========================================================================

function ClipMove(ob: objtype, xmove: number, ymove: number): void {
    const basex = ob.x;
    const basey = ob.y;

    ob.x += xmove;
    ob.y += ymove;

    if (noclip) return;

    // Clip against walls
    const tx = ob.x >> TILESHIFT;
    const ty = ob.y >> TILESHIFT;

    if (tx >= 0 && tx < MAPSIZE && ty >= 0 && ty < MAPSIZE) {
        // Check if player is inside a wall
        if (tilemap[tx][ty]) {
            ob.x = basex;
            ob.y = basey;
            return;
        }
    }

    // Check MINDIST from walls in all 4 directions
    const px = ob.x;
    const py = ob.y;

    const checkx1 = (px - MINDIST) >> TILESHIFT;
    const checkx2 = (px + MINDIST) >> TILESHIFT;
    const checky1 = (py - MINDIST) >> TILESHIFT;
    const checky2 = (py + MINDIST) >> TILESHIFT;

    if (checkx1 >= 0 && checkx1 < MAPSIZE && ty >= 0 && ty < MAPSIZE && tilemap[checkx1][ty]) {
        ob.x = ((checkx1 + 1) << TILESHIFT) + MINDIST;
    }
    if (checkx2 >= 0 && checkx2 < MAPSIZE && ty >= 0 && ty < MAPSIZE && tilemap[checkx2][ty]) {
        ob.x = (checkx2 << TILESHIFT) - MINDIST;
    }
    if (tx >= 0 && tx < MAPSIZE && checky1 >= 0 && checky1 < MAPSIZE && tilemap[tx][checky1]) {
        ob.y = ((checky1 + 1) << TILESHIFT) + MINDIST;
    }
    if (tx >= 0 && tx < MAPSIZE && checky2 >= 0 && checky2 < MAPSIZE && tilemap[tx][checky2]) {
        ob.y = (checky2 << TILESHIFT) - MINDIST;
    }
}

//===========================================================================
// TryMove - check if player can move to current position
//===========================================================================

function TryMove(ob: objtype): boolean {
    const tx = ob.x >> TILESHIFT;
    const ty = ob.y >> TILESHIFT;
    if (tx < 0 || tx >= MAPSIZE || ty < 0 || ty >= MAPSIZE) return false;
    if (tilemap[tx][ty]) return false;
    return true;
}

//===========================================================================
// ControlMovement
//===========================================================================

function ControlMovement(ob: objtype): void {
    thrustspeed = 0;
    const oldx = player ? player.x : 0;
    const oldy = player ? player.y : 0;

    if (buttonstate[bt.bt_strafe]) {
        // Strafing
        if (controlx > 0) {
            let angle = ob.angle - (ANGLES / 4) | 0;
            if (angle < 0) angle += ANGLES;
            Thrust(angle, controlx * MOVESCALE);
        } else if (controlx < 0) {
            let angle = ob.angle + (ANGLES / 4) | 0;
            if (angle >= ANGLES) angle -= ANGLES;
            Thrust(angle, -controlx * MOVESCALE);
        }
    } else {
        // Turning
        anglefrac += controlx;
        const angleunits = (anglefrac / ANGLESCALE) | 0;
        anglefrac -= angleunits * ANGLESCALE;
        ob.angle -= angleunits;

        if (ob.angle >= ANGLES) ob.angle -= ANGLES;
        if (ob.angle < 0) ob.angle += ANGLES;
    }

    // Forward/backward
    if (controly < 0) {
        Thrust(ob.angle, -controly * MOVESCALE);
    } else if (controly > 0) {
        let angle = ob.angle + (ANGLES / 2) | 0;
        if (angle >= ANGLES) angle -= ANGLES;
        Thrust(angle, controly * BACKMOVESCALE);
    }

    if (gamestate.victoryflag) return;

    if (player) {
        playerxmove = player.x - oldx;
        playerymove = player.y - oldy;
    }
}

//===========================================================================
// CheckWeaponChange
//===========================================================================

function CheckWeaponChange(): void {
    if (!gamestate.ammo) return;

    for (let i = weapontype.wp_knife; i <= gamestate.bestweapon; i++) {
        if (buttonstate[bt.bt_readyknife + i - weapontype.wp_knife]) {
            gamestate.weapon = gamestate.chosenweapon = i;
            DrawWeapon();
            return;
        }
    }
}

//===========================================================================
// Cmd_Use - use/open doors
//===========================================================================

function Cmd_Use(): void {
    if (!player) return;

    const checkx = player.tilex + ([0, 1, 0, -1][((player.angle + 45) / 90 | 0) % 4] || 0);
    const checky = player.tiley + ([-1, 0, 1, 0][((player.angle + 45) / 90 | 0) % 4] || 0);

    if (checkx < 0 || checkx >= MAPSIZE || checky < 0 || checky >= MAPSIZE) return;

    const doornum_val = tilemap[checkx][checky];

    if (doornum_val & 0x80) {
        // It's a door
        OperateDoor(doornum_val & 0x3f);
    } else if (doornum_val === 0x62) {
        // Pushwall (PUSHABLETILE = 98 = 0x62)
        const dir = ((player.angle + 45) / 90 | 0) % 4;
        PushWall(checkx, checky, dir);
    }
}

//===========================================================================
// Cmd_Fire - start weapon attack
//===========================================================================

function Cmd_Fire(ob: objtype): void {
    buttonheld[bt.bt_attack] = true;

    gamestate.weaponframe = 0;

    ob.state = s_attack;

    gamestate.attackframe = 0;
    gamestate.attackcount = attackinfo[gamestate.weapon][gamestate.attackframe].tics;
    gamestate.weaponframe = attackinfo[gamestate.weapon][gamestate.attackframe].frame;
}

//===========================================================================
// T_Player - main player think function
//===========================================================================

function T_Player(ob: objtype): void {
    if (!player) return;

    CheckWeaponChange();

    if (buttonstate[bt.bt_use]) {
        Cmd_Use();
    }

    if (buttonstate[bt.bt_attack] && !buttonheld[bt.bt_attack]) {
        Cmd_Fire(ob);
    }

    ControlMovement(ob);

    // Update area connectivity
    if (player) {
        player.areanumber = 0;
        const tx = player.tilex;
        const ty = player.tiley;
        if (tx >= 0 && tx < MAPSIZE && ty >= 0 && ty < MAPSIZE) {
            const mapval = mapsegs[0][farmapylookup[ty] + tx];
            if (mapval >= AREATILE) player.areanumber = mapval - AREATILE;
        }
        ConnectAreas();
    }

    UpdateFace();
}

//===========================================================================
// GunAttack - hit-scan for bullet weapons (pistol, machine gun, chaingun)
//===========================================================================

function GunAttack(): void {
    if (!player) return;

    const px = player.x;
    const py = player.y;
    const angle = player.angle;

    // Step through tiles along the shot direction
    let viewdist = 0x7fffffff;

    // Check all actors for hit
    let closest: objtype | null = null;
    let closestDist = 0x7fffffff;

    for (let check = player.next; check; check = check.next) {
        if (!(check.flags & FL_SHOOTABLE)) continue;
        if (check.active === activetype.ac_no) continue;

        const dx = check.x - px;
        const dy = check.y - py;

        // Transform to player's view space
        const sinAngle = sintable[angle];
        const cosAngle = costable[angle];

        // Distance along view direction
        const dist = ((dx >> 16) * (cosAngle >> 16) - (dy >> 16) * (sinAngle >> 16)) << 16;
        // Lateral offset
        const lateral = ((dx >> 16) * (sinAngle >> 16) + (dy >> 16) * (cosAngle >> 16)) << 16;

        if (dist <= 0) continue;

        // Check if enemy is within the shot cone (±~1.5 degrees for single shot)
        const shotspread = dist >> 5; // roughly ±3% of distance
        if (lateral < -shotspread || lateral > shotspread) continue;

        // Check for wall occlusion (simplified: check tiles between player and enemy)
        let blocked = false;
        const steps = Math.max(Math.abs(check.tilex - player.tilex), Math.abs(check.tiley - player.tiley));
        for (let i = 1; i < steps && !blocked; i++) {
            const tx = player.tilex + ((check.tilex - player.tilex) * i / steps) | 0;
            const ty = player.tiley + ((check.tiley - player.tiley) * i / steps) | 0;
            if (tx >= 0 && tx < MAPSIZE && ty >= 0 && ty < MAPSIZE) {
                const tile = tilemap[tx][ty];
                if (tile && !(tile & 0x80)) blocked = true; // solid wall blocks shot
            }
        }
        if (blocked) continue;

        if (dist < closestDist) {
            closestDist = dist;
            closest = check;
        }
    }

    if (closest) {
        const dist = Math.max(Math.abs(closest.tilex - player.tilex), Math.abs(closest.tiley - player.tiley));
        const hitchance = 256 - dist * 16;
        if (hitchance > 0 && (US.US_RndT() & 0xFF) < hitchance) {
            // Hit!
            const damage = (US.US_RndT() % 10) + 1;
            SD.SD_PlaySound(soundnames.HITENEMYSND);
            import('./wl_state').then(WlState => WlState.DamageActor(closest!, damage));
        } else {
            SD.SD_PlaySound(soundnames.ATKPISTOLSND);
        }
    } else {
        SD.SD_PlaySound(soundnames.ATKPISTOLSND);
    }
}

//===========================================================================
// KnifeAttack - melee attack with knife
//===========================================================================

function KnifeAttack(): void {
    if (!player) return;

    const px = player.x;
    const py = player.y;

    // Check all actors within melee range (~1.5 tiles)
    let closest: objtype | null = null;
    let closestDist = 0x7fffffff;

    for (let check = player.next; check; check = check.next) {
        if (!(check.flags & FL_SHOOTABLE)) continue;
        if (check.active === activetype.ac_no) continue;

        const dx = check.x - px;
        const dy = check.y - py;
        const dist = dx * dx + dy * dy;

        if (dist < closestDist && dist < (TILEGLOBAL * 2) * (TILEGLOBAL * 2)) {
            closestDist = dist;
            closest = check;
        }
    }

    if (closest) {
        const damage = (US.US_RndT() % 10) + 1;
        SD.SD_PlaySound(soundnames.HITENEMYSND);
        import('./wl_state').then(WlState => WlState.DamageActor(closest!, damage));
    } else {
        SD.SD_PlaySound(soundnames.ATKKNIFESND);
    }
}

//===========================================================================
// T_Attack - weapon attack animation with firing logic
//===========================================================================

function T_Attack(ob: objtype): void {
    if (!player) return;

    ControlMovement(ob);

    gamestate.attackcount -= tics;
    while (gamestate.attackcount <= 0) {
        const frameAttack = attackinfo[gamestate.weapon][gamestate.attackframe].attack;

        gamestate.attackframe++;
        if (gamestate.attackframe >= 4 || frameAttack === -1) {
            // Attack finished
            gamestate.attackframe = 0;
            gamestate.weaponframe = 0;
            ob.state = s_player;
            return;
        }
        gamestate.attackcount += attackinfo[gamestate.weapon][gamestate.attackframe].tics;
        gamestate.weaponframe = attackinfo[gamestate.weapon][gamestate.attackframe].frame;

        // Process the attack action for the frame we just left
        if (frameAttack > 0) {
            switch (gamestate.weapon) {
                case weapontype.wp_knife:
                    KnifeAttack();
                    break;
                case weapontype.wp_pistol:
                    if (gamestate.ammo > 0) {
                        gamestate.ammo--;
                        DrawAmmo();
                        GunAttack();
                    }
                    break;
                case weapontype.wp_machinegun:
                    if (gamestate.ammo > 0) {
                        gamestate.ammo--;
                        DrawAmmo();
                        GunAttack();
                        // Machine gun fires extra shots on attack=3
                        if (frameAttack >= 3 && gamestate.ammo > 0) {
                            gamestate.ammo--;
                            DrawAmmo();
                            GunAttack();
                        }
                    }
                    break;
                case weapontype.wp_chaingun:
                    if (gamestate.ammo > 0) {
                        gamestate.ammo--;
                        DrawAmmo();
                        GunAttack();
                        // Chaingun fires extra shots on attack=3,4
                        if (frameAttack >= 3 && gamestate.ammo > 0) {
                            gamestate.ammo--;
                            DrawAmmo();
                            GunAttack();
                        }
                        if (frameAttack >= 4 && gamestate.ammo > 0) {
                            gamestate.ammo--;
                            DrawAmmo();
                            GunAttack();
                        }
                    }
                    break;
            }
        }
    }
}

//===========================================================================
// HUD drawing functions
//===========================================================================

// Status bar Y position (status bar starts at scanline 160)
const STATUS_Y = 160;

//===========================================================================
// StatusDrawPic - draw a graphic in the status bar area
//===========================================================================

function StatusDrawPic(x: number, y: number, picnum: number): void {
    // x,y are in status bar tile coords: x*8 = pixel X, y = pixel Y offset from status bar top
    VH.VWB_DrawPic(x * 8, STATUS_Y + y, picnum);
}

//===========================================================================
// LatchNumber - right-justify and pad with blanks, draw using N_0PIC digits
//===========================================================================

function LatchNumber(x: number, y: number, width: number, num: number): void {
    const str = num.toString();
    let length = str.length;
    let cx = x;
    let w = width;

    // Pad with blank digits
    while (length < w) {
        StatusDrawPic(cx, y, graphicnums.N_BLANKPIC);
        cx++;
        w--;
    }

    // Draw digits (right-most 'width' digits if number is wider)
    const startC = length <= w ? 0 : length - w;
    for (let c = startC; c < length; c++) {
        const digit = str.charCodeAt(c) - 48; // '0' = 48
        StatusDrawPic(cx, y, graphicnums.N_0PIC + digit);
        cx++;
    }
}

//===========================================================================
// DrawFace
//===========================================================================

export function DrawFace(): void {
    if (gamestate.health > 0) {
        // Face graphic: FACE1APIC + 3*((100-health)/16) + faceframe
        // Health bands: 100-85=0, 84-69=1, ..., 0=7 (clamped at 7)
        const band = Math.min(7, ((100 - gamestate.health) / 16) | 0);
        StatusDrawPic(17, 4, graphicnums.FACE1APIC + 3 * band + gamestate.faceframe);
    } else {
        // Dead face
        StatusDrawPic(17, 4, graphicnums.FACE8APIC);
    }
}

function UpdateFace(): void {
    if (SD.SD_SoundPlaying() === soundnames.GETGATLINGSND) return;

    facecount += tics;
    if (facecount > US.US_RndT()) {
        gamestate.faceframe = US.US_RndT() >> 6;
        if (gamestate.faceframe === 3) gamestate.faceframe = 1;
        facecount = 0;
        DrawFace();
    }
}

//===========================================================================
// DrawHealth
//===========================================================================

export function DrawHealth(): void {
    LatchNumber(21, 16, 3, gamestate.health);
}

//===========================================================================
// DrawLevel
//===========================================================================

export function DrawLevel(): void {
    LatchNumber(2, 16, 2, gamestate.mapon + 1);
}

//===========================================================================
// DrawLives
//===========================================================================

export function DrawLives(): void {
    LatchNumber(14, 16, 1, gamestate.lives);
}

//===========================================================================
// DrawScore
//===========================================================================

export function DrawScore(): void {
    LatchNumber(6, 16, 6, gamestate.score);
}

//===========================================================================
// DrawWeapon
//===========================================================================

export function DrawWeapon(): void {
    StatusDrawPic(32, 8, graphicnums.KNIFEPIC + gamestate.weapon);
}

//===========================================================================
// DrawKeys
//===========================================================================

export function DrawKeys(): void {
    if (gamestate.keys & 1) {
        StatusDrawPic(30, 4, graphicnums.GOLDKEYPIC);
    } else {
        StatusDrawPic(30, 4, graphicnums.NOKEYPIC);
    }

    if (gamestate.keys & 2) {
        StatusDrawPic(30, 20, graphicnums.SILVERKEYPIC);
    } else {
        StatusDrawPic(30, 20, graphicnums.NOKEYPIC);
    }
}

//===========================================================================
// DrawAmmo
//===========================================================================

export function DrawAmmo(): void {
    LatchNumber(27, 16, 2, gamestate.ammo);
}

//===========================================================================
// Player action functions
//===========================================================================

export function TakeDamage(points: number, attacker: objtype | null): void {
    LastAttacker = attacker;

    if (gamestate.victoryflag) return;
    if (gamestate.difficulty === 0) points >>= 2; // baby mode

    if (!godmode) {
        gamestate.health -= points;
    }

    if (gamestate.health <= 0) {
        gamestate.health = 0;
        Play.setPlaystate(exit_t.ex_died);
        // killerobj set in wl_play
    }

    Play.StartDamageFlash(points);

    gotgatgun = 0;

    DrawHealth();
    DrawFace();

    SD.SD_PlaySound(soundnames.TAKEDAMAGESND);
}

export function HealSelf(points: number): void {
    gamestate.health += points;
    if (gamestate.health > 100) gamestate.health = 100;
    DrawHealth();
    DrawFace();
}

export function GiveExtraMan(): void {
    gamestate.lives++;
    DrawLives();
    SD.SD_PlaySound(soundnames.BONUS1SND);
}

export function GivePoints(points: number): void {
    gamestate.score += points;
    while (gamestate.score >= gamestate.nextextra) {
        gamestate.nextextra += 40000;
        GiveExtraMan();
    }
    DrawScore();
}

export function GiveWeapon(weapon: number): void {
    GiveAmmo(6);
    if (weapon > gamestate.bestweapon) {
        gamestate.bestweapon = weapon;
    }
    gamestate.weapon = gamestate.chosenweapon = weapon;
    DrawWeapon();
}

export function GiveAmmo(ammo: number): void {
    if (!gamestate.ammo) {
        // Had no ammo before, switch from knife
        if (gamestate.weapon === weapontype.wp_knife) {
            gamestate.weapon = gamestate.chosenweapon;
            DrawWeapon();
        }
    }
    gamestate.ammo += ammo;
    if (gamestate.ammo > 99) gamestate.ammo = 99;
    DrawAmmo();
}

export function GiveKey(key: number): void {
    gamestate.keys |= (1 << key);
    DrawKeys();
}

//===========================================================================
// GetBonus - pick up a static bonus object
//===========================================================================

export function GetBonus(check: statobj_t): void {
    switch (check.itemnumber) {
        case stat_t.bo_firstaid:
            if (gamestate.health >= 100) return;
            SD.SD_PlaySound(soundnames.HEALTH2SND);
            HealSelf(25);
            break;
        case stat_t.bo_key1:
            GiveKey(0);
            SD.SD_PlaySound(soundnames.GETKEYSND);
            break;
        case stat_t.bo_key2:
            GiveKey(1);
            SD.SD_PlaySound(soundnames.GETKEYSND);
            break;
        case stat_t.bo_key3:
            GiveKey(2);
            SD.SD_PlaySound(soundnames.GETKEYSND);
            break;
        case stat_t.bo_key4:
            GiveKey(3);
            SD.SD_PlaySound(soundnames.GETKEYSND);
            break;
        case stat_t.bo_cross:
            SD.SD_PlaySound(soundnames.BONUS1SND);
            GivePoints(100);
            gamestate.treasurecount++;
            break;
        case stat_t.bo_chalice:
            SD.SD_PlaySound(soundnames.BONUS2SND);
            GivePoints(500);
            gamestate.treasurecount++;
            break;
        case stat_t.bo_bible:
            SD.SD_PlaySound(soundnames.BONUS3SND);
            GivePoints(1000);
            gamestate.treasurecount++;
            break;
        case stat_t.bo_crown:
            SD.SD_PlaySound(soundnames.BONUS3SND);
            GivePoints(5000);
            gamestate.treasurecount++;
            break;
        case stat_t.bo_clip:
            if (gamestate.ammo >= 99) return;
            SD.SD_PlaySound(soundnames.GETAMMOSND);
            GiveAmmo(8);
            break;
        case stat_t.bo_clip2:
            if (gamestate.ammo >= 99) return;
            SD.SD_PlaySound(soundnames.GETAMMOSND);
            GiveAmmo(4);
            break;
        case stat_t.bo_25clip:
            if (gamestate.ammo >= 99) return;
            SD.SD_PlaySound(soundnames.GETAMMOSND);
            GiveAmmo(25);
            break;
        case stat_t.bo_machinegun:
            SD.SD_PlaySound(soundnames.GETMACHINESND);
            GiveWeapon(weapontype.wp_machinegun);
            break;
        case stat_t.bo_chaingun:
            SD.SD_PlaySound(soundnames.GETGATLINGSND);
            GiveWeapon(weapontype.wp_chaingun);
            break;
        case stat_t.bo_food:
            if (gamestate.health >= 100) return;
            SD.SD_PlaySound(soundnames.HEALTH1SND);
            HealSelf(10);
            break;
        case stat_t.bo_alpo:
            if (gamestate.health >= 100) return;
            SD.SD_PlaySound(soundnames.HEALTH1SND);
            HealSelf(4);
            break;
        case stat_t.bo_fullheal:
            SD.SD_PlaySound(soundnames.BONUS1SND);
            HealSelf(99);
            GiveAmmo(25);
            GiveExtraMan();
            gamestate.treasurecount++;
            break;
        case stat_t.bo_gibs:
            return;  // gibs are decorative
        default:
            return;
    }

    // Remove the static object
    check.shapenum = -1;
}
