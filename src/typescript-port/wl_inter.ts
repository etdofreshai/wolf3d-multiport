// WL_INTER.TS
// Ported from WL_INTER.C - Intermission screens

import * as VL from './id_vl';
import * as VH from './id_vh';
import * as CA from './id_ca';
import * as IN from './id_in';
import * as SD from './id_sd';
import * as US from './id_us_1';
import * as PM from './id_pm';
import { graphicnums, STARTPICS } from './gfxv_wl6';
import { soundnames } from './audiowl6';
import { gamestate, viewwidth, viewheight } from './wl_main';
import { STATUSLINES } from './wl_def';

//===========================================================================
// IntroScreen
//===========================================================================

export function IntroScreen(): void {
    // Display signon/intro screen
}

//===========================================================================
// PG13
//===========================================================================

export function PG13(): void {
    CA.CA_CacheGrChunk(graphicnums.PG13PIC);
    const data = CA.grsegs[graphicnums.PG13PIC];
    if (data) {
        VL.VL_MemToScreen(data, 320, 200, 0, 0);
        VL.VL_UpdateScreen();
    }
}

//===========================================================================
// PreloadGraphics
//===========================================================================

export function PreloadGraphics(): void {
    // Cache graphics needed for gameplay
    // Cache status bar, faces, numbers, etc.
    for (let i = graphicnums.L_NUM0PIC; i <= graphicnums.L_NUM0PIC + 9; i++) {
        CA.CA_CacheGrChunk(i);
    }

    // Preload all wall textures and sprites via PM
    PM.PM_Preload((current, total) => {
        // Update loading bar
        const barWidth = 160;
        const barX = 80;
        const barY = 100;
        const filled = ((current * barWidth) / total) | 0;
        VL.VL_Bar(barX, barY, filled, 10, 0x37);
        VL.VL_UpdateScreen();
        return true;
    });
}

//===========================================================================
// ClearSplitVWB
//===========================================================================

export function ClearSplitVWB(): void {
    // Clear the split VW buffer
    VL.VL_Bar(0, 0, 320, 160, 0);
}

//===========================================================================
// LevelCompleted
//===========================================================================

export async function LevelCompleted(): Promise<void> {
    // Display level completion stats

    ClearSplitVWB();

    // Background
    CA.CA_CacheGrChunk(graphicnums.L_GUYPIC);
    const guyPic = CA.grsegs[graphicnums.L_GUYPIC];
    if (guyPic) {
        VL.VL_MemToScreen(guyPic, 320, 200, 0, 0);
    }

    // Calculate ratios
    const kr = gamestate.killtotal > 0
        ? ((gamestate.killcount * 100) / gamestate.killtotal) | 0 : 0;
    const sr = gamestate.secrettotal > 0
        ? ((gamestate.secretcount * 100) / gamestate.secrettotal) | 0 : 0;
    const tr = gamestate.treasuretotal > 0
        ? ((gamestate.treasurecount * 100) / gamestate.treasuretotal) | 0 : 0;

    // Draw stats text
    VH.setPx(32); VH.setPy(40);
    VH.VWB_DrawPropString('Floor ' + (gamestate.mapon + 1));
    VH.setPx(32); VH.setPy(56);
    VH.VWB_DrawPropString('Kill Ratio: ' + kr + '%');
    VH.setPx(32); VH.setPy(68);
    VH.VWB_DrawPropString('Secret Ratio: ' + sr + '%');
    VH.setPx(32); VH.setPy(80);
    VH.VWB_DrawPropString('Treasure Ratio: ' + tr + '%');

    // Calculate time bonus
    const par = 99; // placeholder
    const sec = (gamestate.TimeCount / 70) | 0;
    VH.setPx(32); VH.setPy(96);
    VH.VWB_DrawPropString('Time: ' + sec + 's');

    VL.VL_UpdateScreen();

    // Wait for key
    IN.IN_ClearKeysDown();
    while (!IN.LastScan) {
        IN.IN_ProcessEvents();
        await new Promise(resolve => setTimeout(resolve, 16));
    }

    // Bonus points
    if (kr === 100) gamestate.score += 10000;
    if (sr === 100) gamestate.score += 10000;
    if (tr === 100) gamestate.score += 10000;

    SD.SD_PlaySound(soundnames.LEVELDONESND);
}

//===========================================================================
// Victory
//===========================================================================

export async function Victory(): Promise<void> {
    ClearSplitVWB();

    VH.setPx(80); VH.setPy(80);
    VH.VWB_DrawPropString('VICTORY!');
    VH.setPx(60); VH.setPy(100);
    VH.VWB_DrawPropString('You have defeated the enemy!');

    VL.VL_UpdateScreen();

    IN.IN_ClearKeysDown();
    while (!IN.LastScan) {
        IN.IN_ProcessEvents();
        await new Promise(resolve => setTimeout(resolve, 16));
    }
}

//===========================================================================
// CheckHighScore
//===========================================================================

export function CheckHighScore(score: number, _other: number): void {
    // Check and insert into high score table
    for (let i = 0; i < US.Scores.length; i++) {
        if (score > US.Scores[i].score) {
            // Insert score
            for (let j = US.Scores.length - 1; j > i; j--) {
                US.Scores[j] = { ...US.Scores[j - 1] };
            }
            US.Scores[i] = {
                name: 'Player',
                score: score,
                completed: gamestate.mapon,
                episode: gamestate.episode,
            };
            break;
        }
    }
}

//===========================================================================
// FreeMusic
//===========================================================================

export function FreeMusic(): void {
    // Free cached music
}
