// WL_ACT2.TS
// Ported from WL_ACT2.C - Enemy AI and state machines

import { statetype, objtype, enemy_t, classtype, dirtype, activetype } from './wl_def';

//===========================================================================
// State definitions (stubs - full state machine tables would go here)
//===========================================================================

export const s_grdstand: statetype = { rotate: true, shapenum: 50, tictime: 0, think: null, action: null, next: null };
export const s_grdchase1: statetype = { rotate: true, shapenum: 50, tictime: 10, think: null, action: null, next: null };
export const s_grddie1: statetype = { rotate: false, shapenum: 50, tictime: 15, think: null, action: null, next: null };
export const s_grdpain: statetype = { rotate: false, shapenum: 50, tictime: 10, think: null, action: null, next: null };
export const s_grdpain1: statetype = { rotate: false, shapenum: 50, tictime: 10, think: null, action: null, next: null };

export const s_dogchase1: statetype = { rotate: true, shapenum: 99, tictime: 10, think: null, action: null, next: null };
export const s_dogdie1: statetype = { rotate: false, shapenum: 99, tictime: 15, think: null, action: null, next: null };

export const s_ofcchase1: statetype = { rotate: true, shapenum: 50, tictime: 10, think: null, action: null, next: null };
export const s_ofcdie1: statetype = { rotate: false, shapenum: 50, tictime: 15, think: null, action: null, next: null };
export const s_ofcpain: statetype = { rotate: false, shapenum: 50, tictime: 10, think: null, action: null, next: null };
export const s_ofcpain1: statetype = { rotate: false, shapenum: 50, tictime: 10, think: null, action: null, next: null };

export const s_sschase1: statetype = { rotate: true, shapenum: 50, tictime: 10, think: null, action: null, next: null };
export const s_ssdie1: statetype = { rotate: false, shapenum: 50, tictime: 15, think: null, action: null, next: null };
export const s_sspain: statetype = { rotate: false, shapenum: 50, tictime: 10, think: null, action: null, next: null };
export const s_sspain1: statetype = { rotate: false, shapenum: 50, tictime: 10, think: null, action: null, next: null };

export const s_mutchase1: statetype = { rotate: true, shapenum: 50, tictime: 10, think: null, action: null, next: null };
export const s_mutdie1: statetype = { rotate: false, shapenum: 50, tictime: 15, think: null, action: null, next: null };
export const s_mutpain: statetype = { rotate: false, shapenum: 50, tictime: 10, think: null, action: null, next: null };
export const s_mutpain1: statetype = { rotate: false, shapenum: 50, tictime: 10, think: null, action: null, next: null };

export const s_bosschase1: statetype = { rotate: true, shapenum: 50, tictime: 10, think: null, action: null, next: null };
export const s_bossdie1: statetype = { rotate: false, shapenum: 50, tictime: 15, think: null, action: null, next: null };

export const s_schabbchase1: statetype = { rotate: true, shapenum: 50, tictime: 10, think: null, action: null, next: null };
export const s_schabbdie1: statetype = { rotate: false, shapenum: 50, tictime: 15, think: null, action: null, next: null };

export const s_fakechase1: statetype = { rotate: true, shapenum: 50, tictime: 10, think: null, action: null, next: null };
export const s_fakedie1: statetype = { rotate: false, shapenum: 50, tictime: 15, think: null, action: null, next: null };

export const s_mechachase1: statetype = { rotate: true, shapenum: 50, tictime: 10, think: null, action: null, next: null };
export const s_mechadie1: statetype = { rotate: false, shapenum: 50, tictime: 15, think: null, action: null, next: null };

export const s_hitlerchase1: statetype = { rotate: true, shapenum: 50, tictime: 10, think: null, action: null, next: null };
export const s_hitlerdie1: statetype = { rotate: false, shapenum: 50, tictime: 15, think: null, action: null, next: null };

export const s_gretelchase1: statetype = { rotate: true, shapenum: 50, tictime: 10, think: null, action: null, next: null };
export const s_greteldie1: statetype = { rotate: false, shapenum: 50, tictime: 15, think: null, action: null, next: null };

export const s_giftchase1: statetype = { rotate: true, shapenum: 50, tictime: 10, think: null, action: null, next: null };
export const s_giftdie1: statetype = { rotate: false, shapenum: 50, tictime: 15, think: null, action: null, next: null };

export const s_fatchase1: statetype = { rotate: true, shapenum: 50, tictime: 10, think: null, action: null, next: null };
export const s_fatdie1: statetype = { rotate: false, shapenum: 50, tictime: 15, think: null, action: null, next: null };

export const s_spectrechase1: statetype = { rotate: true, shapenum: 50, tictime: 10, think: null, action: null, next: null };
export const s_spectredie1: statetype = { rotate: false, shapenum: 50, tictime: 15, think: null, action: null, next: null };

export const s_angelchase1: statetype = { rotate: true, shapenum: 50, tictime: 10, think: null, action: null, next: null };
export const s_angeldie1: statetype = { rotate: false, shapenum: 50, tictime: 15, think: null, action: null, next: null };

export const s_transchase1: statetype = { rotate: true, shapenum: 50, tictime: 10, think: null, action: null, next: null };
export const s_transdie0: statetype = { rotate: false, shapenum: 50, tictime: 15, think: null, action: null, next: null };

export const s_uberchase1: statetype = { rotate: true, shapenum: 50, tictime: 10, think: null, action: null, next: null };
export const s_uberdie0: statetype = { rotate: false, shapenum: 50, tictime: 15, think: null, action: null, next: null };

export const s_willchase1: statetype = { rotate: true, shapenum: 50, tictime: 10, think: null, action: null, next: null };
export const s_willdie1: statetype = { rotate: false, shapenum: 50, tictime: 15, think: null, action: null, next: null };

export const s_deathchase1: statetype = { rotate: true, shapenum: 50, tictime: 10, think: null, action: null, next: null };
export const s_deathdie1: statetype = { rotate: false, shapenum: 50, tictime: 15, think: null, action: null, next: null };

export const s_blinkychase1: statetype = { rotate: true, shapenum: 50, tictime: 10, think: null, action: null, next: null };

export const s_deathcam: statetype = { rotate: false, shapenum: 0, tictime: 0, think: null, action: null, next: null };
export const s_schabbdeathcam2: statetype = { rotate: false, shapenum: 0, tictime: 0, think: null, action: null, next: null };
export const s_hitlerdeathcam2: statetype = { rotate: false, shapenum: 0, tictime: 0, think: null, action: null, next: null };
export const s_giftdeathcam2: statetype = { rotate: false, shapenum: 0, tictime: 0, think: null, action: null, next: null };
export const s_fatdeathcam2: statetype = { rotate: false, shapenum: 0, tictime: 0, think: null, action: null, next: null };

//===========================================================================
// Spawn functions (stubs)
//===========================================================================

export function SpawnStand(_which: enemy_t, _tilex: number, _tiley: number, _dir: number): void {}
export function SpawnPatrol(_which: enemy_t, _tilex: number, _tiley: number, _dir: number): void {}
export function SpawnDeadGuard(_tilex: number, _tiley: number): void {}
export function SpawnBoss(_tilex: number, _tiley: number): void {}
export function SpawnGretel(_tilex: number, _tiley: number): void {}
export function SpawnTrans(_tilex: number, _tiley: number): void {}
export function SpawnUber(_tilex: number, _tiley: number): void {}
export function SpawnWill(_tilex: number, _tiley: number): void {}
export function SpawnDeath(_tilex: number, _tiley: number): void {}
export function SpawnAngel(_tilex: number, _tiley: number): void {}
export function SpawnSpectre(_tilex: number, _tiley: number): void {}
export function SpawnGhosts(_which: number, _tilex: number, _tiley: number): void {}
export function SpawnSchabbs(_tilex: number, _tiley: number): void {}
export function SpawnGift(_tilex: number, _tiley: number): void {}
export function SpawnFat(_tilex: number, _tiley: number): void {}
export function SpawnFakeHitler(_tilex: number, _tiley: number): void {}
export function SpawnHitler(_tilex: number, _tiley: number): void {}
export function SpawnBJVictory(): void {}
export function A_DeathScream(_ob: objtype): void {}
export function KillActor(_ob: objtype): void {}
