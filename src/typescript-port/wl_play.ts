// WL_PLAY.TS
// Ported from WL_PLAY.C - Play loop and control handling

import * as VL from './id_vl';
import * as VH from './id_vh';
import * as IN from './id_in';
import * as SD from './id_sd';
import * as US from './id_us_1';
import * as CA from './id_ca';
import {
    MAXACTORS, MAXSTATS, MAXDOORS, NUMBUTTONS, NUMAREAS,
    MAPSIZE, MAXVIEWWIDTH, MAXTICS, DEMOTICS,
    objtype, statobj_t, doorobj_t, newObjtype,
    exit_t, classtype, activetype, dirtype,
    tilemap, actorat, spotvis,
    UPDATESIZE, update,
    setTics, tics,
    SETFONTCOLOR,
} from './wl_def';
import {
    gamestate, viewsize, buttonscan, buttonmouse, buttonjoy,
    dirscan, mouseenabled, joystickenabled, mouseadjustment,
    startgame, loadedgame,
} from './wl_main';
import * as Draw from './wl_draw';
import { graphicnums, STARTFONT } from './gfxv_wl6';
import { soundnames, musicnames } from './audiowl6';
const ThreeDRefresh = () => Draw.ThreeDRefresh();
let lasttimecount = 0;
import { MoveDoors, MovePWalls, ConnectAreas } from './wl_act1';
import * as WlState from './wl_state';
import { DebugKeys } from './wl_debug';
import { DrawHealth, DrawAmmo, DrawKeys, DrawWeapon, DrawScore, DrawFace, GiveWeapon } from './wl_agent';
import { ClearSplitVWB } from './wl_inter';

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

// Debug state
export let DebugOk = false;

// Palette shift state
const NUMREDSHIFTS = 6;
const NUMWHITESHIFTS = 3;

let damagecount = 0;
let bonuscount = 0;
let palshifted = false;

// Red shift palettes (damage)
const redshifts: Uint8Array[] = [];
// White shift palettes (bonus pickup)
const whiteshifts: Uint8Array[] = [];

// Songs per level for each episode
const songs: number[] = [
    // Episode One
    musicnames.GETTHEM_MUS, musicnames.SEARCHN_MUS, musicnames.POW_MUS,
    musicnames.SUSPENSE_MUS, musicnames.GETTHEM_MUS, musicnames.SEARCHN_MUS,
    musicnames.POW_MUS, musicnames.SUSPENSE_MUS,
    musicnames.WARMARCH_MUS, musicnames.CORNER_MUS,
    // Episode Two
    musicnames.NAZI_OMI_MUS, musicnames.PREGNANT_MUS, musicnames.GOINGAFT_MUS,
    musicnames.HEADACHE_MUS, musicnames.NAZI_OMI_MUS, musicnames.PREGNANT_MUS,
    musicnames.HEADACHE_MUS, musicnames.GOINGAFT_MUS,
    musicnames.WARMARCH_MUS, musicnames.DUNGEON_MUS,
    // Episode Three
    musicnames.INTROCW3_MUS, musicnames.NAZI_RAP_MUS, musicnames.TWELFTH_MUS,
    musicnames.ZEROHOUR_MUS, musicnames.INTROCW3_MUS, musicnames.NAZI_RAP_MUS,
    musicnames.TWELFTH_MUS, musicnames.ZEROHOUR_MUS,
    musicnames.ULTIMATE_MUS, musicnames.PACMAN_MUS,
    // Episode Four
    musicnames.GETTHEM_MUS, musicnames.SEARCHN_MUS, musicnames.POW_MUS,
    musicnames.SUSPENSE_MUS, musicnames.GETTHEM_MUS, musicnames.SEARCHN_MUS,
    musicnames.POW_MUS, musicnames.SUSPENSE_MUS,
    musicnames.WARMARCH_MUS, musicnames.CORNER_MUS,
    // Episode Five
    musicnames.NAZI_OMI_MUS, musicnames.PREGNANT_MUS, musicnames.GOINGAFT_MUS,
    musicnames.HEADACHE_MUS, musicnames.NAZI_OMI_MUS, musicnames.PREGNANT_MUS,
    musicnames.HEADACHE_MUS, musicnames.GOINGAFT_MUS,
    musicnames.WARMARCH_MUS, musicnames.DUNGEON_MUS,
    // Episode Six
    musicnames.INTROCW3_MUS, musicnames.NAZI_RAP_MUS, musicnames.TWELFTH_MUS,
    musicnames.ZEROHOUR_MUS, musicnames.INTROCW3_MUS, musicnames.NAZI_RAP_MUS,
    musicnames.TWELFTH_MUS, musicnames.ZEROHOUR_MUS,
    musicnames.ULTIMATE_MUS, musicnames.FUNKYOU_MUS,
];

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

    gone.state = null;

    if (gone === lastobj) {
        lastobj = gone.prev;
    } else if (gone.next) {
        gone.next.prev = gone.prev;
    }

    if (gone.prev) {
        gone.prev.next = gone.next;
    }

    gone.next = objfreelist;
    objfreelist = gone;
}

//===========================================================================
// PollControls
//===========================================================================

const BASEMOVE = 35;
const RUNMOVE = 70;
const BASETURN = 35;
const RUNTURN = 70;

export function PollControls(): void {
    if (demoplayback) {
        // Read from demo buffer
        if (demobuffer && demoptr < lastdemoptr) {
            const buttonbits = demobuffer[demoptr++];
            for (let i = 0; i < NUMBUTTONS; i++) {
                buttonstate[i] = !!(buttonbits & (1 << i));
            }
            controlx = (demobuffer[demoptr++] << 24) >> 24; // sign extend
            controly = (demobuffer[demoptr++] << 24) >> 24;

            if (demoptr >= lastdemoptr) {
                playstate = exit_t.ex_completed;
            }

            controlx *= tics;
            controly *= tics;
        }
        return;
    }

    // Save previous button state
    for (let i = 0; i < NUMBUTTONS; i++) {
        buttonheld[i] = buttonstate[i];
        buttonstate[i] = false;
    }

    controlx = 0;
    controly = 0;

    // Keyboard buttons
    for (let i = 0; i < NUMBUTTONS; i++) {
        if (IN.IN_KeyDown(buttonscan[i])) {
            buttonstate[i] = true;
        }
    }

    // Mouse buttons
    if (mouseenabled) {
        const mb = IN.IN_MouseButtons();
        if (mb & 1) buttonstate[buttonmouse[0]] = true;
        if (mb & 2) buttonstate[buttonmouse[1]] = true;
        if (mb & 4) buttonstate[buttonmouse[2]] = true;
    }

    // Keyboard movement
    if (buttonstate[3]) { // bt_run
        if (IN.IN_KeyDown(dirscan[0])) controly -= RUNMOVE * tics;  // north
        if (IN.IN_KeyDown(dirscan[2])) controly += RUNMOVE * tics;  // south
        if (IN.IN_KeyDown(dirscan[3])) controlx -= RUNMOVE * tics;  // west
        if (IN.IN_KeyDown(dirscan[1])) controlx += RUNMOVE * tics;  // east
    } else {
        if (IN.IN_KeyDown(dirscan[0])) controly -= BASEMOVE * tics;
        if (IN.IN_KeyDown(dirscan[2])) controly += BASEMOVE * tics;
        if (IN.IN_KeyDown(dirscan[3])) controlx -= BASEMOVE * tics;
        if (IN.IN_KeyDown(dirscan[1])) controlx += BASEMOVE * tics;
    }

    // Mouse movement
    if (mouseenabled) {
        const md = IN.IN_GetMouseDelta();
        controlx += (md.x * 10 / (13 - mouseadjustment)) | 0;
        controly += (md.y * 20 / (13 - mouseadjustment)) | 0;
    }

    // Bound movement
    const max = 100 * tics;
    const min = -max;
    if (controlx > max) controlx = max;
    else if (controlx < min) controlx = min;
    if (controly > max) controly = max;
    else if (controly < min) controly = min;

    // Demo recording
    if (demorecord && demobuffer) {
        const cx = (controlx / tics) | 0;
        const cy = (controly / tics) | 0;

        let buttonbits = 0;
        for (let i = NUMBUTTONS - 1; i >= 0; i--) {
            buttonbits <<= 1;
            if (buttonstate[i]) buttonbits |= 1;
        }

        demobuffer[demoptr++] = buttonbits;
        demobuffer[demoptr++] = cx & 0xff;
        demobuffer[demoptr++] = cy & 0xff;

        if (demoptr >= lastdemoptr) {
            throw new Error('Demo buffer overflowed!');
        }

        controlx = cx * tics;
        controly = cy * tics;
    }
}

//===========================================================================
// InitRedShifts / FinishPaletteShifts
//===========================================================================

export function InitRedShifts(): void {
    // Pre-calculate palette shifts for damage/bonus effects
    const basePal = new Uint8Array(768);
    VL.VL_GetPalette(basePal);

    // Generate red shifts for damage
    for (let i = 1; i <= NUMREDSHIFTS; i++) {
        const pal = new Uint8Array(768);
        for (let j = 0; j < 256; j++) {
            const r = basePal[j * 3 + 0];
            const g = basePal[j * 3 + 1];
            const b = basePal[j * 3 + 2];
            pal[j * 3 + 0] = Math.min(63, r + ((63 - r) * i / NUMREDSHIFTS) | 0);
            pal[j * 3 + 1] = Math.max(0, (g - g * i / NUMREDSHIFTS) | 0);
            pal[j * 3 + 2] = Math.max(0, (b - b * i / NUMREDSHIFTS) | 0);
        }
        redshifts.push(pal);
    }

    // Generate white shifts for bonus
    for (let i = 1; i <= NUMWHITESHIFTS; i++) {
        const pal = new Uint8Array(768);
        for (let j = 0; j < 256; j++) {
            const r = basePal[j * 3 + 0];
            const g = basePal[j * 3 + 1];
            const b = basePal[j * 3 + 2];
            pal[j * 3 + 0] = Math.min(63, r + ((63 - r) * i / NUMWHITESHIFTS) | 0);
            pal[j * 3 + 1] = Math.min(63, g + ((63 - g) * i / NUMWHITESHIFTS) | 0);
            pal[j * 3 + 2] = Math.min(63, b + ((63 - b) * i / NUMWHITESHIFTS) | 0);
        }
        whiteshifts.push(pal);
    }
}

export function ClearPaletteShifts(): void {
    bonuscount = damagecount = 0;
}

export function FinishPaletteShifts(): void {
    if (palshifted) {
        palshifted = false;
        VL.VL_SetPalette(VH.gamepal);
        VL.VL_UpdateScreen();
    }
}

function UpdatePaletteShifts(): void {
    let red = 0;
    let white = 0;

    if (bonuscount > 0) {
        white = (bonuscount / 10) | 0;
        if (white >= NUMWHITESHIFTS) white = NUMWHITESHIFTS - 1;
        bonuscount -= tics;
        if (bonuscount < 0) bonuscount = 0;
    }

    if (damagecount > 0) {
        red = (damagecount / 10) | 0;
        if (red >= NUMREDSHIFTS) red = NUMREDSHIFTS - 1;
        damagecount -= tics;
        if (damagecount < 0) damagecount = 0;
    }

    if (red > 0 && redshifts.length > 0) {
        VL.VL_SetPalette(redshifts[red - 1]);
        palshifted = true;
    } else if (white > 0 && whiteshifts.length > 0) {
        VL.VL_SetPalette(whiteshifts[white - 1]);
        palshifted = true;
    } else if (palshifted) {
        VL.VL_SetPalette(VH.gamepal);
        palshifted = false;
    }
}

//===========================================================================
// StartDamageFlash / StartBonusFlash
//===========================================================================

export function StartDamageFlash(damage: number): void {
    damagecount += damage;
}

export function StartBonusFlash(): void {
    bonuscount += NUMWHITESHIFTS * 10;
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
    const songIdx = gamestate.episode * 10 + gamestate.mapon;
    if (songIdx >= 0 && songIdx < songs.length) {
        // Would load and start the music from audiosegs
        SD.SD_MusicOn();
    } else {
        SD.SD_MusicOn();
    }
}

//===========================================================================
// PlaySoundLocGlobal / UpdateSoundLoc
//===========================================================================

export function PlaySoundLocGlobal(s: number, _gx: number, _gy: number): void {
    SD.SD_PlaySound(s);
}

export function UpdateSoundLoc(): void {
    if (!player) return;
    // For stereo panning, calculate left/right volumes based on player angle
    // to sound source. In a simple implementation, just update position.
}

//===========================================================================
// DrawPlayScreen - draw the game border and status bar
//===========================================================================

export function DrawPlayScreen(): void {
    // Draw game play border
    VL.VL_Bar(0, 0, 320, 200 - 40, 0x2d);

    // Draw status bar
    CA.CA_CacheGrChunk(graphicnums.STATUSBARPIC);
    VH.VWB_DrawPic(0, 160, graphicnums.STATUSBARPIC);

    DrawHealth();
    DrawAmmo();
    DrawKeys();
    DrawWeapon();
    DrawScore();
    DrawFace();

    VH.VW_UpdateScreen();
}

export function DrawAllPlayBorder(): void {
    DrawPlayScreen();
}

export function DrawAllPlayBorderSides(): void {
    // Redraw just the border sides (not the full screen)
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
// CheckKeys - handle F-key presses and debug keys during gameplay
//===========================================================================

async function CheckKeys(): Promise<void> {
    if (VL.screenfaded || demoplayback) return;

    const scan = IN.LastScan;

    //
    // SECRET CHEAT CODE: 'MLI'
    //
    if (IN.Keyboard[IN.sc_M] && IN.Keyboard[IN.sc_L] && IN.Keyboard[IN.sc_I]) {
        gamestate.health = 100;
        gamestate.ammo = 99;
        gamestate.keys = 3;
        gamestate.score = 0;
        gamestate.TimeCount += 42000;
        GiveWeapon(3); // wp_chaingun

        DrawWeapon();
        DrawHealth();
        DrawKeys();
        DrawAmmo();
        DrawScore();

        CA.CA_CacheGrChunk(STARTFONT + 1);
        ClearSplitVWB();

        const { Message } = await import('./wl_menu');
        Message(
            'You now have 100% Health,\n' +
            '99 Ammo and both Keys!\n\n' +
            'Note that you have also been\n' +
            'charged a hefty penalty score.'
        );

        IN.IN_ClearKeysDown();
        await IN.IN_Ack();
        DrawAllPlayBorder();
    }

    //
    // OPEN UP DEBUG KEYS
    //
    if (IN.Keyboard[IN.sc_BackSpace] && IN.Keyboard[IN.sc_LShift] && IN.Keyboard[IN.sc_Alt]) {
        ClearSplitVWB();
        const { Message } = await import('./wl_menu');
        Message('Debugging keys are\nnow available!');
        IN.IN_ClearKeysDown();
        await IN.IN_Ack();
        DrawAllPlayBorderSides();
        DebugOk = true;
    }

    //
    // Pause
    //
    if (IN.Paused) {
        CA.CA_CacheGrChunk(graphicnums.PAUSEDPIC);
        VH.LatchDrawPic(20 - 4, 80 - 16, graphicnums.PAUSEDPIC);
        SD.SD_MusicOff();
        await IN.IN_Ack();
        IN.IN_ClearKeysDown();
        SD.SD_MusicOn();
        IN.setPaused(false);
        IN.IN_GetMouseDelta();
        return;
    }

    //
    // F1-F10/ESC - control panel invocation
    //
    if (scan === IN.sc_F10 || scan === IN.sc_F9 || scan === IN.sc_F7 || scan === IN.sc_F8) {
        ClearSplitVWB();
        const { US_ControlPanel } = await import('./wl_menu');
        await US_ControlPanel(scan);
        DrawAllPlayBorderSides();
        if (scan === IN.sc_F9) StartMusic();
        SETFONTCOLOR(0, 15);
        IN.IN_ClearKeysDown();
        return;
    }

    if ((scan >= IN.sc_F1 && scan <= IN.sc_F9) || scan === IN.sc_Escape) {
        StopMusic();
        await VH.VW_FadeOut();

        const { US_ControlPanel } = await import('./wl_menu');
        await US_ControlPanel(scan);

        SETFONTCOLOR(0, 15);
        IN.IN_ClearKeysDown();
        DrawPlayScreen();
        if (!startgame && !loadedgame) {
            await VH.VW_FadeIn();
            StartMusic();
        }
        if (loadedgame) {
            playstate = exit_t.ex_abort;
        }
        lasttimecount = SD.TimeCount;
        IN.IN_GetMouseDelta();
        return;
    }

    //
    // TAB + debug key
    //
    if (IN.Keyboard[IN.sc_Tab] && DebugOk) {
        CA.CA_CacheGrChunk(STARTFONT);
        VH.setFontNumber(0);
        SETFONTCOLOR(0, 15);
        DebugKeys();
        IN.IN_GetMouseDelta();
        lasttimecount = SD.TimeCount;
        return;
    }
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
    lasttimecount = SD.TimeCount;

    while (playstate === exit_t.ex_stillplaying) {
        IN.IN_ProcessEvents();

        PollControls();

        if (!demoplayback && !demorecord) {
            CalcTics();
        }

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

        // Palette shift effects (damage/bonus)
        UpdatePaletteShifts();

        // Render the 3D view
        ThreeDRefresh();

        // Update time count
        gamestate.TimeCount += tics;

        // Check for F-keys, debug keys, pause, cheats
        await CheckKeys();

        // Yield to browser
        await new Promise(resolve => requestAnimationFrame(resolve));

        // Check for escape
        if (IN.IN_KeyDown(IN.sc_Escape) && !demoplayback) {
            // Escape is handled in CheckKeys via US_ControlPanel
        }

        // Check for player death
        if (gamestate.health <= 0) {
            playstate = exit_t.ex_died;
        }
    }

    // Clean up palette shifts when leaving gameplay
    FinishPaletteShifts();
}
