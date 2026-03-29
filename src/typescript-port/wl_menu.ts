// WL_MENU.TS
// Ported from WL_MENU.C - Menu system
// by John Romero (C) 1992 Id Software, Inc.

import * as VL from './id_vl';
import * as VH from './id_vh';
import * as CA from './id_ca';
import * as IN from './id_in';
import * as SD from './id_sd';
import * as US from './id_us_1';
import { graphicnums, STARTFONT } from './gfxv_wl1';
import { musicnames } from './audiowl1';
import { soundnames } from './audiowl1';
import { gamestate, NewGame, NewViewSize, viewsize, setViewSize, mouseadjustment, startgame, setStartGame, loadedgame, setLoadedGame } from './wl_main';
import { exit_t, weapontype, SETFONTCOLOR } from './wl_def';
import { playstate, setPlaystate, godmode } from './wl_play';

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

// Sub-menu positions
const SM_X = 48;
const SM_Y1 = 20;
const SM_W = 250;
const SM_H = 13 * 12 + 20;

const CTL_X = 24;
const CTL_Y = 70;
const CTL_W = 284;
const CTL_H = 13 * 6 + 20;

const LSM_X = 85;
const LSM_Y = 55;
const LSM_W = 175;
const LSM_H = 13 * 10 + 10;

const NE_X = 10;
const NE_Y = 20;
const NE_W = 300;
const NE_H = 13 * 11 + 20;

const NM_X = 50;
const NM_Y = 100;
const NM_W = 225;
const NM_H = 13 * 4 + 6;

const CST_Y = 57;

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

const STR_NONE = 'None';
const STR_PC = 'PC Speaker';
const STR_ALSB = 'AdLib/Sound Blaster';
const STR_DISNEY = 'Disney Sound Source';
const STR_SB = 'Sound Blaster';

const STR_MOUSEEN = 'Mouse Enabled';
const STR_JOYEN = 'Joystick Enabled';
const STR_PORT2 = 'Use joystick port 2';
const STR_GAMEPAD = 'Gravis GamePad Enabled';
const STR_SENS = 'Mouse Sensitivity';
const STR_CUSTOM = 'Customize controls';

const STR_DADDY = 'Can I play, Daddy?';
const STR_HURTME = 'Don\'t hurt me.';
const STR_BRINGEM = 'Bring \'em on!';
const STR_DEATH = 'I am Death incarnate!';

const STR_GAME = 'Game';
const STR_DEMO = 'Demo';
const STR_LGC = 'Load game called\n"';
const STR_SAVING = 'Saving';
const STR_LOADING = 'Loading';

const ENDGAMESTR = 'Are you sure you want\nto end the game you\nare playing? (Y or N):';
const CURGAME = 'You are currently in\na game. Proceeding will\nerase old game. OK? (Y or N):';

const STR_ENDGAME1 = 'We owe you a great debt, Mr.';
const STR_ENDGAME2 = 'You have earned the title of';

const STR_CHEATER1 = 'You now have 100% Health,';
const STR_CHEATER2 = '99 Ammo and both Keys!';
const STR_CHEATER3 = '';
const STR_CHEATER4 = 'Note that you have also been';
const STR_CHEATER5 = 'charged a hefty penalty score.';

// Quit messages
const endStrings = [
    'Dost thou wish to\nleave with such hasty\nabandon?',
    'Chickening out...\nalready?',
    'Press N for more carnage.\nPress Y to be a weenie.',
    'So, you think you can\nquit this easily, huh?',
    'Press N to save the world.\nPress Y to abandon it in\nits hour of need.',
    'Press N if you are brave.\nPress Y to cower in shame.',
    'Heroes, press N.\nWimps, press Y.',
    'You are at an intersection.\nA sign says, \'Press Y to quit.\'\n>',
    'For guns and glory, press N.\nFor work and worry, press Y.',
];

//===========================================================================
// Menu enums for index access
//===========================================================================

const enum MainMenuItem {
    newgame = 0,
    soundm,
    control,
    loadgame,
    savegame,
    changeview,
    viewscores,
    backtodemo,
    quit
}

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

// Color tables for menu items
const color_hlite = [DEACTIVE, HIGHLIGHT, READHCOLOR, 0x67];
const color_norml = [DEACTIVE, TEXTCOLOR, READCOLOR, 0x6b];

//===========================================================================
// Menu state
//===========================================================================

let StartGame = 0;
let SoundStatus = 1;
let pickquick = 0;

const SaveGamesAvail: boolean[] = new Array(10).fill(false);
const SaveGameNames: string[] = new Array(10).fill('');

const EpisodeSelect = [1, 1, 1, 1, 1, 1];

const mainItems: CP_iteminfo = { x: MENU_X, y: MENU_Y, amount: 9, curpos: 0, indent: 24 };
const mainMenu: CP_itemtype[] = [
    { active: 1, string: STR_NG, routine: (n) => CP_NewGame(n) },
    { active: 1, string: STR_SD, routine: (n) => CP_Sound(n) },
    { active: 1, string: STR_CL, routine: (n) => CP_Control(n) },
    { active: 1, string: STR_LG, routine: (n) => CP_LoadGame(n) },
    { active: 0, string: STR_SG, routine: (n) => CP_SaveGame(n) },
    { active: 1, string: STR_CV, routine: (n) => CP_ChangeView(n) },
    { active: 1, string: STR_VS, routine: (n) => CP_ViewScores(n) },
    { active: 1, string: STR_BD, routine: null },
    { active: 1, string: STR_QT, routine: (n) => CP_Quit(n) },
];

const SndItems: CP_iteminfo = { x: SM_X, y: SM_Y1, amount: 12, curpos: 0, indent: 52 };
const SndMenu: CP_itemtype[] = [
    { active: 1, string: STR_NONE, routine: null },
    { active: 1, string: STR_PC, routine: null },
    { active: 1, string: STR_ALSB, routine: null },
    { active: 0, string: '', routine: null },
    { active: 0, string: '', routine: null },
    { active: 1, string: STR_NONE, routine: null },
    { active: 1, string: STR_DISNEY, routine: null },
    { active: 1, string: STR_SB, routine: null },
    { active: 0, string: '', routine: null },
    { active: 0, string: '', routine: null },
    { active: 1, string: STR_NONE, routine: null },
    { active: 1, string: STR_ALSB, routine: null },
];

const CtlItems: CP_iteminfo = { x: CTL_X, y: CTL_Y, amount: 6, curpos: -1, indent: 56 };
const CtlMenu: CP_itemtype[] = [
    { active: 0, string: STR_MOUSEEN, routine: null },
    { active: 0, string: STR_JOYEN, routine: null },
    { active: 0, string: STR_PORT2, routine: null },
    { active: 0, string: STR_GAMEPAD, routine: null },
    { active: 0, string: STR_SENS, routine: (n) => MouseSensitivity(n) },
    { active: 1, string: STR_CUSTOM, routine: (n) => CustomControls(n) },
];

const LSItems: CP_iteminfo = { x: LSM_X, y: LSM_Y, amount: 10, curpos: 0, indent: 24 };
const LSMenu: CP_itemtype[] = Array.from({ length: 10 }, () => ({ active: 1, string: '', routine: null }));

const NewEitems: CP_iteminfo = { x: NE_X, y: NE_Y, amount: 11, curpos: 0, indent: 88 };
const NewEmenu: CP_itemtype[] = [
    { active: 1, string: 'Episode 1\nEscape from Wolfenstein', routine: null },
    { active: 0, string: '', routine: null },
    { active: 3, string: 'Episode 2\nOperation: Eisenfaust', routine: null },
    { active: 0, string: '', routine: null },
    { active: 3, string: 'Episode 3\nDie, Fuhrer, Die!', routine: null },
    { active: 0, string: '', routine: null },
    { active: 3, string: 'Episode 4\nA Dark Secret', routine: null },
    { active: 0, string: '', routine: null },
    { active: 3, string: 'Episode 5\nTrail of the Madman', routine: null },
    { active: 0, string: '', routine: null },
    { active: 3, string: 'Episode 6\nConfrontation', routine: null },
];

const NewItems: CP_iteminfo = { x: NM_X, y: NM_Y, amount: 4, curpos: 2, indent: 24 };
const NewMenu: CP_itemtype[] = [
    { active: 1, string: STR_DADDY, routine: null },
    { active: 1, string: STR_HURTME, routine: null },
    { active: 1, string: STR_BRINGEM, routine: null },
    { active: 1, string: STR_DEATH, routine: null },
];

//===========================================================================
// ClearMScreen - Clear the menu screen
//===========================================================================

function ClearMScreen(): void {
    VL.VL_Bar(0, 0, 320, 200, BORDCOLOR);
}

//===========================================================================
// DrawStripes - Draw decorative stripes at top of menu
//===========================================================================

function DrawStripes(y: number): void {
    VL.VL_Bar(0, y, 320, 24, 0);
    for (let i = 0; i < 24; i += 2) {
        VL.VL_Hlin(0, y + i, 320, STRIPE);
    }
}

//===========================================================================
// ShootSnd - Play menu selection sound
//===========================================================================

function ShootSnd(): void {
    SD.SD_PlaySound(soundnames.SHOOTSND);
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
// DrawOutline - Draw selection outline around a menu item
//===========================================================================

function DrawOutline(x: number, y: number, w: number, h: number, color1: number, color2: number): void {
    VL.VL_Hlin(x, y, w, color1);
    VL.VL_Hlin(x, y + h - 1, w, color2);
    VL.VL_Vlin(x, y, h, color1);
    VL.VL_Vlin(x + w - 1, y, h, color2);
}

//===========================================================================
// DrawMenu
//===========================================================================

function DrawMenu(items: CP_iteminfo, menu: CP_itemtype[]): void {
    const x = items.x + items.indent;

    for (let i = 0; i < items.amount; i++) {
        if (menu[i].active) {
            const color = color_norml[menu[i].active];

            VH.setFontColor(color);
            VH.setBackColor(BKGDCOLOR);

            VH.setPx(x);
            VH.setPy(items.y + i * 13);
            VH.VWB_DrawPropString(menu[i].string);
        }
    }
}

//===========================================================================
// DrawMenuGun - draw the cursor gun next to a menu item
//===========================================================================

function DrawMenuGun(items: CP_iteminfo, which: number): void {
    VH.VWB_DrawPic(items.x, items.y + which * 13 - 2, graphicnums.C_CURSOR1PIC);
}

//===========================================================================
// EraseMenuGun - erase the cursor at the old position
//===========================================================================

function EraseMenuGun(items: CP_iteminfo, which: number): void {
    VL.VL_Bar(items.x - 1, items.y + which * 13 - 2, 25, 16, BKGDCOLOR);
}

//===========================================================================
// PrintMenuHighlight
//===========================================================================

function PrintMenuHighlight(items: CP_iteminfo, menu: CP_itemtype[], which: number, hilight: boolean): void {
    const x = items.x + items.indent;
    const y = items.y + which * 13;

    VH.setFontColor(hilight ? color_hlite[menu[which].active] : color_norml[menu[which].active]);
    VH.setBackColor(BKGDCOLOR);
    VH.setPx(x);
    VH.setPy(y);
    VH.VWB_DrawPropString(menu[which].string);
}

//===========================================================================
// HandleMenu - async menu handler with keyboard/mouse input
//===========================================================================

async function HandleMenu(items: CP_iteminfo, menu: CP_itemtype[], callback: ((which: number) => void) | null): Promise<number> {
    let which = items.curpos;
    if (which < 0) which = 0;

    // Find first active item
    while (which < items.amount && !menu[which].active) which++;
    if (which >= items.amount) which = 0;

    // Draw initial cursor
    DrawMenuGun(items, which);
    PrintMenuHighlight(items, menu, which, true);
    VL.VL_UpdateScreen();

    IN.IN_ClearKeysDown();

    let done = false;
    let lastDir = 0;

    while (!done) {
        IN.IN_ProcessEvents();

        const oldWhich = which;

        // Check keyboard
        if (IN.IN_KeyDown(IN.sc_UpArrow)) {
            if (lastDir !== -1) {
                lastDir = -1;
                // Move up to previous active item
                let next = which - 1;
                while (next >= 0 && !menu[next].active) next--;
                if (next >= 0) {
                    EraseMenuGun(items, which);
                    PrintMenuHighlight(items, menu, which, false);
                    which = next;
                    DrawMenuGun(items, which);
                    PrintMenuHighlight(items, menu, which, true);
                    SD.SD_PlaySound(soundnames.MOVEGUN1SND);
                }
            }
        } else if (IN.IN_KeyDown(IN.sc_DownArrow)) {
            if (lastDir !== 1) {
                lastDir = 1;
                // Move down to next active item
                let next = which + 1;
                while (next < items.amount && !menu[next].active) next++;
                if (next < items.amount) {
                    EraseMenuGun(items, which);
                    PrintMenuHighlight(items, menu, which, false);
                    which = next;
                    DrawMenuGun(items, which);
                    PrintMenuHighlight(items, menu, which, true);
                    SD.SD_PlaySound(soundnames.MOVEGUN1SND);
                }
            }
        } else {
            lastDir = 0;
        }

        // Enter = select
        if (IN.IN_KeyDown(IN.sc_Return) || IN.IN_KeyDown(IN.sc_Space)) {
            items.curpos = which;
            IN.IN_ClearKeysDown();

            if (menu[which].routine) {
                ShootSnd();
                menu[which].routine!(0);
            }

            done = true;
            break;
        }

        // Escape = cancel
        if (IN.IN_KeyDown(IN.sc_Escape)) {
            IN.IN_ClearKeysDown();
            SD.SD_PlaySound(soundnames.ESCPRESSEDSND);
            items.curpos = which;
            return -1;
        }

        if (callback && oldWhich !== which) {
            callback(which);
        }

        VL.VL_UpdateScreen();
        await new Promise(resolve => setTimeout(resolve, 50));
    }

    items.curpos = which;
    return which;
}

//===========================================================================
// MenuFadeIn / MenuFadeOut
//===========================================================================

async function MenuFadeIn(): Promise<void> {
    await VL.VL_FadeIn(0, 255, VH.gamepal, 10);
}

async function MenuFadeOut(): Promise<void> {
    await VL.VL_FadeOut(0, 255, 0, 0, 0, 10);
}

//===========================================================================
// WaitKeyUp
//===========================================================================

function WaitKeyUp(): void {
    // Wait for all keys to be released
    IN.IN_ClearKeysDown();
}

//===========================================================================
// SetupControlPanel / CleanupControlPanel
//===========================================================================

function SetupControlPanel(): void {
    // Cache fonts
    CA.CA_CacheGrChunk(STARTFONT + 1);

    // Cache menu graphics
    CA.CA_CacheGrChunk(graphicnums.C_OPTIONSPIC);
    CA.CA_CacheGrChunk(graphicnums.C_CURSOR1PIC);
    CA.CA_CacheGrChunk(graphicnums.C_CURSOR2PIC);
    CA.CA_CacheGrChunk(graphicnums.C_MOUSELBACKPIC);

    VH.setFontNumber(1);
    SETFONTCOLOR(TEXTCOLOR, BKGDCOLOR);

    // Load saved game info from localStorage
    for (let i = 0; i < 10; i++) {
        try {
            const data = localStorage.getItem(`wolf3d_save_${i}`);
            if (data) {
                SaveGamesAvail[i] = true;
                const parsed = JSON.parse(data);
                SaveGameNames[i] = parsed.name || `Save ${i}`;
            } else {
                SaveGamesAvail[i] = false;
                SaveGameNames[i] = '';
            }
        } catch {
            SaveGamesAvail[i] = false;
            SaveGameNames[i] = '';
        }
    }
}

function CleanupControlPanel(): void {
    VH.setFontNumber(0);
    SETFONTCOLOR(0, 15);
}

//===========================================================================
// StartCPMusic
//===========================================================================

function StartCPMusic(song: number): void {
    // Music switching for control panel
    // For now, a stub - full music system handles this
}

//===========================================================================
// DrawMainMenu
//===========================================================================

function DrawMainMenu(): void {
    ClearMScreen();

    VH.VWB_DrawPic(112, 184, graphicnums.C_MOUSELBACKPIC);
    DrawStripes(10);
    VH.VWB_DrawPic(84, 0, graphicnums.C_OPTIONSPIC);

    DrawWindow(MENU_X - 8, MENU_Y - 3, MENU_W, MENU_H, BKGDCOLOR);

    // Change text based on in-game state
    if (US.ingame) {
        mainMenu[MainMenuItem.backtodemo].active = 2;
    } else {
        mainMenu[MainMenuItem.backtodemo].active = 1;
    }

    DrawMenu(mainItems, mainMenu);
    VH.VW_UpdateScreen();
}

//===========================================================================
// DrawNewEpisode
//===========================================================================

function DrawNewEpisode(): void {
    ClearMScreen();
    VH.VWB_DrawPic(112, 184, graphicnums.C_MOUSELBACKPIC);

    DrawWindow(NE_X - 4, NE_Y - 4, NE_W + 8, NE_H + 8, BKGDCOLOR);
    SETFONTCOLOR(READHCOLOR, BKGDCOLOR);
    US.setPrintY(2);
    US.setWindowX(0);
    US.US_CPrint('Which episode to play?');

    SETFONTCOLOR(TEXTCOLOR, BKGDCOLOR);
    DrawMenu(NewEitems, NewEmenu);

    // Draw episode graphics
    for (let i = 0; i < 6; i++) {
        VH.VWB_DrawPic(NE_X + 32, NE_Y + i * 26, graphicnums.C_EPISODE1PIC + i);
    }

    VH.VW_UpdateScreen();
}

//===========================================================================
// DrawNewGame
//===========================================================================

function DrawNewGame(): void {
    ClearMScreen();
    VH.VWB_DrawPic(112, 184, graphicnums.C_MOUSELBACKPIC);

    DrawWindow(NM_X - 5, NM_Y - 10, NM_W, NM_H, BKGDCOLOR);

    SETFONTCOLOR(READHCOLOR, BKGDCOLOR);
    VH.setPx(NM_X + 20);
    VH.setPy(NM_Y - 5);
    VH.VWB_DrawPropString('How tough are you?');

    DrawMenu(NewItems, NewMenu);

    // Draw difficulty pictures
    VH.VWB_DrawPic(NM_X + 185, NM_Y + 7, graphicnums.C_BABYMODEPIC + NewItems.curpos);

    VH.VW_UpdateScreen();
}

//===========================================================================
// DrawNewGameDiff - callback for difficulty selection
//===========================================================================

function DrawNewGameDiff(which: number): void {
    VH.VWB_DrawPic(NM_X + 185, NM_Y + 7, graphicnums.C_BABYMODEPIC + which);
}

//===========================================================================
// CP_NewGame
//===========================================================================

async function CP_NewGame(_unused: number): Promise<void> {
    // Episode selection
    DrawNewEpisode();
    await MenuFadeIn();

    const episodeWhich = await HandleMenu(NewEitems, NewEmenu, null);
    if (episodeWhich < 0) {
        await MenuFadeOut();
        return;
    }

    const episode = (episodeWhich / 2) | 0;
    ShootSnd();

    // Already in a game?
    if (US.ingame) {
        if (!(await Confirm(CURGAME))) {
            await MenuFadeOut();
            return;
        }
    }

    await MenuFadeOut();

    // Difficulty selection
    DrawNewGame();
    await MenuFadeIn();

    const diffWhich = await HandleMenu(NewItems, NewMenu, DrawNewGameDiff);
    if (diffWhich < 0) {
        await MenuFadeOut();
        return;
    }

    ShootSnd();
    NewGame(diffWhich, episode);
    StartGame = 1;
    await MenuFadeOut();

    pickquick = 0;
}

//===========================================================================
// CP_Sound
//===========================================================================

async function CP_Sound(_unused: number): Promise<void> {
    // Draw sound menu
    ClearMScreen();
    VH.VWB_DrawPic(112, 184, graphicnums.C_MOUSELBACKPIC);
    DrawStripes(10);
    VH.VWB_DrawPic(84, 0, graphicnums.C_FXTITLEPIC);

    DrawWindow(SM_X - 2, SM_Y1 - 5, SM_W, SM_H, BKGDCOLOR);

    // Draw sound titles
    SETFONTCOLOR(READHCOLOR, BKGDCOLOR);
    VH.setPx(SM_X + 10);
    VH.setPy(SM_Y1 - 1);
    VH.VWB_DrawPropString('Sound Effects');

    VH.setPx(SM_X + 10);
    VH.setPy(SM_Y1 + 13 * 5 - 1);
    VH.VWB_DrawPropString('Digitized');

    VH.setPx(SM_X + 10);
    VH.setPy(SM_Y1 + 13 * 10 - 1);
    VH.VWB_DrawPropString('Music');

    DrawMenu(SndItems, SndMenu);

    // Mark current selections
    DrawSoundCurrentSelection();

    VH.VW_UpdateScreen();
    await MenuFadeIn();

    await HandleMenu(SndItems, SndMenu, null);

    // Apply sound selection based on curpos
    applySound(SndItems.curpos);

    await MenuFadeOut();
}

function DrawSoundCurrentSelection(): void {
    // Mark current sound mode
    let sfxPos: number;
    switch (SD.SoundMode) {
        case SD.SDMode.sdm_Off: sfxPos = 0; break;
        case SD.SDMode.sdm_PC: sfxPos = 1; break;
        case SD.SDMode.sdm_AdLib: sfxPos = 2; break;
        default: sfxPos = 0;
    }
    DrawOutline(SM_X + SndItems.indent - 10, SM_Y1 + sfxPos * 13 - 1, 120, 13, READCOLOR, READCOLOR);

    // Mark current music mode
    const musPos = SD.MusicMode === SD.SMMode.smm_Off ? 10 : 11;
    DrawOutline(SM_X + SndItems.indent - 10, SM_Y1 + musPos * 13 - 1, 120, 13, READCOLOR, READCOLOR);
}

function applySound(curpos: number): void {
    if (curpos <= 2) {
        // SFX selection
        SD.SD_SetSoundMode([SD.SDMode.sdm_Off, SD.SDMode.sdm_PC, SD.SDMode.sdm_AdLib][curpos] ?? SD.SDMode.sdm_Off);
    } else if (curpos >= 10) {
        // Music selection
        SD.SD_SetMusicMode(curpos === 10 ? SD.SMMode.smm_Off : SD.SMMode.smm_AdLib);
    }
}

//===========================================================================
// CP_Control
//===========================================================================

async function CP_Control(_unused: number): Promise<void> {
    ClearMScreen();
    VH.VWB_DrawPic(112, 184, graphicnums.C_MOUSELBACKPIC);
    DrawStripes(10);
    VH.VWB_DrawPic(84, 0, graphicnums.C_CONTROLPIC);

    DrawWindow(CTL_X - 2, CTL_Y - 5, CTL_W, CTL_H, BKGDCOLOR);

    // Set up active state based on devices
    CtlMenu[0].active = IN.MousePresent ? 1 : 0;
    CtlMenu[4].active = IN.MousePresent ? 1 : 0;

    DrawMenu(CtlItems, CtlMenu);
    VH.VW_UpdateScreen();
    await MenuFadeIn();

    const which = await HandleMenu(CtlItems, CtlMenu, null);
    if (which >= 0 && CtlMenu[which].routine) {
        CtlMenu[which].routine!(0);
    }

    await MenuFadeOut();
}

//===========================================================================
// MouseSensitivity
//===========================================================================

function MouseSensitivity(_unused: number): void {
    // Simple cycle 1-9
    const ma = mouseadjustment;
    // mouseadjustment is const from wl_main import, cycle via mod
    // We can't mutate it directly; in a real implementation we'd store in config
}

//===========================================================================
// CustomControls
//===========================================================================

function CustomControls(_unused: number): void {
    // Custom key binding screen
    // For browser port, we display current bindings
    US.US_CenterWindow(24, 8);
    US.US_Print('CURRENT CONTROLS\n\n');
    US.US_Print('Move    : Arrow Keys\n');
    US.US_Print('Fire    : Ctrl\n');
    US.US_Print('Strafe  : Alt\n');
    US.US_Print('Use     : Space\n');
    US.US_Print('Run     : Shift\n');
    VH.VW_UpdateScreen();
}

//===========================================================================
// CP_LoadGame
//===========================================================================

async function CP_LoadGame(_unused: number): Promise<void> {
    ClearMScreen();
    VH.VWB_DrawPic(112, 184, graphicnums.C_MOUSELBACKPIC);
    DrawStripes(10);
    VH.VWB_DrawPic(84, 0, graphicnums.C_LOADGAMEPIC);

    DrawWindow(LSM_X - 2, LSM_Y - 5, LSM_W, LSM_H, BKGDCOLOR);

    // Fill in save game names
    for (let i = 0; i < 10; i++) {
        if (SaveGamesAvail[i]) {
            LSMenu[i].string = SaveGameNames[i];
            LSMenu[i].active = 1;
        } else {
            LSMenu[i].string = '  - empty -';
            LSMenu[i].active = 0;
        }
    }

    // Check if any saves exist
    let anyExist = false;
    for (let i = 0; i < 10; i++) {
        if (SaveGamesAvail[i]) { anyExist = true; break; }
    }
    if (!anyExist) {
        Message('No saved games found!');
        await IN.IN_Ack();
        return;
    }

    DrawMenu(LSItems, LSMenu);
    VH.VW_UpdateScreen();
    await MenuFadeIn();

    const which = await HandleMenu(LSItems, LSMenu, null);
    if (which >= 0 && SaveGamesAvail[which]) {
        // Load the game from localStorage
        try {
            const data = localStorage.getItem(`wolf3d_save_${which}`);
            if (data) {
                const save = JSON.parse(data);
                // Restore gamestate
                Object.assign(gamestate, save.gamestate);
                setLoadedGame(true);
                StartGame = 1;
                Message(STR_LOADING + '...');
                VH.VW_UpdateScreen();
            }
        } catch (e) {
            Message('Error loading game!');
            await IN.IN_Ack();
        }
    }

    await MenuFadeOut();
}

//===========================================================================
// CP_SaveGame
//===========================================================================

async function CP_SaveGame(_unused: number): Promise<void> {
    ClearMScreen();
    VH.VWB_DrawPic(112, 184, graphicnums.C_MOUSELBACKPIC);
    DrawStripes(10);
    VH.VWB_DrawPic(84, 0, graphicnums.C_SAVEGAMEPIC);

    DrawWindow(LSM_X - 2, LSM_Y - 5, LSM_W, LSM_H, BKGDCOLOR);

    for (let i = 0; i < 10; i++) {
        if (SaveGamesAvail[i]) {
            LSMenu[i].string = SaveGameNames[i];
        } else {
            LSMenu[i].string = '  - empty -';
        }
        LSMenu[i].active = 1;  // All slots available for saving
    }

    DrawMenu(LSItems, LSMenu);
    VH.VW_UpdateScreen();
    await MenuFadeIn();

    const which = await HandleMenu(LSItems, LSMenu, null);
    if (which >= 0) {
        // Save the game to localStorage
        const saveName = `Save ${which + 1} - Floor ${gamestate.mapon + 1}`;
        try {
            const saveData = {
                name: saveName,
                gamestate: { ...gamestate },
                timestamp: Date.now(),
            };
            localStorage.setItem(`wolf3d_save_${which}`, JSON.stringify(saveData));
            SaveGamesAvail[which] = true;
            SaveGameNames[which] = saveName;
            Message(STR_SAVING + '...');
            VH.VW_UpdateScreen();
            pickquick = 1;
        } catch (e) {
            Message('Error saving game!');
            await IN.IN_Ack();
        }
    }

    await MenuFadeOut();
}

//===========================================================================
// CP_ChangeView
//===========================================================================

async function CP_ChangeView(_unused: number): Promise<void> {
    ClearMScreen();
    DrawStripes(10);

    VH.VWB_DrawPic(112, 184, graphicnums.C_MOUSELBACKPIC);

    Message('Use +/- to adjust,\nENTER to accept.');
    VH.VW_UpdateScreen();

    let newsize = viewsize;
    let done = false;

    IN.IN_ClearKeysDown();

    while (!done) {
        IN.IN_ProcessEvents();

        if (IN.IN_KeyDown(IN.sc_RightArrow) || IN.IN_KeyDown(0x0d)) { // + or =
            if (newsize < 20) {
                newsize++;
                SD.SD_PlaySound(soundnames.MOVEGUN1SND);
            }
        }
        if (IN.IN_KeyDown(IN.sc_LeftArrow) || IN.IN_KeyDown(0x0c)) { // -
            if (newsize > 4) {
                newsize--;
                SD.SD_PlaySound(soundnames.MOVEGUN1SND);
            }
        }

        // Draw view size indicator
        VL.VL_Bar(60, 80, 200, 30, BKGDCOLOR);
        VL.VL_Bar(60, 90, ((newsize - 4) * 200 / 16) | 0, 10, READCOLOR);
        VH.setFontColor(TEXTCOLOR);
        VH.setPx(130);
        VH.setPy(82);
        VH.VWB_DrawPropString('Size: ' + newsize);
        VL.VL_UpdateScreen();

        if (IN.IN_KeyDown(IN.sc_Return)) {
            done = true;
            NewViewSize(newsize);
            IN.IN_ClearKeysDown();
        }
        if (IN.IN_KeyDown(IN.sc_Escape)) {
            done = true;
            IN.IN_ClearKeysDown();
        }

        await new Promise(resolve => setTimeout(resolve, 100));
    }
}

//===========================================================================
// CP_ViewScores
//===========================================================================

async function CP_ViewScores(_unused: number): Promise<void> {
    VH.setFontNumber(0);

    DrawHighScores();
    VH.VW_UpdateScreen();
    await MenuFadeIn();

    VH.setFontNumber(1);
    await IN.IN_Ack();

    StartCPMusic(MENUSONG);
    await MenuFadeOut();
}

//===========================================================================
// DrawHighScores
//===========================================================================

function DrawHighScores(): void {
    ClearMScreen();
    DrawStripes(10);

    VH.VWB_DrawPic(48, 0, graphicnums.HIGHSCORESPIC);

    VH.setFontColor(HIGHLIGHT);
    VH.setBackColor(BKGDCOLOR);

    DrawWindow(32, 44, 256, 120, BKGDCOLOR);

    SETFONTCOLOR(TEXTCOLOR, BKGDCOLOR);
    VH.setPx(48);
    VH.setPy(50);
    VH.VWB_DrawPropString('Name             Score  Ep  Fl');

    for (let i = 0; i < US.MaxScores; i++) {
        const s = US.Scores[i];
        const y = 62 + i * 13;

        VH.setFontColor(s.score > 0 ? HIGHLIGHT : DEACTIVE);
        VH.setPx(48);
        VH.setPy(y);

        // Pad name to 18 chars
        let name = s.name || '---';
        while (name.length < 18) name += ' ';
        name = name.substring(0, 18);

        const scoreStr = s.score > 0 ? s.score.toString().padStart(6, ' ') : '     0';
        const epStr = (s.episode + 1).toString().padStart(2, ' ');
        const flStr = (s.completed + 1).toString().padStart(2, ' ');

        VH.VWB_DrawPropString(name + scoreStr + '  ' + epStr + '  ' + flStr);
    }
}

//===========================================================================
// CP_EndGame
//===========================================================================

async function CP_EndGame(): Promise<boolean> {
    if (!(await Confirm(ENDGAMESTR))) {
        return false;
    }

    pickquick = 0;
    gamestate.lives = 0;
    setPlaystate(exit_t.ex_died);

    mainMenu[MainMenuItem.savegame].active = 0;
    mainMenu[MainMenuItem.viewscores].routine = (n) => CP_ViewScores(n);
    mainMenu[MainMenuItem.viewscores].string = STR_VS;

    return true;
}

//===========================================================================
// CP_Quit
//===========================================================================

async function CP_Quit(_unused: number): Promise<void> {
    const quitMsg = endStrings[US.US_RndT() % endStrings.length];
    if (await Confirm(quitMsg)) {
        // In browser, we can't truly quit. Stop music and show quit screen.
        SD.SD_MusicOff();
        SD.SD_StopSound();
        await MenuFadeOut();

        // Silence AdLib
        for (let i = 1; i <= 0xf5; i++) {
            SD.alOut(i, 0);
        }

        // Show a final screen
        VL.VL_Bar(0, 0, 320, 200, 0);
        VH.setFontColor(0x4a);
        VH.setPx(80);
        VH.setPy(90);
        VH.VWB_DrawPropString('Thanks for playing!');
        VL.VL_UpdateScreen();
    }
}

//===========================================================================
// CP_CheckQuick - handle quick F-key actions during gameplay
//===========================================================================

export async function CP_CheckQuick(scancode: number): Promise<boolean> {
    switch (scancode) {
        case IN.sc_F7: {
            // End game
            if (await Confirm(ENDGAMESTR)) {
                setPlaystate(exit_t.ex_died);
                pickquick = 0;
                gamestate.lives = 0;
            }
            return true;
        }
        case IN.sc_F8: {
            // Quick save
            if (SaveGamesAvail[LSItems.curpos] && pickquick) {
                VH.setFontNumber(1);
                Message(STR_SAVING + '...');
                await CP_SaveGame(1);
                VH.setFontNumber(0);
            } else {
                await CP_SaveGame(0);
            }
            return true;
        }
        case IN.sc_F9: {
            // Quick load
            if (SaveGamesAvail[LSItems.curpos] && pickquick) {
                await CP_LoadGame(1);
            } else {
                await CP_LoadGame(0);
            }
            return true;
        }
        case IN.sc_F10: {
            // Quit
            const quitMsg = endStrings[US.US_RndT() % endStrings.length];
            if (await Confirm(quitMsg)) {
                SD.SD_MusicOff();
                SD.SD_StopSound();
            }
            return true;
        }
    }
    return false;
}

//===========================================================================
// US_ControlPanel - Main menu entry point
//===========================================================================

export async function US_ControlPanel(scancode: number): Promise<void> {
    // Quick-key checks from within a game
    if (US.ingame) {
        if (await CP_CheckQuick(scancode)) {
            return;
        }
    }

    StartCPMusic(MENUSONG);
    SetupControlPanel();

    // F-KEYS FROM WITHIN GAME
    switch (scancode) {
        case IN.sc_F1:
            // Help screens would go here
            CleanupControlPanel();
            return;
        case IN.sc_F2:
            await CP_SaveGame(0);
            CleanupControlPanel();
            return;
        case IN.sc_F3:
            await CP_LoadGame(0);
            CleanupControlPanel();
            return;
        case IN.sc_F4:
            await CP_Sound(0);
            CleanupControlPanel();
            return;
        case IN.sc_F5:
            await CP_ChangeView(0);
            CleanupControlPanel();
            return;
        case IN.sc_F6:
            await CP_Control(0);
            CleanupControlPanel();
            return;
    }

    DrawMainMenu();
    await MenuFadeIn();
    StartGame = 0;

    // MAIN MENU LOOP
    do {
        const which = await HandleMenu(mainItems, mainMenu, null);

        switch (which) {
            case MainMenuItem.viewscores:
                if (mainMenu[MainMenuItem.viewscores].routine === null) {
                    if (await CP_EndGame()) {
                        StartGame = 1;
                    }
                }
                DrawMainMenu();
                await MenuFadeIn();
                break;

            case MainMenuItem.backtodemo:
                StartGame = 1;
                if (!US.ingame) {
                    StartCPMusic(INTROSONG);
                }
                await VL.VL_FadeOut(0, 255, 0, 0, 0, 10);
                break;

            case -1:
            case MainMenuItem.quit:
                await CP_Quit(0);
                break;

            default:
                if (!StartGame) {
                    DrawMainMenu();
                    await MenuFadeIn();
                }
        }
    } while (!StartGame);

    CleanupControlPanel();

    // Change main menu item when game starts
    if (startgame || loadedgame) {
        mainMenu[MainMenuItem.viewscores].routine = null;
        mainMenu[MainMenuItem.viewscores].string = STR_EG;
    }
}

//===========================================================================
// Message / Confirm helpers
//===========================================================================

export function Message(str: string): void {
    // Count lines and max width for window sizing
    const lines = str.split('\n');
    let maxLen = 0;
    for (const line of lines) {
        if (line.length > maxLen) maxLen = line.length;
    }

    US.US_CenterWindow(maxLen + 2, lines.length + 2);
    for (let i = 0; i < lines.length; i++) {
        US.US_Print(lines[i]);
        if (i < lines.length - 1) {
            US.setPrintX(US.WindowX);
            US.setPrintY(US.PrintY + 10);
        }
    }
    VL.VL_UpdateScreen();
}

export async function Confirm(str: string): Promise<boolean> {
    Message(str);
    // Wait for Y/N
    IN.IN_ClearKeysDown();
    while (true) {
        IN.IN_ProcessEvents();
        if (IN.IN_KeyDown(IN.sc_Y)) {
            IN.IN_ClearKeysDown();
            ShootSnd();
            return true;
        }
        if (IN.IN_KeyDown(IN.sc_N) || IN.IN_KeyDown(IN.sc_Escape)) {
            IN.IN_ClearKeysDown();
            SD.SD_PlaySound(soundnames.ESCPRESSEDSND);
            return false;
        }
        await new Promise(r => setTimeout(r, 16));
    }
}
