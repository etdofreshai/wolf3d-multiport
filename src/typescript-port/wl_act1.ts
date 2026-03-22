// WL_ACT1.TS
// Ported from WL_ACT1.C - Doors, static objects, pushwalls

import {
    MAXDOORS, NUMAREAS,
    objtype, statobj_t, doorobj_t, dooraction_t,
} from './wl_def';
import { doorobjlist, statobjlist, areaconnect, areabyplayer } from './wl_play';

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

//===========================================================================
// InitDoorList
//===========================================================================

export function InitDoorList(): void {
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
    for (let i = 0; i < statobjlist.length; i++) {
        statobjlist[i].shapenum = -1;
    }
}

//===========================================================================
// SpawnStatic
//===========================================================================

export function SpawnStatic(_tilex: number, _tiley: number, _type: number): void {
    // Spawn a static object (lamp, item, decoration, etc.)
}

//===========================================================================
// SpawnDoor
//===========================================================================

export function SpawnDoor(_tilex: number, _tiley: number, _vertical: boolean, _lock: number): void {
    if (doornum >= MAXDOORS) {
        throw new Error('SpawnDoor: Too many doors!');
    }
    doornum++;
}

//===========================================================================
// MoveDoors / OpenDoor / OperateDoor
//===========================================================================

export function MoveDoors(): void {
    // Process door animations
}

export function OpenDoor(_door: number): void {
    // Start opening a door
}

export function OperateDoor(_door: number): void {
    // Toggle a door
}

//===========================================================================
// MovePWalls / PushWall
//===========================================================================

export function MovePWalls(): void {
    // Process pushwall movement
}

export function PushWall(_checkx: number, _checky: number, _dir: number): void {
    // Start pushing a wall
}

//===========================================================================
// PlaceItemType
//===========================================================================

export function PlaceItemType(_itemtype: number, _tilex: number, _tiley: number): void {
    // Place an item at a location
}

//===========================================================================
// InitAreas
//===========================================================================

export function InitAreas(): void {
    for (let i = 0; i < NUMAREAS; i++) {
        areabyplayer[i] = false;
        for (let j = 0; j < NUMAREAS; j++) {
            areaconnect[i][j] = 0;
        }
    }
}
