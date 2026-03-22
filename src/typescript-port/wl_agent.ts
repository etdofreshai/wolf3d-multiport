// WL_AGENT.TS
// Ported from WL_AGENT.C - Player movement, weapons, HUD

import * as VL from './id_vl';
import { objtype, ANGLES, GLOBAL1, TILEGLOBAL, TILESHIFT, MINDIST } from './wl_def';
import { gamestate, sintable, costable, viewwidth } from './wl_main';
import { player, controlx, controly, buttonstate } from './wl_play';

//===========================================================================
// Global variables
//===========================================================================

export let running = false;
export let thrustspeed: number = 0;
export let plux = 0;
export let pluy = 0;
export let anglefrac = 0;
export let facecount = 0;

//===========================================================================
// SpawnPlayer
//===========================================================================

export function SpawnPlayer(tilex: number, tiley: number, dir: number): void {
    if (!player) return;
    player.obclass = 1;  // playerobj
    player.active = 2;   // ac_allways
    player.tilex = tilex;
    player.tiley = tiley;
    player.x = ((tilex << TILESHIFT) + TILEGLOBAL / 2) | 0;
    player.y = ((tiley << TILESHIFT) + TILEGLOBAL / 2) | 0;
    player.angle = (1 - dir) * 90;
    if (player.angle < 0) player.angle += ANGLES;
}

//===========================================================================
// Thrust - push player in a direction
//===========================================================================

export function Thrust(angle: number, speed: number): void {
    if (!player) return;

    const idx = angle % ANGLES;
    if (idx >= 0 && idx < sintable.length) {
        player.x += ((speed * costable[idx]) / GLOBAL1) | 0;
        player.y -= ((speed * sintable[idx]) / GLOBAL1) | 0;
    }

    player.tilex = (player.x >> TILESHIFT) | 0;
    player.tiley = (player.y >> TILESHIFT) | 0;
}

//===========================================================================
// HUD drawing functions
//===========================================================================

export function DrawFace(): void {}
export function DrawHealth(): void {}
export function DrawLevel(): void {}
export function DrawLives(): void {}
export function DrawScore(): void {}
export function DrawWeapon(): void {}
export function DrawKeys(): void {}
export function DrawAmmo(): void {}

//===========================================================================
// Player action functions
//===========================================================================

export function TakeDamage(_points: number, _attacker: objtype | null): void {
    gamestate.health -= _points;
    if (gamestate.health <= 0) {
        gamestate.health = 0;
    }
}

export function HealSelf(points: number): void {
    gamestate.health += points;
    if (gamestate.health > 100) gamestate.health = 100;
}

export function GiveExtraMan(): void {
    gamestate.lives++;
}

export function GivePoints(points: number): void {
    gamestate.score += points;
    while (gamestate.score >= gamestate.nextextra) {
        gamestate.nextextra += 40000;
        GiveExtraMan();
    }
}

export function GiveWeapon(weapon: number): void {
    gamestate.weapon = weapon;
    if (weapon > gamestate.bestweapon) {
        gamestate.bestweapon = weapon;
    }
}

export function GiveAmmo(ammo: number): void {
    gamestate.ammo += ammo;
    if (gamestate.ammo > 99) gamestate.ammo = 99;
}

export function GiveKey(key: number): void {
    gamestate.keys |= (1 << key);
}

export function GetBonus(_check: any): void {}
