// WL_DEBUG.TS
// Ported from WL_DEBUG.C - Debug keys and routines

import * as VL from './id_vl';
import * as VH from './id_vh';
import * as IN from './id_in';
import * as SD from './id_sd';
import * as US from './id_us_1';
import { ChunksInFile, PMSpriteStart, PMSoundStart } from './id_pm';
import * as CA from './id_ca';
import {
    MAPSIZE, MAXWALLTILES, exit_t, weapontype,
    tilemap, actorat, spotvis, mapsegs, farmapylookup,
} from './wl_def';
import { gamestate, viewwidth, viewheight } from './wl_main';
import {
    player, singlestep, godmode, noclip, extravbls,
    statobjlist, laststatobj, doorobjlist, lastdoorobj,
    playstate, setPlaystate, objlist,
} from './wl_play';
import { TakeDamage, HealSelf, GiveWeapon, GiveAmmo, DrawAmmo, DrawHealth, DrawKeys, DrawWeapon, DrawScore } from './wl_agent';
import { soundnames } from './audiowl6';
import { graphicnums, STARTFONT } from './gfxv_wl6';

//===========================================================================
// Constants
//===========================================================================

const VIEWTILEX = ((viewwidth / 16) | 0);
const VIEWTILEY = ((viewheight / 16) | 0);

//===========================================================================
// Local variables
//===========================================================================

let maporgx = 0;
let maporgy = 0;

//===========================================================================
// DebugMemory
//===========================================================================

function DebugMemory(): void {
    US.US_CenterWindow(16, 4);

    US.US_CPrint('Memory Usage');
    US.US_CPrint('------------');
    US.US_Print('Free      :');
    // In the browser, report approximate JS heap usage
    const perf = (performance as unknown as { memory?: { usedJSHeapSize: number; totalJSHeapSize: number } });
    if (perf.memory) {
        US.US_PrintUnsigned(((perf.memory.totalJSHeapSize - perf.memory.usedJSHeapSize) / 1024) | 0);
    } else {
        US.US_PrintUnsigned(0);
    }
    US.US_Print('k\nTotal     :');
    if (perf.memory) {
        US.US_PrintUnsigned((perf.memory.totalJSHeapSize / 1024) | 0);
    } else {
        US.US_PrintUnsigned(0);
    }
    US.US_Print('k\n');
    VH.VW_UpdateScreen();
}

//===========================================================================
// CountObjects
//===========================================================================

function CountObjects(): void {
    US.US_CenterWindow(16, 7);
    let active = 0;
    let inactive = 0;
    let count = 0;
    let doors = 0;

    // Count static objects
    let total = 0;
    for (let i = 0; i < statobjlist.length; i++) {
        if (statobjlist[i].tilex === 0 && statobjlist[i].tiley === 0 && statobjlist[i].shapenum === -1) break;
        total++;
    }

    US.US_Print('Total statics :');
    US.US_PrintUnsigned(total);

    US.US_Print('\nIn use statics:');
    for (let i = 0; i < total; i++) {
        if (statobjlist[i].shapenum !== -1) {
            count++;
        } else {
            doors++;
        }
    }
    US.US_PrintUnsigned(count);

    US.US_Print('\nDoors         :');
    let doornum = 0;
    for (let i = 0; i < doorobjlist.length; i++) {
        if (doorobjlist[i].tilex === 0 && doorobjlist[i].tiley === 0) break;
        doornum++;
    }
    US.US_PrintUnsigned(doornum);

    // Count actors
    for (let obj = player ? player.next : null; obj; obj = obj.next) {
        if (obj.active) {
            active++;
        } else {
            inactive++;
        }
    }

    US.US_Print('\nTotal actors  :');
    US.US_PrintUnsigned(active + inactive);

    US.US_Print('\nActive actors :');
    US.US_PrintUnsigned(active);

    VH.VW_UpdateScreen();
}

//===========================================================================
// PicturePause
//===========================================================================

export function PicturePause(): void {
    VL.VL_ColorBorder(15);

    IN.setLastScan(0);
    // In async context we can't loop; just update screen
    VL.VL_ColorBorder(0);
    VH.VW_UpdateScreen();
}

//===========================================================================
// DebugKeys - main debug key handler (Tab + key combos)
//
// Returns 1 if a debug key was handled, 0 otherwise.
//===========================================================================

// We use a mutable module-level ref for noclip/godmode/singlestep etc.
// through wl_play's exports. Because they are `let`, we import the
// module and mutate through the module namespace.
import * as Play from './wl_play';

export function DebugKeys(): number {
    // B = border color
    if (IN.Keyboard[IN.sc_B]) {
        US.US_CenterWindow(24, 3);
        US.setPrintY(US.PrintY + 6);
        US.US_Print(' Border color (0-15):');
        VH.VW_UpdateScreen();
        // Simplified: just cycle border color
        VL.VL_ColorBorder((VL.bordercolor + 1) & 15);
        return 1;
    }

    // C = count objects
    if (IN.Keyboard[IN.sc_C]) {
        CountObjects();
        return 1;
    }

    // E = complete level
    if (IN.Keyboard[IN.sc_E]) {
        setPlaystate(exit_t.ex_completed);
        return 1;
    }

    // F = facing spot (position info)
    if (IN.Keyboard[IN.sc_F]) {
        US.US_CenterWindow(14, 4);
        US.US_Print('X:');
        if (player) US.US_PrintUnsigned(player.x);
        US.US_Print('\nY:');
        if (player) US.US_PrintUnsigned(player.y);
        US.US_Print('\nA:');
        if (player) US.US_PrintUnsigned(player.angle);
        VH.VW_UpdateScreen();
        return 1;
    }

    // G = god mode toggle
    if (IN.Keyboard[IN.sc_G]) {
        US.US_CenterWindow(12, 2);
        if (godmode) {
            US.US_PrintCentered('God mode OFF');
        } else {
            US.US_PrintCentered('God mode ON');
        }
        VH.VW_UpdateScreen();
        (Play as { godmode: boolean }).godmode = !godmode;
        return 1;
    }

    // H = hurt self
    if (IN.Keyboard[IN.sc_H]) {
        IN.IN_ClearKeysDown();
        TakeDamage(16, null);
        return 1;
    }

    // I = item cheat (free items)
    if (IN.Keyboard[IN.sc_I]) {
        US.US_CenterWindow(12, 3);
        US.US_PrintCentered('Free items!');
        VH.VW_UpdateScreen();
        import('./wl_agent').then(Agent => {
            Agent.GivePoints(100000);
            Agent.HealSelf(99);
            if (gamestate.bestweapon < weapontype.wp_chaingun) {
                Agent.GiveWeapon(gamestate.bestweapon + 1);
            }
            gamestate.ammo += 50;
            if (gamestate.ammo > 99) gamestate.ammo = 99;
            Agent.DrawAmmo();
        });
        return 1;
    }

    // M = memory info
    if (IN.Keyboard[IN.sc_M]) {
        DebugMemory();
        return 1;
    }

    // N = no clip toggle
    if (IN.Keyboard[IN.sc_N]) {
        (Play as { noclip: boolean }).noclip = !noclip;
        US.US_CenterWindow(18, 3);
        if (!noclip) {
            // Value was just toggled above
            US.US_PrintCentered('No clipping OFF');
        } else {
            US.US_PrintCentered('No clipping ON');
        }
        VH.VW_UpdateScreen();
        return 1;
    }

    // P = pause with no screen disruption
    if (IN.Keyboard[IN.sc_P]) {
        PicturePause();
        return 1;
    }

    // Q = fast quit
    if (IN.Keyboard[IN.sc_Q]) {
        // In browser, we can't truly quit - just log
        console.log('Debug: Fast quit requested');
        return 1;
    }

    // S = slow motion (single step) toggle
    if (IN.Keyboard[IN.sc_S]) {
        (Play as { singlestep: boolean }).singlestep = !singlestep;
        US.US_CenterWindow(18, 3);
        if (!singlestep) {
            US.US_PrintCentered('Slow motion OFF');
        } else {
            US.US_PrintCentered('Slow motion ON');
        }
        VH.VW_UpdateScreen();
        return 1;
    }

    // T = shape test (simplified - show page info)
    if (IN.Keyboard[IN.sc_T]) {
        US.US_CenterWindow(20, 5);
        US.US_Print(' Shape Test\n');
        US.US_Print(' PM Pages: ');
        US.US_PrintUnsigned(ChunksInFile);
        US.US_Print('\n Sprite Start: ');
        US.US_PrintUnsigned(PMSpriteStart);
        US.US_Print('\n Sound Start: ');
        US.US_PrintUnsigned(PMSoundStart);
        VH.VW_UpdateScreen();
        return 1;
    }

    // V = extra VBLs
    if (IN.Keyboard[IN.sc_V]) {
        US.US_CenterWindow(30, 3);
        US.setPrintY(US.PrintY + 6);
        US.US_Print('  Extra VBLs: ');
        const newVbls = ((Play as { extravbls: number }).extravbls + 1) % 9;
        (Play as { extravbls: number }).extravbls = newVbls;
        US.US_PrintUnsigned(newVbls);
        VH.VW_UpdateScreen();
        return 1;
    }

    // W = warp to level
    if (IN.Keyboard[IN.sc_W]) {
        US.US_CenterWindow(26, 3);
        US.setPrintY(US.PrintY + 6);
        US.US_Print('  Warp to which level(1-10):');
        VH.VW_UpdateScreen();
        // Simplified: warp to next level
        const nextLevel = (gamestate.mapon + 1) % 10;
        gamestate.mapon = nextLevel;
        setPlaystate(exit_t.ex_warped);
        return 1;
    }

    // X = extra stuff
    if (IN.Keyboard[IN.sc_X]) {
        US.US_CenterWindow(12, 3);
        US.US_PrintCentered('Extra stuff!');
        VH.VW_UpdateScreen();
        // Give everything
        gamestate.health = 100;
        gamestate.ammo = 99;
        gamestate.keys = 3;
        GiveWeapon(weapontype.wp_chaingun);
        DrawHealth();
        DrawAmmo();
        DrawKeys();
        DrawWeapon();
        DrawScore();
        return 1;
    }

    return 0;
}
