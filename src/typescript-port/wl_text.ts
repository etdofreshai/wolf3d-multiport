// WL_TEXT.TS
// Ported from WL_TEXT.C - Text display routines

import * as VL from './id_vl';
import * as VH from './id_vh';
import * as CA from './id_ca';
import * as IN from './id_in';
import * as US from './id_us_1';
import { graphicnums } from './gfxv_wl6';
import { gamestate } from './wl_main';

//===========================================================================
// Constants
//===========================================================================

export const helpfilename = 'HELPART.';
export const endfilename = 'ENDART1.';

const BACKCOLOR = 0x11;
const WORDLIMIT = 80;
const FONTHEIGHT = 10;
const TOPMARGIN = 16;
const BOTTOMMARGIN = 32;
const LEFTMARGIN = 16;
const RIGHTMARGIN = 16;
const PICMARGIN = 8;
const TEXTROWS = ((200 - TOPMARGIN - BOTTOMMARGIN) / FONTHEIGHT) | 0;
const TEXTCOLS = ((320 - LEFTMARGIN - RIGHTMARGIN) / 8) | 0;

//===========================================================================
// RipToEOL - skip past end of line in text
//===========================================================================

function RipToEOL(text: string, idx: number): number {
    while (idx < text.length && text[idx] !== '\n') idx++;
    return idx + 1;
}

//===========================================================================
// ParseStuff - parse text for display
//===========================================================================

function ParseStuff(text: string, idx: number): { newIdx: number; line: string } {
    let line = '';
    while (idx < text.length) {
        const ch = text[idx];
        if (ch === '\n' || ch === '^') break;
        line += ch;
        idx++;
    }
    return { newIdx: idx, line };
}

//===========================================================================
// ShowArticle - display text article (help/end text)
//===========================================================================

async function ShowArticle(text: string): Promise<void> {
    VL.VL_Bar(0, 0, 320, 200, BACKCOLOR);

    let idx = 0;
    let y = TOPMARGIN;
    let page = 0;

    while (idx < text.length) {
        // Display one page of text
        VL.VL_Bar(0, 0, 320, 200, BACKCOLOR);
        y = TOPMARGIN;

        for (let row = 0; row < TEXTROWS && idx < text.length; row++) {
            const result = ParseStuff(text, idx);
            idx = result.newIdx;

            VH.setPx(LEFTMARGIN);
            VH.setPy(y);
            VH.VWB_DrawPropString(result.line);
            y += FONTHEIGHT;

            // Skip newline
            if (idx < text.length && text[idx] === '\n') idx++;

            // Page break
            if (idx < text.length && text[idx] === '^') {
                idx++;
                if (idx < text.length && text[idx] === 'P') {
                    idx++;
                    break;  // page break
                }
                if (idx < text.length && text[idx] === 'E') {
                    idx = text.length;  // end
                    break;
                }
            }
        }

        // Draw page number
        VH.setPx(213);
        VH.setPy(183);
        VH.VWB_DrawPropString('pg ' + (page + 1));

        VL.VL_UpdateScreen();
        page++;

        // Wait for key
        IN.IN_ClearKeysDown();
        let done = false;
        while (!done) {
            IN.IN_ProcessEvents();
            if (IN.LastScan) {
                if (IN.IN_KeyDown(IN.sc_Escape)) {
                    return;
                }
                done = true;
            }
            await new Promise(resolve => setTimeout(resolve, 16));
        }
        IN.IN_ClearKeysDown();
    }
}

//===========================================================================
// HelpScreens
//===========================================================================

export async function HelpScreens(): Promise<void> {
    // In the original, this loads HELPART.WL6 and displays it
    // For the browser port, we show a simplified help screen

    const helpText = [
        'WOLFENSTEIN 3-D HELP',
        '',
        'CONTROLS:',
        '  Arrow Keys - Move/Turn',
        '  Ctrl - Fire',
        '  Space - Open doors/Use',
        '  Alt - Strafe',
        '  Shift - Run',
        '',
        '  1-4 - Select weapon',
        '  Esc - Menu',
        '',
        'TIPS:',
        '  Search for secret push walls',
        '  Collect treasure for bonus points',
        '  Find keys to open locked doors',
        '',
        'Press any key to continue...',
    ].join('\n');

    await ShowArticle(helpText);
}

//===========================================================================
// EndText
//===========================================================================

export async function EndText(): Promise<void> {
    // Display end-of-episode text
    const episode = gamestate.episode;

    const endTexts = [
        // Episode 1
        'You have escaped from Castle Wolfenstein!\n\nYour escape comes at a cost,\nbut the fight continues...\n\n^E',
        // Episode 2
        'Dr. Schabbs has been defeated!\n\nThe mutant army is no more.\n\n^E',
        // Episode 3
        'Hitler is dead!\n\nThe war may finally end.\n\n^E',
        // Episode 4
        'Otto Giftmacher is no more!\n\nHis chemical weapons are destroyed.\n\n^E',
        // Episode 5
        'Gretel Grosse has fallen!\n\nThe castle is secure.\n\n^E',
        // Episode 6
        'General Fettgesicht is eliminated!\n\nVictory is yours!\n\n^E',
    ];

    const text = endTexts[episode] || endTexts[0];
    await ShowArticle(text);
}
