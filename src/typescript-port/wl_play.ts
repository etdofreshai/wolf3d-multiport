// WL_PLAY.TS
// Ported from WL_PLAY.C - Play loop and control handling

import * as VL from './id_vl';
import * as IN from './id_in';
import * as SD from './id_sd';
import * as US from './id_us_1';
import {
    MAXACTORS, MAXSTATS, MAXDOORS, NUMBUTTONS, NUMAREAS,
    MAPSIZE, MAXVIEWWIDTH, MAXTICS, DEMOTICS,
    objtype, statobj_t, doorobj_t, newObjtype,
    exit_t, classtype, activetype, dirtype,
    tilemap, actorat, spotvis,
    UPDATESIZE, update,
    setTics, tics,
} from './wl_def';
import {
    gamestate, viewsize, buttonscan, buttonmouse, buttonjoy,
    dirscan, mouseenabled, joystickenabled, mouseadjustment,
} from './wl_main';
import * as Draw from './wl_draw';
const ThreeDRefresh = () => Draw.ThreeDRefresh();
let lasttimecount = 0;
import { MoveDoors, MovePWalls, ConnectAreas } from './wl_act1';
import { soundnames } from './audiowl6';
import * as WlState from './wl_state';

//===========================================================================
// Global variables
//===========================================================================

export let playstate: exit_t = exit_t.ex_stillplaying;
export function setPlaystate(v: exit_t): void { playstate = v; }

export let madenoise = false;

// Object lists
export const objlist: objtype[] = Array.from({ length: MAXACTORS }, () => newObjtype());
export let newobj: objtype | null = null;
export let obj: objtype | null = null;
export let player: objtype | null = null;
export let lastobj: objtype | null = null;
export let objfreelist: objtype | null = null;
export let killerobj: objtype | null = null;

export const statobjlist: statobj_t[] = Array.from({ length: MAXSTATS }, () => ({
    tilex: 0, tiley: 0, visspot: 0, shapenum: -1, flags: 0, itemnumber: 0,
}));
export let laststatobj: statobj_t | null = null;

export const doorobjlist: doorobj_t[] = Array.from({ length: MAXDOORS }, () => ({
    tilex: 0, tiley: 0, vertical: false, lock: 0, action: 0, ticcount: 0,
}));
export let lastdoorobj: doorobj_t | null = null;

export const areaconnect: Uint8Array[] = Array.from({ length: NUMAREAS }, () => new Uint8Array(NUMAREAS));
export const areabyplayer: boolean[] = new Array(NUMAREAS).fill(false);

// Control state
export let singlestep = false;
export let godmode = false;
export let noclip = false;
export let extravbls = 0;

export let controlx = 0;
export let controly = 0;
export const buttonstate: boolean[] = new Array(NUMBUTTONS).fill(false);
export const buttonheld: boolean[] = new Array(NUMBUTTONS).fill(false);

export let demorecord = false;
export let demoplayback = false;
export let demoptr: number = 0;
export let lastdemoptr: number = 0;
export let demobuffer: Uint8Array | null = null;

// Palette shift state
const NUMREDSHIFTS = 6;
const NUMWHITESHIFTS = 3;

//===========================================================================
// InitActorList
//===========================================================================

export function InitActorList(): void {
    for (let i = 0; i < MAXACTORS; i++) {
        Object.assign(objlist[i], newObjtype());
    }

    // Set up free list
    for (let i = 0; i < MAXACTORS - 1; i++) {
        objlist[i].next = objlist[i + 1];
    }
    objlist[MAXACTORS - 1].next = null;

    objfreelist = objlist[1];
    lastobj = objlist[0];
    lastobj.next = null;

    player = objlist[0];
    player.active = activetype.ac_allways;
    player.obclass = classtype.playerobj;
}

//===========================================================================
// GetNewActor
//===========================================================================

export function GetNewActor(): objtype {
    if (!objfreelist) {
        throw new Error('GetNewActor: No free actors!');
    }

    newobj = objfreelist;
    objfreelist = objfreelist.next;

    Object.assign(newobj, newObjtype());

    if (lastobj) {
        lastobj.next = newobj;
    }
    newobj.prev = lastobj;
    newobj.next = null;
    lastobj = newobj;

    return newobj;
}

//===========================================================================
// RemoveObj
//===========================================================================

export function RemoveObj(gone: objtype): void {
    if (gone === player) {
        throw new Error('RemoveObj: Tried to remove player!');
    }

    if (gone.prev) gone.prev.next = gone.next;
    if (gone.next) gone.next.prev = gone.prev;
    if (gone === lastobj) lastobj = gone.prev;

    gone.next = objfreelist;
    objfreelist = gone;
}

//===========================================================================
// PollControls
//===========================================================================

export function PollControls(): void {
    const info: IN.ControlInfo = {
        button0: false, button1: false, button2: false, button3: false,
        x: 0, y: 0, xaxis: 0, yaxis: 0, dir: IN.Direction.dir_None,
    };

    IN.IN_ReadControl(0, info);

    controlx = 0;
    controly = 0;

    if (info.xaxis === -1) controlx = -1;
    else if (info.xaxis === 1) controlx = 1;

    if (info.yaxis === -1) controly = -1;
    else if (info.yaxis === 1) controly = 1;

    // Check button states from keyboard
    for (let i = 0; i < NUMBUTTONS; i++) {
        buttonstate[i] = IN.IN_KeyDown(buttonscan[i]);
    }

    // Mouse buttons
    if (mouseenabled) {
        const mb = IN.IN_MouseButtons();
        if (mb & 1) buttonstate[0] = true;
        if (mb & 2) buttonstate[1] = true;
        if (mb & 4) buttonstate[2] = true;

        const md = IN.IN_GetMouseDelta();
        controlx += (md.x * mouseadjustment / 10) | 0;
    }
}

//===========================================================================
// InitRedShifts / FinishPaletteShifts
//===========================================================================

export function InitRedShifts(): void {
    // Pre-calculate palette shifts for damage/bonus effects
}

export function FinishPaletteShifts(): void {
    // Ensure palette is back to normal
}

//===========================================================================
// CenterWindow
//===========================================================================

export function CenterWindow(w: number, h: number): void {
    US.US_CenterWindow(w, h);
}

//===========================================================================
// StopMusic / StartMusic
//===========================================================================

export function StopMusic(): void {
    SD.SD_MusicOff();
}

export function StartMusic(): void {
    SD.SD_MusicOn();
}

//===========================================================================
// PlaySoundLocGlobal / UpdateSoundLoc
//===========================================================================

export function PlaySoundLocGlobal(s: number, _gx: number, _gy: number): void {
    SD.SD_PlaySound(s);
}

export function UpdateSoundLoc(): void {
    // Update sound positioning
}

//===========================================================================
// StartDamageFlash / StartBonusFlash
//===========================================================================

export function StartDamageFlash(_damage: number): void {
    // Red flash effect
}

export function StartBonusFlash(): void {
    // White/gold flash effect
}

//===========================================================================
// CalcTics
//===========================================================================

export function CalcTics(): void {
    const newtime = SD.TimeCount;
    let t = newtime - lasttimecount;
    if (t <= 0) t = 1;
    if (t > MAXTICS) t = MAXTICS;
    setTics(t);
    lasttimecount = newtime;
}

//===========================================================================
// DoActor - process a single actor's state machine
//===========================================================================

function DoActor(ob: objtype): void {
    if (!ob.state) return;

    if (ob.ticcount > 0) {
        ob.ticcount -= tics;
        while (ob.ticcount <= 0) {
            // Action at end of state
            if (ob.state && ob.state.action) {
                ob.state.action(ob);
            }
            // Move to next state
            if (ob.state && ob.state.next) {
                ob.state = ob.state.next;
                ob.ticcount += ob.state.tictime;
            } else {
                break;
            }
        }
    }

    // Think function
    if (ob.state && ob.state.think) {
        ob.state.think(ob);
    }

    // Move if distance is set
    if (ob.distance > 0 && ob.speed > 0) {
        const move = Math.min(ob.speed * tics, ob.distance);
        WlState.MoveObj(ob, move);
    }
}

//===========================================================================
// PlayLoop - main per-frame game loop
//===========================================================================

export async function PlayLoop(): Promise<void> {
    playstate = exit_t.ex_stillplaying;
    lasttimecount = 0;

    while (playstate === exit_t.ex_stillplaying) {
        IN.IN_ProcessEvents();
        PollControls();
        CalcTics();

        // Process the player
        if (player && player.state && player.state.think) {
            player.state.think(player);
        }

        // Process all actors
        for (let check = player ? player.next : null; check; check = check.next) {
            if (check.active === activetype.ac_no) continue;
            DoActor(check);
        }

        // Process doors and pushwalls
        MoveDoors();
        MovePWalls();

        // Update sound positioning
        UpdateSoundLoc();

        // Render the 3D view
        ThreeDRefresh();

        // Update time count
        gamestate.TimeCount += tics;

        // Yield to browser
        await new Promise(resolve => requestAnimationFrame(resolve));

        // Check for escape
        if (IN.IN_KeyDown(IN.sc_Escape)) {
            playstate = exit_t.ex_abort;
        }

        // Check for player death
        if (gamestate.health <= 0) {
            playstate = exit_t.ex_died;
        }
    }
}
