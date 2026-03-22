// WL_MENU.TS
// Ported from WL_MENU.C - Menu system

import * as VL from './id_vl';
import * as VH from './id_vh';
import * as CA from './id_ca';
import * as IN from './id_in';
import * as SD from './id_sd';
import * as US from './id_us_1';
import { graphicnums } from './gfxv_wl6';
import { musicnames } from './audiowl6';
import { soundnames } from './audiowl6';
import { gamestate, NewGame, NewViewSize, viewsize, setViewSize, mouseadjustment } from './wl_main';
import { exit_t } from './wl_def';

//===========================================================================
// Menu colors
//===========================================================================

export const BORDCOLOR = 0x29;
export const BORD2COLOR = 0x23;
export const DEACTIVE = 0x2b;
export const BKGDCOLOR = 0x2d;
export const STRIPE = 0x2c;
export const READCOLOR = 0x4a;
export const READHCOLOR = 0x47;
export const VIEWCOLOR = 0x7f;
export const TEXTCOLOR = 0x17;
export const HIGHLIGHT = 0x13;

export const MENUSONG = musicnames.WONDERIN_MUS;
export const INTROSONG = musicnames.NAZI_NOR_MUS;

export const SENSITIVE = 60;
export const CENTER = SENSITIVE * 2;

export const MENU_X = 76;
export const MENU_Y = 55;
export const MENU_W = 178;
export const MENU_H = 13 * 10 + 6;

//===========================================================================
// Menu strings
//===========================================================================

export const STR_NG = 'New Game';
export const STR_SD = 'Sound';
export const STR_CL = 'Control';
export const STR_LG = 'Load Game';
export const STR_SG = 'Save Game';
export const STR_CV = 'Change View';
export const STR_VS = 'View Scores';
export const STR_EG = 'End Game';
export const STR_BD = 'Back to Demo';
export const STR_QT = 'Quit';

//===========================================================================
// Menu item types
//===========================================================================

export interface CP_iteminfo {
    x: number;
    y: number;
    amount: number;
    curpos: number;
    indent: number;
}

export interface CP_itemtype {
    active: number;
    string: string;
    routine: ((temp1: number) => void) | null;
}

//===========================================================================
// Menu state
//===========================================================================

let lastgamemenunum = 0;
let menux = 0;
let menuy = 0;

const mainItems: CP_iteminfo = { x: MENU_X, y: MENU_Y, amount: 10, curpos: 0, indent: 24 };
const mainMenu: CP_itemtype[] = [
    { active: 1, string: STR_NG, routine: CP_NewGame },
    { active: 1, string: STR_SD, routine: CP_Sound },
    { active: 1, string: STR_CL, routine: CP_Control },
    { active: 1, string: STR_LG, routine: CP_LoadGame },
    { active: 0, string: STR_SG, routine: CP_SaveGame },
    { active: 1, string: STR_CV, routine: CP_ChangeView },
    { active: 1, string: STR_VS, routine: CP_ViewScores },
    { active: 0, string: STR_EG, routine: CP_EndGame },
    { active: 1, string: STR_BD, routine: null },
    { active: 1, string: STR_QT, routine: CP_Quit },
];

//===========================================================================
// DrawMenu
//===========================================================================

function DrawMenu(items: CP_iteminfo, menu: CP_itemtype[]): void {
    let x = items.x + items.indent;
    let y = items.y;

    for (let i = 0; i < items.amount; i++) {
        if (menu[i].active) {
            VH.VWB_DrawPropString(menu[i].string);
        }
        y += 13;
    }
}

//===========================================================================
// DrawWindow
//===========================================================================

function DrawWindow(x: number, y: number, w: number, h: number, wcolor: number): void {
    VL.VL_Bar(x, y, w, h, wcolor);
    VL.VL_Hlin(x, y, w, BORD2COLOR);
    VL.VL_Hlin(x, y + h - 1, w, BORDCOLOR);
    VL.VL_Vlin(x, y, h, BORD2COLOR);
    VL.VL_Vlin(x + w - 1, y, h, BORDCOLOR);
}

//===========================================================================
// HandleMenu
//===========================================================================

function HandleMenu(items: CP_iteminfo, menu: CP_itemtype[], callback: ((which: number) => void) | null): number {
    let which = items.curpos;
    // Simple menu - in a real implementation this would loop waiting for input
    // For now, return current selection
    items.curpos = which;
    return which;
}

//===========================================================================
// Sub-menu functions
//===========================================================================

function CP_NewGame(unused: number): void {
    // Display episode/difficulty selection
    // For now, start game with defaults
    NewGame(gamestate.difficulty, 0);
}

function CP_Sound(unused: number): void {
    // Sound settings submenu
}

function CP_Control(unused: number): void {
    // Control settings submenu
}

function CP_LoadGame(unused: number): void {
    // Load game submenu
}

function CP_SaveGame(unused: number): void {
    // Save game submenu
}

function CP_ChangeView(unused: number): void {
    // View size adjustment
    let newsize = viewsize;
    // Would show slider UI
    NewViewSize(newsize);
}

function CP_ViewScores(unused: number): void {
    // Show high scores
}

function CP_EndGame(unused: number): void {
    // End current game
}

function CP_Quit(unused: number): void {
    // Quit confirmation
}

//===========================================================================
// US_ControlPanel - Main menu entry point
//===========================================================================

export function US_ControlPanel(scancode: number): void {
    // Draw the main menu background
    CA.CA_CacheGrChunk(graphicnums.C_OPTIONSPIC);

    // Draw menu window
    DrawWindow(MENU_X - 8, MENU_Y - 3, MENU_W, MENU_H, BKGDCOLOR);

    // Draw menu items
    DrawMenu(mainItems, mainMenu);

    // Handle menu selection
    const which = HandleMenu(mainItems, mainMenu, null);

    if (which >= 0 && mainMenu[which].routine) {
        mainMenu[which].routine!(0);
    }

    // Redraw the play screen when menu closes
    VL.VL_UpdateScreen();
}

//===========================================================================
// Message / Confirm helpers
//===========================================================================

export function Message(str: string): void {
    US.US_CenterWindow(str.length + 2, 3);
    US.US_Print(str);
    VL.VL_UpdateScreen();
}

export async function Confirm(str: string): Promise<boolean> {
    Message(str);
    // Wait for Y/N
    while (true) {
        IN.IN_ProcessEvents();
        if (IN.IN_KeyDown(0x15)) return true;   // Y key
        if (IN.IN_KeyDown(0x31)) return false;   // N key
        if (IN.IN_KeyDown(IN.sc_Escape)) return false;
        await new Promise(r => setTimeout(r, 16));
    }
}
