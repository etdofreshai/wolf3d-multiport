// WL_DEF.TS
// Ported from WL_DEF.H - Core type definitions and constants for Wolfenstein 3D

//#define BETA
export const YEAR = 1992;
export const MONTH = 9;
export const DAY = 30;

//=============================================================================
//                          MACROS
//=============================================================================

export function MAPSPOT(x: number, y: number, plane: number): number {
    return mapsegs[plane][farmapylookup[y] + x];
}

export function MAPSPOT_SET(x: number, y: number, plane: number, val: number): void {
    mapsegs[plane][farmapylookup[y] + x] = val;
}

export function SIGN(x: number): number { return x > 0 ? 1 : -1; }
export function ABS(x: number): number { return x > 0 ? x : -x; }

//=============================================================================
//                      GLOBAL CONSTANTS
//=============================================================================

export const MAXACTORS = 150;
export const MAXSTATS = 400;
export const MAXDOORS = 64;
export const MAXWALLTILES = 64;

// tile constants
export const ICONARROWS = 90;
export const PUSHABLETILE = 98;
export const EXITTILE = 99;
export const AREATILE = 107;
export const NUMAREAS = 37;
export const ELEVATORTILE = 21;
export const AMBUSHTILE = 106;
export const ALTELEVATORTILE = 107;

export const NUMBERCHARS = 9;

export const EXTRAPOINTS = 40000;
export const PLAYERSPEED = 3000;
export const RUNSPEED = 6000;

export const SCREENBWIDE = 80;
export const HEIGHTRATIO = 0.50;

export const BORDERCOLOR_DEF = 3;
export const FLASHCOLOR = 5;
export const FLASHTICS = 4;

export const PLAYERSIZE = 0x5800; // MINDIST
export const MINACTORDIST = 0x10000;

export const NUMLATCHPICS = 100;

export const PI = 3.141592657;
export const M_PI = 3.14159265358979323846;

export const GLOBAL1 = (1 << 16);
export const TILEGLOBAL = GLOBAL1;
export const PIXGLOBAL = (GLOBAL1 / 64) | 0;
export const TILESHIFT = 16;
export const UNSIGNEDSHIFT = 8;

export const ANGLES = 360;
export const ANGLEQUAD = (ANGLES / 4);
export const FINEANGLES = 3600;
export const ANG90 = (FINEANGLES / 4);
export const ANG180 = (ANG90 * 2);
export const ANG270 = (ANG90 * 3);
export const ANG360 = (ANG90 * 4);
export const VANG90 = (ANGLES / 4);
export const VANG180 = (VANG90 * 2);
export const VANG270 = (VANG90 * 3);
export const VANG360 = (VANG90 * 4);

export const MINDIST = 0x5800;

export const MAXSCALEHEIGHT = 256;
export const MAXVIEWWIDTH = 320;

export const MAPSIZE = 64;
export const NORTH = 0;
export const EAST_DIR = 1;
export const SOUTH = 2;
export const WEST_DIR = 3;

export const STATUSLINES = 40;

export const SCREENWIDTH = 80;
export const MAXSCANLINES = 200;
export const SCREENSIZE = (SCREENBWIDE * 208);
export const PAGE1START = 0;
export const PAGE2START = SCREENSIZE;
export const PAGE3START = (SCREENSIZE * 2);
export const FREESTART = (SCREENSIZE * 3);

export const PIXRADIUS = 512;
export const STARTAMMO = 8;

// object flag values
export const FL_SHOOTABLE = 1;
export const FL_BONUS = 2;
export const FL_NEVERMARK = 4;
export const FL_VISABLE = 8;
export const FL_ATTACKMODE = 16;
export const FL_FIRSTATTACK = 32;
export const FL_AMBUSH = 64;
export const FL_NONMARK = 128;

//=============================================================================
//                      SPRITE CONSTANTS
//=============================================================================

export enum SpriteEnum {
    SPR_DEMO = 0,
    SPR_DEATHCAM,
    // static sprites
    SPR_STAT_0, SPR_STAT_1, SPR_STAT_2, SPR_STAT_3,
    SPR_STAT_4, SPR_STAT_5, SPR_STAT_6, SPR_STAT_7,
    SPR_STAT_8, SPR_STAT_9, SPR_STAT_10, SPR_STAT_11,
    SPR_STAT_12, SPR_STAT_13, SPR_STAT_14, SPR_STAT_15,
    SPR_STAT_16, SPR_STAT_17, SPR_STAT_18, SPR_STAT_19,
    SPR_STAT_20, SPR_STAT_21, SPR_STAT_22, SPR_STAT_23,
    SPR_STAT_24, SPR_STAT_25, SPR_STAT_26, SPR_STAT_27,
    SPR_STAT_28, SPR_STAT_29, SPR_STAT_30, SPR_STAT_31,
    SPR_STAT_32, SPR_STAT_33, SPR_STAT_34, SPR_STAT_35,
    SPR_STAT_36, SPR_STAT_37, SPR_STAT_38, SPR_STAT_39,
    SPR_STAT_40, SPR_STAT_41, SPR_STAT_42, SPR_STAT_43,
    SPR_STAT_44, SPR_STAT_45, SPR_STAT_46, SPR_STAT_47,
    // guard
    SPR_GRD_S_1, SPR_GRD_S_2, SPR_GRD_S_3, SPR_GRD_S_4,
    SPR_GRD_S_5, SPR_GRD_S_6, SPR_GRD_S_7, SPR_GRD_S_8,
    SPR_GRD_W1_1, SPR_GRD_W1_2, SPR_GRD_W1_3, SPR_GRD_W1_4,
    SPR_GRD_W1_5, SPR_GRD_W1_6, SPR_GRD_W1_7, SPR_GRD_W1_8,
    SPR_GRD_W2_1, SPR_GRD_W2_2, SPR_GRD_W2_3, SPR_GRD_W2_4,
    SPR_GRD_W2_5, SPR_GRD_W2_6, SPR_GRD_W2_7, SPR_GRD_W2_8,
    SPR_GRD_W3_1, SPR_GRD_W3_2, SPR_GRD_W3_3, SPR_GRD_W3_4,
    SPR_GRD_W3_5, SPR_GRD_W3_6, SPR_GRD_W3_7, SPR_GRD_W3_8,
    SPR_GRD_W4_1, SPR_GRD_W4_2, SPR_GRD_W4_3, SPR_GRD_W4_4,
    SPR_GRD_W4_5, SPR_GRD_W4_6, SPR_GRD_W4_7, SPR_GRD_W4_8,
    SPR_GRD_PAIN_1, SPR_GRD_DIE_1, SPR_GRD_DIE_2, SPR_GRD_DIE_3,
    SPR_GRD_PAIN_2, SPR_GRD_DEAD,
    SPR_GRD_SHOOT1, SPR_GRD_SHOOT2, SPR_GRD_SHOOT3,
    // dogs
    SPR_DOG_W1_1, SPR_DOG_W1_2, SPR_DOG_W1_3, SPR_DOG_W1_4,
    SPR_DOG_W1_5, SPR_DOG_W1_6, SPR_DOG_W1_7, SPR_DOG_W1_8,
    SPR_DOG_W2_1, SPR_DOG_W2_2, SPR_DOG_W2_3, SPR_DOG_W2_4,
    SPR_DOG_W2_5, SPR_DOG_W2_6, SPR_DOG_W2_7, SPR_DOG_W2_8,
    SPR_DOG_W3_1, SPR_DOG_W3_2, SPR_DOG_W3_3, SPR_DOG_W3_4,
    SPR_DOG_W3_5, SPR_DOG_W3_6, SPR_DOG_W3_7, SPR_DOG_W3_8,
    SPR_DOG_W4_1, SPR_DOG_W4_2, SPR_DOG_W4_3, SPR_DOG_W4_4,
    SPR_DOG_W4_5, SPR_DOG_W4_6, SPR_DOG_W4_7, SPR_DOG_W4_8,
    SPR_DOG_DIE_1, SPR_DOG_DIE_2, SPR_DOG_DIE_3, SPR_DOG_DEAD,
    SPR_DOG_JUMP1, SPR_DOG_JUMP2, SPR_DOG_JUMP3,
    // ss
    SPR_SS_S_1, SPR_SS_S_2, SPR_SS_S_3, SPR_SS_S_4,
    SPR_SS_S_5, SPR_SS_S_6, SPR_SS_S_7, SPR_SS_S_8,
    SPR_SS_W1_1, SPR_SS_W1_2, SPR_SS_W1_3, SPR_SS_W1_4,
    SPR_SS_W1_5, SPR_SS_W1_6, SPR_SS_W1_7, SPR_SS_W1_8,
    SPR_SS_W2_1, SPR_SS_W2_2, SPR_SS_W2_3, SPR_SS_W2_4,
    SPR_SS_W2_5, SPR_SS_W2_6, SPR_SS_W2_7, SPR_SS_W2_8,
    SPR_SS_W3_1, SPR_SS_W3_2, SPR_SS_W3_3, SPR_SS_W3_4,
    SPR_SS_W3_5, SPR_SS_W3_6, SPR_SS_W3_7, SPR_SS_W3_8,
    SPR_SS_W4_1, SPR_SS_W4_2, SPR_SS_W4_3, SPR_SS_W4_4,
    SPR_SS_W4_5, SPR_SS_W4_6, SPR_SS_W4_7, SPR_SS_W4_8,
    SPR_SS_PAIN_1, SPR_SS_DIE_1, SPR_SS_DIE_2, SPR_SS_DIE_3,
    SPR_SS_PAIN_2, SPR_SS_DEAD,
    SPR_SS_SHOOT1, SPR_SS_SHOOT2, SPR_SS_SHOOT3,
    // mutant
    SPR_MUT_S_1, SPR_MUT_S_2, SPR_MUT_S_3, SPR_MUT_S_4,
    SPR_MUT_S_5, SPR_MUT_S_6, SPR_MUT_S_7, SPR_MUT_S_8,
    SPR_MUT_W1_1, SPR_MUT_W1_2, SPR_MUT_W1_3, SPR_MUT_W1_4,
    SPR_MUT_W1_5, SPR_MUT_W1_6, SPR_MUT_W1_7, SPR_MUT_W1_8,
    SPR_MUT_W2_1, SPR_MUT_W2_2, SPR_MUT_W2_3, SPR_MUT_W2_4,
    SPR_MUT_W2_5, SPR_MUT_W2_6, SPR_MUT_W2_7, SPR_MUT_W2_8,
    SPR_MUT_W3_1, SPR_MUT_W3_2, SPR_MUT_W3_3, SPR_MUT_W3_4,
    SPR_MUT_W3_5, SPR_MUT_W3_6, SPR_MUT_W3_7, SPR_MUT_W3_8,
    SPR_MUT_W4_1, SPR_MUT_W4_2, SPR_MUT_W4_3, SPR_MUT_W4_4,
    SPR_MUT_W4_5, SPR_MUT_W4_6, SPR_MUT_W4_7, SPR_MUT_W4_8,
    SPR_MUT_PAIN_1, SPR_MUT_DIE_1, SPR_MUT_DIE_2, SPR_MUT_DIE_3,
    SPR_MUT_PAIN_2, SPR_MUT_DIE_4, SPR_MUT_DEAD,
    SPR_MUT_SHOOT1, SPR_MUT_SHOOT2, SPR_MUT_SHOOT3, SPR_MUT_SHOOT4,
    // officer
    SPR_OFC_S_1, SPR_OFC_S_2, SPR_OFC_S_3, SPR_OFC_S_4,
    SPR_OFC_S_5, SPR_OFC_S_6, SPR_OFC_S_7, SPR_OFC_S_8,
    SPR_OFC_W1_1, SPR_OFC_W1_2, SPR_OFC_W1_3, SPR_OFC_W1_4,
    SPR_OFC_W1_5, SPR_OFC_W1_6, SPR_OFC_W1_7, SPR_OFC_W1_8,
    SPR_OFC_W2_1, SPR_OFC_W2_2, SPR_OFC_W2_3, SPR_OFC_W2_4,
    SPR_OFC_W2_5, SPR_OFC_W2_6, SPR_OFC_W2_7, SPR_OFC_W2_8,
    SPR_OFC_W3_1, SPR_OFC_W3_2, SPR_OFC_W3_3, SPR_OFC_W3_4,
    SPR_OFC_W3_5, SPR_OFC_W3_6, SPR_OFC_W3_7, SPR_OFC_W3_8,
    SPR_OFC_W4_1, SPR_OFC_W4_2, SPR_OFC_W4_3, SPR_OFC_W4_4,
    SPR_OFC_W4_5, SPR_OFC_W4_6, SPR_OFC_W4_7, SPR_OFC_W4_8,
    SPR_OFC_PAIN_1, SPR_OFC_DIE_1, SPR_OFC_DIE_2, SPR_OFC_DIE_3,
    SPR_OFC_PAIN_2, SPR_OFC_DIE_4, SPR_OFC_DEAD,
    SPR_OFC_SHOOT1, SPR_OFC_SHOOT2, SPR_OFC_SHOOT3,
    // ghosts
    SPR_BLINKY_W1, SPR_BLINKY_W2, SPR_PINKY_W1, SPR_PINKY_W2,
    SPR_CLYDE_W1, SPR_CLYDE_W2, SPR_INKY_W1, SPR_INKY_W2,
    // hans
    SPR_BOSS_W1, SPR_BOSS_W2, SPR_BOSS_W3, SPR_BOSS_W4,
    SPR_BOSS_SHOOT1, SPR_BOSS_SHOOT2, SPR_BOSS_SHOOT3, SPR_BOSS_DEAD,
    SPR_BOSS_DIE1, SPR_BOSS_DIE2, SPR_BOSS_DIE3,
    // schabbs
    SPR_SCHABB_W1, SPR_SCHABB_W2, SPR_SCHABB_W3, SPR_SCHABB_W4,
    SPR_SCHABB_SHOOT1, SPR_SCHABB_SHOOT2,
    SPR_SCHABB_DIE1, SPR_SCHABB_DIE2, SPR_SCHABB_DIE3, SPR_SCHABB_DEAD,
    SPR_HYPO1, SPR_HYPO2, SPR_HYPO3, SPR_HYPO4,
    // fake
    SPR_FAKE_W1, SPR_FAKE_W2, SPR_FAKE_W3, SPR_FAKE_W4,
    SPR_FAKE_SHOOT, SPR_FIRE1, SPR_FIRE2,
    SPR_FAKE_DIE1, SPR_FAKE_DIE2, SPR_FAKE_DIE3, SPR_FAKE_DIE4,
    SPR_FAKE_DIE5, SPR_FAKE_DEAD,
    // hitler
    SPR_MECHA_W1, SPR_MECHA_W2, SPR_MECHA_W3, SPR_MECHA_W4,
    SPR_MECHA_SHOOT1, SPR_MECHA_SHOOT2, SPR_MECHA_SHOOT3, SPR_MECHA_DEAD,
    SPR_MECHA_DIE1, SPR_MECHA_DIE2, SPR_MECHA_DIE3,
    SPR_HITLER_W1, SPR_HITLER_W2, SPR_HITLER_W3, SPR_HITLER_W4,
    SPR_HITLER_SHOOT1, SPR_HITLER_SHOOT2, SPR_HITLER_SHOOT3, SPR_HITLER_DEAD,
    SPR_HITLER_DIE1, SPR_HITLER_DIE2, SPR_HITLER_DIE3, SPR_HITLER_DIE4,
    SPR_HITLER_DIE5, SPR_HITLER_DIE6, SPR_HITLER_DIE7,
    // giftmacher
    SPR_GIFT_W1, SPR_GIFT_W2, SPR_GIFT_W3, SPR_GIFT_W4,
    SPR_GIFT_SHOOT1, SPR_GIFT_SHOOT2,
    SPR_GIFT_DIE1, SPR_GIFT_DIE2, SPR_GIFT_DIE3, SPR_GIFT_DEAD,
    // Rocket, smoke and small explosion
    SPR_ROCKET_1, SPR_ROCKET_2, SPR_ROCKET_3, SPR_ROCKET_4,
    SPR_ROCKET_5, SPR_ROCKET_6, SPR_ROCKET_7, SPR_ROCKET_8,
    SPR_SMOKE_1, SPR_SMOKE_2, SPR_SMOKE_3, SPR_SMOKE_4,
    SPR_BOOM_1, SPR_BOOM_2, SPR_BOOM_3,
    // gretel
    SPR_GRETEL_W1, SPR_GRETEL_W2, SPR_GRETEL_W3, SPR_GRETEL_W4,
    SPR_GRETEL_SHOOT1, SPR_GRETEL_SHOOT2, SPR_GRETEL_SHOOT3, SPR_GRETEL_DEAD,
    SPR_GRETEL_DIE1, SPR_GRETEL_DIE2, SPR_GRETEL_DIE3,
    // fat face
    SPR_FAT_W1, SPR_FAT_W2, SPR_FAT_W3, SPR_FAT_W4,
    SPR_FAT_SHOOT1, SPR_FAT_SHOOT2, SPR_FAT_SHOOT3, SPR_FAT_SHOOT4,
    SPR_FAT_DIE1, SPR_FAT_DIE2, SPR_FAT_DIE3, SPR_FAT_DEAD,
    // bj
    SPR_BJ_W1, SPR_BJ_W2, SPR_BJ_W3, SPR_BJ_W4,
    SPR_BJ_JUMP1, SPR_BJ_JUMP2, SPR_BJ_JUMP3, SPR_BJ_JUMP4,
    // player attack frames
    SPR_KNIFEREADY, SPR_KNIFEATK1, SPR_KNIFEATK2, SPR_KNIFEATK3,
    SPR_KNIFEATK4,
    SPR_PISTOLREADY, SPR_PISTOLATK1, SPR_PISTOLATK2, SPR_PISTOLATK3,
    SPR_PISTOLATK4,
    SPR_MACHINEGUNREADY, SPR_MACHINEGUNATK1, SPR_MACHINEGUNATK2, MACHINEGUNATK3,
    SPR_MACHINEGUNATK4,
    SPR_CHAINREADY, SPR_CHAINATK1, SPR_CHAINATK2, SPR_CHAINATK3,
    SPR_CHAINATK4,
}

//=============================================================================
//                          GLOBAL TYPES
//=============================================================================

export type fixed = number;  // 32-bit fixed point (16.16)
export type boolean_t = boolean;
export type byte = number;
export type word = number;
export type longword = number;

export enum controldir_t {
    di_north,
    di_east,
    di_south,
    di_west
}

export enum door_t {
    dr_normal,
    dr_lock1,
    dr_lock2,
    dr_lock3,
    dr_lock4,
    dr_elevator
}

export enum activetype {
    ac_badobject = -1,
    ac_no = 0,
    ac_yes = 1,
    ac_allways = 2
}

export enum classtype {
    nothing,
    playerobj,
    inertobj,
    guardobj,
    officerobj,
    ssobj,
    dogobj,
    bossobj,
    schabbobj,
    fakeobj,
    mechahitlerobj,
    mutantobj,
    needleobj,
    fireobj,
    bjobj,
    ghostobj,
    realhitlerobj,
    gretelobj,
    giftobj,
    fatobj,
    rocketobj,
    spectreobj,
    angelobj,
    transobj,
    uberobj,
    willobj,
    deathobj,
    hrocketobj,
    sparkobj
}

export enum stat_t {
    dressing,
    block,
    bo_gibs,
    bo_alpo,
    bo_firstaid,
    bo_key1,
    bo_key2,
    bo_key3,
    bo_key4,
    bo_cross,
    bo_chalice,
    bo_bible,
    bo_crown,
    bo_clip,
    bo_clip2,
    bo_machinegun,
    bo_chaingun,
    bo_food,
    bo_fullheal,
    bo_25clip,
    bo_spear
}

export enum dirtype {
    east = 0,
    northeast,
    north,
    northwest,
    west,
    southwest,
    south,
    southeast,
    nodir
}

export const NUMENEMIES = 22;
export enum enemy_t {
    en_guard,
    en_officer,
    en_ss,
    en_dog,
    en_boss,
    en_schabbs,
    en_fake,
    en_hitler,
    en_mutant,
    en_blinky,
    en_clyde,
    en_pinky,
    en_inky,
    en_gretel,
    en_gift,
    en_fat,
    en_spectre,
    en_angel,
    en_trans,
    en_uber,
    en_will,
    en_death
}

export interface statetype {
    rotate: boolean;
    shapenum: number;
    tictime: number;
    think: ((ob: objtype) => void) | null;
    action: ((ob: objtype) => void) | null;
    next: statetype | null;
}

export interface statobj_t {
    tilex: number;
    tiley: number;
    visspot: number;    // index into spotvis flat array
    shapenum: number;
    flags: number;
    itemnumber: number;
}

export enum dooraction_t {
    dr_open = 0,
    dr_closed,
    dr_opening,
    dr_closing
}

export interface doorobj_t {
    tilex: number;
    tiley: number;
    vertical: boolean;
    lock: number;
    action: dooraction_t;
    ticcount: number;
}

export interface objtype {
    active: activetype;
    ticcount: number;
    obclass: classtype;
    state: statetype | null;
    flags: number;
    distance: number;
    dir: dirtype;
    x: fixed;
    y: fixed;
    tilex: number;
    tiley: number;
    areanumber: number;
    viewx: number;
    viewheight: number;
    transx: fixed;
    transy: fixed;
    angle: number;
    hitpoints: number;
    speed: number;
    temp1: number;
    temp2: number;
    temp3: number;
    next: objtype | null;
    prev: objtype | null;
}

export function newObjtype(): objtype {
    return {
        active: activetype.ac_no,
        ticcount: 0,
        obclass: classtype.nothing,
        state: null,
        flags: 0,
        distance: 0,
        dir: dirtype.nodir,
        x: 0, y: 0,
        tilex: 0, tiley: 0,
        areanumber: 0,
        viewx: 0, viewheight: 0,
        transx: 0, transy: 0,
        angle: 0,
        hitpoints: 0,
        speed: 0,
        temp1: 0, temp2: 0, temp3: 0,
        next: null, prev: null,
    };
}

export const NUMBUTTONS = 8;
export enum bt {
    bt_nobutton = -1,
    bt_attack = 0,
    bt_strafe,
    bt_run,
    bt_use,
    bt_readyknife,
    bt_readypistol,
    bt_readymachinegun,
    bt_readychaingun
}

export const NUMWEAPONS = 5;
export enum weapontype {
    wp_knife,
    wp_pistol,
    wp_machinegun,
    wp_chaingun
}

export enum gamedifficulty_t {
    gd_baby,
    gd_easy,
    gd_medium,
    gd_hard
}

export interface gametype {
    difficulty: number;
    mapon: number;
    oldscore: number;
    score: number;
    nextextra: number;
    lives: number;
    health: number;
    ammo: number;
    keys: number;
    bestweapon: weapontype;
    weapon: weapontype;
    chosenweapon: weapontype;
    faceframe: number;
    attackframe: number;
    attackcount: number;
    weaponframe: number;
    episode: number;
    secretcount: number;
    treasurecount: number;
    killcount: number;
    secrettotal: number;
    treasuretotal: number;
    killtotal: number;
    TimeCount: number;
    killx: number;
    killy: number;
    victoryflag: boolean;
}

export function newGametype(): gametype {
    return {
        difficulty: 0, mapon: 0,
        oldscore: 0, score: 0, nextextra: 0,
        lives: 0, health: 0, ammo: 0, keys: 0,
        bestweapon: weapontype.wp_knife,
        weapon: weapontype.wp_knife,
        chosenweapon: weapontype.wp_knife,
        faceframe: 0, attackframe: 0, attackcount: 0, weaponframe: 0,
        episode: 0, secretcount: 0, treasurecount: 0, killcount: 0,
        secrettotal: 0, treasuretotal: 0, killtotal: 0,
        TimeCount: 0, killx: 0, killy: 0,
        victoryflag: false,
    };
}

export enum exit_t {
    ex_stillplaying,
    ex_completed,
    ex_died,
    ex_warped,
    ex_resetgame,
    ex_loadedgame,
    ex_victorious,
    ex_abort,
    ex_demodone,
    ex_secretlevel
}

//=============================================================================
//                      Refresh manager replacements
//=============================================================================

export const PORTTILESWIDE = 20;
export const PORTTILESHIGH = 13;
export const UPDATEWIDE = PORTTILESWIDE;
export const UPDATEHIGH = PORTTILESHIGH;
export const MAXTICS = 10;
export const DEMOTICS = 4;
export const UPDATETERMINATE = 0x0301;

export const UPDATESIZE = (UPDATEWIDE * UPDATEHIGH);

//=============================================================================
//                      WL_SCALE DEFINITIONS
//=============================================================================

export const COMPSCALECODESTART = (65 * 4);

export interface t_compshape {
    leftpix: number;
    rightpix: number;
    dataofs: Uint16Array;   // dataofs[64]
    data: Uint8Array;       // variable length data following
}

//=============================================================================
//                      GLOBAL MUTABLE STATE
//
// These mirror the C globals. We keep them module-level for faithfulness.
//=============================================================================

export let mapwidth = 0;
export let mapheight = 0;
export let tics = 0;
export let compatability = false;

export let updateptr: Uint8Array = new Uint8Array(0);
export const uwidthtable: Uint32Array = new Uint32Array(UPDATEHIGH);
export const blockstarts: Uint32Array = new Uint32Array(UPDATEWIDE * UPDATEHIGH);

export let fontcolor: number = 0;
export let backcolor: number = 0;

export function SETFONTCOLOR(f: number, b: number): void {
    fontcolor = f;
    backcolor = b;
}

// map data  (set by CA_CacheMap)
export const mapsegs: Uint16Array[] = [new Uint16Array(0), new Uint16Array(0)];
export const farmapylookup: Uint32Array = new Uint32Array(MAPSIZE);

// tilemap & spotvis
export const tilemap: Uint8Array[] = Array.from({ length: MAPSIZE }, () => new Uint8Array(MAPSIZE));
export const spotvis: Uint8Array[] = Array.from({ length: MAPSIZE }, () => new Uint8Array(MAPSIZE));
export const actorat: (objtype | number | null)[][] = Array.from({ length: MAPSIZE }, () => new Array(MAPSIZE).fill(null));

export const update: Uint8Array = new Uint8Array(UPDATESIZE);

// setter helpers for module-level lets
export function setMapWidth(v: number): void { mapwidth = v; }
export function setMapHeight(v: number): void { mapheight = v; }
export function setTics(v: number): void { tics = v; }
export function setCompatability(v: boolean): void { compatability = v; }
export function setUpdatePtr(v: Uint8Array): void { updateptr = v; }
