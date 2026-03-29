// WL_TEXT.TS
// Ported from WL_TEXT.C - Text display routines

import * as VL from './id_vl';
import * as VH from './id_vh';
import * as CA from './id_ca';
import * as IN from './id_in';
import * as US from './id_us_1';
import * as SD from './id_sd';
import { graphicnums, STARTPICS } from './gfxv_wl1';
import { gamestate } from './wl_main';
import { SETFONTCOLOR } from './wl_def';

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
// ParseNumber - parse a numeric value from text
//===========================================================================

function ParseNumber(text: string, idx: number): { value: number; newIdx: number } {
    let num = 0;
    while (idx < text.length && text[idx] >= '0' && text[idx] <= '9') {
        num = num * 10 + (text.charCodeAt(idx) - 48);
        idx++;
    }
    return { value: num, newIdx: idx };
}

//===========================================================================
// TimedT - check for timeout or key press
//===========================================================================

async function TimedT(): Promise<boolean> {
    IN.IN_ProcessEvents();
    if (IN.LastScan || IN.IN_CheckAck()) return true;
    await new Promise(resolve => setTimeout(resolve, 1));
    return false;
}

//===========================================================================
// BackPage - go back one page (stub - browser can't easily rewind)
//===========================================================================

function BackPage(_text: string, _idx: number): number {
    // In the original, this scanned backward for ^P markers.
    // We simplify for the browser port.
    return 0;
}

//===========================================================================
// CacheLayoutGraphics - cache any graphics referenced by ^G commands
//===========================================================================

function CacheLayoutGraphics(text: string): void {
    let idx = 0;
    while (idx < text.length) {
        if (text[idx] === '^' && idx + 1 < text.length) {
            if (text[idx + 1] === 'G') {
                idx += 2;
                const result = ParseNumber(text, idx);
                const grNum = result.value;
                idx = result.newIdx;
                if (idx < text.length && text[idx] === ',') idx++;
                // skip x,y
                const rx = ParseNumber(text, idx);
                idx = rx.newIdx;
                if (idx < text.length && text[idx] === ',') idx++;
                const ry = ParseNumber(text, idx);
                idx = ry.newIdx;
                CA.CA_CacheGrChunk(grNum);
            } else {
                idx += 2;
            }
        } else {
            idx++;
        }
    }
}

//===========================================================================
// ShowArticle - display text article (help/end text) with full markup
//
// Markup commands:
//   ^P  - Page break
//   ^E  - End of article
//   ^C<n> - Change text color to palette index n
//   ^G<n>,<x>,<y> - Draw graphic chunk n at pixel position (x,y)
//   ^T<n> - Timed pause of n 70ths
//   ^B<n> - Set background color
//   ^L<x>,<y> - Position text cursor at (x,y) in characters
//===========================================================================

async function ShowArticle(text: string): Promise<void> {
    CacheLayoutGraphics(text);

    let idx = 0;
    let rowon = 0;
    let page = 0;
    let numpages = 0;

    // Count pages first
    let tmp = 0;
    let pages = 1;
    while (tmp < text.length) {
        if (text[tmp] === '^') {
            if (tmp + 1 < text.length && text[tmp + 1] === 'P') pages++;
            if (tmp + 1 < text.length && text[tmp + 1] === 'E') break;
        }
        tmp++;
    }
    numpages = pages;

    let done = false;

    while (!done && idx < text.length) {
        // Clear screen for new page
        VL.VL_Bar(0, 0, 320, 200, BACKCOLOR);

        let textY = TOPMARGIN;
        let textX = LEFTMARGIN;
        rowon = 0;

        // Set default font
        VH.setFontNumber(0);
        VH.setFontColor(0x7c); // default text color for articles
        VH.setBackColor(BACKCOLOR);

        // Process text for this page
        let pageComplete = false;
        while (!pageComplete && idx < text.length && rowon < TEXTROWS) {
            const ch = text[idx];

            if (ch === '^') {
                idx++;
                if (idx >= text.length) break;

                const cmd = text[idx];
                idx++;

                switch (cmd) {
                    case 'P': // Page break
                        pageComplete = true;
                        break;

                    case 'E': // End
                        pageComplete = true;
                        done = true;
                        break;

                    case 'C': { // Color change
                        const result = ParseNumber(text, idx);
                        idx = result.newIdx;
                        VH.setFontColor(result.value);
                        break;
                    }

                    case 'G': { // Graphic
                        const grResult = ParseNumber(text, idx);
                        idx = grResult.newIdx;
                        const grNum = grResult.value;
                        if (idx < text.length && text[idx] === ',') idx++;
                        const gxResult = ParseNumber(text, idx);
                        idx = gxResult.newIdx;
                        if (idx < text.length && text[idx] === ',') idx++;
                        const gyResult = ParseNumber(text, idx);
                        idx = gyResult.newIdx;
                        VH.VWB_DrawPic(gxResult.value, gyResult.value, grNum);
                        break;
                    }

                    case 'T': { // Timed pause
                        const result = ParseNumber(text, idx);
                        idx = result.newIdx;
                        const delay = (result.value * 1000 / 70) | 0;
                        VL.VL_UpdateScreen();
                        await new Promise(resolve => setTimeout(resolve, delay));
                        break;
                    }

                    case 'B': { // Background color
                        const result = ParseNumber(text, idx);
                        idx = result.newIdx;
                        VH.setBackColor(result.value);
                        break;
                    }

                    case 'L': { // Position cursor
                        const lxResult = ParseNumber(text, idx);
                        idx = lxResult.newIdx;
                        if (idx < text.length && text[idx] === ',') idx++;
                        const lyResult = ParseNumber(text, idx);
                        idx = lyResult.newIdx;
                        textX = LEFTMARGIN + lxResult.value * 8;
                        textY = TOPMARGIN + lyResult.value * FONTHEIGHT;
                        break;
                    }

                    default:
                        // Unknown command, skip
                        break;
                }
                continue;
            }

            if (ch === '\n') {
                idx++;
                textX = LEFTMARGIN;
                textY += FONTHEIGHT;
                rowon++;
                continue;
            }

            // Regular character - collect a word
            let word = '';
            while (idx < text.length && text[idx] !== '\n' && text[idx] !== '^' && text[idx] !== ' ') {
                word += text[idx];
                idx++;
            }

            // Measure the word
            const measured = VH.VW_MeasurePropString(word);

            // Word wrap check
            if (textX + measured.width > 320 - RIGHTMARGIN) {
                textX = LEFTMARGIN;
                textY += FONTHEIGHT;
                rowon++;
                if (rowon >= TEXTROWS) {
                    pageComplete = true;
                    break;
                }
            }

            // Draw the word
            VH.setPx(textX);
            VH.setPy(textY);
            VH.VWB_DrawPropString(word);
            textX = VH.px;

            // Handle space
            if (idx < text.length && text[idx] === ' ') {
                textX += VH.VW_MeasurePropString(' ').width;
                idx++;
            }
        }

        // Draw page number
        VH.setFontColor(0x7c);
        VH.setPx(213);
        VH.setPy(183);
        VH.VWB_DrawPropString('pg ' + (page + 1) + ' of ' + numpages);

        VL.VL_UpdateScreen();
        page++;

        if (done) break;

        // Wait for key with page navigation
        IN.IN_ClearKeysDown();
        let waitDone = false;
        while (!waitDone) {
            IN.IN_ProcessEvents();
            if (IN.LastScan) {
                if (IN.IN_KeyDown(IN.sc_Escape)) {
                    return;
                }
                waitDone = true;
            }
            await new Promise(resolve => setTimeout(resolve, 16));
        }
        IN.IN_ClearKeysDown();
    }

    // Wait for final acknowledgment if ended via ^E
    if (done) {
        IN.IN_ClearKeysDown();
        await IN.IN_Ack();
    }
}

//===========================================================================
// HelpScreens
//===========================================================================

export async function HelpScreens(): Promise<void> {
    // Try to load help text from cached graphics
    const helpChunk = graphicnums.T_HELPART;
    CA.CA_CacheGrChunk(helpChunk);
    const data = CA.grsegs[helpChunk];

    if (data && data.length > 0) {
        // Decode text from cached data
        const decoder = new TextDecoder('ascii');
        const text = decoder.decode(data);
        await ShowArticle(text);
    } else {
        // Fallback built-in help text
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
            '  Tab - Automap (debug)',
            '',
            'F-KEYS:',
            '  F1 - Help',
            '  F2 - Save Game',
            '  F3 - Load Game',
            '  F4 - Sound Options',
            '  F5 - Change View Size',
            '  F6 - Controls',
            '  F8 - Quick Save',
            '  F9 - Quick Load',
            '  F10 - Quit',
            '',
            'TIPS:',
            '  Search for secret push walls',
            '  Collect treasure for bonus points',
            '  Find keys to open locked doors',
            '',
            '^E',
        ].join('\n');

        await ShowArticle(helpText);
    }
}

//===========================================================================
// EndText
//===========================================================================

export async function EndText(): Promise<void> {
    // T_ENDART chunks don't exist in shareware (WL1), use fallback text
    const episode = gamestate.episode;

    const endTexts = [
        'You have escaped from Castle Wolfenstein!\n\nYour escape comes at a cost,\nbut the fight continues...\n\n^E',
        'Dr. Schabbs has been defeated!\n\nThe mutant army is no more.\n\n^E',
        'Hitler is dead!\n\nThe war may finally end.\n\n^E',
        'Otto Giftmacher is no more!\n\nHis chemical weapons are destroyed.\n\n^E',
        'Gretel Grosse has fallen!\n\nThe castle is secure.\n\n^E',
        'General Fettgesicht is eliminated!\n\nVictory is yours!\n\n^E',
    ];

    const text = endTexts[episode] || endTexts[0];
    await ShowArticle(text);
}
