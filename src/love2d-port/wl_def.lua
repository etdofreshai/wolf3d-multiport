-- WL_DEF.lua
-- Core type definitions and constants for Wolfenstein 3-D
-- Ported from WL_DEF.H

local bit = require("bit")
local band, bor, bxor, lshift, rshift = bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift

local wl_def = {}

---------------------------------------------------------------------------
-- Build configuration (equivalent to VERSION.H)
---------------------------------------------------------------------------
-- #define GOODTIMES
-- #define ARTSEXTERN
-- #define DEMOSEXTERN
-- #define CARMACIZED
wl_def.GOODTIMES = true
wl_def.CARMACIZED = true

---------------------------------------------------------------------------
-- Date
---------------------------------------------------------------------------
wl_def.YEAR  = 1992
wl_def.MONTH = 9
wl_def.DAY   = 30

---------------------------------------------------------------------------
-- MACROS
---------------------------------------------------------------------------
function wl_def.SIGN(x)
    if x > 0 then return 1
    elseif x < 0 then return -1
    else return 0
    end
end

function wl_def.ABS(x)
    return math.abs(x)
end

function wl_def.LABS(x)
    return math.abs(x)
end

---------------------------------------------------------------------------
-- GLOBAL CONSTANTS
---------------------------------------------------------------------------
wl_def.MAXACTORS   = 150
wl_def.MAXSTATS    = 400
wl_def.MAXDOORS    = 64
wl_def.MAXWALLTILES = 64

-- tile constants
wl_def.ICONARROWS     = 90
wl_def.PUSHABLETILE   = 98
wl_def.EXITTILE       = 99
wl_def.AREATILE       = 107
wl_def.NUMAREAS       = 37
wl_def.ELEVATORTILE   = 21
wl_def.AMBUSHTILE     = 106
wl_def.ALTELEVATORTILE = 107

wl_def.NUMBERCHARS    = 9

wl_def.EXTRAPOINTS    = 40000
wl_def.PLAYERSPEED    = 3000
wl_def.RUNSPEED       = 6000

wl_def.SCREENBWIDE    = 80

wl_def.HEIGHTRATIO    = 0.50

wl_def.BORDERCOLOR_CONST = 3
wl_def.FLASHCOLOR     = 5
wl_def.FLASHTICS      = 4

wl_def.MINACTORDIST   = 0x10000

wl_def.NUMLATCHPICS   = 100

wl_def.PI = 3.141592657
wl_def.M_PI = math.pi

wl_def.GLOBAL1      = lshift(1, 16)   -- 65536
wl_def.TILEGLOBAL   = lshift(1, 16)
wl_def.PIXGLOBAL    = math.floor(lshift(1, 16) / 64)
wl_def.TILESHIFT    = 16
wl_def.UNSIGNEDSHIFT = 8

wl_def.ANGLES       = 360
wl_def.ANGLEQUAD    = 90
wl_def.FINEANGLES   = 3600
wl_def.ANG90        = 900
wl_def.ANG180       = 1800
wl_def.ANG270       = 2700
wl_def.ANG360       = 3600
wl_def.VANG90       = 90
wl_def.VANG180      = 180
wl_def.VANG270      = 270
wl_def.VANG360      = 360

wl_def.MINDIST       = 0x5800

wl_def.MAXSCALEHEIGHT = 256
wl_def.MAXVIEWWIDTH   = 320

wl_def.MAPSIZE       = 64
wl_def.NORTH         = 0
wl_def.EAST          = 1
wl_def.SOUTH         = 2
wl_def.WEST          = 3

wl_def.STATUSLINES   = 40

wl_def.SCREENWIDTH   = 80
wl_def.SCREENSIZE    = 80 * 208
wl_def.PAGE1START    = 0
wl_def.PAGE2START    = 80 * 208
wl_def.PAGE3START    = 80 * 208 * 2
wl_def.FREESTART     = 80 * 208 * 3

wl_def.PIXRADIUS     = 512
wl_def.STARTAMMO     = 8

-- object flag values
wl_def.FL_SHOOTABLE   = 1
wl_def.FL_BONUS       = 2
wl_def.FL_NEVERMARK   = 4
wl_def.FL_VISABLE     = 8
wl_def.FL_ATTACKMODE  = 16
wl_def.FL_FIRSTATTACK = 32
wl_def.FL_AMBUSH      = 64
wl_def.FL_NONMARK     = 128

---------------------------------------------------------------------------
-- Sprite constants (enum, WL6 version - not SPEAR)
---------------------------------------------------------------------------
local spr_idx = 0
local function next_spr()
    local v = spr_idx
    spr_idx = spr_idx + 1
    return v
end

wl_def.SPR_DEMO = next_spr()       -- 0
wl_def.SPR_DEATHCAM = next_spr()   -- 1

-- static sprites 0..47
for i = 0, 47 do
    wl_def["SPR_STAT_" .. i] = next_spr()
end

-- guard
wl_def.SPR_GRD_S_1 = next_spr()
for i = 2, 8 do wl_def["SPR_GRD_S_" .. i] = next_spr() end
for w = 1, 4 do
    for i = 1, 8 do wl_def["SPR_GRD_W" .. w .. "_" .. i] = next_spr() end
end
wl_def.SPR_GRD_PAIN_1 = next_spr()
wl_def.SPR_GRD_DIE_1 = next_spr()
wl_def.SPR_GRD_DIE_2 = next_spr()
wl_def.SPR_GRD_DIE_3 = next_spr()
wl_def.SPR_GRD_PAIN_2 = next_spr()
wl_def.SPR_GRD_DEAD = next_spr()
wl_def.SPR_GRD_SHOOT1 = next_spr()
wl_def.SPR_GRD_SHOOT2 = next_spr()
wl_def.SPR_GRD_SHOOT3 = next_spr()

-- dogs
for w = 1, 4 do
    for i = 1, 8 do wl_def["SPR_DOG_W" .. w .. "_" .. i] = next_spr() end
end
wl_def.SPR_DOG_DIE_1 = next_spr()
wl_def.SPR_DOG_DIE_2 = next_spr()
wl_def.SPR_DOG_DIE_3 = next_spr()
wl_def.SPR_DOG_DEAD = next_spr()
wl_def.SPR_DOG_JUMP1 = next_spr()
wl_def.SPR_DOG_JUMP2 = next_spr()
wl_def.SPR_DOG_JUMP3 = next_spr()

-- ss
for i = 1, 8 do wl_def["SPR_SS_S_" .. i] = next_spr() end
for w = 1, 4 do
    for i = 1, 8 do wl_def["SPR_SS_W" .. w .. "_" .. i] = next_spr() end
end
wl_def.SPR_SS_PAIN_1 = next_spr()
wl_def.SPR_SS_DIE_1 = next_spr()
wl_def.SPR_SS_DIE_2 = next_spr()
wl_def.SPR_SS_DIE_3 = next_spr()
wl_def.SPR_SS_PAIN_2 = next_spr()
wl_def.SPR_SS_DEAD = next_spr()
wl_def.SPR_SS_SHOOT1 = next_spr()
wl_def.SPR_SS_SHOOT2 = next_spr()
wl_def.SPR_SS_SHOOT3 = next_spr()

-- mutant
for i = 1, 8 do wl_def["SPR_MUT_S_" .. i] = next_spr() end
for w = 1, 4 do
    for i = 1, 8 do wl_def["SPR_MUT_W" .. w .. "_" .. i] = next_spr() end
end
wl_def.SPR_MUT_PAIN_1 = next_spr()
wl_def.SPR_MUT_DIE_1 = next_spr()
wl_def.SPR_MUT_DIE_2 = next_spr()
wl_def.SPR_MUT_DIE_3 = next_spr()
wl_def.SPR_MUT_PAIN_2 = next_spr()
wl_def.SPR_MUT_DIE_4 = next_spr()
wl_def.SPR_MUT_DEAD = next_spr()
wl_def.SPR_MUT_SHOOT1 = next_spr()
wl_def.SPR_MUT_SHOOT2 = next_spr()
wl_def.SPR_MUT_SHOOT3 = next_spr()
wl_def.SPR_MUT_SHOOT4 = next_spr()

-- officer
for i = 1, 8 do wl_def["SPR_OFC_S_" .. i] = next_spr() end
for w = 1, 4 do
    for i = 1, 8 do wl_def["SPR_OFC_W" .. w .. "_" .. i] = next_spr() end
end
wl_def.SPR_OFC_PAIN_1 = next_spr()
wl_def.SPR_OFC_DIE_1 = next_spr()
wl_def.SPR_OFC_DIE_2 = next_spr()
wl_def.SPR_OFC_DIE_3 = next_spr()
wl_def.SPR_OFC_PAIN_2 = next_spr()
wl_def.SPR_OFC_DIE_4 = next_spr()
wl_def.SPR_OFC_DEAD = next_spr()
wl_def.SPR_OFC_SHOOT1 = next_spr()
wl_def.SPR_OFC_SHOOT2 = next_spr()
wl_def.SPR_OFC_SHOOT3 = next_spr()

-- ghosts (WL6 only, not SPEAR)
wl_def.SPR_BLINKY_W1 = next_spr()
wl_def.SPR_BLINKY_W2 = next_spr()
wl_def.SPR_PINKY_W1  = next_spr()
wl_def.SPR_PINKY_W2  = next_spr()
wl_def.SPR_CLYDE_W1  = next_spr()
wl_def.SPR_CLYDE_W2  = next_spr()
wl_def.SPR_INKY_W1   = next_spr()
wl_def.SPR_INKY_W2   = next_spr()

-- hans
wl_def.SPR_BOSS_W1 = next_spr()
wl_def.SPR_BOSS_W2 = next_spr()
wl_def.SPR_BOSS_W3 = next_spr()
wl_def.SPR_BOSS_W4 = next_spr()
wl_def.SPR_BOSS_SHOOT1 = next_spr()
wl_def.SPR_BOSS_SHOOT2 = next_spr()
wl_def.SPR_BOSS_SHOOT3 = next_spr()
wl_def.SPR_BOSS_DEAD = next_spr()
wl_def.SPR_BOSS_DIE1 = next_spr()
wl_def.SPR_BOSS_DIE2 = next_spr()
wl_def.SPR_BOSS_DIE3 = next_spr()

-- schabbs
wl_def.SPR_SCHABB_W1 = next_spr()
wl_def.SPR_SCHABB_W2 = next_spr()
wl_def.SPR_SCHABB_W3 = next_spr()
wl_def.SPR_SCHABB_W4 = next_spr()
wl_def.SPR_SCHABB_SHOOT1 = next_spr()
wl_def.SPR_SCHABB_SHOOT2 = next_spr()
wl_def.SPR_SCHABB_DIE1 = next_spr()
wl_def.SPR_SCHABB_DIE2 = next_spr()
wl_def.SPR_SCHABB_DIE3 = next_spr()
wl_def.SPR_SCHABB_DEAD = next_spr()
wl_def.SPR_HYPO1 = next_spr()
wl_def.SPR_HYPO2 = next_spr()
wl_def.SPR_HYPO3 = next_spr()
wl_def.SPR_HYPO4 = next_spr()

-- fake
wl_def.SPR_FAKE_W1 = next_spr()
wl_def.SPR_FAKE_W2 = next_spr()
wl_def.SPR_FAKE_W3 = next_spr()
wl_def.SPR_FAKE_W4 = next_spr()
wl_def.SPR_FAKE_SHOOT = next_spr()
wl_def.SPR_FIRE1 = next_spr()
wl_def.SPR_FIRE2 = next_spr()
wl_def.SPR_FAKE_DIE1 = next_spr()
wl_def.SPR_FAKE_DIE2 = next_spr()
wl_def.SPR_FAKE_DIE3 = next_spr()
wl_def.SPR_FAKE_DIE4 = next_spr()
wl_def.SPR_FAKE_DIE5 = next_spr()
wl_def.SPR_FAKE_DEAD = next_spr()

-- hitler
wl_def.SPR_MECHA_W1 = next_spr()
wl_def.SPR_MECHA_W2 = next_spr()
wl_def.SPR_MECHA_W3 = next_spr()
wl_def.SPR_MECHA_W4 = next_spr()
wl_def.SPR_MECHA_SHOOT1 = next_spr()
wl_def.SPR_MECHA_SHOOT2 = next_spr()
wl_def.SPR_MECHA_SHOOT3 = next_spr()
wl_def.SPR_MECHA_DEAD = next_spr()
wl_def.SPR_MECHA_DIE1 = next_spr()
wl_def.SPR_MECHA_DIE2 = next_spr()
wl_def.SPR_MECHA_DIE3 = next_spr()

wl_def.SPR_HITLER_W1 = next_spr()
wl_def.SPR_HITLER_W2 = next_spr()
wl_def.SPR_HITLER_W3 = next_spr()
wl_def.SPR_HITLER_W4 = next_spr()
wl_def.SPR_HITLER_SHOOT1 = next_spr()
wl_def.SPR_HITLER_SHOOT2 = next_spr()
wl_def.SPR_HITLER_SHOOT3 = next_spr()
wl_def.SPR_HITLER_DEAD = next_spr()
wl_def.SPR_HITLER_DIE1 = next_spr()
wl_def.SPR_HITLER_DIE2 = next_spr()
wl_def.SPR_HITLER_DIE3 = next_spr()
wl_def.SPR_HITLER_DIE4 = next_spr()
wl_def.SPR_HITLER_DIE5 = next_spr()
wl_def.SPR_HITLER_DIE6 = next_spr()
wl_def.SPR_HITLER_DIE7 = next_spr()

-- giftmacher
wl_def.SPR_GIFT_W1 = next_spr()
wl_def.SPR_GIFT_W2 = next_spr()
wl_def.SPR_GIFT_W3 = next_spr()
wl_def.SPR_GIFT_W4 = next_spr()
wl_def.SPR_GIFT_SHOOT1 = next_spr()
wl_def.SPR_GIFT_SHOOT2 = next_spr()
wl_def.SPR_GIFT_DIE1 = next_spr()
wl_def.SPR_GIFT_DIE2 = next_spr()
wl_def.SPR_GIFT_DIE3 = next_spr()
wl_def.SPR_GIFT_DEAD = next_spr()

-- rocket, smoke, boom
wl_def.SPR_ROCKET_1 = next_spr()
wl_def.SPR_ROCKET_2 = next_spr()
wl_def.SPR_ROCKET_3 = next_spr()
wl_def.SPR_ROCKET_4 = next_spr()
wl_def.SPR_ROCKET_5 = next_spr()
wl_def.SPR_ROCKET_6 = next_spr()
wl_def.SPR_ROCKET_7 = next_spr()
wl_def.SPR_ROCKET_8 = next_spr()
wl_def.SPR_SMOKE_1 = next_spr()
wl_def.SPR_SMOKE_2 = next_spr()
wl_def.SPR_SMOKE_3 = next_spr()
wl_def.SPR_SMOKE_4 = next_spr()
wl_def.SPR_BOOM_1 = next_spr()
wl_def.SPR_BOOM_2 = next_spr()
wl_def.SPR_BOOM_3 = next_spr()

-- gretel
wl_def.SPR_GRETEL_W1 = next_spr()
wl_def.SPR_GRETEL_W2 = next_spr()
wl_def.SPR_GRETEL_W3 = next_spr()
wl_def.SPR_GRETEL_W4 = next_spr()
wl_def.SPR_GRETEL_SHOOT1 = next_spr()
wl_def.SPR_GRETEL_SHOOT2 = next_spr()
wl_def.SPR_GRETEL_SHOOT3 = next_spr()
wl_def.SPR_GRETEL_DEAD = next_spr()
wl_def.SPR_GRETEL_DIE1 = next_spr()
wl_def.SPR_GRETEL_DIE2 = next_spr()
wl_def.SPR_GRETEL_DIE3 = next_spr()

-- fat face
wl_def.SPR_FAT_W1 = next_spr()
wl_def.SPR_FAT_W2 = next_spr()
wl_def.SPR_FAT_W3 = next_spr()
wl_def.SPR_FAT_W4 = next_spr()
wl_def.SPR_FAT_SHOOT1 = next_spr()
wl_def.SPR_FAT_SHOOT2 = next_spr()
wl_def.SPR_FAT_SHOOT3 = next_spr()
wl_def.SPR_FAT_SHOOT4 = next_spr()
wl_def.SPR_FAT_DIE1 = next_spr()
wl_def.SPR_FAT_DIE2 = next_spr()
wl_def.SPR_FAT_DIE3 = next_spr()
wl_def.SPR_FAT_DEAD = next_spr()

-- bj
wl_def.SPR_BJ_W1 = next_spr()
wl_def.SPR_BJ_W2 = next_spr()
wl_def.SPR_BJ_W3 = next_spr()
wl_def.SPR_BJ_W4 = next_spr()
wl_def.SPR_BJ_JUMP1 = next_spr()
wl_def.SPR_BJ_JUMP2 = next_spr()
wl_def.SPR_BJ_JUMP3 = next_spr()
wl_def.SPR_BJ_JUMP4 = next_spr()

-- player attack frames
wl_def.SPR_KNIFEREADY = next_spr()
wl_def.SPR_KNIFEATK1 = next_spr()
wl_def.SPR_KNIFEATK2 = next_spr()
wl_def.SPR_KNIFEATK3 = next_spr()
wl_def.SPR_KNIFEATK4 = next_spr()

wl_def.SPR_PISTOLREADY = next_spr()
wl_def.SPR_PISTOLATK1 = next_spr()
wl_def.SPR_PISTOLATK2 = next_spr()
wl_def.SPR_PISTOLATK3 = next_spr()
wl_def.SPR_PISTOLATK4 = next_spr()

wl_def.SPR_MACHINEGUNREADY = next_spr()
wl_def.SPR_MACHINEGUNATK1 = next_spr()
wl_def.SPR_MACHINEGUNATK2 = next_spr()
wl_def.MACHINEGUNATK3 = next_spr()
wl_def.SPR_MACHINEGUNATK4 = next_spr()

wl_def.SPR_CHAINREADY = next_spr()
wl_def.SPR_CHAINATK1 = next_spr()
wl_def.SPR_CHAINATK2 = next_spr()
wl_def.SPR_CHAINATK3 = next_spr()
wl_def.SPR_CHAINATK4 = next_spr()

---------------------------------------------------------------------------
-- GLOBAL TYPES (enums)
---------------------------------------------------------------------------

-- controldir_t
wl_def.di_north = 0
wl_def.di_east  = 1
wl_def.di_south = 2
wl_def.di_west  = 3

-- door_t
wl_def.dr_normal   = 0
wl_def.dr_lock1    = 1
wl_def.dr_lock2    = 2
wl_def.dr_lock3    = 3
wl_def.dr_lock4    = 4
wl_def.dr_elevator = 5

-- activetype
wl_def.ac_badobject = -1
wl_def.ac_no       = 0
wl_def.ac_yes      = 1
wl_def.ac_allways  = 2

-- classtype
wl_def.nothing        = 0
wl_def.playerobj      = 1
wl_def.inertobj       = 2
wl_def.guardobj       = 3
wl_def.officerobj     = 4
wl_def.ssobj          = 5
wl_def.dogobj         = 6
wl_def.bossobj        = 7
wl_def.schabbobj      = 8
wl_def.fakeobj        = 9
wl_def.mechahitlerobj = 10
wl_def.mutantobj      = 11
wl_def.needleobj      = 12
wl_def.fireobj        = 13
wl_def.bjobj          = 14
wl_def.ghostobj       = 15
wl_def.realhitlerobj  = 16
wl_def.gretelobj      = 17
wl_def.giftobj        = 18
wl_def.fatobj         = 19
wl_def.rocketobj      = 20
wl_def.spectreobj     = 21
wl_def.angelobj       = 22
wl_def.transobj       = 23
wl_def.uberobj        = 24
wl_def.willobj        = 25
wl_def.deathobj       = 26
wl_def.hrocketobj     = 27
wl_def.sparkobj       = 28

-- stat_t (bonus object types)
wl_def.dressing     = 0
wl_def.block        = 1
wl_def.bo_gibs      = 2
wl_def.bo_alpo      = 3
wl_def.bo_firstaid  = 4
wl_def.bo_key1      = 5
wl_def.bo_key2      = 6
wl_def.bo_key3      = 7
wl_def.bo_key4      = 8
wl_def.bo_cross     = 9
wl_def.bo_chalice   = 10
wl_def.bo_bible     = 11
wl_def.bo_crown     = 12
wl_def.bo_clip      = 13
wl_def.bo_clip2     = 14
wl_def.bo_machinegun = 15
wl_def.bo_chaingun  = 16
wl_def.bo_food      = 17
wl_def.bo_fullheal  = 18
wl_def.bo_25clip    = 19
wl_def.bo_spear     = 20

-- dirtype (8 directions + nodir)
wl_def.dir_east      = 0
wl_def.dir_northeast = 1
wl_def.dir_north     = 2
wl_def.dir_northwest = 3
wl_def.dir_west      = 4
wl_def.dir_southwest = 5
wl_def.dir_south     = 6
wl_def.dir_southeast = 7
wl_def.dir_nodir     = 8

-- enemy_t
wl_def.NUMENEMIES = 22
wl_def.en_guard   = 0
wl_def.en_officer = 1
wl_def.en_ss      = 2
wl_def.en_dog     = 3
wl_def.en_boss    = 4
wl_def.en_schabbs = 5
wl_def.en_fake    = 6
wl_def.en_hitler  = 7
wl_def.en_mutant  = 8
wl_def.en_blinky  = 9
wl_def.en_clyde   = 10
wl_def.en_pinky   = 11
wl_def.en_inky    = 12
wl_def.en_gretel  = 13
wl_def.en_gift    = 14
wl_def.en_fat     = 15
wl_def.en_spectre = 16
wl_def.en_angel   = 17
wl_def.en_trans   = 18
wl_def.en_uber    = 19
wl_def.en_will    = 20
wl_def.en_death   = 21

-- door action states
wl_def.dr_open    = 0
wl_def.dr_closed  = 1
wl_def.dr_opening = 2
wl_def.dr_closing = 3

-- button types
wl_def.NUMBUTTONS         = 8
wl_def.bt_nobutton        = -1
wl_def.bt_attack          = 0
wl_def.bt_strafe          = 1
wl_def.bt_run             = 2
wl_def.bt_use             = 3
wl_def.bt_readyknife      = 4
wl_def.bt_readypistol     = 5
wl_def.bt_readymachinegun = 6
wl_def.bt_readychaingun   = 7

-- weapontype
wl_def.NUMWEAPONS    = 5
wl_def.wp_knife      = 0
wl_def.wp_pistol     = 1
wl_def.wp_machinegun = 2
wl_def.wp_chaingun   = 3

-- gamedifficulty_t
wl_def.gd_baby   = 0
wl_def.gd_easy   = 1
wl_def.gd_medium = 2
wl_def.gd_hard   = 3

-- exit_t (playstate values)
wl_def.ex_stillplaying = 0
wl_def.ex_completed    = 1
wl_def.ex_died         = 2
wl_def.ex_warped       = 3
wl_def.ex_resetgame    = 4
wl_def.ex_loadedgame   = 5
wl_def.ex_victorious   = 6
wl_def.ex_abort        = 7
wl_def.ex_demodone     = 8
wl_def.ex_secretlevel  = 9

---------------------------------------------------------------------------
-- WL_STATE DEFINITIONS
---------------------------------------------------------------------------
wl_def.TURNTICS  = 10
wl_def.SPDPATROL = 512
wl_def.SPDDOG    = 1500

---------------------------------------------------------------------------
-- Refresh manager defines
---------------------------------------------------------------------------
wl_def.PORTTILESWIDE = 20
wl_def.PORTTILESHIGH = 13
wl_def.UPDATEWIDE    = 20
wl_def.UPDATEHIGH    = 13
wl_def.MAXTICS       = 10
wl_def.DEMOTICS      = 4
wl_def.UPDATETERMINATE = 0x0301

---------------------------------------------------------------------------
-- WL_SCALE DEFINITIONS
---------------------------------------------------------------------------
wl_def.COMPSCALECODESTART = 65 * 4

---------------------------------------------------------------------------
-- Struct constructors
---------------------------------------------------------------------------

-- Create a new statetype (state machine state)
function wl_def.new_statetype(rotate, shapenum, tictime, think, action, next_state)
    return {
        rotate   = rotate,
        shapenum = shapenum,
        tictime  = tictime,
        think    = think,
        action   = action,
        next     = next_state,
    }
end

-- Create a new statobj_t (static object)
function wl_def.new_statobj()
    return {
        tilex    = 0,
        tiley    = 0,
        visspot  = nil,
        shapenum = -1,
        flags    = 0,
        itemnumber = 0,
    }
end

-- Create a new doorobj_t (door object)
function wl_def.new_doorobj()
    return {
        tilex    = 0,
        tiley    = 0,
        vertical = false,
        lock     = 0,
        action   = wl_def.dr_closed,
        ticcount = 0,
    }
end

-- Create a new objtype (thinking actor)
function wl_def.new_objtype()
    return {
        active     = wl_def.ac_no,
        ticcount   = 0,
        obclass    = wl_def.nothing,
        state      = nil,
        flags      = 0,
        distance   = 0,
        dir        = wl_def.dir_nodir,
        x          = 0,
        y          = 0,
        tilex      = 0,
        tiley      = 0,
        areanumber = 0,
        viewx      = 0,
        viewheight = 0,
        transx     = 0,
        transy     = 0,
        angle      = 0,
        hitpoints  = 0,
        speed      = 0,
        temp1      = 0,
        temp2      = 0,
        temp3      = 0,
        next       = nil,
        prev       = nil,
    }
end

-- Create a new gamestate
function wl_def.new_gamestate()
    return {
        difficulty    = 0,
        mapon         = 0,
        oldscore      = 0,
        score         = 0,
        nextextra     = 0,
        lives         = 0,
        health        = 0,
        ammo          = 0,
        keys          = 0,
        bestweapon    = wl_def.wp_pistol,
        weapon        = wl_def.wp_pistol,
        chosenweapon  = wl_def.wp_pistol,
        faceframe     = 0,
        attackframe   = 0,
        attackcount   = 0,
        weaponframe   = 0,
        episode       = 0,
        secretcount   = 0,
        treasurecount = 0,
        killcount     = 0,
        secrettotal   = 0,
        treasuretotal = 0,
        killtotal     = 0,
        TimeCount     = 0,
        killx         = 0,
        killy         = 0,
        victoryflag   = false,
    }
end

---------------------------------------------------------------------------
-- MAPSPOT helper (x,y are 0-indexed tile coords, plane is 0-indexed)
-- mapsegs is a global table of arrays indexed [offset+1] (1-indexed)
---------------------------------------------------------------------------
function wl_def.MAPSPOT(x, y, plane, mapsegs, farmapylookup)
    return mapsegs[plane + 1][farmapylookup[y + 1] + x + 1]
end

function wl_def.SET_MAPSPOT(x, y, plane, mapsegs, farmapylookup, val)
    mapsegs[plane + 1][farmapylookup[y + 1] + x + 1] = val
end

return wl_def
