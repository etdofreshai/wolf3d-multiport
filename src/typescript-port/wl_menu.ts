// WL_MENU.TS
// Ported from WL_MENU.H / WL_MENU.C - Menu system (stub)
// Full menu implementation would be very large; this provides the constants and interface

import { musicnames } from './audiowl6';

//===========================================================================
// Menu colors (WL6, non-SPEAR)
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
// Menu strings (from FOREIGN.H)
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
// Menu item type
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
// US_ControlPanel - Main menu entry point (stub)
//===========================================================================

export function US_ControlPanel(scancode: number): void {
    // This is a massive function that handles the entire menu system.
    // For now, this is a stub. A full implementation would handle:
    // - New Game selection (episode/difficulty)
    // - Sound settings
    // - Control settings
    // - Load/Save game
    // - Change view size
    // - View high scores
    // - Quit confirmation
    console.log('US_ControlPanel called with scancode:', scancode);
}
