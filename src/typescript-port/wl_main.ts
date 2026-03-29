// WL_MAIN.TS
// Ported from WL_MAIN.C - Wolfenstein 3-D main module

import * as VL from './id_vl';
import * as VH from './id_vh';
import * as IN from './id_in';
import * as SD from './id_sd';
import * as CA from './id_ca';
import * as MM from './id_mm';
import * as PM from './id_pm';
import * as US from './id_us_1';
import {
    ANGLES, FINEANGLES, GLOBAL1, TILEGLOBAL, TILESHIFT, MINDIST,
    EXTRAPOINTS, STARTAMMO, MAXVIEWWIDTH, MAXSCALEHEIGHT,
    gametype, newGametype, weapontype, NUMBUTTONS,
    SCREENSIZE,
} from './wl_def';
import { graphicnums } from './gfxv_wl1';
import { SDMode, SMMode, SDSMode } from './id_sd';
import { sc_Escape } from './id_in';

//===========================================================================
// Constants
//===========================================================================

const FOCALLENGTH = 0x5700;
const VIEWGLOBAL = 0x10000;
const VIEWWIDTH_DEF = 256;
const VIEWHEIGHT_DEF = 144;

//===========================================================================
// Global variables
//===========================================================================

export let str = '';
export let str2 = '';
export let tedlevelnum = 0;
export let tedlevel = false;
export let nospr = false;
export let IsA386 = true;

// Projection variables
export let focallength: number = 0;
export let screenofs: number = 0;
export let viewwidth: number = VIEWWIDTH_DEF;
export let viewheight: number = VIEWHEIGHT_DEF;
export let centerx: number = 0;
export let shootdelta: number = 0;
export let scale: number = 0;
export let maxslope: number = 0;
export let heightnumerator: number = 0;
export let minheightdiv: number = 0;

export const dirangle: number[] = [0, ANGLES/8, 2*ANGLES/8, 3*ANGLES/8, 4*ANGLES/8,
    5*ANGLES/8, 6*ANGLES/8, 7*ANGLES/8, ANGLES];

export let startgame = false;
export let loadedgame = false;
export let virtualreality = false;
export let mouseadjustment = 5;

// Math tables
export const pixelangle: Int32Array = new Int32Array(MAXVIEWWIDTH);
export const finetangent: Float64Array = new Float64Array(FINEANGLES / 4);
export const sintable: Float64Array = new Float64Array(ANGLES + ANGLES / 4 + 1);
export let costable: Float64Array;  // points into sintable at offset ANGLES/4

export let configname = 'CONFIG.WL6';

// Game state
export const gamestate: gametype = newGametype();

// Control variables
export let mouseenabled = true;
export let joystickenabled = false;
export let joypadenabled = false;
export let joystickprogressive = false;
export let joystickport = 0;
export const dirscan: number[] = [IN.sc_UpArrow, IN.sc_RightArrow, IN.sc_DownArrow, IN.sc_LeftArrow];
export const buttonscan: number[] = new Array(NUMBUTTONS).fill(IN.sc_None);
export const buttonmouse: number[] = [IN.sc_None, IN.sc_None, IN.sc_None, IN.sc_None];
export const buttonjoy: number[] = [IN.sc_None, IN.sc_None, IN.sc_None, IN.sc_None];

export let viewsize = 20;

// Screen locations for triple buffering
export const screenloc: number[] = [0, SCREENSIZE, SCREENSIZE * 2];
export let freelatch = SCREENSIZE * 3;

// Setter helpers
export function setStartGame(v: boolean): void { startgame = v; }
export function setLoadedGame(v: boolean): void { loadedgame = v; }
export function setViewSize(v: number): void { viewsize = v; }

//===========================================================================
// BuildTables - pre-calculate math tables
//===========================================================================

export function BuildTables(): void {
    // Build sine/cosine table
    for (let i = 0; i <= ANGLES; i++) {
        const angle = (i * Math.PI * 2) / ANGLES;
        sintable[i] = Math.round(Math.sin(angle) * GLOBAL1);
    }
    // Extra quarter for cosine lookups
    for (let i = 0; i < ANGLES / 4 + 1; i++) {
        sintable[ANGLES + i] = sintable[i];
    }
    costable = new Float64Array(sintable.buffer, (ANGLES / 4) * 8);

    // Build tangent table for ray casting
    for (let i = 0; i < FINEANGLES / 4; i++) {
        const angle = ((i + 0.5) / (FINEANGLES / 4)) * (Math.PI / 2);
        const t = Math.tan(angle);
        finetangent[i] = Math.round(t * GLOBAL1);
    }
}

//===========================================================================
// CalcProjection
//===========================================================================

export function CalcProjection(focal: number): void {
    focallength = focal;

    const halfview = (viewwidth / 2) | 0;
    const facedist = focal + MINDIST;

    // scale = halfview * facedist / (VIEWGLOBAL/2)
    scale = ((halfview * facedist) / (VIEWGLOBAL / 2)) | 0;

    centerx = halfview;
    shootdelta = (viewwidth / 10) | 0;

    // heightnumerator = (TILEGLOBAL * scale) >> 6
    heightnumerator = (TILEGLOBAL * scale) >> 6;
    minheightdiv = ((viewwidth * 3) / 2) | 0;

    // Calculate pixel angles for each column
    for (let i = 0; i < viewwidth; i++) {
        const tang = ((centerx - i) * GLOBAL1) / focal;
        const angle = Math.atan2(tang, GLOBAL1);
        const intang = Math.round(angle * (FINEANGLES / (2 * Math.PI)));
        pixelangle[i] = intang;
    }
}

//===========================================================================
// SetViewSize
//===========================================================================

export function SetViewSize(width: number, height: number): boolean {
    viewwidth = width & ~15;  // Round down to 16 pixel boundary
    viewheight = height & ~1;  // Round down to even

    centerx = viewwidth / 2 - 1;
    shootdelta = viewwidth / 10;

    screenofs = ((200 - 40 - viewheight) / 2) * 320 + ((320 - viewwidth) / 2);

    CalcProjection(FOCALLENGTH);

    // Initialize sprite scaling tables for this viewport size
    // Use dynamic import to avoid circular dependency with wl_scale
    import('./wl_scale').then(mod => {
        if (mod.SetupScaling) mod.SetupScaling(viewheight + 1);
    });

    return true;
}

//===========================================================================
// NewViewSize
//===========================================================================

export function NewViewSize(width: number): void {
    viewsize = width;
    SetViewSize(width * 16, (width * 16 * 0.5) | 0);
}

//===========================================================================
// NewGame
//===========================================================================

export function NewGame(difficulty: number, episode: number): void {
    // Reset gamestate
    Object.assign(gamestate, newGametype());
    gamestate.difficulty = difficulty;
    gamestate.weapon = weapontype.wp_pistol;
    gamestate.bestweapon = weapontype.wp_pistol;
    gamestate.chosenweapon = weapontype.wp_pistol;
    gamestate.health = 100;
    gamestate.ammo = STARTAMMO;
    gamestate.lives = 3;
    gamestate.nextextra = EXTRAPOINTS;
    gamestate.episode = episode;

    startgame = true;
}

//===========================================================================
// ReadConfig (from localStorage)
//===========================================================================

function ReadConfig(): void {
    // Try to read config from localStorage
    try {
        const data = localStorage.getItem('wolf3d_config');
        if (data) {
            const config = JSON.parse(data);
            viewsize = config.viewsize || 20;
            mouseadjustment = config.mouseadjustment || 5;
        }
    } catch {
        // Use defaults
    }

    // Set defaults
    SD.SD_SetSoundMode(SDMode.sdm_AdLib);
    SD.SD_SetMusicMode(SMMode.smm_AdLib);
    SD.SD_SetDigiDevice(SDSMode.sds_SoundBlaster);

    viewsize = 20;
    mouseadjustment = 5;
    mouseenabled = true;

    // Set default keyboard controls
    buttonscan[0] = IN.sc_Control;  // attack
    buttonscan[1] = IN.sc_Alt;      // strafe
    buttonscan[2] = IN.sc_RShift;   // run
    buttonscan[3] = IN.sc_Space;    // use
    buttonscan[4] = IN.sc_1;        // knife
    buttonscan[5] = IN.sc_2;        // pistol
    buttonscan[6] = IN.sc_3;        // machinegun
    buttonscan[7] = IN.sc_4;        // chaingun
}

//===========================================================================
// WriteConfig (to localStorage)
//===========================================================================

function WriteConfig(): void {
    try {
        localStorage.setItem('wolf3d_config', JSON.stringify({
            viewsize,
            mouseadjustment,
        }));
    } catch {
        // Ignore errors
    }
}

//===========================================================================
// InitGame
//===========================================================================

async function InitGame(): Promise<void> {
    // Start subsystems
    MM.MM_Startup();
    VL.VL_Startup();
    IN.IN_Startup();
    SD.SD_Startup();

    // Load all game data
    await CA.CA_Startup();
    await PM.PM_Startup();

    // Load all sounds
    CA.CA_LoadAllSounds();

    // Initialize user manager
    US.US_Startup();

    // Build math tables
    BuildTables();

    // Read config
    ReadConfig();

    // Set up the view
    NewViewSize(viewsize);

    // Set VGA plane mode
    VL.VL_SetVGAPlaneMode();
    VL.VL_TestPaletteSet();

    // Load default game palette
    VH.VH_SetDefaultColors();
}

//===========================================================================
// ShutdownId
//===========================================================================

export function ShutdownId(): void {
    US.US_Shutdown();
    SD.SD_Shutdown();
    PM.PM_Shutdown();
    IN.IN_Shutdown();
    VL.VL_Shutdown();
    CA.CA_Shutdown();
    MM.MM_Shutdown();
}

//===========================================================================
// Quit
//===========================================================================

export function Quit(error: string | null): void {
    if (error) {
        console.error('Wolf3D Error:', error);
    }
    WriteConfig();
    ShutdownId();
}

//===========================================================================
// DemoLoop - Main game loop (handles intro screens and menu)
//===========================================================================

async function DemoLoop(): Promise<void> {
    // PG13 screen (shown once before the main loop)
    await VH.VW_FadeOut();
    VH.VWB_Bar(0, 0, 320, 200, 0x82);
    CA.CA_CacheGrChunk(graphicnums.PG13PIC);
    VH.VWB_DrawPic(216, 110, graphicnums.PG13PIC);
    VH.VW_UpdateScreen();
    await VH.VW_FadeIn();
    await IN.IN_UserInput(SD.TickBase * 7);
    await VH.VW_FadeOut();

    // Main game cycle (matches original C DemoLoop)
    while (true) {
        // Inner loop: cycle title → credits → high scores → demo
        while (true) {
            // Title page
            CA.CA_CacheScreen(graphicnums.TITLEPIC);
            VH.VW_UpdateScreen();
            await VH.VW_FadeIn();
            if (await IN.IN_UserInput(SD.TickBase * 15))
                break;
            await VH.VW_FadeOut();

            // Credits page
            CA.CA_CacheScreen(graphicnums.CREDITSPIC);
            VH.VW_UpdateScreen();
            await VH.VW_FadeIn();
            if (await IN.IN_UserInput(SD.TickBase * 10))
                break;
            await VH.VW_FadeOut();

            // High scores
            // TODO: DrawHighScores();
            VH.VW_UpdateScreen();
            await VH.VW_FadeIn();
            if (await IN.IN_UserInput(SD.TickBase * 10))
                break;

            // TODO: PlayDemo()
            break;
        }

        await VH.VW_FadeOut();

        // Resume audio context on first user interaction
        SD.SD_EnsureAudioStarted();

        // Show main menu
        const { US_ControlPanel } = await import('./wl_menu');
        console.log('[DemoLoop] Entering US_ControlPanel');
        await US_ControlPanel(0);

        if (startgame || loadedgame) {
            const { GameLoop } = await import('./wl_game');
            await GameLoop();
            startgame = false;
            loadedgame = false;
            await VH.VW_FadeOut();
        }
    }
}

//===========================================================================
// main - Entry point
//===========================================================================

export async function wolfMain(): Promise<void> {
    console.log('Wolfenstein 3-D TypeScript Port');
    console.log('Starting initialization...');

    try {
        await InitGame();
        console.log('Initialization complete');

        await DemoLoop();
    } catch (err) {
        console.error('Wolf3D fatal error:', err);
        Quit((err as Error).message);
    }
}
