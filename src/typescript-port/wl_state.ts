// WL_STATE.TS
// Ported from WL_STATE.C - Actor state machine and movement

import { objtype, statetype, dirtype, MAPSIZE, TILEGLOBAL, TILESHIFT, GLOBAL1, tilemap, actorat, spotvis } from './wl_def';

//===========================================================================
// Constants
//===========================================================================

export const TURNTICS = 10;
export const SPDPATROL = 512;
export const SPDDOG = 1500;

//===========================================================================
// Direction tables
//===========================================================================

export const opposite: dirtype[] = [
    dirtype.west, dirtype.southwest, dirtype.south, dirtype.southeast,
    dirtype.east, dirtype.northeast, dirtype.north, dirtype.northwest,
    dirtype.nodir,
];

export const diagonal: dirtype[][] = Array.from({ length: 9 }, () =>
    new Array(9).fill(dirtype.nodir)
);

//===========================================================================
// Functions
//===========================================================================

export function InitHitRect(_ob: objtype, _radius: number): void {}

export function SpawnNewObj(_tilex: number, _tiley: number, _state: statetype): void {}

export function NewState(ob: objtype, state: statetype): void {
    ob.state = state;
    ob.ticcount = state.tictime;
}

export function TryWalk(_ob: objtype): boolean { return false; }
export function SelectChaseDir(_ob: objtype): void {}
export function SelectDodgeDir(_ob: objtype): void {}
export function SelectRunDir(_ob: objtype): void {}

export function MoveObj(ob: objtype, move: number): void {
    // Move object in its current direction
    const dx = [TILEGLOBAL, TILEGLOBAL, 0, -TILEGLOBAL, -TILEGLOBAL, -TILEGLOBAL, 0, TILEGLOBAL, 0];
    const dy = [0, -TILEGLOBAL, -TILEGLOBAL, -TILEGLOBAL, 0, TILEGLOBAL, TILEGLOBAL, TILEGLOBAL, 0];

    if (ob.dir < 8) {
        ob.x += ((dx[ob.dir] * move) / TILEGLOBAL) | 0;
        ob.y += ((dy[ob.dir] * move) / TILEGLOBAL) | 0;
    }

    ob.tilex = (ob.x >> TILESHIFT) | 0;
    ob.tiley = (ob.y >> TILESHIFT) | 0;
}

export function SightPlayer(_ob: objtype): boolean { return false; }
export function KillActor(_ob: objtype): void {}
export function DamageActor(_ob: objtype, _damage: number): void {}
export function CheckLine(_ob: objtype): boolean { return false; }
export function CheckSight(_ob: objtype): boolean { return false; }
