// WL_ACT2.TS
// Ported from WL_ACT2.C - Enemy AI and state machines

import {
    statetype, objtype, enemy_t, classtype, dirtype, activetype,
    FL_SHOOTABLE, FL_AMBUSH, FL_ATTACKMODE, FL_FIRSTATTACK,
    FL_NEVERMARK, FL_NONMARK,
    TILEGLOBAL, TILESHIFT, ANGLES, M_PI,
    SpriteEnum,
    SPDPATROL, SPDDOG,
    tics, newObjtype,
} from './wl_def';
import { gamestate } from './wl_main';
import { player, GetNewActor, newobj, madenoise, lastobj, areabyplayer } from './wl_play';
import {
    SpawnNewObj, NewState, SelectDodgeDir, SelectChaseDir, SelectRunDir,
    MoveObj, CheckLine, SightPlayer, CheckSight,
} from './wl_state';
import * as SD from './id_sd';
import * as US from './id_us_1';
import { soundnames } from './audiowl1';
import { TakeDamage } from './wl_agent';

//===========================================================================
// Think/Action functions
//===========================================================================

function T_Stand(ob: objtype): void {
    SightPlayer(ob);
}

function T_Path(ob: objtype): void {
    if (SightPlayer(ob)) return;

    // Continue patrolling - move along current direction
    if (ob.distance < 0) {
        // Waiting at door
        return;
    }

    if (ob.distance > 0 && ob.speed > 0) {
        const move = Math.min(ob.speed * (typeof tics !== 'undefined' ? tics : 1), ob.distance);
        MoveObj(ob, move);
    } else if (ob.distance <= 0) {
        // Reached destination - pick a new direction or stop
        ob.distance = 0;
    }
}

// Attack range constants
const CLOSE_RANGE = 2;    // tiles for melee/dog attacks
const SHOOT_RANGE = 12;   // tiles for shooting attacks

function T_Chase(ob: objtype): void {
    if (!player) return;
    if (gamestate.victoryflag) return;

    let dodge = false;

    if (CheckLine(ob)) {
        const dx = Math.abs(ob.tilex - player.tilex);
        const dy = Math.abs(ob.tiley - player.tiley);
        const dist = Math.max(dx, dy);

        let chance: number;
        if (!dist || (dist === 1 && ob.distance < 0x4000)) {
            chance = 300;
        } else {
            chance = ((tics << 4) / dist) | 0;
        }

        if ((US.US_RndT() & 0xFF) < chance) {
            // Go into attack frame
            switch (ob.obclass) {
                case classtype.guardobj:
                    NewState(ob, s_grdshoot1);
                    return;
                case classtype.officerobj:
                    NewState(ob, s_ofcshoot1);
                    return;
                case classtype.ssobj:
                    NewState(ob, s_ssshoot1);
                    return;
                case classtype.mutantobj:
                    NewState(ob, s_mutshoot1);
                    return;
                case classtype.bossobj:
                    NewState(ob, s_bossshoot1);
                    return;
                case classtype.gretelobj:
                    NewState(ob, s_gretelshoot1);
                    return;
                case classtype.mechahitlerobj:
                    NewState(ob, s_mechashoot1);
                    return;
                case classtype.realhitlerobj:
                    NewState(ob, s_hitlershoot1);
                    return;
                default:
                    break;
            }
        }
        dodge = true;
    }

    if ((ob.dir as number) === (dirtype.nodir as number)) {
        if (dodge)
            SelectDodgeDir(ob);
        else
            SelectChaseDir(ob);
        if ((ob.dir as number) === (dirtype.nodir as number))
            return;
    }

    const move = ob.speed * (typeof tics !== 'undefined' ? tics : 1);
    if (move > 0 && ob.distance > 0) {
        const actual = Math.min(move, ob.distance);
        MoveObj(ob, actual);
    }
}

function T_DogChase(ob: objtype): void {
    if (!player) return;

    if (CheckSight(ob)) {
        const dx = Math.abs(ob.tilex - player.tilex);
        const dy = Math.abs(ob.tiley - player.tiley);
        const dist = Math.max(dx, dy);

        // Dogs lunge at close range
        if (dist <= CLOSE_RANGE) {
            NewState(ob, s_dogjump1);
            return;
        }
    }

    SelectDodgeDir(ob);
}

function T_Shoot(ob: objtype): void {
    // Enemy fires at player
    if (!player) return;

    const dx = Math.abs(ob.tilex - player.tilex);
    const dy = Math.abs(ob.tiley - player.tiley);
    const dist = Math.max(dx, dy);

    const hitchance = US.US_RndT() & 0xFF;
    let damage = 0;

    if (dist < 2) damage = hitchance >> 2;
    else if (dist < 4) damage = hitchance >> 3;
    else if (dist < 8) damage = hitchance >> 4;
    else damage = hitchance >> 5;

    if (damage > 0) {
        TakeDamage(damage, ob);
    }

    SD.SD_PlaySound(soundnames.ATKPISTOLSND);
}

function T_Bite(ob: objtype): void {
    // Dog bite attack
    if (!player) return;
    const dx = Math.abs(ob.tilex - player.tilex);
    const dy = Math.abs(ob.tiley - player.tiley);
    if (dx <= 1 && dy <= 1) {
        const damage = (US.US_RndT() >> 4) + 1;
        TakeDamage(damage, ob);
    }
}

//===========================================================================
// Boss-specific chase/think functions
//===========================================================================

// T_Schabb - Schabbs chase AI (throws needles)
function T_Schabb(ob: objtype): void {
    if (!player) return;

    let dodge = false;
    const dx = Math.abs(ob.tilex - player.tilex);
    const dy = Math.abs(ob.tiley - player.tiley);
    const dist = Math.max(dx, dy);

    if (CheckLine(ob)) {
        if (US.US_RndT() < (tics << 3)) {
            NewState(ob, s_schabbshoot1);
            return;
        }
        dodge = true;
    }

    if ((ob.dir as number) === (dirtype.nodir as number)) {
        if (dodge)
            SelectDodgeDir(ob);
        else
            SelectChaseDir(ob);
        if ((ob.dir as number) === (dirtype.nodir as number))
            return;
    }

    const move = ob.speed * (typeof tics !== 'undefined' ? tics : 1);
    if (move > 0 && ob.distance > 0) {
        if (dist < 4)
            SelectRunDir(ob);
        else if (dodge)
            SelectDodgeDir(ob);
        else
            SelectChaseDir(ob);

        if ((ob.dir as number) !== (dirtype.nodir as number)) {
            const actual = Math.min(move, ob.distance);
            MoveObj(ob, actual);
        }
    }
}

// T_Gift - Giftmacher chase AI (throws rockets)
function T_Gift(ob: objtype): void {
    if (!player) return;

    let dodge = false;
    const dx = Math.abs(ob.tilex - player.tilex);
    const dy = Math.abs(ob.tiley - player.tiley);
    const dist = Math.max(dx, dy);

    if (CheckLine(ob)) {
        if (US.US_RndT() < (tics << 3)) {
            NewState(ob, s_giftshoot1);
            return;
        }
        dodge = true;
    }

    if ((ob.dir as number) === (dirtype.nodir as number)) {
        if (dodge)
            SelectDodgeDir(ob);
        else
            SelectChaseDir(ob);
        if ((ob.dir as number) === (dirtype.nodir as number))
            return;
    }

    const move = ob.speed * (typeof tics !== 'undefined' ? tics : 1);
    if (move > 0 && ob.distance > 0) {
        if (dist < 4)
            SelectRunDir(ob);
        else if (dodge)
            SelectDodgeDir(ob);
        else
            SelectChaseDir(ob);

        if ((ob.dir as number) !== (dirtype.nodir as number)) {
            const actual = Math.min(move, ob.distance);
            MoveObj(ob, actual);
        }
    }
}

// T_Fat - Fat Face chase AI (throws rockets and shoots)
function T_Fat(ob: objtype): void {
    if (!player) return;

    let dodge = false;
    const dx = Math.abs(ob.tilex - player.tilex);
    const dy = Math.abs(ob.tiley - player.tiley);
    const dist = Math.max(dx, dy);

    if (CheckLine(ob)) {
        if (US.US_RndT() < (tics << 3)) {
            NewState(ob, s_fatshoot1);
            return;
        }
        dodge = true;
    }

    if ((ob.dir as number) === (dirtype.nodir as number)) {
        if (dodge)
            SelectDodgeDir(ob);
        else
            SelectChaseDir(ob);
        if ((ob.dir as number) === (dirtype.nodir as number))
            return;
    }

    const move = ob.speed * (typeof tics !== 'undefined' ? tics : 1);
    if (move > 0 && ob.distance > 0) {
        if (dist < 4)
            SelectRunDir(ob);
        else if (dodge)
            SelectDodgeDir(ob);
        else
            SelectChaseDir(ob);

        if ((ob.dir as number) !== (dirtype.nodir as number)) {
            const actual = Math.min(move, ob.distance);
            MoveObj(ob, actual);
        }
    }
}

// T_Fake - Fake Hitler chase AI (shoots fire)
function T_Fake(ob: objtype): void {
    if (!player) return;

    if (CheckLine(ob)) {
        if (US.US_RndT() < (tics << 1)) {
            NewState(ob, s_fakeshoot1);
            return;
        }
    }

    if ((ob.dir as number) === (dirtype.nodir as number)) {
        SelectDodgeDir(ob);
        if ((ob.dir as number) === (dirtype.nodir as number))
            return;
    }

    const move = ob.speed * (typeof tics !== 'undefined' ? tics : 1);
    if (move > 0 && ob.distance > 0) {
        const actual = Math.min(move, ob.distance);
        MoveObj(ob, actual);
    }
}

function T_Ghosts(ob: objtype): void {
    SelectChaseDir(ob);
}

function T_Projectile(ob: objtype): void {
    // Move projectile forward
    const speed = 0x2000;
    MoveObj(ob, speed);
}

//===========================================================================
// Action functions
//===========================================================================

// T_SchabbThrow - Schabbs throws a needle projectile
function T_SchabbThrow(ob: objtype): void {
    if (!player) return;

    const deltax = player.x - ob.x;
    const deltay = ob.y - player.y;
    let angle = Math.atan2(deltay, deltax);
    if (angle < 0) angle = M_PI * 2 + angle;
    const iangle = (angle / (M_PI * 2) * ANGLES) | 0;

    const proj = GetNewActor();
    proj.state = s_needle1;
    proj.ticcount = 1;
    proj.tilex = ob.tilex;
    proj.tiley = ob.tiley;
    proj.x = ob.x;
    proj.y = ob.y;
    proj.obclass = classtype.needleobj;
    proj.dir = dirtype.nodir;
    proj.angle = iangle;
    proj.speed = 0x2000;
    proj.flags = FL_NONMARK;
    proj.active = activetype.ac_yes;

    SD.SD_PlaySound(soundnames.BOSSFIRESND);
}

// T_GiftThrow - Gift/Fat throw a rocket
function T_GiftThrow(ob: objtype): void {
    if (!player) return;

    const deltax = player.x - ob.x;
    const deltay = ob.y - player.y;
    let angle = Math.atan2(deltay, deltax);
    if (angle < 0) angle = M_PI * 2 + angle;
    const iangle = (angle / (M_PI * 2) * ANGLES) | 0;

    const proj = GetNewActor();
    proj.state = s_rocket;
    proj.ticcount = 1;
    proj.tilex = ob.tilex;
    proj.tiley = ob.tiley;
    proj.x = ob.x;
    proj.y = ob.y;
    proj.obclass = classtype.rocketobj;
    proj.dir = dirtype.nodir;
    proj.angle = iangle;
    proj.speed = 0x2000;
    proj.flags = FL_NONMARK;
    proj.active = activetype.ac_yes;

    SD.SD_PlaySound(soundnames.MISSILEFIRESND);
}

// T_FakeFire - Fake Hitler shoots fire projectiles
function T_FakeFire(ob: objtype): void {
    if (!player) return;

    const deltax = player.x - ob.x;
    const deltay = ob.y - player.y;
    let angle = Math.atan2(deltay, deltax);
    if (angle < 0) angle = M_PI * 2 + angle;
    const iangle = (angle / (M_PI * 2) * ANGLES) | 0;

    const proj = GetNewActor();
    proj.state = s_fire1;
    proj.ticcount = 1;
    proj.tilex = ob.tilex;
    proj.tiley = ob.tiley;
    proj.x = ob.x;
    proj.y = ob.y;
    proj.dir = dirtype.nodir;
    proj.angle = iangle;
    proj.obclass = classtype.fireobj;
    proj.speed = 0x1200;
    proj.flags = FL_NEVERMARK;
    proj.active = activetype.ac_yes;

    SD.SD_PlaySound(soundnames.FLAMETHROWERSND);
}

// A_Smoke - spawn smoke trail behind rockets
function A_Smoke(ob: objtype): void {
    const smoke = GetNewActor();
    smoke.state = s_smoke1;
    smoke.ticcount = 6;
    smoke.tilex = ob.tilex;
    smoke.tiley = ob.tiley;
    smoke.x = ob.x;
    smoke.y = ob.y;
    smoke.obclass = classtype.inertobj;
    smoke.active = activetype.ac_yes;
    smoke.flags = FL_NEVERMARK;
}

// A_HitlerMorph - Mecha Hitler dies and spawns real Hitler
function A_HitlerMorph(ob: objtype): void {
    const hitpoints = [500, 700, 800, 900];

    SpawnNewObj(ob.tilex, ob.tiley, s_hitlerchase1);
    const newHitler = lastObj();
    if (!newHitler) return;

    newHitler.speed = SPDPATROL * 5;
    newHitler.x = ob.x;
    newHitler.y = ob.y;
    newHitler.distance = ob.distance;
    newHitler.dir = ob.dir;
    newHitler.flags = ob.flags | FL_SHOOTABLE;
    newHitler.obclass = classtype.realhitlerobj;
    newHitler.hitpoints = hitpoints[gamestate.difficulty] || hitpoints[0];
}

// A_MechaSound - stomp sound while mecha walks
function A_MechaSound(ob: objtype): void {
    if (areabyplayer[ob.areanumber]) {
        SD.SD_PlaySound(soundnames.MECHSTEPSND);
    }
}

// A_Slurpie - slurpie sound when Hitler dies
function A_Slurpie(_ob: objtype): void {
    SD.SD_PlaySound(soundnames.SLURPIESND);
}

// A_StartDeathCam - placeholder for deathcam sequence
function A_StartDeathCam(_ob: objtype): void {
    // Death camera sequence - will be fully implemented with rendering
}

//===========================================================================
// Full state machine definitions with correct sprite numbers
//===========================================================================

// ---- Rocket / Smoke / Boom projectile states ----

export const s_rocket: statetype = { rotate: true, shapenum: SpriteEnum.SPR_ROCKET_1, tictime: 3, think: T_Projectile, action: A_Smoke, next: null as any };
s_rocket.next = s_rocket; // self-loop

export const s_smoke1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SMOKE_1, tictime: 3, think: null, action: null, next: null as any };
export const s_smoke2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SMOKE_2, tictime: 3, think: null, action: null, next: null as any };
export const s_smoke3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SMOKE_3, tictime: 3, think: null, action: null, next: null as any };
export const s_smoke4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SMOKE_4, tictime: 3, think: null, action: null, next: null };
s_smoke1.next = s_smoke2; s_smoke2.next = s_smoke3; s_smoke3.next = s_smoke4;

export const s_boom1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BOOM_1, tictime: 6, think: null, action: null, next: null as any };
export const s_boom2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BOOM_2, tictime: 6, think: null, action: null, next: null as any };
export const s_boom3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BOOM_3, tictime: 6, think: null, action: null, next: null };
s_boom1.next = s_boom2; s_boom2.next = s_boom3;

// ---- Needle (Schabbs syringe projectile) ----

export const s_needle1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HYPO1, tictime: 6, think: T_Projectile, action: null, next: null as any };
export const s_needle2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HYPO2, tictime: 6, think: T_Projectile, action: null, next: null as any };
export const s_needle3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HYPO3, tictime: 6, think: T_Projectile, action: null, next: null as any };
export const s_needle4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HYPO4, tictime: 6, think: T_Projectile, action: null, next: null as any };
s_needle1.next = s_needle2; s_needle2.next = s_needle3; s_needle3.next = s_needle4; s_needle4.next = s_needle1;

// ---- Fire (Fake Hitler fire projectile) ----

export const s_fire1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FIRE1, tictime: 6, think: null, action: T_Projectile, next: null as any };
export const s_fire2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FIRE2, tictime: 6, think: null, action: T_Projectile, next: null as any };
s_fire1.next = s_fire2; s_fire2.next = s_fire1;

//===========================================================================
// Guard states
//===========================================================================

export const s_grdstand: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GRD_S_1, tictime: 0, think: T_Stand, action: null, next: null as any };
s_grdstand.next = s_grdstand;

export const s_grdpath1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GRD_W1_1, tictime: 20, think: T_Path, action: null, next: null as any };
export const s_grdpath1s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GRD_W1_1, tictime: 5, think: null, action: null, next: null as any };
export const s_grdpath2: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GRD_W2_1, tictime: 15, think: T_Path, action: null, next: null as any };
export const s_grdpath3: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GRD_W3_1, tictime: 20, think: T_Path, action: null, next: null as any };
export const s_grdpath3s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GRD_W3_1, tictime: 5, think: null, action: null, next: null as any };
export const s_grdpath4: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GRD_W4_1, tictime: 15, think: T_Path, action: null, next: null as any };
s_grdpath1.next = s_grdpath1s; s_grdpath1s.next = s_grdpath2;
s_grdpath2.next = s_grdpath3; s_grdpath3.next = s_grdpath3s;
s_grdpath3s.next = s_grdpath4; s_grdpath4.next = s_grdpath1;

export const s_grdchase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GRD_W1_1, tictime: 10, think: T_Chase, action: null, next: null as any };
export const s_grdchase1s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GRD_W1_1, tictime: 3, think: null, action: null, next: null as any };
export const s_grdchase2: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GRD_W2_1, tictime: 8, think: T_Chase, action: null, next: null as any };
export const s_grdchase3: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GRD_W3_1, tictime: 10, think: T_Chase, action: null, next: null as any };
export const s_grdchase3s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GRD_W3_1, tictime: 3, think: null, action: null, next: null as any };
export const s_grdchase4: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GRD_W4_1, tictime: 8, think: T_Chase, action: null, next: null as any };
s_grdchase1.next = s_grdchase1s; s_grdchase1s.next = s_grdchase2;
s_grdchase2.next = s_grdchase3; s_grdchase3.next = s_grdchase3s;
s_grdchase3s.next = s_grdchase4; s_grdchase4.next = s_grdchase1;

export const s_grdpain: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRD_PAIN_1, tictime: 10, think: null, action: null, next: null as any };
export const s_grdpain1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRD_PAIN_2, tictime: 10, think: null, action: null, next: null as any };
s_grdpain.next = s_grdchase1; s_grdpain1.next = s_grdchase1;

export const s_grdshoot1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRD_SHOOT1, tictime: 20, think: null, action: null, next: null as any };
export const s_grdshoot2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRD_SHOOT2, tictime: 20, think: null, action: T_Shoot, next: null as any };
export const s_grdshoot3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRD_SHOOT3, tictime: 20, think: null, action: null, next: null as any };
s_grdshoot1.next = s_grdshoot2; s_grdshoot2.next = s_grdshoot3; s_grdshoot3.next = s_grdchase1;

export const s_grddie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRD_DIE_1, tictime: 15, think: null, action: A_DeathScream, next: null as any };
export const s_grddie2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRD_DIE_2, tictime: 15, think: null, action: null, next: null as any };
export const s_grddie3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRD_DIE_3, tictime: 15, think: null, action: null, next: null as any };
export const s_grddie4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRD_DEAD, tictime: 0, think: null, action: null, next: null as any };
s_grddie1.next = s_grddie2; s_grddie2.next = s_grddie3; s_grddie3.next = s_grddie4;
s_grddie4.next = s_grddie4; // terminal self-loop

//===========================================================================
// Dog states
//===========================================================================

export const s_dogpath1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_DOG_W1_1, tictime: 20, think: T_Path, action: null, next: null as any };
export const s_dogpath1s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_DOG_W1_1, tictime: 5, think: null, action: null, next: null as any };
export const s_dogpath2: statetype = { rotate: true, shapenum: SpriteEnum.SPR_DOG_W2_1, tictime: 15, think: T_Path, action: null, next: null as any };
export const s_dogpath3: statetype = { rotate: true, shapenum: SpriteEnum.SPR_DOG_W3_1, tictime: 20, think: T_Path, action: null, next: null as any };
export const s_dogpath3s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_DOG_W3_1, tictime: 5, think: null, action: null, next: null as any };
export const s_dogpath4: statetype = { rotate: true, shapenum: SpriteEnum.SPR_DOG_W4_1, tictime: 15, think: T_Path, action: null, next: null as any };
s_dogpath1.next = s_dogpath1s; s_dogpath1s.next = s_dogpath2;
s_dogpath2.next = s_dogpath3; s_dogpath3.next = s_dogpath3s;
s_dogpath3s.next = s_dogpath4; s_dogpath4.next = s_dogpath1;

export const s_dogchase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_DOG_W1_1, tictime: 10, think: T_DogChase, action: null, next: null as any };
export const s_dogchase1s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_DOG_W1_1, tictime: 3, think: null, action: null, next: null as any };
export const s_dogchase2: statetype = { rotate: true, shapenum: SpriteEnum.SPR_DOG_W2_1, tictime: 8, think: T_DogChase, action: null, next: null as any };
export const s_dogchase3: statetype = { rotate: true, shapenum: SpriteEnum.SPR_DOG_W3_1, tictime: 10, think: T_DogChase, action: null, next: null as any };
export const s_dogchase3s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_DOG_W3_1, tictime: 3, think: null, action: null, next: null as any };
export const s_dogchase4: statetype = { rotate: true, shapenum: SpriteEnum.SPR_DOG_W4_1, tictime: 8, think: T_DogChase, action: null, next: null as any };
s_dogchase1.next = s_dogchase1s; s_dogchase1s.next = s_dogchase2;
s_dogchase2.next = s_dogchase3; s_dogchase3.next = s_dogchase3s;
s_dogchase3s.next = s_dogchase4; s_dogchase4.next = s_dogchase1;

export const s_dogdie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_DOG_DIE_1, tictime: 15, think: null, action: A_DeathScream, next: null as any };
export const s_dogdie2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_DOG_DIE_2, tictime: 15, think: null, action: null, next: null as any };
export const s_dogdie3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_DOG_DIE_3, tictime: 15, think: null, action: null, next: null as any };
export const s_dogdead: statetype = { rotate: false, shapenum: SpriteEnum.SPR_DOG_DEAD, tictime: 15, think: null, action: null, next: null as any };
s_dogdie1.next = s_dogdie2; s_dogdie2.next = s_dogdie3; s_dogdie3.next = s_dogdead;
s_dogdead.next = s_dogdead;

export const s_dogjump1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_DOG_JUMP1, tictime: 10, think: null, action: null, next: null as any };
export const s_dogjump2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_DOG_JUMP2, tictime: 10, think: null, action: T_Bite, next: null as any };
export const s_dogjump3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_DOG_JUMP3, tictime: 10, think: null, action: null, next: null as any };
export const s_dogjump4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_DOG_JUMP1, tictime: 10, think: null, action: null, next: null as any };
export const s_dogjump5: statetype = { rotate: false, shapenum: SpriteEnum.SPR_DOG_W1_1, tictime: 10, think: null, action: null, next: null as any };
s_dogjump1.next = s_dogjump2; s_dogjump2.next = s_dogjump3;
s_dogjump3.next = s_dogjump4; s_dogjump4.next = s_dogjump5;
s_dogjump5.next = s_dogchase1;

//===========================================================================
// Officer states
//===========================================================================

export const s_ofcstand: statetype = { rotate: true, shapenum: SpriteEnum.SPR_OFC_S_1, tictime: 0, think: T_Stand, action: null, next: null as any };
s_ofcstand.next = s_ofcstand;

export const s_ofcpath1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_OFC_W1_1, tictime: 20, think: T_Path, action: null, next: null as any };
export const s_ofcpath1s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_OFC_W1_1, tictime: 5, think: null, action: null, next: null as any };
export const s_ofcpath2: statetype = { rotate: true, shapenum: SpriteEnum.SPR_OFC_W2_1, tictime: 15, think: T_Path, action: null, next: null as any };
export const s_ofcpath3: statetype = { rotate: true, shapenum: SpriteEnum.SPR_OFC_W3_1, tictime: 20, think: T_Path, action: null, next: null as any };
export const s_ofcpath3s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_OFC_W3_1, tictime: 5, think: null, action: null, next: null as any };
export const s_ofcpath4: statetype = { rotate: true, shapenum: SpriteEnum.SPR_OFC_W4_1, tictime: 15, think: T_Path, action: null, next: null as any };
s_ofcpath1.next = s_ofcpath1s; s_ofcpath1s.next = s_ofcpath2;
s_ofcpath2.next = s_ofcpath3; s_ofcpath3.next = s_ofcpath3s;
s_ofcpath3s.next = s_ofcpath4; s_ofcpath4.next = s_ofcpath1;

export const s_ofcchase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_OFC_W1_1, tictime: 10, think: T_Chase, action: null, next: null as any };
export const s_ofcchase1s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_OFC_W1_1, tictime: 3, think: null, action: null, next: null as any };
export const s_ofcchase2: statetype = { rotate: true, shapenum: SpriteEnum.SPR_OFC_W2_1, tictime: 8, think: T_Chase, action: null, next: null as any };
export const s_ofcchase3: statetype = { rotate: true, shapenum: SpriteEnum.SPR_OFC_W3_1, tictime: 10, think: T_Chase, action: null, next: null as any };
export const s_ofcchase3s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_OFC_W3_1, tictime: 3, think: null, action: null, next: null as any };
export const s_ofcchase4: statetype = { rotate: true, shapenum: SpriteEnum.SPR_OFC_W4_1, tictime: 8, think: T_Chase, action: null, next: null as any };
s_ofcchase1.next = s_ofcchase1s; s_ofcchase1s.next = s_ofcchase2;
s_ofcchase2.next = s_ofcchase3; s_ofcchase3.next = s_ofcchase3s;
s_ofcchase3s.next = s_ofcchase4; s_ofcchase4.next = s_ofcchase1;

export const s_ofcpain: statetype = { rotate: false, shapenum: SpriteEnum.SPR_OFC_PAIN_1, tictime: 10, think: null, action: null, next: null as any };
export const s_ofcpain1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_OFC_PAIN_2, tictime: 10, think: null, action: null, next: null as any };
s_ofcpain.next = s_ofcchase1; s_ofcpain1.next = s_ofcchase1;

export const s_ofcshoot1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_OFC_SHOOT1, tictime: 6, think: null, action: null, next: null as any };
export const s_ofcshoot2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_OFC_SHOOT2, tictime: 20, think: null, action: T_Shoot, next: null as any };
export const s_ofcshoot3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_OFC_SHOOT3, tictime: 10, think: null, action: null, next: null as any };
s_ofcshoot1.next = s_ofcshoot2; s_ofcshoot2.next = s_ofcshoot3; s_ofcshoot3.next = s_ofcchase1;

export const s_ofcdie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_OFC_DIE_1, tictime: 11, think: null, action: A_DeathScream, next: null as any };
export const s_ofcdie2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_OFC_DIE_2, tictime: 11, think: null, action: null, next: null as any };
export const s_ofcdie3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_OFC_DIE_3, tictime: 11, think: null, action: null, next: null as any };
export const s_ofcdie4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_OFC_DIE_4, tictime: 11, think: null, action: null, next: null as any };
export const s_ofcdead: statetype = { rotate: false, shapenum: SpriteEnum.SPR_OFC_DEAD, tictime: 0, think: null, action: null, next: null as any };
s_ofcdie1.next = s_ofcdie2; s_ofcdie2.next = s_ofcdie3; s_ofcdie3.next = s_ofcdie4;
s_ofcdie4.next = s_ofcdead; s_ofcdead.next = s_ofcdead;

//===========================================================================
// SS states
//===========================================================================

export const s_ssstand: statetype = { rotate: true, shapenum: SpriteEnum.SPR_SS_S_1, tictime: 0, think: T_Stand, action: null, next: null as any };
s_ssstand.next = s_ssstand;

export const s_sspath1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_SS_W1_1, tictime: 20, think: T_Path, action: null, next: null as any };
export const s_sspath1s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_SS_W1_1, tictime: 5, think: null, action: null, next: null as any };
export const s_sspath2: statetype = { rotate: true, shapenum: SpriteEnum.SPR_SS_W2_1, tictime: 15, think: T_Path, action: null, next: null as any };
export const s_sspath3: statetype = { rotate: true, shapenum: SpriteEnum.SPR_SS_W3_1, tictime: 20, think: T_Path, action: null, next: null as any };
export const s_sspath3s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_SS_W3_1, tictime: 5, think: null, action: null, next: null as any };
export const s_sspath4: statetype = { rotate: true, shapenum: SpriteEnum.SPR_SS_W4_1, tictime: 15, think: T_Path, action: null, next: null as any };
s_sspath1.next = s_sspath1s; s_sspath1s.next = s_sspath2;
s_sspath2.next = s_sspath3; s_sspath3.next = s_sspath3s;
s_sspath3s.next = s_sspath4; s_sspath4.next = s_sspath1;

export const s_sschase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_SS_W1_1, tictime: 10, think: T_Chase, action: null, next: null as any };
export const s_sschase1s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_SS_W1_1, tictime: 3, think: null, action: null, next: null as any };
export const s_sschase2: statetype = { rotate: true, shapenum: SpriteEnum.SPR_SS_W2_1, tictime: 8, think: T_Chase, action: null, next: null as any };
export const s_sschase3: statetype = { rotate: true, shapenum: SpriteEnum.SPR_SS_W3_1, tictime: 10, think: T_Chase, action: null, next: null as any };
export const s_sschase3s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_SS_W3_1, tictime: 3, think: null, action: null, next: null as any };
export const s_sschase4: statetype = { rotate: true, shapenum: SpriteEnum.SPR_SS_W4_1, tictime: 8, think: T_Chase, action: null, next: null as any };
s_sschase1.next = s_sschase1s; s_sschase1s.next = s_sschase2;
s_sschase2.next = s_sschase3; s_sschase3.next = s_sschase3s;
s_sschase3s.next = s_sschase4; s_sschase4.next = s_sschase1;

export const s_sspain: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SS_PAIN_1, tictime: 10, think: null, action: null, next: null as any };
export const s_sspain1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SS_PAIN_2, tictime: 10, think: null, action: null, next: null as any };
s_sspain.next = s_sschase1; s_sspain1.next = s_sschase1;

// SS shoots a burst of 4 shots
export const s_ssshoot1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SS_SHOOT1, tictime: 20, think: null, action: null, next: null as any };
export const s_ssshoot2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SS_SHOOT2, tictime: 20, think: null, action: T_Shoot, next: null as any };
export const s_ssshoot3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SS_SHOOT3, tictime: 10, think: null, action: null, next: null as any };
export const s_ssshoot4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SS_SHOOT2, tictime: 10, think: null, action: T_Shoot, next: null as any };
export const s_ssshoot5: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SS_SHOOT3, tictime: 10, think: null, action: null, next: null as any };
export const s_ssshoot6: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SS_SHOOT2, tictime: 10, think: null, action: T_Shoot, next: null as any };
export const s_ssshoot7: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SS_SHOOT3, tictime: 10, think: null, action: null, next: null as any };
export const s_ssshoot8: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SS_SHOOT2, tictime: 10, think: null, action: T_Shoot, next: null as any };
export const s_ssshoot9: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SS_SHOOT3, tictime: 10, think: null, action: null, next: null as any };
s_ssshoot1.next = s_ssshoot2; s_ssshoot2.next = s_ssshoot3;
s_ssshoot3.next = s_ssshoot4; s_ssshoot4.next = s_ssshoot5;
s_ssshoot5.next = s_ssshoot6; s_ssshoot6.next = s_ssshoot7;
s_ssshoot7.next = s_ssshoot8; s_ssshoot8.next = s_ssshoot9;
s_ssshoot9.next = s_sschase1;

export const s_ssdie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SS_DIE_1, tictime: 15, think: null, action: A_DeathScream, next: null as any };
export const s_ssdie2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SS_DIE_2, tictime: 15, think: null, action: null, next: null as any };
export const s_ssdie3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SS_DIE_3, tictime: 15, think: null, action: null, next: null as any };
export const s_ssdead: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SS_DEAD, tictime: 0, think: null, action: null, next: null as any };
s_ssdie1.next = s_ssdie2; s_ssdie2.next = s_ssdie3; s_ssdie3.next = s_ssdead;
s_ssdead.next = s_ssdead;

//===========================================================================
// Mutant states
//===========================================================================

export const s_mutstand: statetype = { rotate: true, shapenum: SpriteEnum.SPR_MUT_S_1, tictime: 0, think: T_Stand, action: null, next: null as any };
s_mutstand.next = s_mutstand;

export const s_mutpath1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_MUT_W1_1, tictime: 20, think: T_Path, action: null, next: null as any };
export const s_mutpath1s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_MUT_W1_1, tictime: 5, think: null, action: null, next: null as any };
export const s_mutpath2: statetype = { rotate: true, shapenum: SpriteEnum.SPR_MUT_W2_1, tictime: 15, think: T_Path, action: null, next: null as any };
export const s_mutpath3: statetype = { rotate: true, shapenum: SpriteEnum.SPR_MUT_W3_1, tictime: 20, think: T_Path, action: null, next: null as any };
export const s_mutpath3s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_MUT_W3_1, tictime: 5, think: null, action: null, next: null as any };
export const s_mutpath4: statetype = { rotate: true, shapenum: SpriteEnum.SPR_MUT_W4_1, tictime: 15, think: T_Path, action: null, next: null as any };
s_mutpath1.next = s_mutpath1s; s_mutpath1s.next = s_mutpath2;
s_mutpath2.next = s_mutpath3; s_mutpath3.next = s_mutpath3s;
s_mutpath3s.next = s_mutpath4; s_mutpath4.next = s_mutpath1;

export const s_mutchase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_MUT_W1_1, tictime: 10, think: T_Chase, action: null, next: null as any };
export const s_mutchase1s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_MUT_W1_1, tictime: 3, think: null, action: null, next: null as any };
export const s_mutchase2: statetype = { rotate: true, shapenum: SpriteEnum.SPR_MUT_W2_1, tictime: 8, think: T_Chase, action: null, next: null as any };
export const s_mutchase3: statetype = { rotate: true, shapenum: SpriteEnum.SPR_MUT_W3_1, tictime: 10, think: T_Chase, action: null, next: null as any };
export const s_mutchase3s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_MUT_W3_1, tictime: 3, think: null, action: null, next: null as any };
export const s_mutchase4: statetype = { rotate: true, shapenum: SpriteEnum.SPR_MUT_W4_1, tictime: 8, think: T_Chase, action: null, next: null as any };
s_mutchase1.next = s_mutchase1s; s_mutchase1s.next = s_mutchase2;
s_mutchase2.next = s_mutchase3; s_mutchase3.next = s_mutchase3s;
s_mutchase3s.next = s_mutchase4; s_mutchase4.next = s_mutchase1;

export const s_mutpain: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MUT_PAIN_1, tictime: 10, think: null, action: null, next: null as any };
export const s_mutpain1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MUT_PAIN_2, tictime: 10, think: null, action: null, next: null as any };
s_mutpain.next = s_mutchase1; s_mutpain1.next = s_mutchase1;

// Mutant shoots twice (double shot)
export const s_mutshoot1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MUT_SHOOT1, tictime: 6, think: null, action: T_Shoot, next: null as any };
export const s_mutshoot2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MUT_SHOOT2, tictime: 20, think: null, action: null, next: null as any };
export const s_mutshoot3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MUT_SHOOT3, tictime: 10, think: null, action: T_Shoot, next: null as any };
export const s_mutshoot4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MUT_SHOOT4, tictime: 20, think: null, action: null, next: null as any };
s_mutshoot1.next = s_mutshoot2; s_mutshoot2.next = s_mutshoot3;
s_mutshoot3.next = s_mutshoot4; s_mutshoot4.next = s_mutchase1;

export const s_mutdie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MUT_DIE_1, tictime: 7, think: null, action: A_DeathScream, next: null as any };
export const s_mutdie2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MUT_DIE_2, tictime: 7, think: null, action: null, next: null as any };
export const s_mutdie3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MUT_DIE_3, tictime: 7, think: null, action: null, next: null as any };
export const s_mutdie4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MUT_DIE_4, tictime: 7, think: null, action: null, next: null as any };
export const s_mutdead: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MUT_DEAD, tictime: 0, think: null, action: null, next: null as any };
s_mutdie1.next = s_mutdie2; s_mutdie2.next = s_mutdie3; s_mutdie3.next = s_mutdie4;
s_mutdie4.next = s_mutdead; s_mutdead.next = s_mutdead;

//===========================================================================
// Ghost states
//===========================================================================

export const s_blinkychase1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BLINKY_W1, tictime: 10, think: T_Ghosts, action: null, next: null as any };
export const s_blinkychase2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BLINKY_W2, tictime: 10, think: T_Ghosts, action: null, next: null as any };
s_blinkychase1.next = s_blinkychase2; s_blinkychase2.next = s_blinkychase1;

export const s_inkychase1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_INKY_W1, tictime: 10, think: T_Ghosts, action: null, next: null as any };
export const s_inkychase2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_INKY_W2, tictime: 10, think: T_Ghosts, action: null, next: null as any };
s_inkychase1.next = s_inkychase2; s_inkychase2.next = s_inkychase1;

export const s_pinkychase1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_PINKY_W1, tictime: 10, think: T_Ghosts, action: null, next: null as any };
export const s_pinkychase2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_PINKY_W2, tictime: 10, think: T_Ghosts, action: null, next: null as any };
s_pinkychase1.next = s_pinkychase2; s_pinkychase2.next = s_pinkychase1;

export const s_clydechase1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_CLYDE_W1, tictime: 10, think: T_Ghosts, action: null, next: null as any };
export const s_clydechase2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_CLYDE_W2, tictime: 10, think: T_Ghosts, action: null, next: null as any };
s_clydechase1.next = s_clydechase2; s_clydechase2.next = s_clydechase1;

//===========================================================================
// Hans (Boss) states
//===========================================================================

export const s_bossstand: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BOSS_W1, tictime: 0, think: T_Stand, action: null, next: null as any };
s_bossstand.next = s_bossstand;

export const s_bosschase1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BOSS_W1, tictime: 10, think: T_Chase, action: null, next: null as any };
export const s_bosschase1s: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BOSS_W1, tictime: 3, think: null, action: null, next: null as any };
export const s_bosschase2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BOSS_W2, tictime: 8, think: T_Chase, action: null, next: null as any };
export const s_bosschase3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BOSS_W3, tictime: 10, think: T_Chase, action: null, next: null as any };
export const s_bosschase3s: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BOSS_W3, tictime: 3, think: null, action: null, next: null as any };
export const s_bosschase4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BOSS_W4, tictime: 8, think: T_Chase, action: null, next: null as any };
s_bosschase1.next = s_bosschase1s; s_bosschase1s.next = s_bosschase2;
s_bosschase2.next = s_bosschase3; s_bosschase3.next = s_bosschase3s;
s_bosschase3s.next = s_bosschase4; s_bosschase4.next = s_bosschase1;

export const s_bossshoot1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BOSS_SHOOT1, tictime: 30, think: null, action: null, next: null as any };
export const s_bossshoot2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BOSS_SHOOT2, tictime: 10, think: null, action: T_Shoot, next: null as any };
export const s_bossshoot3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BOSS_SHOOT3, tictime: 10, think: null, action: T_Shoot, next: null as any };
export const s_bossshoot4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BOSS_SHOOT2, tictime: 10, think: null, action: T_Shoot, next: null as any };
export const s_bossshoot5: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BOSS_SHOOT3, tictime: 10, think: null, action: T_Shoot, next: null as any };
export const s_bossshoot6: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BOSS_SHOOT2, tictime: 10, think: null, action: T_Shoot, next: null as any };
export const s_bossshoot7: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BOSS_SHOOT3, tictime: 10, think: null, action: T_Shoot, next: null as any };
export const s_bossshoot8: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BOSS_SHOOT1, tictime: 10, think: null, action: null, next: null as any };
s_bossshoot1.next = s_bossshoot2; s_bossshoot2.next = s_bossshoot3;
s_bossshoot3.next = s_bossshoot4; s_bossshoot4.next = s_bossshoot5;
s_bossshoot5.next = s_bossshoot6; s_bossshoot6.next = s_bossshoot7;
s_bossshoot7.next = s_bossshoot8; s_bossshoot8.next = s_bosschase1;

export const s_bossdie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BOSS_DIE1, tictime: 15, think: null, action: A_DeathScream, next: null as any };
export const s_bossdie2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BOSS_DIE2, tictime: 15, think: null, action: null, next: null as any };
export const s_bossdie3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BOSS_DIE3, tictime: 15, think: null, action: null, next: null as any };
export const s_bossdie4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BOSS_DEAD, tictime: 0, think: null, action: null, next: null as any };
s_bossdie1.next = s_bossdie2; s_bossdie2.next = s_bossdie3; s_bossdie3.next = s_bossdie4;
s_bossdie4.next = s_bossdie4;

//===========================================================================
// Gretel states
//===========================================================================

export const s_gretelstand: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRETEL_W1, tictime: 0, think: T_Stand, action: null, next: null as any };
s_gretelstand.next = s_gretelstand;

export const s_gretelchase1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRETEL_W1, tictime: 10, think: T_Chase, action: null, next: null as any };
export const s_gretelchase1s: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRETEL_W1, tictime: 3, think: null, action: null, next: null as any };
export const s_gretelchase2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRETEL_W2, tictime: 8, think: T_Chase, action: null, next: null as any };
export const s_gretelchase3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRETEL_W3, tictime: 10, think: T_Chase, action: null, next: null as any };
export const s_gretelchase3s: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRETEL_W3, tictime: 3, think: null, action: null, next: null as any };
export const s_gretelchase4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRETEL_W4, tictime: 8, think: T_Chase, action: null, next: null as any };
s_gretelchase1.next = s_gretelchase1s; s_gretelchase1s.next = s_gretelchase2;
s_gretelchase2.next = s_gretelchase3; s_gretelchase3.next = s_gretelchase3s;
s_gretelchase3s.next = s_gretelchase4; s_gretelchase4.next = s_gretelchase1;

export const s_gretelshoot1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRETEL_SHOOT1, tictime: 30, think: null, action: null, next: null as any };
export const s_gretelshoot2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRETEL_SHOOT2, tictime: 10, think: null, action: T_Shoot, next: null as any };
export const s_gretelshoot3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRETEL_SHOOT3, tictime: 10, think: null, action: T_Shoot, next: null as any };
export const s_gretelshoot4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRETEL_SHOOT2, tictime: 10, think: null, action: T_Shoot, next: null as any };
export const s_gretelshoot5: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRETEL_SHOOT3, tictime: 10, think: null, action: T_Shoot, next: null as any };
export const s_gretelshoot6: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRETEL_SHOOT2, tictime: 10, think: null, action: T_Shoot, next: null as any };
export const s_gretelshoot7: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRETEL_SHOOT3, tictime: 10, think: null, action: T_Shoot, next: null as any };
export const s_gretelshoot8: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRETEL_SHOOT1, tictime: 10, think: null, action: null, next: null as any };
s_gretelshoot1.next = s_gretelshoot2; s_gretelshoot2.next = s_gretelshoot3;
s_gretelshoot3.next = s_gretelshoot4; s_gretelshoot4.next = s_gretelshoot5;
s_gretelshoot5.next = s_gretelshoot6; s_gretelshoot6.next = s_gretelshoot7;
s_gretelshoot7.next = s_gretelshoot8; s_gretelshoot8.next = s_gretelchase1;

export const s_greteldie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRETEL_DIE1, tictime: 15, think: null, action: A_DeathScream, next: null as any };
export const s_greteldie2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRETEL_DIE2, tictime: 15, think: null, action: null, next: null as any };
export const s_greteldie3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRETEL_DIE3, tictime: 15, think: null, action: null, next: null as any };
export const s_greteldie4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRETEL_DEAD, tictime: 0, think: null, action: null, next: null as any };
s_greteldie1.next = s_greteldie2; s_greteldie2.next = s_greteldie3; s_greteldie3.next = s_greteldie4;
s_greteldie4.next = s_greteldie4;

//===========================================================================
// Schabbs states
//===========================================================================

export const s_schabbstand: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SCHABB_W1, tictime: 0, think: T_Stand, action: null, next: null as any };
s_schabbstand.next = s_schabbstand;

export const s_schabbchase1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SCHABB_W1, tictime: 10, think: T_Schabb, action: null, next: null as any };
export const s_schabbchase1s: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SCHABB_W1, tictime: 3, think: null, action: null, next: null as any };
export const s_schabbchase2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SCHABB_W2, tictime: 8, think: T_Schabb, action: null, next: null as any };
export const s_schabbchase3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SCHABB_W3, tictime: 10, think: T_Schabb, action: null, next: null as any };
export const s_schabbchase3s: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SCHABB_W3, tictime: 3, think: null, action: null, next: null as any };
export const s_schabbchase4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SCHABB_W4, tictime: 8, think: T_Schabb, action: null, next: null as any };
s_schabbchase1.next = s_schabbchase1s; s_schabbchase1s.next = s_schabbchase2;
s_schabbchase2.next = s_schabbchase3; s_schabbchase3.next = s_schabbchase3s;
s_schabbchase3s.next = s_schabbchase4; s_schabbchase4.next = s_schabbchase1;

export const s_schabbshoot1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SCHABB_SHOOT1, tictime: 30, think: null, action: null, next: null as any };
export const s_schabbshoot2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SCHABB_SHOOT2, tictime: 10, think: null, action: T_SchabbThrow, next: null as any };
s_schabbshoot1.next = s_schabbshoot2; s_schabbshoot2.next = s_schabbchase1;

export const s_schabbdeathcam: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SCHABB_W1, tictime: 1, think: null, action: null, next: null as any };
export const s_schabbdie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SCHABB_W1, tictime: 10, think: null, action: A_DeathScream, next: null as any };
export const s_schabbdie2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SCHABB_W1, tictime: 10, think: null, action: null, next: null as any };
export const s_schabbdie3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SCHABB_DIE1, tictime: 10, think: null, action: null, next: null as any };
export const s_schabbdie4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SCHABB_DIE2, tictime: 10, think: null, action: null, next: null as any };
export const s_schabbdie5: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SCHABB_DIE3, tictime: 10, think: null, action: null, next: null as any };
export const s_schabbdie6: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SCHABB_DEAD, tictime: 20, think: null, action: A_StartDeathCam, next: null as any };
s_schabbdeathcam.next = s_schabbdie1;
s_schabbdie1.next = s_schabbdie2; s_schabbdie2.next = s_schabbdie3;
s_schabbdie3.next = s_schabbdie4; s_schabbdie4.next = s_schabbdie5;
s_schabbdie5.next = s_schabbdie6; s_schabbdie6.next = s_schabbdie6;

//===========================================================================
// Giftmacher states
//===========================================================================

export const s_giftstand: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GIFT_W1, tictime: 0, think: T_Stand, action: null, next: null as any };
s_giftstand.next = s_giftstand;

export const s_giftchase1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GIFT_W1, tictime: 10, think: T_Gift, action: null, next: null as any };
export const s_giftchase1s: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GIFT_W1, tictime: 3, think: null, action: null, next: null as any };
export const s_giftchase2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GIFT_W2, tictime: 8, think: T_Gift, action: null, next: null as any };
export const s_giftchase3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GIFT_W3, tictime: 10, think: T_Gift, action: null, next: null as any };
export const s_giftchase3s: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GIFT_W3, tictime: 3, think: null, action: null, next: null as any };
export const s_giftchase4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GIFT_W4, tictime: 8, think: T_Gift, action: null, next: null as any };
s_giftchase1.next = s_giftchase1s; s_giftchase1s.next = s_giftchase2;
s_giftchase2.next = s_giftchase3; s_giftchase3.next = s_giftchase3s;
s_giftchase3s.next = s_giftchase4; s_giftchase4.next = s_giftchase1;

export const s_giftshoot1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GIFT_SHOOT1, tictime: 30, think: null, action: null, next: null as any };
export const s_giftshoot2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GIFT_SHOOT2, tictime: 10, think: null, action: T_GiftThrow, next: null as any };
s_giftshoot1.next = s_giftshoot2; s_giftshoot2.next = s_giftchase1;

export const s_giftdeathcam: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GIFT_W1, tictime: 1, think: null, action: null, next: null as any };
export const s_giftdie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GIFT_W1, tictime: 1, think: null, action: A_DeathScream, next: null as any };
export const s_giftdie2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GIFT_W1, tictime: 10, think: null, action: null, next: null as any };
export const s_giftdie3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GIFT_DIE1, tictime: 10, think: null, action: null, next: null as any };
export const s_giftdie4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GIFT_DIE2, tictime: 10, think: null, action: null, next: null as any };
export const s_giftdie5: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GIFT_DIE3, tictime: 10, think: null, action: null, next: null as any };
export const s_giftdie6: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GIFT_DEAD, tictime: 20, think: null, action: A_StartDeathCam, next: null as any };
s_giftdeathcam.next = s_giftdie1;
s_giftdie1.next = s_giftdie2; s_giftdie2.next = s_giftdie3;
s_giftdie3.next = s_giftdie4; s_giftdie4.next = s_giftdie5;
s_giftdie5.next = s_giftdie6; s_giftdie6.next = s_giftdie6;

//===========================================================================
// Fat Face states
//===========================================================================

export const s_fatstand: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAT_W1, tictime: 0, think: T_Stand, action: null, next: null as any };
s_fatstand.next = s_fatstand;

export const s_fatchase1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAT_W1, tictime: 10, think: T_Fat, action: null, next: null as any };
export const s_fatchase1s: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAT_W1, tictime: 3, think: null, action: null, next: null as any };
export const s_fatchase2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAT_W2, tictime: 8, think: T_Fat, action: null, next: null as any };
export const s_fatchase3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAT_W3, tictime: 10, think: T_Fat, action: null, next: null as any };
export const s_fatchase3s: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAT_W3, tictime: 3, think: null, action: null, next: null as any };
export const s_fatchase4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAT_W4, tictime: 8, think: T_Fat, action: null, next: null as any };
s_fatchase1.next = s_fatchase1s; s_fatchase1s.next = s_fatchase2;
s_fatchase2.next = s_fatchase3; s_fatchase3.next = s_fatchase3s;
s_fatchase3s.next = s_fatchase4; s_fatchase4.next = s_fatchase1;

// Fat shoots a rocket then fires bullets
export const s_fatshoot1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAT_SHOOT1, tictime: 30, think: null, action: null, next: null as any };
export const s_fatshoot2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAT_SHOOT2, tictime: 10, think: null, action: T_GiftThrow, next: null as any };
export const s_fatshoot3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAT_SHOOT3, tictime: 10, think: null, action: T_Shoot, next: null as any };
export const s_fatshoot4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAT_SHOOT4, tictime: 10, think: null, action: T_Shoot, next: null as any };
export const s_fatshoot5: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAT_SHOOT3, tictime: 10, think: null, action: T_Shoot, next: null as any };
export const s_fatshoot6: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAT_SHOOT4, tictime: 10, think: null, action: T_Shoot, next: null as any };
s_fatshoot1.next = s_fatshoot2; s_fatshoot2.next = s_fatshoot3;
s_fatshoot3.next = s_fatshoot4; s_fatshoot4.next = s_fatshoot5;
s_fatshoot5.next = s_fatshoot6; s_fatshoot6.next = s_fatchase1;

export const s_fatdeathcam: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAT_W1, tictime: 1, think: null, action: null, next: null as any };
export const s_fatdie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAT_W1, tictime: 1, think: null, action: A_DeathScream, next: null as any };
export const s_fatdie2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAT_W1, tictime: 10, think: null, action: null, next: null as any };
export const s_fatdie3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAT_DIE1, tictime: 10, think: null, action: null, next: null as any };
export const s_fatdie4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAT_DIE2, tictime: 10, think: null, action: null, next: null as any };
export const s_fatdie5: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAT_DIE3, tictime: 10, think: null, action: null, next: null as any };
export const s_fatdie6: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAT_DEAD, tictime: 20, think: null, action: A_StartDeathCam, next: null as any };
s_fatdeathcam.next = s_fatdie1;
s_fatdie1.next = s_fatdie2; s_fatdie2.next = s_fatdie3;
s_fatdie3.next = s_fatdie4; s_fatdie4.next = s_fatdie5;
s_fatdie5.next = s_fatdie6; s_fatdie6.next = s_fatdie6;

//===========================================================================
// Fake Hitler states (fire breathing)
//===========================================================================

export const s_fakestand: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAKE_W1, tictime: 0, think: T_Stand, action: null, next: null as any };
s_fakestand.next = s_fakestand;

export const s_fakechase1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAKE_W1, tictime: 10, think: T_Fake, action: null, next: null as any };
export const s_fakechase1s: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAKE_W1, tictime: 3, think: null, action: null, next: null as any };
export const s_fakechase2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAKE_W2, tictime: 8, think: T_Fake, action: null, next: null as any };
export const s_fakechase3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAKE_W3, tictime: 10, think: T_Fake, action: null, next: null as any };
export const s_fakechase3s: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAKE_W3, tictime: 3, think: null, action: null, next: null as any };
export const s_fakechase4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAKE_W4, tictime: 8, think: T_Fake, action: null, next: null as any };
s_fakechase1.next = s_fakechase1s; s_fakechase1s.next = s_fakechase2;
s_fakechase2.next = s_fakechase3; s_fakechase3.next = s_fakechase3s;
s_fakechase3s.next = s_fakechase4; s_fakechase4.next = s_fakechase1;

// Fake Hitler shoots 9 frames of fire
export const s_fakeshoot1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAKE_SHOOT, tictime: 8, think: null, action: T_FakeFire, next: null as any };
export const s_fakeshoot2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAKE_SHOOT, tictime: 8, think: null, action: T_FakeFire, next: null as any };
export const s_fakeshoot3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAKE_SHOOT, tictime: 8, think: null, action: T_FakeFire, next: null as any };
export const s_fakeshoot4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAKE_SHOOT, tictime: 8, think: null, action: T_FakeFire, next: null as any };
export const s_fakeshoot5: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAKE_SHOOT, tictime: 8, think: null, action: T_FakeFire, next: null as any };
export const s_fakeshoot6: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAKE_SHOOT, tictime: 8, think: null, action: T_FakeFire, next: null as any };
export const s_fakeshoot7: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAKE_SHOOT, tictime: 8, think: null, action: T_FakeFire, next: null as any };
export const s_fakeshoot8: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAKE_SHOOT, tictime: 8, think: null, action: T_FakeFire, next: null as any };
export const s_fakeshoot9: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAKE_SHOOT, tictime: 8, think: null, action: null, next: null as any };
s_fakeshoot1.next = s_fakeshoot2; s_fakeshoot2.next = s_fakeshoot3;
s_fakeshoot3.next = s_fakeshoot4; s_fakeshoot4.next = s_fakeshoot5;
s_fakeshoot5.next = s_fakeshoot6; s_fakeshoot6.next = s_fakeshoot7;
s_fakeshoot7.next = s_fakeshoot8; s_fakeshoot8.next = s_fakeshoot9;
s_fakeshoot9.next = s_fakechase1;

export const s_fakedie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAKE_DIE1, tictime: 10, think: null, action: A_DeathScream, next: null as any };
export const s_fakedie2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAKE_DIE2, tictime: 10, think: null, action: null, next: null as any };
export const s_fakedie3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAKE_DIE3, tictime: 10, think: null, action: null, next: null as any };
export const s_fakedie4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAKE_DIE4, tictime: 10, think: null, action: null, next: null as any };
export const s_fakedie5: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAKE_DIE5, tictime: 10, think: null, action: null, next: null as any };
export const s_fakedie6: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAKE_DEAD, tictime: 0, think: null, action: null, next: null as any };
s_fakedie1.next = s_fakedie2; s_fakedie2.next = s_fakedie3;
s_fakedie3.next = s_fakedie4; s_fakedie4.next = s_fakedie5;
s_fakedie5.next = s_fakedie6; s_fakedie6.next = s_fakedie6;

//===========================================================================
// Mecha Hitler states
//===========================================================================

export const s_mechastand: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MECHA_W1, tictime: 0, think: T_Stand, action: null, next: null as any };
s_mechastand.next = s_mechastand;

export const s_mechachase1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MECHA_W1, tictime: 10, think: T_Chase, action: A_MechaSound, next: null as any };
export const s_mechachase1s: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MECHA_W1, tictime: 6, think: null, action: null, next: null as any };
export const s_mechachase2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MECHA_W2, tictime: 8, think: T_Chase, action: null, next: null as any };
export const s_mechachase3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MECHA_W3, tictime: 10, think: T_Chase, action: A_MechaSound, next: null as any };
export const s_mechachase3s: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MECHA_W3, tictime: 6, think: null, action: null, next: null as any };
export const s_mechachase4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MECHA_W4, tictime: 8, think: T_Chase, action: null, next: null as any };
s_mechachase1.next = s_mechachase1s; s_mechachase1s.next = s_mechachase2;
s_mechachase2.next = s_mechachase3; s_mechachase3.next = s_mechachase3s;
s_mechachase3s.next = s_mechachase4; s_mechachase4.next = s_mechachase1;

export const s_mechashoot1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MECHA_SHOOT1, tictime: 30, think: null, action: null, next: null as any };
export const s_mechashoot2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MECHA_SHOOT2, tictime: 10, think: null, action: T_Shoot, next: null as any };
export const s_mechashoot3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MECHA_SHOOT3, tictime: 10, think: null, action: T_Shoot, next: null as any };
export const s_mechashoot4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MECHA_SHOOT2, tictime: 10, think: null, action: T_Shoot, next: null as any };
export const s_mechashoot5: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MECHA_SHOOT3, tictime: 10, think: null, action: T_Shoot, next: null as any };
export const s_mechashoot6: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MECHA_SHOOT2, tictime: 10, think: null, action: T_Shoot, next: null as any };
s_mechashoot1.next = s_mechashoot2; s_mechashoot2.next = s_mechashoot3;
s_mechashoot3.next = s_mechashoot4; s_mechashoot4.next = s_mechashoot5;
s_mechashoot5.next = s_mechashoot6; s_mechashoot6.next = s_mechachase1;

export const s_mechadie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MECHA_DIE1, tictime: 10, think: null, action: A_DeathScream, next: null as any };
export const s_mechadie2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MECHA_DIE2, tictime: 10, think: null, action: null, next: null as any };
export const s_mechadie3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MECHA_DIE3, tictime: 10, think: null, action: A_HitlerMorph, next: null as any };
export const s_mechadie4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MECHA_DEAD, tictime: 0, think: null, action: null, next: null as any };
s_mechadie1.next = s_mechadie2; s_mechadie2.next = s_mechadie3;
s_mechadie3.next = s_mechadie4; s_mechadie4.next = s_mechadie4;

//===========================================================================
// Real Hitler states
//===========================================================================

export const s_hitlerchase1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HITLER_W1, tictime: 6, think: T_Chase, action: null, next: null as any };
export const s_hitlerchase1s: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HITLER_W1, tictime: 4, think: null, action: null, next: null as any };
export const s_hitlerchase2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HITLER_W2, tictime: 2, think: T_Chase, action: null, next: null as any };
export const s_hitlerchase3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HITLER_W3, tictime: 6, think: T_Chase, action: null, next: null as any };
export const s_hitlerchase3s: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HITLER_W3, tictime: 4, think: null, action: null, next: null as any };
export const s_hitlerchase4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HITLER_W4, tictime: 2, think: T_Chase, action: null, next: null as any };
s_hitlerchase1.next = s_hitlerchase1s; s_hitlerchase1s.next = s_hitlerchase2;
s_hitlerchase2.next = s_hitlerchase3; s_hitlerchase3.next = s_hitlerchase3s;
s_hitlerchase3s.next = s_hitlerchase4; s_hitlerchase4.next = s_hitlerchase1;

export const s_hitlershoot1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HITLER_SHOOT1, tictime: 30, think: null, action: null, next: null as any };
export const s_hitlershoot2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HITLER_SHOOT2, tictime: 10, think: null, action: T_Shoot, next: null as any };
export const s_hitlershoot3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HITLER_SHOOT3, tictime: 10, think: null, action: T_Shoot, next: null as any };
export const s_hitlershoot4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HITLER_SHOOT2, tictime: 10, think: null, action: T_Shoot, next: null as any };
export const s_hitlershoot5: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HITLER_SHOOT3, tictime: 10, think: null, action: T_Shoot, next: null as any };
export const s_hitlershoot6: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HITLER_SHOOT2, tictime: 10, think: null, action: T_Shoot, next: null as any };
s_hitlershoot1.next = s_hitlershoot2; s_hitlershoot2.next = s_hitlershoot3;
s_hitlershoot3.next = s_hitlershoot4; s_hitlershoot4.next = s_hitlershoot5;
s_hitlershoot5.next = s_hitlershoot6; s_hitlershoot6.next = s_hitlerchase1;

export const s_hitlerdeathcam: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HITLER_W1, tictime: 10, think: null, action: null, next: null as any };
export const s_hitlerdie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HITLER_W1, tictime: 1, think: null, action: A_DeathScream, next: null as any };
export const s_hitlerdie2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HITLER_W1, tictime: 10, think: null, action: null, next: null as any };
export const s_hitlerdie3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HITLER_DIE1, tictime: 10, think: null, action: A_Slurpie, next: null as any };
export const s_hitlerdie4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HITLER_DIE2, tictime: 10, think: null, action: null, next: null as any };
export const s_hitlerdie5: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HITLER_DIE3, tictime: 10, think: null, action: null, next: null as any };
export const s_hitlerdie6: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HITLER_DIE4, tictime: 10, think: null, action: null, next: null as any };
export const s_hitlerdie7: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HITLER_DIE5, tictime: 10, think: null, action: null, next: null as any };
export const s_hitlerdie8: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HITLER_DIE6, tictime: 10, think: null, action: null, next: null as any };
export const s_hitlerdie9: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HITLER_DIE7, tictime: 10, think: null, action: null, next: null as any };
export const s_hitlerdie10: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HITLER_DEAD, tictime: 20, think: null, action: A_StartDeathCam, next: null as any };
s_hitlerdeathcam.next = s_hitlerdie1;
s_hitlerdie1.next = s_hitlerdie2; s_hitlerdie2.next = s_hitlerdie3;
s_hitlerdie3.next = s_hitlerdie4; s_hitlerdie4.next = s_hitlerdie5;
s_hitlerdie5.next = s_hitlerdie6; s_hitlerdie6.next = s_hitlerdie7;
s_hitlerdie7.next = s_hitlerdie8; s_hitlerdie8.next = s_hitlerdie9;
s_hitlerdie9.next = s_hitlerdie10; s_hitlerdie10.next = s_hitlerdie10;

//===========================================================================
// Spectre (SoD-era placeholder, uses ghost-like behavior)
//===========================================================================

export const s_spectrechase1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BLINKY_W1, tictime: 10, think: T_Ghosts, action: null, next: null as any };
export const s_spectrechase2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BLINKY_W2, tictime: 10, think: T_Ghosts, action: null, next: null as any };
s_spectrechase1.next = s_spectrechase2; s_spectrechase2.next = s_spectrechase1;
export const s_spectredie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BLINKY_W1, tictime: 15, think: null, action: null, next: null as any };
s_spectredie1.next = s_spectredie1;

//===========================================================================
// Spear of Destiny bosses - placeholder states (SPR_BLINKY_W1 sprites)
// These are SoD-exclusive and the Wolf3D sprite set doesn't include them,
// but the state references are needed for the spawn functions.
//===========================================================================

export const s_angelchase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_BLINKY_W1, tictime: 10, think: T_Chase, action: null, next: null as any };
export const s_angeldie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BLINKY_W1, tictime: 15, think: null, action: null, next: null as any };
s_angelchase1.next = s_angelchase1; s_angeldie1.next = s_angeldie1;

export const s_transchase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_BLINKY_W1, tictime: 10, think: T_Chase, action: null, next: null as any };
export const s_transdie0: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BLINKY_W1, tictime: 15, think: null, action: null, next: null as any };
s_transchase1.next = s_transchase1; s_transdie0.next = s_transdie0;

export const s_uberchase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_BLINKY_W1, tictime: 10, think: T_Chase, action: null, next: null as any };
export const s_uberdie0: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BLINKY_W1, tictime: 15, think: null, action: null, next: null as any };
s_uberchase1.next = s_uberchase1; s_uberdie0.next = s_uberdie0;

export const s_willchase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_BLINKY_W1, tictime: 10, think: T_Chase, action: null, next: null as any };
export const s_willdie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BLINKY_W1, tictime: 15, think: null, action: null, next: null as any };
s_willchase1.next = s_willchase1; s_willdie1.next = s_willdie1;

export const s_deathchase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_BLINKY_W1, tictime: 10, think: T_Chase, action: null, next: null as any };
export const s_deathdie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BLINKY_W1, tictime: 15, think: null, action: null, next: null as any };
s_deathchase1.next = s_deathchase1; s_deathdie1.next = s_deathdie1;

//===========================================================================
// BJ / deathcam states
//===========================================================================

export const s_deathcam: statetype = { rotate: false, shapenum: SpriteEnum.SPR_DEATHCAM, tictime: 0, think: null, action: null, next: null };

export const s_schabbdeathcam2: statetype = { rotate: false, shapenum: 0, tictime: 0, think: null, action: null, next: null };
export const s_hitlerdeathcam2: statetype = { rotate: false, shapenum: 0, tictime: 0, think: null, action: null, next: null };
export const s_giftdeathcam2: statetype = { rotate: false, shapenum: 0, tictime: 0, think: null, action: null, next: null };
export const s_fatdeathcam2: statetype = { rotate: false, shapenum: 0, tictime: 0, think: null, action: null, next: null };

//===========================================================================
// Spawn functions
//===========================================================================

const starthitpoints: number[][] = [
    // Baby
    [25, 50, 100, 1, 850, 850, 200, 800, 45, 25, 25, 25, 25, 850, 850, 850, 5, 1450, 850, 1050, 950, 1250],
    // Don't hurt me
    [25, 50, 100, 1, 950, 950, 300, 950, 55, 25, 25, 25, 25, 950, 950, 950, 10, 1550, 950, 1150, 1050, 1350],
    // Bring 'em on
    [25, 50, 100, 1, 1050, 1550, 400, 1050, 55, 25, 25, 25, 25, 1050, 1050, 1050, 15, 1650, 1050, 1250, 1150, 1450],
    // Death incarnate
    [25, 50, 100, 1, 1200, 2400, 500, 1200, 65, 25, 25, 25, 25, 1200, 1200, 1200, 25, 2000, 1200, 1400, 1300, 1600],
];

const stateForEnemy: Record<number, { stand: statetype; path: statetype; chase: statetype; speed: number }> = {
    [enemy_t.en_guard]:   { stand: s_grdstand, path: s_grdpath1, chase: s_grdchase1, speed: SPDPATROL },
    [enemy_t.en_officer]: { stand: s_ofcstand, path: s_ofcpath1, chase: s_ofcchase1, speed: SPDPATROL },
    [enemy_t.en_ss]:      { stand: s_ssstand,  path: s_sspath1,  chase: s_sschase1,  speed: SPDPATROL },
    [enemy_t.en_dog]:     { stand: s_dogpath1, path: s_dogpath1, chase: s_dogchase1, speed: SPDDOG },
    [enemy_t.en_mutant]:  { stand: s_mutstand, path: s_mutpath1, chase: s_mutchase1, speed: SPDPATROL },
};

export function SpawnStand(which: enemy_t, tilex: number, tiley: number, dir: number): void {
    const info = stateForEnemy[which];
    if (!info) return;

    SpawnNewObj(tilex, tiley, info.stand);
    const ob = lastObj();
    if (!ob) return;

    ob.obclass = enemyToClass(which);
    ob.hitpoints = starthitpoints[gamestate.difficulty]?.[which] ?? 25;
    ob.dir = (dir * 2) as dirtype;
    ob.flags |= FL_SHOOTABLE;
    ob.speed = info.speed;

    if (!loadedGameFlag()) gamestate.killtotal++;
}

export function SpawnPatrol(which: enemy_t, tilex: number, tiley: number, dir: number): void {
    const info = stateForEnemy[which];
    if (!info) return;

    SpawnNewObj(tilex, tiley, info.path);
    const ob = lastObj();
    if (!ob) return;

    ob.obclass = enemyToClass(which);
    ob.hitpoints = starthitpoints[gamestate.difficulty]?.[which] ?? 25;
    ob.dir = (dir * 2) as dirtype;
    ob.flags |= FL_SHOOTABLE;
    ob.speed = info.speed;
    ob.distance = TILEGLOBAL;
    ob.active = activetype.ac_yes;

    if (!loadedGameFlag()) gamestate.killtotal++;
}

export function SpawnDeadGuard(tilex: number, tiley: number): void {
    SpawnNewObj(tilex, tiley, s_grddie4);
    const ob = lastObj();
    if (ob) ob.obclass = classtype.inertobj;
}

export function SpawnBoss(tilex: number, tiley: number): void {
    SpawnNewObj(tilex, tiley, s_bossstand);
    const ob = lastObj();
    if (!ob) return;
    ob.obclass = classtype.bossobj;
    ob.hitpoints = starthitpoints[gamestate.difficulty]?.[enemy_t.en_boss] ?? 850;
    ob.dir = dirtype.south;
    ob.flags |= FL_SHOOTABLE | FL_AMBUSH;
    ob.speed = SPDPATROL;
    if (!loadedGameFlag()) gamestate.killtotal++;
}

export function SpawnGretel(tilex: number, tiley: number): void {
    SpawnNewObj(tilex, tiley, s_gretelstand);
    const ob = lastObj();
    if (!ob) return;
    ob.obclass = classtype.gretelobj;
    ob.hitpoints = starthitpoints[gamestate.difficulty]?.[enemy_t.en_gretel] ?? 850;
    ob.dir = dirtype.north;
    ob.flags |= FL_SHOOTABLE | FL_AMBUSH;
    ob.speed = SPDPATROL;
    if (!loadedGameFlag()) gamestate.killtotal++;
}

export function SpawnSchabbs(tilex: number, tiley: number): void {
    SpawnBossGeneric(tilex, tiley, classtype.schabbobj, s_schabbstand, enemy_t.en_schabbs);
}

export function SpawnGift(tilex: number, tiley: number): void {
    SpawnBossGeneric(tilex, tiley, classtype.giftobj, s_giftstand, enemy_t.en_gift);
}

export function SpawnFat(tilex: number, tiley: number): void {
    SpawnBossGeneric(tilex, tiley, classtype.fatobj, s_fatstand, enemy_t.en_fat);
}

export function SpawnFakeHitler(tilex: number, tiley: number): void {
    SpawnBossGeneric(tilex, tiley, classtype.fakeobj, s_fakestand, enemy_t.en_fake);
}

export function SpawnHitler(tilex: number, tiley: number): void {
    SpawnBossGeneric(tilex, tiley, classtype.mechahitlerobj, s_mechastand, enemy_t.en_hitler);
}

export function SpawnTrans(tilex: number, tiley: number): void {
    SpawnBossGeneric(tilex, tiley, classtype.transobj, s_transchase1, enemy_t.en_trans);
}

export function SpawnUber(tilex: number, tiley: number): void {
    SpawnBossGeneric(tilex, tiley, classtype.uberobj, s_uberchase1, enemy_t.en_uber);
}

export function SpawnWill(tilex: number, tiley: number): void {
    SpawnBossGeneric(tilex, tiley, classtype.willobj, s_willchase1, enemy_t.en_will);
}

export function SpawnDeath(tilex: number, tiley: number): void {
    SpawnBossGeneric(tilex, tiley, classtype.deathobj, s_deathchase1, enemy_t.en_death);
}

export function SpawnAngel(tilex: number, tiley: number): void {
    SpawnBossGeneric(tilex, tiley, classtype.angelobj, s_angelchase1, enemy_t.en_angel);
}

export function SpawnSpectre(tilex: number, tiley: number): void {
    SpawnBossGeneric(tilex, tiley, classtype.spectreobj, s_spectrechase1, enemy_t.en_spectre);
}

export function SpawnGhosts(which: number, tilex: number, tiley: number): void {
    SpawnNewObj(tilex, tiley, s_blinkychase1);
    const ob = lastObj();
    if (!ob) return;
    ob.obclass = classtype.ghostobj;
    ob.hitpoints = 99999;
    ob.speed = SPDPATROL * 3;
    ob.flags |= FL_AMBUSH;
    if (!loadedGameFlag()) gamestate.killtotal++;
}

function SpawnBossGeneric(tilex: number, tiley: number, cls: classtype, state: statetype, enemyType: enemy_t): void {
    SpawnNewObj(tilex, tiley, state);
    const ob = lastObj();
    if (!ob) return;
    ob.obclass = cls;
    ob.hitpoints = starthitpoints[gamestate.difficulty]?.[enemyType] ?? 850;
    ob.flags |= FL_SHOOTABLE | FL_AMBUSH;
    ob.speed = SPDPATROL;
    if (!loadedGameFlag()) gamestate.killtotal++;
}

export function SpawnBJVictory(): void {
    SpawnNewObj(0, 0, s_deathcam);
    const ob = lastObj();
    if (ob) ob.obclass = classtype.bjobj;
}

export function A_DeathScream(ob: objtype): void {
    switch (ob.obclass) {
        case classtype.guardobj: SD.SD_PlaySound(soundnames.DEATHSCREAM1SND); break;
        case classtype.officerobj: SD.SD_PlaySound(soundnames.DEATHSCREAM2SND); break;
        case classtype.ssobj: SD.SD_PlaySound(soundnames.DEATHSCREAM3SND); break;
        case classtype.dogobj: SD.SD_PlaySound(soundnames.DOGDEATHSND); break;
        case classtype.mutantobj: SD.SD_PlaySound(soundnames.DEATHSCREAM2SND); break;
        case classtype.bossobj: SD.SD_PlaySound(soundnames.NAZIFIRESND); break;
        case classtype.schabbobj: SD.SD_PlaySound(soundnames.BOSSFIRESND); break;
        case classtype.fakeobj: SD.SD_PlaySound(soundnames.DEATHSCREAM1SND); break;
        case classtype.mechahitlerobj: SD.SD_PlaySound(soundnames.DEATHSCREAM5SND); break;
        case classtype.realhitlerobj: SD.SD_PlaySound(soundnames.DEATHSCREAM5SND); break;
        case classtype.gretelobj: SD.SD_PlaySound(soundnames.NAZIFIRESND); break;
        case classtype.giftobj: SD.SD_PlaySound(soundnames.BOSSFIRESND); break;
        case classtype.fatobj: SD.SD_PlaySound(soundnames.BOSSFIRESND); break;
        default: SD.SD_PlaySound(soundnames.DEATHSCREAM1SND); break;
    }
}

export function KillActor(ob: objtype): void {
    // Delegated to wl_state.ts KillActor
}

// Helper to get the last spawned object
function lastObj(): objtype | null {
    return lastobj;
}

function enemyToClass(which: enemy_t): classtype {
    switch (which) {
        case enemy_t.en_guard: return classtype.guardobj;
        case enemy_t.en_officer: return classtype.officerobj;
        case enemy_t.en_ss: return classtype.ssobj;
        case enemy_t.en_dog: return classtype.dogobj;
        case enemy_t.en_mutant: return classtype.mutantobj;
        case enemy_t.en_boss: return classtype.bossobj;
        default: return classtype.guardobj;
    }
}

function loadedGameFlag(): boolean {
    return false;  // simplified; will be updated when save/load is implemented
}
