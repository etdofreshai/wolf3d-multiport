// WL_INTER.TS
// Ported from WL_INTER.C - Intermission screens

import * as VL from './id_vl';
import * as VH from './id_vh';
import * as CA from './id_ca';
import * as IN from './id_in';
import * as SD from './id_sd';
import * as US from './id_us_1';
import * as PM from './id_pm';
import { graphicnums, STARTPICS, STARTFONT } from './gfxv_wl6';
import { soundnames, musicnames } from './audiowl6';
import { gamestate, viewwidth, viewheight } from './wl_main';
import { STATUSLINES, SETFONTCOLOR } from './wl_def';
import { READHCOLOR, BKGDCOLOR, VIEWCOLOR, HIGHLIGHT, TEXTCOLOR } from './wl_menu';

//===========================================================================
// LevelRatios - stored stats per level
//===========================================================================

export interface LRstruct {
    kill: number;
    secret: number;
    treasure: number;
    time: number;
}

export const LevelRatios: LRstruct[] = Array.from({ length: 8 }, () => ({
    kill: 0, secret: 0, treasure: 0, time: 0,
}));

//===========================================================================
// Par times (Episode One thru Six, in minutes)
//===========================================================================

interface ParTime {
    time: number;
    timestr: string;
}

const parTimes: ParTime[][] = [
    // Episode One
    [
        { time: 1.5, timestr: '01:30' }, { time: 2, timestr: '02:00' },
        { time: 2, timestr: '02:00' }, { time: 3.5, timestr: '03:30' },
        { time: 3, timestr: '03:00' }, { time: 3, timestr: '03:00' },
        { time: 2.5, timestr: '02:30' }, { time: 2.5, timestr: '02:30' },
        { time: 0, timestr: '??:??' }, { time: 0, timestr: '??:??' },
    ],
    // Episode Two
    [
        { time: 1.5, timestr: '01:30' }, { time: 3.5, timestr: '03:30' },
        { time: 3, timestr: '03:00' }, { time: 2, timestr: '02:00' },
        { time: 4, timestr: '04:00' }, { time: 6, timestr: '06:00' },
        { time: 1, timestr: '01:00' }, { time: 3, timestr: '03:00' },
        { time: 0, timestr: '??:??' }, { time: 0, timestr: '??:??' },
    ],
    // Episode Three
    [
        { time: 1.5, timestr: '01:30' }, { time: 1.5, timestr: '01:30' },
        { time: 2.5, timestr: '02:30' }, { time: 2.5, timestr: '02:30' },
        { time: 3.5, timestr: '03:30' }, { time: 2.5, timestr: '02:30' },
        { time: 2, timestr: '02:00' }, { time: 6, timestr: '06:00' },
        { time: 0, timestr: '??:??' }, { time: 0, timestr: '??:??' },
    ],
    // Episode Four
    [
        { time: 2, timestr: '02:00' }, { time: 2, timestr: '02:00' },
        { time: 1.5, timestr: '01:30' }, { time: 1, timestr: '01:00' },
        { time: 4.5, timestr: '04:30' }, { time: 3.5, timestr: '03:30' },
        { time: 2, timestr: '02:00' }, { time: 4.5, timestr: '04:30' },
        { time: 0, timestr: '??:??' }, { time: 0, timestr: '??:??' },
    ],
    // Episode Five
    [
        { time: 2.5, timestr: '02:30' }, { time: 1.5, timestr: '01:30' },
        { time: 2.5, timestr: '02:30' }, { time: 2.5, timestr: '02:30' },
        { time: 4, timestr: '04:00' }, { time: 3, timestr: '03:00' },
        { time: 4.5, timestr: '04:30' }, { time: 3.5, timestr: '03:30' },
        { time: 0, timestr: '??:??' }, { time: 0, timestr: '??:??' },
    ],
    // Episode Six
    [
        { time: 6.5, timestr: '06:30' }, { time: 4, timestr: '04:00' },
        { time: 4.5, timestr: '04:30' }, { time: 6, timestr: '06:00' },
        { time: 5, timestr: '05:00' }, { time: 5.5, timestr: '05:30' },
        { time: 5.5, timestr: '05:30' }, { time: 8.5, timestr: '08:30' },
        { time: 0, timestr: '??:??' }, { time: 0, timestr: '??:??' },
    ],
];

//===========================================================================
// Write - draw text using the large letter graphics (L_APIC etc)
//===========================================================================

export function Write(x: number, y: number, str: string): void {
    const alpha = [
        graphicnums.L_NUM0PIC, graphicnums.L_NUM0PIC + 1, graphicnums.L_NUM0PIC + 2,
        graphicnums.L_NUM0PIC + 3, graphicnums.L_NUM0PIC + 4, graphicnums.L_NUM0PIC + 5,
        graphicnums.L_NUM0PIC + 6, graphicnums.L_NUM0PIC + 7, graphicnums.L_NUM0PIC + 8,
        graphicnums.L_NUM0PIC + 9, graphicnums.L_COLONPIC,
        0, 0, 0, 0, 0, 0,  // ;, <, =, >, ?, @
        graphicnums.L_APIC, graphicnums.L_BPIC, graphicnums.L_CPIC,
        graphicnums.L_DPIC, graphicnums.L_EPIC, graphicnums.L_FPIC,
        graphicnums.L_GPIC, graphicnums.L_HPIC, graphicnums.L_IPIC,
        graphicnums.L_JPIC, graphicnums.L_KPIC, graphicnums.L_LPIC,
        graphicnums.L_MPIC, graphicnums.L_NPIC, graphicnums.L_OPIC,
        graphicnums.L_PPIC, graphicnums.L_QPIC, graphicnums.L_RPIC,
        graphicnums.L_SPIC, graphicnums.L_TPIC, graphicnums.L_UPIC,
        graphicnums.L_VPIC, graphicnums.L_WPIC, graphicnums.L_XPIC,
        graphicnums.L_YPIC, graphicnums.L_ZPIC,
    ];

    const ox = x * 8;
    let nx = ox;
    let ny = y * 8;

    for (let i = 0; i < str.length; i++) {
        if (str[i] === '\n') {
            nx = ox;
            ny += 16;
            continue;
        }

        let ch = str.charCodeAt(i);
        // Convert lowercase to uppercase
        if (ch >= 97) ch -= 32;  // 'a'-'A' = 32
        ch -= 48;  // '0'

        switch (str[i]) {
            case '!':
                VH.VWB_DrawPic(nx, ny, graphicnums.L_EXPOINTPIC);
                nx += 8;
                continue;
            case '\'':
                VH.VWB_DrawPic(nx, ny, graphicnums.L_APOSTROPHEPIC);
                nx += 8;
                continue;
            case ' ':
                nx += 16;
                continue;
            case ':':
                VH.VWB_DrawPic(nx, ny, graphicnums.L_COLONPIC);
                nx += 8;
                continue;
            case '%':
                VH.VWB_DrawPic(nx, ny, graphicnums.L_PERCENTPIC);
                nx += 16;
                continue;
            default:
                if (ch >= 0 && ch < alpha.length && alpha[ch]) {
                    VH.VWB_DrawPic(nx, ny, alpha[ch]);
                }
                nx += 16;
        }
    }
}

//===========================================================================
// BJ_Breathe - animate BJ breathing
//===========================================================================

let bjBreathWhich = 0;
let bjBreathMax = 10;

export function BJ_Breathe(): void {
    const pics = [graphicnums.L_GUYPIC, graphicnums.L_GUY2PIC];

    if (SD.TimeCount > bjBreathMax) {
        bjBreathWhich ^= 1;
        VH.VWB_DrawPic(0, 16, pics[bjBreathWhich]);
        VH.VW_UpdateScreen();
        SD.setTimeCount(0);
        bjBreathMax = 35;
    }
}

//===========================================================================
// IntroScreen
//===========================================================================

export function IntroScreen(): void {
    // Display signon/intro screen
}

//===========================================================================
// PG13
//===========================================================================

export async function PG13(): Promise<void> {
    await VH.VW_FadeOut();
    VH.VWB_Bar(0, 0, 320, 200, 0x82);

    CA.CA_CacheGrChunk(graphicnums.PG13PIC);
    VH.VWB_DrawPic(216, 110, graphicnums.PG13PIC);
    VH.VW_UpdateScreen();

    await VH.VW_FadeIn();
    await IN.IN_UserInput(SD.TickBase * 7);
    await VH.VW_FadeOut();
}

//===========================================================================
// PreloadGraphics
//===========================================================================

export function PreloadGraphics(): void {
    // Cache the "Get Psyched" loading bar graphic
    CA.CA_CacheGrChunk(graphicnums.GETPSYCHEDPIC);

    // Draw the Get Psyched background
    ClearSplitVWB();
    VH.VWB_Bar(0, 0, 320, 200 - STATUSLINES, 0x7f);
    VH.VWB_DrawPic(124, 64, graphicnums.GETPSYCHEDPIC);
    VH.VW_UpdateScreen();

    // Draw progress bar outline
    const barX = 48;
    const barY = 100;
    const barW = 224;
    const barH = 10;
    VL.VL_Bar(barX - 1, barY - 1, barW + 2, barH + 2, 0x29);

    // Preload wall textures and sprites via PM
    PM.PM_Preload((current, total) => {
        const filled = ((current * barW) / total) | 0;
        VL.VL_Bar(barX, barY, filled, barH, 0x37);
        VL.VL_Bar(barX + filled, barY, barW - filled, barH, 0x2d);
        VL.VL_UpdateScreen();
        return true;
    });

    // Cache status bar, faces, numbers, etc.
    for (let i = graphicnums.L_NUM0PIC; i <= graphicnums.L_NUM0PIC + 9; i++) {
        CA.CA_CacheGrChunk(i);
    }
    CA.CA_CacheGrChunk(graphicnums.L_COLONPIC);
    CA.CA_CacheGrChunk(graphicnums.L_PERCENTPIC);
    CA.CA_CacheGrChunk(graphicnums.L_APIC);
    CA.CA_CacheGrChunk(graphicnums.L_GUYPIC);
    CA.CA_CacheGrChunk(graphicnums.L_GUY2PIC);
    CA.CA_CacheGrChunk(graphicnums.L_BJWINSPIC);
    CA.CA_CacheGrChunk(graphicnums.L_EXPOINTPIC);
    CA.CA_CacheGrChunk(graphicnums.L_APOSTROPHEPIC);
    CA.CA_CacheGrChunk(graphicnums.STATUSBARPIC);
}

//===========================================================================
// ClearSplitVWB
//===========================================================================

export function ClearSplitVWB(): void {
    US.setWindowX(0);
    US.setWindowY(0);
    US.setWindowW(320);
    US.setWindowH(160);
}

//===========================================================================
// LevelCompleted
//===========================================================================

export async function LevelCompleted(): Promise<void> {
    const VBLWAIT = 30;
    const PAR_AMOUNT = 500;
    const PERCENT100AMT = 10000;

    ClearSplitVWB();
    VH.VWB_Bar(0, 0, 320, 200 - STATUSLINES, 0x7f);

    IN.IN_ClearKeysDown();
    IN.IN_StartAck();

    // Draw BJ
    VH.VWB_DrawPic(0, 16, graphicnums.L_GUYPIC);

    const mapon = gamestate.mapon;
    const ep = gamestate.episode;

    // Check if it's a regular level (not boss or secret)
    if (mapon < 8) {
        Write(14, 2, 'floor\ncompleted');

        Write(14, 7, 'bonus     0');
        Write(16, 10, 'time');
        Write(16, 12, 'par');

        Write(11, 14, 'kill ratio');
        Write(11, 16, 'secret ratio');
        Write(11, 18, 'treasure ratio');

        // Calculate kill/secret/treasure ratios
        const kr = gamestate.killtotal > 0
            ? ((gamestate.killcount * 100) / gamestate.killtotal) | 0 : 0;
        const sr = gamestate.secrettotal > 0
            ? ((gamestate.secretcount * 100) / gamestate.secrettotal) | 0 : 0;
        const tr = gamestate.treasuretotal > 0
            ? ((gamestate.treasurecount * 100) / gamestate.treasuretotal) | 0 : 0;

        // Calculate time
        const sec = (gamestate.TimeCount / 70) | 0;
        const min = (sec / 60) | 0;
        const secLeft = sec % 60;

        // Draw floor number
        VH.VWB_DrawPic(26 * 8, 2 * 8, graphicnums.L_NUM0PIC + mapon + 1);

        // Draw time
        const i = 26 * 8;
        if (min < 10) {
            VH.VWB_DrawPic(i, 10 * 8, graphicnums.L_NUM0PIC + min);
        } else {
            VH.VWB_DrawPic(i, 10 * 8, graphicnums.L_NUM0PIC + ((min / 10) | 0));
            VH.VWB_DrawPic(i + 16, 10 * 8, graphicnums.L_NUM0PIC + (min % 10));
        }
        VH.VWB_DrawPic(i + 32, 10 * 8, graphicnums.L_COLONPIC);
        VH.VWB_DrawPic(i + 40, 10 * 8, graphicnums.L_NUM0PIC + ((secLeft / 10) | 0));
        VH.VWB_DrawPic(i + 56, 10 * 8, graphicnums.L_NUM0PIC + (secLeft % 10));

        // Draw par time
        const parList = parTimes[ep] || parTimes[0];
        const par = parList[mapon];
        if (par) {
            VH.setFontColor(HIGHLIGHT);
            VH.setPx(26 * 8);
            VH.setPy(12 * 8);
            VH.VWB_DrawPropString(par.timestr);
        }

        // Store ratios
        if (mapon < LevelRatios.length) {
            LevelRatios[mapon].kill = kr;
            LevelRatios[mapon].secret = sr;
            LevelRatios[mapon].treasure = tr;
            LevelRatios[mapon].time = sec;
        }

        VH.VW_UpdateScreen();
        await VH.VW_FadeIn();

        // Animated counting of kill ratio
        SD.setTimeCount(0);
        for (let ratio = 0; ratio <= kr; ratio += 2) {
            VL.VL_Bar(26 * 8, 14 * 8, 40, 14, 0x7f);
            Write(26, 14, ratio.toString());
            VH.VW_UpdateScreen();
            if (IN.IN_CheckAck()) break;
            while (SD.TimeCount < 2) {
                SD.SD_TimeCountUpdate();
                await new Promise(r => setTimeout(r, 1));
            }
            SD.setTimeCount(0);
            if (ratio >= kr) break;
        }
        // Draw final ratio
        VL.VL_Bar(26 * 8, 14 * 8, 40, 14, 0x7f);
        Write(26, 14, kr.toString());

        // Secret ratio
        SD.setTimeCount(0);
        for (let ratio = 0; ratio <= sr; ratio += 2) {
            VL.VL_Bar(26 * 8, 16 * 8, 40, 14, 0x7f);
            Write(26, 16, ratio.toString());
            VH.VW_UpdateScreen();
            if (IN.IN_CheckAck()) break;
            while (SD.TimeCount < 2) {
                SD.SD_TimeCountUpdate();
                await new Promise(r => setTimeout(r, 1));
            }
            SD.setTimeCount(0);
            if (ratio >= sr) break;
        }
        VL.VL_Bar(26 * 8, 16 * 8, 40, 14, 0x7f);
        Write(26, 16, sr.toString());

        // Treasure ratio
        SD.setTimeCount(0);
        for (let ratio = 0; ratio <= tr; ratio += 2) {
            VL.VL_Bar(26 * 8, 18 * 8, 40, 14, 0x7f);
            Write(26, 18, ratio.toString());
            VH.VW_UpdateScreen();
            if (IN.IN_CheckAck()) break;
            while (SD.TimeCount < 2) {
                SD.SD_TimeCountUpdate();
                await new Promise(r => setTimeout(r, 1));
            }
            SD.setTimeCount(0);
            if (ratio >= tr) break;
        }
        VL.VL_Bar(26 * 8, 18 * 8, 40, 14, 0x7f);
        Write(26, 18, tr.toString());

        VH.VW_UpdateScreen();

        // Calculate bonus
        let bonus = 0;
        const parSecs = par ? (par.time * 60) | 0 : 0;
        if (parSecs > 0 && sec < parSecs) {
            bonus = (parSecs - sec) * PAR_AMOUNT;
        }
        if (kr === 100) bonus += PERCENT100AMT;
        if (sr === 100) bonus += PERCENT100AMT;
        if (tr === 100) bonus += PERCENT100AMT;

        // Show bonus
        VL.VL_Bar(26 * 8, 7 * 8, 60, 14, 0x7f);
        Write(26, 7, bonus.toString());
        gamestate.score += bonus;

        VH.VW_UpdateScreen();
        SD.SD_PlaySound(soundnames.LEVELDONESND);
    } else {
        // Boss level or secret level - simpler display
        Write(14, 2, 'floor\ncompleted');
        VH.VW_UpdateScreen();
        await VH.VW_FadeIn();
    }

    // Wait for acknowledgment
    await IN.IN_Ack();

    await VH.VW_FadeOut();
}

//===========================================================================
// Victory
//===========================================================================

export async function Victory(): Promise<void> {
    const RATIOX = 6;
    const RATIOY = 14;
    const TIMEX = 14;
    const TIMEY = 8;

    ClearSplitVWB();
    CA.CA_CacheGrChunk(STARTFONT);

    VH.VWB_Bar(0, 0, 320, 200 - STATUSLINES, 0x7f);

    Write(18, 2, 'you win!');
    Write(TIMEX, TIMEY - 2, 'total time');
    Write(12, RATIOY - 2, 'averages');
    Write(RATIOX + 8, RATIOY, 'kill ratio');
    Write(RATIOX + 4, RATIOY + 2, 'secret ratio');
    Write(RATIOX, RATIOY + 4, 'treasure ratio');

    VH.VWB_DrawPic(8, 4, graphicnums.L_BJWINSPIC);

    // Calculate averages from LevelRatios
    let kr = 0, sr = 0, tr = 0;
    let totalSec = 0;
    for (let i = 0; i < 8; i++) {
        totalSec += LevelRatios[i].time;
        kr += LevelRatios[i].kill;
        sr += LevelRatios[i].secret;
        tr += LevelRatios[i].treasure;
    }
    kr = (kr / 8) | 0;
    sr = (sr / 8) | 0;
    tr = (tr / 8) | 0;

    let min = (totalSec / 60) | 0;
    let sec = totalSec % 60;
    if (min > 99) { min = 99; sec = 99; }

    // Draw total time
    let ix = TIMEX * 8 + 1;
    VH.VWB_DrawPic(ix, TIMEY * 8, graphicnums.L_NUM0PIC + ((min / 10) | 0));
    ix += 16;
    VH.VWB_DrawPic(ix, TIMEY * 8, graphicnums.L_NUM0PIC + (min % 10));
    ix += 16;
    Write(ix / 8, TIMEY, ':');
    ix += 8;
    VH.VWB_DrawPic(ix, TIMEY * 8, graphicnums.L_NUM0PIC + ((sec / 10) | 0));
    ix += 16;
    VH.VWB_DrawPic(ix, TIMEY * 8, graphicnums.L_NUM0PIC + (sec % 10));

    // Draw ratios
    Write(RATIOX + 24 - kr.toString().length * 2, RATIOY, kr.toString());
    Write(RATIOX + 24 - sr.toString().length * 2, RATIOY + 2, sr.toString());
    Write(RATIOX + 24 - tr.toString().length * 2, RATIOY + 4, tr.toString());

    VH.setFontNumber(1);

    VH.VW_UpdateScreen();
    await VH.VW_FadeIn();

    await IN.IN_Ack();
    await VH.VW_FadeOut();

    // Show end text
    const { EndText } = await import('./wl_text');
    await EndText();
}

//===========================================================================
// CheckHighScore
//===========================================================================

export async function CheckHighScore(score: number, _other: number): Promise<void> {
    let placed = -1;

    // Find insertion point
    for (let i = 0; i < US.Scores.length; i++) {
        if (score > US.Scores[i].score) {
            placed = i;
            // Shift scores down
            for (let j = US.Scores.length - 1; j > i; j--) {
                US.Scores[j] = { ...US.Scores[j - 1] };
            }
            US.Scores[i] = {
                name: '',
                score: score,
                completed: gamestate.mapon,
                episode: gamestate.episode,
            };
            break;
        }
    }

    // Draw high scores
    CA.CA_CacheGrChunk(graphicnums.HIGHSCORESPIC);
    CA.CA_CacheGrChunk(STARTFONT);
    CA.CA_CacheGrChunk(STARTFONT + 1);

    ClearSplitVWB();

    VH.VWB_DrawPic(0, 0, graphicnums.HIGHSCORESPIC);
    VH.VW_UpdateScreen();
    await VH.VW_FadeIn();

    // If placed, prompt for name entry
    if (placed >= 0) {
        VH.setFontNumber(0);
        SETFONTCOLOR(HIGHLIGHT, BKGDCOLOR);

        // Name input using US_LineInput
        const buf = { value: '' };
        const x = 48;
        const y = 62 + placed * 13;

        VH.setPx(x);
        VH.setPy(y);
        VH.VWB_DrawPropString('_');
        VH.VW_UpdateScreen();

        const result = await US.US_LineInput(x, y, buf, '', true, US.MaxHighName, 120);
        if (result && buf.value.length > 0) {
            US.Scores[placed].name = buf.value;
        } else {
            US.Scores[placed].name = 'Player';
        }
    }

    VH.VW_UpdateScreen();
    await IN.IN_Ack();
    await VH.VW_FadeOut();
}

//===========================================================================
// FreeMusic
//===========================================================================

export function FreeMusic(): void {
    // Free cached music - in browser this is a no-op
}
