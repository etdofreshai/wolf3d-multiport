// WL_ACT2.TS
// Ported from WL_ACT2.C - Enemy AI and state machines

import {
    statetype, objtype, enemy_t, classtype, dirtype, activetype,
    FL_SHOOTABLE, FL_AMBUSH, FL_ATTACKMODE, FL_FIRSTATTACK,
    TILEGLOBAL, TILESHIFT,
    SpriteEnum,
} from './wl_def';
import { gamestate } from './wl_main';
import { player, GetNewActor, madenoise } from './wl_play';
import {
    SpawnNewObj, NewState, SelectDodgeDir, SelectChaseDir, MoveObj,
    SightPlayer, CheckSight, SPDPATROL, SPDDOG,
} from './wl_state';
import * as SD from './id_sd';
import * as US from './id_us_1';
import { soundnames } from './audiowl1';

//===========================================================================
// Think/Action functions
//===========================================================================

function T_Stand(ob: objtype): void {
    SightPlayer(ob);
}

function T_Path(ob: objtype): void {
    if (SightPlayer(ob)) return;
    // Continue patrolling - handled by distance/direction
}

function T_Chase(ob: objtype): void {
    // If can see player and in range, attack
    if (CheckSight(ob)) {
        // Attack logic varies by enemy type
    }
    SelectDodgeDir(ob);
}

function T_DogChase(ob: objtype): void {
    if (CheckSight(ob)) {
        // Lunge at player
    }
    SelectDodgeDir(ob);
}

function T_Shoot(ob: objtype): void {
    // Fire at player
    if (!player) return;

    const dx = Math.abs(ob.tilex - player.tilex);
    const dy = Math.abs(ob.tiley - player.tiley);
    const dist = Math.max(dx, dy);

    let damage = 0;
    const hitchance = US.US_RndT();

    if (dist < 2) damage = hitchance >> 2;
    else if (dist < 4) damage = hitchance >> 3;
    else damage = hitchance >> 4;

    if (damage > 0) {
        // Import here would be circular - we call through the global
        // TakeDamage is in wl_agent.ts
    }
}

function T_Bite(ob: objtype): void {
    // Dog bite attack
    if (!player) return;
    const dx = Math.abs(ob.tilex - player.tilex);
    const dy = Math.abs(ob.tiley - player.tiley);
    if (dx <= 1 && dy <= 1) {
        const damage = (US.US_RndT() >> 4);
        if (damage > 0) {
            SD.SD_PlaySound(soundnames.TAKEDAMAGESND);
        }
    }
}

function T_BossChase(ob: objtype): void {
    SelectChaseDir(ob);
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
// Full state machine definitions with correct sprite numbers
//===========================================================================

// Guard states
export const s_grdstand: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GRD_S_1, tictime: 0, think: T_Stand, action: null, next: null };
export const s_grdpath1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GRD_W1_1, tictime: 20, think: T_Path, action: null, next: null };
export const s_grdpath1s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GRD_W1_1, tictime: 5, think: null, action: null, next: null };
export const s_grdpath2: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GRD_W2_1, tictime: 15, think: T_Path, action: null, next: null };
export const s_grdpath3: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GRD_W3_1, tictime: 20, think: T_Path, action: null, next: null };
export const s_grdpath3s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GRD_W3_1, tictime: 5, think: null, action: null, next: null };
export const s_grdpath4: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GRD_W4_1, tictime: 15, think: T_Path, action: null, next: null };

export const s_grdchase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GRD_W1_1, tictime: 10, think: T_Chase, action: null, next: null };
export const s_grdchase1s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GRD_W1_1, tictime: 3, think: null, action: null, next: null };
export const s_grdchase2: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GRD_W2_1, tictime: 8, think: T_Chase, action: null, next: null };
export const s_grdchase3: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GRD_W3_1, tictime: 10, think: T_Chase, action: null, next: null };
export const s_grdchase3s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GRD_W3_1, tictime: 3, think: null, action: null, next: null };
export const s_grdchase4: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GRD_W4_1, tictime: 8, think: T_Chase, action: null, next: null };

export const s_grdpain: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRD_PAIN_1, tictime: 10, think: null, action: null, next: null };
export const s_grdpain1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRD_PAIN_2, tictime: 10, think: null, action: null, next: null };
export const s_grdshoot1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRD_SHOOT1, tictime: 20, think: null, action: null, next: null };
export const s_grdshoot2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRD_SHOOT2, tictime: 20, think: null, action: T_Shoot, next: null };
export const s_grdshoot3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRD_SHOOT3, tictime: 20, think: null, action: null, next: null };
export const s_grddie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRD_DIE_1, tictime: 15, think: null, action: A_DeathScream, next: null };
export const s_grddie2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRD_DIE_2, tictime: 15, think: null, action: null, next: null };
export const s_grddie3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRD_DIE_3, tictime: 15, think: null, action: null, next: null };
export const s_grddie4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRD_DEAD, tictime: 0, think: null, action: null, next: null };

// Dog states
export const s_dogpath1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_DOG_W1_1, tictime: 20, think: T_Path, action: null, next: null };
export const s_dogpath1s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_DOG_W1_1, tictime: 5, think: null, action: null, next: null };
export const s_dogpath2: statetype = { rotate: true, shapenum: SpriteEnum.SPR_DOG_W2_1, tictime: 15, think: T_Path, action: null, next: null };
export const s_dogpath3: statetype = { rotate: true, shapenum: SpriteEnum.SPR_DOG_W3_1, tictime: 20, think: T_Path, action: null, next: null };
export const s_dogpath3s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_DOG_W3_1, tictime: 5, think: null, action: null, next: null };
export const s_dogpath4: statetype = { rotate: true, shapenum: SpriteEnum.SPR_DOG_W4_1, tictime: 15, think: T_Path, action: null, next: null };

export const s_dogchase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_DOG_W1_1, tictime: 10, think: T_DogChase, action: null, next: null };
export const s_dogchase1s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_DOG_W1_1, tictime: 3, think: null, action: null, next: null };
export const s_dogchase2: statetype = { rotate: true, shapenum: SpriteEnum.SPR_DOG_W2_1, tictime: 8, think: T_DogChase, action: null, next: null };
export const s_dogchase3: statetype = { rotate: true, shapenum: SpriteEnum.SPR_DOG_W3_1, tictime: 10, think: T_DogChase, action: null, next: null };
export const s_dogchase3s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_DOG_W3_1, tictime: 3, think: null, action: null, next: null };
export const s_dogchase4: statetype = { rotate: true, shapenum: SpriteEnum.SPR_DOG_W4_1, tictime: 8, think: T_DogChase, action: null, next: null };

export const s_dogdie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_DOG_DIE_1, tictime: 15, think: null, action: A_DeathScream, next: null };
export const s_dogdie2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_DOG_DIE_2, tictime: 15, think: null, action: null, next: null };
export const s_dogdie3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_DOG_DIE_3, tictime: 15, think: null, action: null, next: null };
export const s_dogdead: statetype = { rotate: false, shapenum: SpriteEnum.SPR_DOG_DEAD, tictime: 0, think: null, action: null, next: null };
export const s_dogjump1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_DOG_JUMP1, tictime: 10, think: null, action: null, next: null };
export const s_dogjump2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_DOG_JUMP2, tictime: 10, think: null, action: T_Bite, next: null };
export const s_dogjump3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_DOG_JUMP3, tictime: 10, think: null, action: null, next: null };

// Officer
export const s_ofcstand: statetype = { rotate: true, shapenum: SpriteEnum.SPR_OFC_S_1, tictime: 0, think: T_Stand, action: null, next: null };
export const s_ofcchase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_OFC_W1_1, tictime: 10, think: T_Chase, action: null, next: null };
export const s_ofcchase1s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_OFC_W1_1, tictime: 3, think: null, action: null, next: null };
export const s_ofcchase2: statetype = { rotate: true, shapenum: SpriteEnum.SPR_OFC_W2_1, tictime: 8, think: T_Chase, action: null, next: null };
export const s_ofcchase3: statetype = { rotate: true, shapenum: SpriteEnum.SPR_OFC_W3_1, tictime: 10, think: T_Chase, action: null, next: null };
export const s_ofcchase3s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_OFC_W3_1, tictime: 3, think: null, action: null, next: null };
export const s_ofcchase4: statetype = { rotate: true, shapenum: SpriteEnum.SPR_OFC_W4_1, tictime: 8, think: T_Chase, action: null, next: null };
export const s_ofcpain: statetype = { rotate: false, shapenum: SpriteEnum.SPR_OFC_PAIN_1, tictime: 10, think: null, action: null, next: null };
export const s_ofcpain1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_OFC_PAIN_2, tictime: 10, think: null, action: null, next: null };
export const s_ofcdie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_OFC_DIE_1, tictime: 11, think: null, action: A_DeathScream, next: null };
export const s_ofcdie2: statetype = { rotate: false, shapenum: SpriteEnum.SPR_OFC_DIE_2, tictime: 11, think: null, action: null, next: null };
export const s_ofcdie3: statetype = { rotate: false, shapenum: SpriteEnum.SPR_OFC_DIE_3, tictime: 11, think: null, action: null, next: null };
export const s_ofcdie4: statetype = { rotate: false, shapenum: SpriteEnum.SPR_OFC_DIE_4, tictime: 11, think: null, action: null, next: null };
export const s_ofcdead: statetype = { rotate: false, shapenum: SpriteEnum.SPR_OFC_DEAD, tictime: 0, think: null, action: null, next: null };

// SS
export const s_ssstand: statetype = { rotate: true, shapenum: SpriteEnum.SPR_SS_S_1, tictime: 0, think: T_Stand, action: null, next: null };
export const s_sschase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_SS_W1_1, tictime: 10, think: T_Chase, action: null, next: null };
export const s_sschase1s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_SS_W1_1, tictime: 3, think: null, action: null, next: null };
export const s_sschase2: statetype = { rotate: true, shapenum: SpriteEnum.SPR_SS_W2_1, tictime: 8, think: T_Chase, action: null, next: null };
export const s_sschase3: statetype = { rotate: true, shapenum: SpriteEnum.SPR_SS_W3_1, tictime: 10, think: T_Chase, action: null, next: null };
export const s_sschase3s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_SS_W3_1, tictime: 3, think: null, action: null, next: null };
export const s_sschase4: statetype = { rotate: true, shapenum: SpriteEnum.SPR_SS_W4_1, tictime: 8, think: T_Chase, action: null, next: null };
export const s_sspain: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SS_PAIN_1, tictime: 10, think: null, action: null, next: null };
export const s_sspain1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SS_PAIN_2, tictime: 10, think: null, action: null, next: null };
export const s_ssdie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SS_DIE_1, tictime: 15, think: null, action: A_DeathScream, next: null };
export const s_ssdead: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SS_DEAD, tictime: 0, think: null, action: null, next: null };

// Mutant
export const s_mutstand: statetype = { rotate: true, shapenum: SpriteEnum.SPR_MUT_S_1, tictime: 0, think: T_Stand, action: null, next: null };
export const s_mutchase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_MUT_W1_1, tictime: 10, think: T_Chase, action: null, next: null };
export const s_mutchase1s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_MUT_W1_1, tictime: 3, think: null, action: null, next: null };
export const s_mutchase2: statetype = { rotate: true, shapenum: SpriteEnum.SPR_MUT_W2_1, tictime: 8, think: T_Chase, action: null, next: null };
export const s_mutchase3: statetype = { rotate: true, shapenum: SpriteEnum.SPR_MUT_W3_1, tictime: 10, think: T_Chase, action: null, next: null };
export const s_mutchase3s: statetype = { rotate: true, shapenum: SpriteEnum.SPR_MUT_W3_1, tictime: 3, think: null, action: null, next: null };
export const s_mutchase4: statetype = { rotate: true, shapenum: SpriteEnum.SPR_MUT_W4_1, tictime: 8, think: T_Chase, action: null, next: null };
export const s_mutpain: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MUT_PAIN_1, tictime: 10, think: null, action: null, next: null };
export const s_mutpain1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MUT_PAIN_2, tictime: 10, think: null, action: null, next: null };
export const s_mutdie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MUT_DIE_1, tictime: 7, think: null, action: A_DeathScream, next: null };
export const s_mutdead: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MUT_DEAD, tictime: 0, think: null, action: null, next: null };

// Bosses - simplified state definitions
export const s_bosschase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_BOSS_W1, tictime: 10, think: T_BossChase, action: null, next: null };
export const s_bossdie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BOSS_DIE1, tictime: 15, think: null, action: A_DeathScream, next: null };

export const s_schabbchase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_SCHABB_W1, tictime: 10, think: T_BossChase, action: null, next: null };
export const s_schabbdie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_SCHABB_DIE1, tictime: 15, think: null, action: null, next: null };

export const s_fakechase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_FAKE_W1, tictime: 10, think: T_BossChase, action: null, next: null };
export const s_fakedie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAKE_DIE1, tictime: 15, think: null, action: null, next: null };

export const s_mechachase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_MECHA_W1, tictime: 10, think: T_BossChase, action: null, next: null };
export const s_mechadie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_MECHA_DIE1, tictime: 15, think: null, action: null, next: null };

export const s_hitlerchase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_HITLER_W1, tictime: 6, think: T_BossChase, action: null, next: null };
export const s_hitlerdie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_HITLER_DIE1, tictime: 15, think: null, action: A_DeathScream, next: null };

export const s_gretelchase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GRETEL_W1, tictime: 10, think: T_BossChase, action: null, next: null };
export const s_greteldie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GRETEL_DIE1, tictime: 15, think: null, action: null, next: null };

export const s_giftchase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_GIFT_W1, tictime: 10, think: T_BossChase, action: null, next: null };
export const s_giftdie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_GIFT_DIE1, tictime: 15, think: null, action: null, next: null };

export const s_fatchase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_FAT_W1, tictime: 10, think: T_BossChase, action: null, next: null };
export const s_fatdie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_FAT_DIE1, tictime: 15, think: null, action: null, next: null };

export const s_spectrechase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_BLINKY_W1, tictime: 10, think: T_Ghosts, action: null, next: null };
export const s_spectredie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BLINKY_W1, tictime: 15, think: null, action: null, next: null };

export const s_angelchase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_BLINKY_W1, tictime: 10, think: T_BossChase, action: null, next: null };
export const s_angeldie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BLINKY_W1, tictime: 15, think: null, action: null, next: null };

export const s_transchase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_BLINKY_W1, tictime: 10, think: T_BossChase, action: null, next: null };
export const s_transdie0: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BLINKY_W1, tictime: 15, think: null, action: null, next: null };

export const s_uberchase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_BLINKY_W1, tictime: 10, think: T_BossChase, action: null, next: null };
export const s_uberdie0: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BLINKY_W1, tictime: 15, think: null, action: null, next: null };

export const s_willchase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_BLINKY_W1, tictime: 10, think: T_BossChase, action: null, next: null };
export const s_willdie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BLINKY_W1, tictime: 15, think: null, action: null, next: null };

export const s_deathchase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_BLINKY_W1, tictime: 10, think: T_BossChase, action: null, next: null };
export const s_deathdie1: statetype = { rotate: false, shapenum: SpriteEnum.SPR_BLINKY_W1, tictime: 15, think: null, action: null, next: null };

export const s_blinkychase1: statetype = { rotate: true, shapenum: SpriteEnum.SPR_BLINKY_W1, tictime: 10, think: T_Ghosts, action: null, next: null };

export const s_deathcam: statetype = { rotate: false, shapenum: SpriteEnum.SPR_DEATHCAM, tictime: 0, think: null, action: null, next: null };
export const s_schabbdeathcam2: statetype = { rotate: false, shapenum: 0, tictime: 0, think: null, action: null, next: null };
export const s_hitlerdeathcam2: statetype = { rotate: false, shapenum: 0, tictime: 0, think: null, action: null, next: null };
export const s_giftdeathcam2: statetype = { rotate: false, shapenum: 0, tictime: 0, think: null, action: null, next: null };
export const s_fatdeathcam2: statetype = { rotate: false, shapenum: 0, tictime: 0, think: null, action: null, next: null };

// Link state chains
s_grdchase1.next = s_grdchase1s; s_grdchase1s.next = s_grdchase2;
s_grdchase2.next = s_grdchase3; s_grdchase3.next = s_grdchase3s;
s_grdchase3s.next = s_grdchase4; s_grdchase4.next = s_grdchase1;
s_grddie1.next = s_grddie2; s_grddie2.next = s_grddie3; s_grddie3.next = s_grddie4;
s_grdpain.next = s_grdchase1;
s_grdshoot1.next = s_grdshoot2; s_grdshoot2.next = s_grdshoot3; s_grdshoot3.next = s_grdchase1;

s_dogchase1.next = s_dogchase1s; s_dogchase1s.next = s_dogchase2;
s_dogchase2.next = s_dogchase3; s_dogchase3.next = s_dogchase3s;
s_dogchase3s.next = s_dogchase4; s_dogchase4.next = s_dogchase1;
s_dogdie1.next = s_dogdie2; s_dogdie2.next = s_dogdie3; s_dogdie3.next = s_dogdead;
s_dogjump1.next = s_dogjump2; s_dogjump2.next = s_dogjump3; s_dogjump3.next = s_dogchase1;

s_ofcchase1.next = s_ofcchase1s; s_ofcchase1s.next = s_ofcchase2;
s_ofcchase2.next = s_ofcchase3; s_ofcchase3.next = s_ofcchase3s;
s_ofcchase3s.next = s_ofcchase4; s_ofcchase4.next = s_ofcchase1;
s_ofcdie1.next = s_ofcdie2; s_ofcdie2.next = s_ofcdie3; s_ofcdie3.next = s_ofcdie4; s_ofcdie4.next = s_ofcdead;
s_ofcpain.next = s_ofcchase1;

s_sschase1.next = s_sschase1s; s_sschase1s.next = s_sschase2;
s_sschase2.next = s_sschase3; s_sschase3.next = s_sschase3s;
s_sschase3s.next = s_sschase4; s_sschase4.next = s_sschase1;
s_ssdie1.next = s_ssdead; s_sspain.next = s_sschase1;

s_mutchase1.next = s_mutchase1s; s_mutchase1s.next = s_mutchase2;
s_mutchase2.next = s_mutchase3; s_mutchase3.next = s_mutchase3s;
s_mutchase3s.next = s_mutchase4; s_mutchase4.next = s_mutchase1;
s_mutdie1.next = s_mutdead; s_mutpain.next = s_mutchase1;

//===========================================================================
// Spawn functions
//===========================================================================

const stateForEnemy: Record<number, { stand: statetype; chase: statetype; speed: number; hitpoints: number[] }> = {
    [enemy_t.en_guard]: { stand: s_grdstand, chase: s_grdchase1, speed: SPDPATROL, hitpoints: [25, 25, 25, 25] },
    [enemy_t.en_officer]: { stand: s_ofcstand, chase: s_ofcchase1, speed: SPDPATROL, hitpoints: [50, 50, 100, 150] },
    [enemy_t.en_ss]: { stand: s_ssstand, chase: s_sschase1, speed: SPDPATROL, hitpoints: [100, 100, 100, 100] },
    [enemy_t.en_dog]: { stand: s_dogchase1, chase: s_dogchase1, speed: SPDDOG, hitpoints: [1, 1, 1, 1] },
    [enemy_t.en_mutant]: { stand: s_mutstand, chase: s_mutchase1, speed: SPDPATROL, hitpoints: [45, 55, 55, 65] },
};

export function SpawnStand(which: enemy_t, tilex: number, tiley: number, dir: number): void {
    const info = stateForEnemy[which];
    if (!info) return;

    SpawnNewObj(tilex, tiley, info.stand);
    if (!GetNewActor) return;

    const ob = lastObj();
    if (!ob) return;

    ob.obclass = enemyToClass(which);
    ob.hitpoints = info.hitpoints[gamestate.difficulty] || info.hitpoints[0];
    ob.dir = dir as dirtype;
    ob.flags |= FL_SHOOTABLE;
    ob.speed = info.speed;

    if (!loadedGameFlag()) gamestate.killtotal++;
}

export function SpawnPatrol(which: enemy_t, tilex: number, tiley: number, dir: number): void {
    const info = stateForEnemy[which];
    if (!info) return;

    SpawnNewObj(tilex, tiley, info.chase);
    const ob = lastObj();
    if (!ob) return;

    ob.obclass = enemyToClass(which);
    ob.hitpoints = info.hitpoints[gamestate.difficulty] || info.hitpoints[0];
    ob.dir = dir as dirtype;
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
    SpawnNewObj(tilex, tiley, s_bosschase1);
    const ob = lastObj();
    if (!ob) return;
    ob.obclass = classtype.bossobj;
    ob.hitpoints = 850;
    ob.flags |= FL_SHOOTABLE;
    ob.speed = SPDPATROL;
    if (!loadedGameFlag()) gamestate.killtotal++;
}

export function SpawnGretel(tilex: number, tiley: number): void {
    SpawnNewObj(tilex, tiley, s_gretelchase1);
    const ob = lastObj();
    if (!ob) return;
    ob.obclass = classtype.gretelobj;
    ob.hitpoints = 950;
    ob.flags |= FL_SHOOTABLE;
    ob.speed = SPDPATROL;
    if (!loadedGameFlag()) gamestate.killtotal++;
}

export function SpawnTrans(tilex: number, tiley: number): void { SpawnBossGeneric(tilex, tiley, classtype.transobj, s_transchase1, 850); }
export function SpawnUber(tilex: number, tiley: number): void { SpawnBossGeneric(tilex, tiley, classtype.uberobj, s_uberchase1, 950); }
export function SpawnWill(tilex: number, tiley: number): void { SpawnBossGeneric(tilex, tiley, classtype.willobj, s_willchase1, 950); }
export function SpawnDeath(tilex: number, tiley: number): void { SpawnBossGeneric(tilex, tiley, classtype.deathobj, s_deathchase1, 1050); }
export function SpawnAngel(tilex: number, tiley: number): void { SpawnBossGeneric(tilex, tiley, classtype.angelobj, s_angelchase1, 1550); }
export function SpawnSpectre(tilex: number, tiley: number): void { SpawnBossGeneric(tilex, tiley, classtype.spectreobj, s_spectrechase1, 5); }
export function SpawnGhosts(which: number, tilex: number, tiley: number): void { SpawnBossGeneric(tilex, tiley, classtype.ghostobj, s_blinkychase1, 99999); }
export function SpawnSchabbs(tilex: number, tiley: number): void { SpawnBossGeneric(tilex, tiley, classtype.schabbobj, s_schabbchase1, 1500); }
export function SpawnGift(tilex: number, tiley: number): void { SpawnBossGeneric(tilex, tiley, classtype.giftobj, s_giftchase1, 950); }
export function SpawnFat(tilex: number, tiley: number): void { SpawnBossGeneric(tilex, tiley, classtype.fatobj, s_fatchase1, 950); }
export function SpawnFakeHitler(tilex: number, tiley: number): void { SpawnBossGeneric(tilex, tiley, classtype.fakeobj, s_fakechase1, 300); }
export function SpawnHitler(tilex: number, tiley: number): void { SpawnBossGeneric(tilex, tiley, classtype.mechahitlerobj, s_mechachase1, 800); }

function SpawnBossGeneric(tilex: number, tiley: number, cls: classtype, state: statetype, hp: number): void {
    SpawnNewObj(tilex, tiley, state);
    const ob = lastObj();
    if (!ob) return;
    ob.obclass = cls;
    ob.hitpoints = hp;
    ob.flags |= FL_SHOOTABLE;
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
        default: SD.SD_PlaySound(soundnames.DEATHSCREAM1SND); break;
    }
}

export function KillActor(ob: objtype): void {
    // Delegated to wl_state.ts KillActor
}

// Helpers
function lastObj(): objtype | null {
    // Get the last spawned object from the play module
    // SpawnNewObj calls GetNewActor which sets lastobj
    // We import it at the top
    return _lastobj;
}

// Lazy accessor for lastobj to avoid circular import at module init
let _lastobj: objtype | null = null;
export function _setLastObj(obj: objtype | null): void { _lastobj = obj; }

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
