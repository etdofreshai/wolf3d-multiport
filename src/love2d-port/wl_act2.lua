-- WL_ACT2.lua
-- Actor behavior/AI - ported from WL_ACT2.C
-- Contains state definitions and think/action functions for all enemies

local bit = require("bit")
local band, bor, bxor, lshift, rshift = bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift

local wl_def = require("wl_def")
local id_us  = require("id_us")

local wl_act2 = {}

---------------------------------------------------------------------------
-- Hit points table [difficulty][enemy]  (0-indexed on both)
---------------------------------------------------------------------------
wl_act2.starthitpoints = {
    -- Baby mode
    [0] = {[0]=25, 50, 100, 1, 850, 850, 200, 800, 45, 25, 25, 25, 25, 850, 850, 850, 5, 1450, 850, 1050, 950, 1250},
    -- Don't hurt me
    [1] = {[0]=25, 50, 100, 1, 950, 950, 300, 950, 55, 25, 25, 25, 25, 950, 950, 950, 10, 1550, 950, 1150, 1050, 1350},
    -- Bring 'em on
    [2] = {[0]=25, 50, 100, 1, 1050, 1550, 400, 1050, 55, 25, 25, 25, 25, 1050, 1050, 1050, 15, 1650, 1050, 1250, 1150, 1450},
    -- Death incarnate
    [3] = {[0]=25, 50, 100, 1, 1200, 2400, 500, 1200, 65, 25, 25, 25, 25, 1200, 1200, 1200, 25, 2000, 1200, 1400, 1300, 1600},
}

---------------------------------------------------------------------------
-- Forward-declare think/action functions
---------------------------------------------------------------------------

-- These will be defined after state tables
local T_Stand, T_Path, T_Chase, T_Shoot, T_Bite, T_DogChase
local T_Ghosts, T_Projectile, T_BJRun, T_BJJump, T_BJDone, T_BJYell
local T_SchabbChase, T_SchabbThrow, T_GiftChase, T_GiftThrow
local T_FakeChase, T_FakeFire, T_FatChase, T_FatRocket
local T_BossChase, T_GretelChase
local T_MechaChase, T_MechaShoot, T_HitlerChase, T_HitlerShoot
local A_DeathScream, A_Smoke, A_Slurpie, A_HitlerMorph, A_MechaSound
local A_StartDeathCam

---------------------------------------------------------------------------
-- State machine definitions
---------------------------------------------------------------------------

-- We define states as tables. Because of forward references (next state
-- references a state not yet defined), we create them first, then fill in .next.

local function S(rotate, shapenum, tictime, think, action)
    return {rotate = rotate, shapenum = shapenum, tictime = tictime, think = think, action = action, next = nil}
end

-- Guard states
wl_act2.s_grdstand   = S(true, wl_def.SPR_GRD_S_1, 0, nil, nil)
wl_act2.s_grdpath1   = S(true, wl_def.SPR_GRD_W1_1, 20, nil, nil)
wl_act2.s_grdpath1s  = S(true, wl_def.SPR_GRD_W1_1, 5, nil, nil)
wl_act2.s_grdpath2   = S(true, wl_def.SPR_GRD_W2_1, 15, nil, nil)
wl_act2.s_grdpath3   = S(true, wl_def.SPR_GRD_W3_1, 20, nil, nil)
wl_act2.s_grdpath3s  = S(true, wl_def.SPR_GRD_W3_1, 5, nil, nil)
wl_act2.s_grdpath4   = S(true, wl_def.SPR_GRD_W4_1, 15, nil, nil)
wl_act2.s_grdpain    = S(2, wl_def.SPR_GRD_PAIN_1, 10, nil, nil)
wl_act2.s_grdpain1   = S(2, wl_def.SPR_GRD_PAIN_2, 10, nil, nil)
wl_act2.s_grdshoot1  = S(false, wl_def.SPR_GRD_SHOOT1, 20, nil, nil)
wl_act2.s_grdshoot2  = S(false, wl_def.SPR_GRD_SHOOT2, 20, nil, nil)
wl_act2.s_grdshoot3  = S(false, wl_def.SPR_GRD_SHOOT3, 20, nil, nil)
wl_act2.s_grdchase1  = S(true, wl_def.SPR_GRD_W1_1, 10, nil, nil)
wl_act2.s_grdchase1s = S(true, wl_def.SPR_GRD_W1_1, 3, nil, nil)
wl_act2.s_grdchase2  = S(true, wl_def.SPR_GRD_W2_1, 8, nil, nil)
wl_act2.s_grdchase3  = S(true, wl_def.SPR_GRD_W3_1, 10, nil, nil)
wl_act2.s_grdchase3s = S(true, wl_def.SPR_GRD_W3_1, 3, nil, nil)
wl_act2.s_grdchase4  = S(true, wl_def.SPR_GRD_W4_1, 8, nil, nil)
wl_act2.s_grddie1    = S(false, wl_def.SPR_GRD_DIE_1, 15, nil, nil)
wl_act2.s_grddie2    = S(false, wl_def.SPR_GRD_DIE_2, 15, nil, nil)
wl_act2.s_grddie3    = S(false, wl_def.SPR_GRD_DIE_3, 15, nil, nil)
wl_act2.s_grddie4    = S(false, wl_def.SPR_GRD_DEAD, 0, nil, nil)

-- Dog states
wl_act2.s_dogpath1   = S(true, wl_def.SPR_DOG_W1_1, 20, nil, nil)
wl_act2.s_dogpath1s  = S(true, wl_def.SPR_DOG_W1_1, 5, nil, nil)
wl_act2.s_dogpath2   = S(true, wl_def.SPR_DOG_W2_1, 15, nil, nil)
wl_act2.s_dogpath3   = S(true, wl_def.SPR_DOG_W3_1, 20, nil, nil)
wl_act2.s_dogpath3s  = S(true, wl_def.SPR_DOG_W3_1, 5, nil, nil)
wl_act2.s_dogpath4   = S(true, wl_def.SPR_DOG_W4_1, 15, nil, nil)
wl_act2.s_dogchase1  = S(true, wl_def.SPR_DOG_W1_1, 10, nil, nil)
wl_act2.s_dogchase1s = S(true, wl_def.SPR_DOG_W1_1, 3, nil, nil)
wl_act2.s_dogchase2  = S(true, wl_def.SPR_DOG_W2_1, 8, nil, nil)
wl_act2.s_dogchase3  = S(true, wl_def.SPR_DOG_W3_1, 10, nil, nil)
wl_act2.s_dogchase3s = S(true, wl_def.SPR_DOG_W3_1, 3, nil, nil)
wl_act2.s_dogchase4  = S(true, wl_def.SPR_DOG_W4_1, 8, nil, nil)
wl_act2.s_dogjump1   = S(false, wl_def.SPR_DOG_JUMP1, 10, nil, nil)
wl_act2.s_dogjump2   = S(false, wl_def.SPR_DOG_JUMP2, 10, nil, nil)
wl_act2.s_dogjump3   = S(false, wl_def.SPR_DOG_JUMP3, 10, nil, nil)
wl_act2.s_dogdie1    = S(false, wl_def.SPR_DOG_DIE_1, 15, nil, nil)
wl_act2.s_dogdie2    = S(false, wl_def.SPR_DOG_DIE_2, 15, nil, nil)
wl_act2.s_dogdie3    = S(false, wl_def.SPR_DOG_DIE_3, 15, nil, nil)
wl_act2.s_dogdead    = S(false, wl_def.SPR_DOG_DEAD, 0, nil, nil)

-- SS states
wl_act2.s_ssstand    = S(true, wl_def.SPR_SS_S_1, 0, nil, nil)
wl_act2.s_sspath1    = S(true, wl_def.SPR_SS_W1_1, 20, nil, nil)
wl_act2.s_sspath1s   = S(true, wl_def.SPR_SS_W1_1, 5, nil, nil)
wl_act2.s_sspath2    = S(true, wl_def.SPR_SS_W2_1, 15, nil, nil)
wl_act2.s_sspath3    = S(true, wl_def.SPR_SS_W3_1, 20, nil, nil)
wl_act2.s_sspath3s   = S(true, wl_def.SPR_SS_W3_1, 5, nil, nil)
wl_act2.s_sspath4    = S(true, wl_def.SPR_SS_W4_1, 15, nil, nil)
wl_act2.s_sschase1   = S(true, wl_def.SPR_SS_W1_1, 10, nil, nil)
wl_act2.s_sschase1s  = S(true, wl_def.SPR_SS_W1_1, 3, nil, nil)
wl_act2.s_sschase2   = S(true, wl_def.SPR_SS_W2_1, 8, nil, nil)
wl_act2.s_sschase3   = S(true, wl_def.SPR_SS_W3_1, 10, nil, nil)
wl_act2.s_sschase3s  = S(true, wl_def.SPR_SS_W3_1, 3, nil, nil)
wl_act2.s_sschase4   = S(true, wl_def.SPR_SS_W4_1, 8, nil, nil)
wl_act2.s_sspain     = S(2, wl_def.SPR_SS_PAIN_1, 10, nil, nil)
wl_act2.s_sspain1    = S(2, wl_def.SPR_SS_PAIN_2, 10, nil, nil)
wl_act2.s_ssshoot1   = S(false, wl_def.SPR_SS_SHOOT1, 20, nil, nil)
wl_act2.s_ssshoot2   = S(false, wl_def.SPR_SS_SHOOT2, 20, nil, nil)
wl_act2.s_ssshoot3   = S(false, wl_def.SPR_SS_SHOOT3, 20, nil, nil)
wl_act2.s_ssdie1     = S(false, wl_def.SPR_SS_DIE_1, 15, nil, nil)
wl_act2.s_ssdie2     = S(false, wl_def.SPR_SS_DIE_2, 15, nil, nil)
wl_act2.s_ssdie3     = S(false, wl_def.SPR_SS_DIE_3, 15, nil, nil)
wl_act2.s_ssdead     = S(false, wl_def.SPR_SS_DEAD, 0, nil, nil)

-- Officer states
wl_act2.s_ofcstand   = S(true, wl_def.SPR_OFC_S_1, 0, nil, nil)
wl_act2.s_ofcpath1   = S(true, wl_def.SPR_OFC_W1_1, 20, nil, nil)
wl_act2.s_ofcpath1s  = S(true, wl_def.SPR_OFC_W1_1, 5, nil, nil)
wl_act2.s_ofcpath2   = S(true, wl_def.SPR_OFC_W2_1, 15, nil, nil)
wl_act2.s_ofcpath3   = S(true, wl_def.SPR_OFC_W3_1, 20, nil, nil)
wl_act2.s_ofcpath3s  = S(true, wl_def.SPR_OFC_W3_1, 5, nil, nil)
wl_act2.s_ofcpath4   = S(true, wl_def.SPR_OFC_W4_1, 15, nil, nil)
wl_act2.s_ofcchase1  = S(true, wl_def.SPR_OFC_W1_1, 10, nil, nil)
wl_act2.s_ofcchase1s = S(true, wl_def.SPR_OFC_W1_1, 3, nil, nil)
wl_act2.s_ofcchase2  = S(true, wl_def.SPR_OFC_W2_1, 8, nil, nil)
wl_act2.s_ofcchase3  = S(true, wl_def.SPR_OFC_W3_1, 10, nil, nil)
wl_act2.s_ofcchase3s = S(true, wl_def.SPR_OFC_W3_1, 3, nil, nil)
wl_act2.s_ofcchase4  = S(true, wl_def.SPR_OFC_W4_1, 8, nil, nil)
wl_act2.s_ofcpain    = S(2, wl_def.SPR_OFC_PAIN_1, 10, nil, nil)
wl_act2.s_ofcpain1   = S(2, wl_def.SPR_OFC_PAIN_2, 10, nil, nil)
wl_act2.s_ofcshoot1  = S(false, wl_def.SPR_OFC_SHOOT1, 6, nil, nil)
wl_act2.s_ofcshoot2  = S(false, wl_def.SPR_OFC_SHOOT2, 20, nil, nil)
wl_act2.s_ofcshoot3  = S(false, wl_def.SPR_OFC_SHOOT3, 10, nil, nil)
wl_act2.s_ofcdie1    = S(false, wl_def.SPR_OFC_DIE_1, 11, nil, nil)
wl_act2.s_ofcdie2    = S(false, wl_def.SPR_OFC_DIE_2, 11, nil, nil)
wl_act2.s_ofcdie3    = S(false, wl_def.SPR_OFC_DIE_3, 11, nil, nil)
wl_act2.s_ofcdie4    = S(false, wl_def.SPR_OFC_DIE_4, 11, nil, nil)
wl_act2.s_ofcdead    = S(false, wl_def.SPR_OFC_DEAD, 0, nil, nil)

-- Mutant states
wl_act2.s_mutstand   = S(true, wl_def.SPR_MUT_S_1, 0, nil, nil)
wl_act2.s_mutpath1   = S(true, wl_def.SPR_MUT_W1_1, 20, nil, nil)
wl_act2.s_mutpath1s  = S(true, wl_def.SPR_MUT_W1_1, 5, nil, nil)
wl_act2.s_mutpath2   = S(true, wl_def.SPR_MUT_W2_1, 15, nil, nil)
wl_act2.s_mutpath3   = S(true, wl_def.SPR_MUT_W3_1, 20, nil, nil)
wl_act2.s_mutpath3s  = S(true, wl_def.SPR_MUT_W3_1, 5, nil, nil)
wl_act2.s_mutpath4   = S(true, wl_def.SPR_MUT_W4_1, 15, nil, nil)
wl_act2.s_mutchase1  = S(true, wl_def.SPR_MUT_W1_1, 10, nil, nil)
wl_act2.s_mutchase1s = S(true, wl_def.SPR_MUT_W1_1, 3, nil, nil)
wl_act2.s_mutchase2  = S(true, wl_def.SPR_MUT_W2_1, 8, nil, nil)
wl_act2.s_mutchase3  = S(true, wl_def.SPR_MUT_W3_1, 10, nil, nil)
wl_act2.s_mutchase3s = S(true, wl_def.SPR_MUT_W3_1, 3, nil, nil)
wl_act2.s_mutchase4  = S(true, wl_def.SPR_MUT_W4_1, 8, nil, nil)
wl_act2.s_mutpain    = S(2, wl_def.SPR_MUT_PAIN_1, 10, nil, nil)
wl_act2.s_mutpain1   = S(2, wl_def.SPR_MUT_PAIN_2, 10, nil, nil)
wl_act2.s_mutshoot1  = S(false, wl_def.SPR_MUT_SHOOT1, 6, nil, nil)
wl_act2.s_mutshoot2  = S(false, wl_def.SPR_MUT_SHOOT2, 20, nil, nil)
wl_act2.s_mutshoot3  = S(false, wl_def.SPR_MUT_SHOOT3, 10, nil, nil)
wl_act2.s_mutshoot4  = S(false, wl_def.SPR_MUT_SHOOT4, 20, nil, nil)
wl_act2.s_mutdie1    = S(false, wl_def.SPR_MUT_DIE_1, 7, nil, nil)
wl_act2.s_mutdie2    = S(false, wl_def.SPR_MUT_DIE_2, 7, nil, nil)
wl_act2.s_mutdie3    = S(false, wl_def.SPR_MUT_DIE_3, 7, nil, nil)
wl_act2.s_mutdie4    = S(false, wl_def.SPR_MUT_DIE_4, 7, nil, nil)
wl_act2.s_mutdead    = S(false, wl_def.SPR_MUT_DEAD, 0, nil, nil)

-- Ghost states (WL6)
wl_act2.s_blinkychase1 = S(false, wl_def.SPR_BLINKY_W1, 10, nil, nil)
wl_act2.s_blinkychase2 = S(false, wl_def.SPR_BLINKY_W2, 10, nil, nil)
wl_act2.s_inkychase1   = S(false, wl_def.SPR_INKY_W1, 10, nil, nil)
wl_act2.s_inkychase2   = S(false, wl_def.SPR_INKY_W2, 10, nil, nil)
wl_act2.s_pinkychase1  = S(false, wl_def.SPR_PINKY_W1, 10, nil, nil)
wl_act2.s_pinkychase2  = S(false, wl_def.SPR_PINKY_W2, 10, nil, nil)
wl_act2.s_clydechase1  = S(false, wl_def.SPR_CLYDE_W1, 10, nil, nil)
wl_act2.s_clydechase2  = S(false, wl_def.SPR_CLYDE_W2, 10, nil, nil)

-- Boss stand states
wl_act2.s_bossstand    = S(false, wl_def.SPR_BOSS_W1, 0, nil, nil)
wl_act2.s_gretelstand  = S(false, wl_def.SPR_GRETEL_W1, 0, nil, nil)
wl_act2.s_schabbstand  = S(false, wl_def.SPR_SCHABB_W1, 0, nil, nil)
wl_act2.s_giftstand    = S(false, wl_def.SPR_GIFT_W1, 0, nil, nil)
wl_act2.s_fatstand     = S(false, wl_def.SPR_FAT_W1, 0, nil, nil)
wl_act2.s_fakestand    = S(false, wl_def.SPR_FAKE_W1, 0, nil, nil)
wl_act2.s_mechastand   = S(false, wl_def.SPR_MECHA_W1, 0, nil, nil)

-- Hans (Boss) chase/shoot/die states
wl_act2.s_bosschase1   = S(false, wl_def.SPR_BOSS_W1, 10, nil, nil)
wl_act2.s_bosschase1s  = S(false, wl_def.SPR_BOSS_W1, 3, nil, nil)
wl_act2.s_bosschase2   = S(false, wl_def.SPR_BOSS_W2, 8, nil, nil)
wl_act2.s_bosschase3   = S(false, wl_def.SPR_BOSS_W3, 10, nil, nil)
wl_act2.s_bosschase3s  = S(false, wl_def.SPR_BOSS_W3, 3, nil, nil)
wl_act2.s_bosschase4   = S(false, wl_def.SPR_BOSS_W4, 8, nil, nil)
wl_act2.s_bossshoot1   = S(false, wl_def.SPR_BOSS_SHOOT1, 30, nil, nil)
wl_act2.s_bossshoot2   = S(false, wl_def.SPR_BOSS_SHOOT2, 10, nil, nil)
wl_act2.s_bossshoot3   = S(false, wl_def.SPR_BOSS_SHOOT3, 10, nil, nil)
wl_act2.s_bossdie1     = S(false, wl_def.SPR_BOSS_DIE1, 15, nil, nil)
wl_act2.s_bossdie2     = S(false, wl_def.SPR_BOSS_DIE2, 15, nil, nil)
wl_act2.s_bossdie3     = S(false, wl_def.SPR_BOSS_DIE3, 15, nil, nil)
wl_act2.s_bossdead     = S(false, wl_def.SPR_BOSS_DEAD, 0, nil, nil)

-- Schabbs chase/throw/die states
wl_act2.s_schabbchase1  = S(false, wl_def.SPR_SCHABB_W1, 10, nil, nil)
wl_act2.s_schabbchase1s = S(false, wl_def.SPR_SCHABB_W1, 3, nil, nil)
wl_act2.s_schabbchase2  = S(false, wl_def.SPR_SCHABB_W2, 8, nil, nil)
wl_act2.s_schabbchase3  = S(false, wl_def.SPR_SCHABB_W3, 10, nil, nil)
wl_act2.s_schabbchase3s = S(false, wl_def.SPR_SCHABB_W3, 3, nil, nil)
wl_act2.s_schabbchase4  = S(false, wl_def.SPR_SCHABB_W4, 8, nil, nil)
wl_act2.s_schabbshoot1  = S(false, wl_def.SPR_SCHABB_SHOOT1, 30, nil, nil)
wl_act2.s_schabbshoot2  = S(false, wl_def.SPR_SCHABB_SHOOT2, 10, nil, nil)
wl_act2.s_schabbdie1    = S(false, wl_def.SPR_SCHABB_DIE1, 18, nil, nil)
wl_act2.s_schabbdie2    = S(false, wl_def.SPR_SCHABB_DIE2, 18, nil, nil)
wl_act2.s_schabbdie3    = S(false, wl_def.SPR_SCHABB_DIE3, 18, nil, nil)
wl_act2.s_schabbdead    = S(false, wl_def.SPR_SCHABB_DEAD, 0, nil, nil)

-- Needle (Schabbs projectile) states
wl_act2.s_needle1 = S(false, wl_def.SPR_HYPO1, 6, nil, nil)
wl_act2.s_needle2 = S(false, wl_def.SPR_HYPO2, 6, nil, nil)
wl_act2.s_needle3 = S(false, wl_def.SPR_HYPO3, 6, nil, nil)
wl_act2.s_needle4 = S(false, wl_def.SPR_HYPO4, 6, nil, nil)

-- Gift chase/shoot/die states
wl_act2.s_giftchase1  = S(false, wl_def.SPR_GIFT_W1, 10, nil, nil)
wl_act2.s_giftchase1s = S(false, wl_def.SPR_GIFT_W1, 3, nil, nil)
wl_act2.s_giftchase2  = S(false, wl_def.SPR_GIFT_W2, 8, nil, nil)
wl_act2.s_giftchase3  = S(false, wl_def.SPR_GIFT_W3, 10, nil, nil)
wl_act2.s_giftchase3s = S(false, wl_def.SPR_GIFT_W3, 3, nil, nil)
wl_act2.s_giftchase4  = S(false, wl_def.SPR_GIFT_W4, 8, nil, nil)
wl_act2.s_giftshoot1  = S(false, wl_def.SPR_GIFT_SHOOT1, 30, nil, nil)
wl_act2.s_giftshoot2  = S(false, wl_def.SPR_GIFT_SHOOT2, 10, nil, nil)
wl_act2.s_giftdie1    = S(false, wl_def.SPR_GIFT_DIE1, 18, nil, nil)
wl_act2.s_giftdie2    = S(false, wl_def.SPR_GIFT_DIE2, 18, nil, nil)
wl_act2.s_giftdie3    = S(false, wl_def.SPR_GIFT_DIE3, 18, nil, nil)
wl_act2.s_giftdead    = S(false, wl_def.SPR_GIFT_DEAD, 0, nil, nil)

-- Fat chase/shoot/die states
wl_act2.s_fatchase1  = S(false, wl_def.SPR_FAT_W1, 10, nil, nil)
wl_act2.s_fatchase1s = S(false, wl_def.SPR_FAT_W1, 3, nil, nil)
wl_act2.s_fatchase2  = S(false, wl_def.SPR_FAT_W2, 8, nil, nil)
wl_act2.s_fatchase3  = S(false, wl_def.SPR_FAT_W3, 10, nil, nil)
wl_act2.s_fatchase3s = S(false, wl_def.SPR_FAT_W3, 3, nil, nil)
wl_act2.s_fatchase4  = S(false, wl_def.SPR_FAT_W4, 8, nil, nil)
wl_act2.s_fatshoot1  = S(false, wl_def.SPR_FAT_SHOOT1, 30, nil, nil)
wl_act2.s_fatshoot2  = S(false, wl_def.SPR_FAT_SHOOT2, 10, nil, nil)
wl_act2.s_fatshoot3  = S(false, wl_def.SPR_FAT_SHOOT3, 10, nil, nil)
wl_act2.s_fatshoot4  = S(false, wl_def.SPR_FAT_SHOOT4, 10, nil, nil)
wl_act2.s_fatdie1    = S(false, wl_def.SPR_FAT_DIE1, 18, nil, nil)
wl_act2.s_fatdie2    = S(false, wl_def.SPR_FAT_DIE2, 18, nil, nil)
wl_act2.s_fatdie3    = S(false, wl_def.SPR_FAT_DIE3, 18, nil, nil)
wl_act2.s_fatdead    = S(false, wl_def.SPR_FAT_DEAD, 0, nil, nil)

-- Fake Hitler chase/shoot/die states
wl_act2.s_fakechase1  = S(false, wl_def.SPR_FAKE_W1, 10, nil, nil)
wl_act2.s_fakechase1s = S(false, wl_def.SPR_FAKE_W1, 3, nil, nil)
wl_act2.s_fakechase2  = S(false, wl_def.SPR_FAKE_W2, 8, nil, nil)
wl_act2.s_fakechase3  = S(false, wl_def.SPR_FAKE_W3, 10, nil, nil)
wl_act2.s_fakechase3s = S(false, wl_def.SPR_FAKE_W3, 3, nil, nil)
wl_act2.s_fakechase4  = S(false, wl_def.SPR_FAKE_W4, 8, nil, nil)
wl_act2.s_fakeshoot1  = S(false, wl_def.SPR_FAKE_SHOOT, 8, nil, nil)
wl_act2.s_fakeshoot2  = S(false, wl_def.SPR_FIRE1, 15, nil, nil)
wl_act2.s_fakeshoot3  = S(false, wl_def.SPR_FIRE2, 15, nil, nil)
wl_act2.s_fakedie1    = S(false, wl_def.SPR_FAKE_DIE1, 10, nil, nil)
wl_act2.s_fakedie2    = S(false, wl_def.SPR_FAKE_DIE2, 10, nil, nil)
wl_act2.s_fakedie3    = S(false, wl_def.SPR_FAKE_DIE3, 10, nil, nil)
wl_act2.s_fakedie4    = S(false, wl_def.SPR_FAKE_DIE4, 10, nil, nil)
wl_act2.s_fakedie5    = S(false, wl_def.SPR_FAKE_DIE5, 10, nil, nil)
wl_act2.s_fakedead    = S(false, wl_def.SPR_FAKE_DEAD, 0, nil, nil)

-- Mecha Hitler chase/shoot/die states
wl_act2.s_mechachase1  = S(false, wl_def.SPR_MECHA_W1, 10, nil, nil)
wl_act2.s_mechachase1s = S(false, wl_def.SPR_MECHA_W1, 6, nil, nil)
wl_act2.s_mechachase2  = S(false, wl_def.SPR_MECHA_W2, 8, nil, nil)
wl_act2.s_mechachase3  = S(false, wl_def.SPR_MECHA_W3, 10, nil, nil)
wl_act2.s_mechachase3s = S(false, wl_def.SPR_MECHA_W3, 6, nil, nil)
wl_act2.s_mechachase4  = S(false, wl_def.SPR_MECHA_W4, 8, nil, nil)
wl_act2.s_mechashoot1  = S(false, wl_def.SPR_MECHA_SHOOT1, 30, nil, nil)
wl_act2.s_mechashoot2  = S(false, wl_def.SPR_MECHA_SHOOT2, 10, nil, nil)
wl_act2.s_mechashoot3  = S(false, wl_def.SPR_MECHA_SHOOT3, 10, nil, nil)
wl_act2.s_mechadie1    = S(false, wl_def.SPR_MECHA_DIE1, 10, nil, nil)
wl_act2.s_mechadie2    = S(false, wl_def.SPR_MECHA_DIE2, 10, nil, nil)
wl_act2.s_mechadie3    = S(false, wl_def.SPR_MECHA_DIE3, 10, nil, nil)
wl_act2.s_mechadead    = S(false, wl_def.SPR_MECHA_DEAD, 0, nil, nil)

-- Real Hitler chase/shoot/die states
wl_act2.s_hitlerchase1  = S(false, wl_def.SPR_HITLER_W1, 6, nil, nil)
wl_act2.s_hitlerchase1s = S(false, wl_def.SPR_HITLER_W1, 4, nil, nil)
wl_act2.s_hitlerchase2  = S(false, wl_def.SPR_HITLER_W2, 2, nil, nil)
wl_act2.s_hitlerchase3  = S(false, wl_def.SPR_HITLER_W3, 6, nil, nil)
wl_act2.s_hitlerchase3s = S(false, wl_def.SPR_HITLER_W3, 4, nil, nil)
wl_act2.s_hitlerchase4  = S(false, wl_def.SPR_HITLER_W4, 2, nil, nil)
wl_act2.s_hitlershoot1  = S(false, wl_def.SPR_HITLER_SHOOT1, 30, nil, nil)
wl_act2.s_hitlershoot2  = S(false, wl_def.SPR_HITLER_SHOOT2, 10, nil, nil)
wl_act2.s_hitlershoot3  = S(false, wl_def.SPR_HITLER_SHOOT3, 10, nil, nil)
wl_act2.s_hitlerdie1    = S(false, wl_def.SPR_HITLER_DIE1, 1, nil, nil)
wl_act2.s_hitlerdie2    = S(false, wl_def.SPR_HITLER_DIE2, 10, nil, nil)
wl_act2.s_hitlerdie3    = S(false, wl_def.SPR_HITLER_DIE3, 10, nil, nil)
wl_act2.s_hitlerdie4    = S(false, wl_def.SPR_HITLER_DIE4, 10, nil, nil)
wl_act2.s_hitlerdie5    = S(false, wl_def.SPR_HITLER_DIE5, 10, nil, nil)
wl_act2.s_hitlerdie6    = S(false, wl_def.SPR_HITLER_DIE6, 10, nil, nil)
wl_act2.s_hitlerdie7    = S(false, wl_def.SPR_HITLER_DIE7, 10, nil, nil)
wl_act2.s_hitlerdead    = S(false, wl_def.SPR_HITLER_DEAD, 0, nil, nil)

-- Gretel chase/shoot/die states
wl_act2.s_gretelchase1  = S(false, wl_def.SPR_GRETEL_W1, 10, nil, nil)
wl_act2.s_gretelchase1s = S(false, wl_def.SPR_GRETEL_W1, 3, nil, nil)
wl_act2.s_gretelchase2  = S(false, wl_def.SPR_GRETEL_W2, 8, nil, nil)
wl_act2.s_gretelchase3  = S(false, wl_def.SPR_GRETEL_W3, 10, nil, nil)
wl_act2.s_gretelchase3s = S(false, wl_def.SPR_GRETEL_W3, 3, nil, nil)
wl_act2.s_gretelchase4  = S(false, wl_def.SPR_GRETEL_W4, 8, nil, nil)
wl_act2.s_gretelshoot1  = S(false, wl_def.SPR_GRETEL_SHOOT1, 30, nil, nil)
wl_act2.s_gretelshoot2  = S(false, wl_def.SPR_GRETEL_SHOOT2, 10, nil, nil)
wl_act2.s_gretelshoot3  = S(false, wl_def.SPR_GRETEL_SHOOT3, 10, nil, nil)
wl_act2.s_greteldie1    = S(false, wl_def.SPR_GRETEL_DIE1, 15, nil, nil)
wl_act2.s_greteldie2    = S(false, wl_def.SPR_GRETEL_DIE2, 15, nil, nil)
wl_act2.s_greteldie3    = S(false, wl_def.SPR_GRETEL_DIE3, 15, nil, nil)
wl_act2.s_greteldead    = S(false, wl_def.SPR_GRETEL_DEAD, 0, nil, nil)

-- Projectile/explosion states
wl_act2.s_rocket  = S(true, wl_def.SPR_ROCKET_1, 3, nil, nil)
wl_act2.s_smoke1  = S(false, wl_def.SPR_SMOKE_1, 3, nil, nil)
wl_act2.s_smoke2  = S(false, wl_def.SPR_SMOKE_2, 3, nil, nil)
wl_act2.s_smoke3  = S(false, wl_def.SPR_SMOKE_3, 3, nil, nil)
wl_act2.s_smoke4  = S(false, wl_def.SPR_SMOKE_4, 3, nil, nil)
wl_act2.s_boom1   = S(false, wl_def.SPR_BOOM_1, 6, nil, nil)
wl_act2.s_boom2   = S(false, wl_def.SPR_BOOM_2, 6, nil, nil)
wl_act2.s_boom3   = S(false, wl_def.SPR_BOOM_3, 6, nil, nil)

---------------------------------------------------------------------------
-- Wire up .next pointers and think/action functions
---------------------------------------------------------------------------

-- This must be done after all states exist (forward reference resolution)
local function wireStates()
    -- Guard
    wl_act2.s_grdstand.next = wl_act2.s_grdstand
    wl_act2.s_grdstand.think = T_Stand
    wl_act2.s_grdpath1.next = wl_act2.s_grdpath1s; wl_act2.s_grdpath1.think = T_Path
    wl_act2.s_grdpath1s.next = wl_act2.s_grdpath2
    wl_act2.s_grdpath2.next = wl_act2.s_grdpath3; wl_act2.s_grdpath2.think = T_Path
    wl_act2.s_grdpath3.next = wl_act2.s_grdpath3s; wl_act2.s_grdpath3.think = T_Path
    wl_act2.s_grdpath3s.next = wl_act2.s_grdpath4
    wl_act2.s_grdpath4.next = wl_act2.s_grdpath1; wl_act2.s_grdpath4.think = T_Path
    wl_act2.s_grdpain.next = wl_act2.s_grdchase1
    wl_act2.s_grdpain1.next = wl_act2.s_grdchase1
    wl_act2.s_grdshoot1.next = wl_act2.s_grdshoot2
    wl_act2.s_grdshoot2.next = wl_act2.s_grdshoot3; wl_act2.s_grdshoot2.action = T_Shoot
    wl_act2.s_grdshoot3.next = wl_act2.s_grdchase1
    wl_act2.s_grdchase1.next = wl_act2.s_grdchase1s; wl_act2.s_grdchase1.think = T_Chase
    wl_act2.s_grdchase1s.next = wl_act2.s_grdchase2
    wl_act2.s_grdchase2.next = wl_act2.s_grdchase3; wl_act2.s_grdchase2.think = T_Chase
    wl_act2.s_grdchase3.next = wl_act2.s_grdchase3s; wl_act2.s_grdchase3.think = T_Chase
    wl_act2.s_grdchase3s.next = wl_act2.s_grdchase4
    wl_act2.s_grdchase4.next = wl_act2.s_grdchase1; wl_act2.s_grdchase4.think = T_Chase
    wl_act2.s_grddie1.next = wl_act2.s_grddie2; wl_act2.s_grddie1.action = A_DeathScream
    wl_act2.s_grddie2.next = wl_act2.s_grddie3
    wl_act2.s_grddie3.next = wl_act2.s_grddie4
    wl_act2.s_grddie4.next = wl_act2.s_grddie4

    -- Ghost states
    wl_act2.s_blinkychase1.next = wl_act2.s_blinkychase2; wl_act2.s_blinkychase1.think = T_Ghosts
    wl_act2.s_blinkychase2.next = wl_act2.s_blinkychase1; wl_act2.s_blinkychase2.think = T_Ghosts
    wl_act2.s_inkychase1.next = wl_act2.s_inkychase2; wl_act2.s_inkychase1.think = T_Ghosts
    wl_act2.s_inkychase2.next = wl_act2.s_inkychase1; wl_act2.s_inkychase2.think = T_Ghosts
    wl_act2.s_pinkychase1.next = wl_act2.s_pinkychase2; wl_act2.s_pinkychase1.think = T_Ghosts
    wl_act2.s_pinkychase2.next = wl_act2.s_pinkychase1; wl_act2.s_pinkychase2.think = T_Ghosts
    wl_act2.s_clydechase1.next = wl_act2.s_clydechase2; wl_act2.s_clydechase1.think = T_Ghosts
    wl_act2.s_clydechase2.next = wl_act2.s_clydechase1; wl_act2.s_clydechase2.think = T_Ghosts

    -- Boss stand states self-loop
    wl_act2.s_bossstand.next = wl_act2.s_bossstand; wl_act2.s_bossstand.think = T_Stand
    wl_act2.s_gretelstand.next = wl_act2.s_gretelstand; wl_act2.s_gretelstand.think = T_Stand
    wl_act2.s_schabbstand.next = wl_act2.s_schabbstand; wl_act2.s_schabbstand.think = T_Stand
    wl_act2.s_giftstand.next = wl_act2.s_giftstand; wl_act2.s_giftstand.think = T_Stand
    wl_act2.s_fatstand.next = wl_act2.s_fatstand; wl_act2.s_fatstand.think = T_Stand
    wl_act2.s_fakestand.next = wl_act2.s_fakestand; wl_act2.s_fakestand.think = T_Stand
    wl_act2.s_mechastand.next = wl_act2.s_mechastand; wl_act2.s_mechastand.think = T_Stand

    -- Hans (Boss) chase/shoot/die
    wl_act2.s_bosschase1.next = wl_act2.s_bosschase1s; wl_act2.s_bosschase1.think = T_BossChase
    wl_act2.s_bosschase1s.next = wl_act2.s_bosschase2
    wl_act2.s_bosschase2.next = wl_act2.s_bosschase3; wl_act2.s_bosschase2.think = T_BossChase
    wl_act2.s_bosschase3.next = wl_act2.s_bosschase3s; wl_act2.s_bosschase3.think = T_BossChase
    wl_act2.s_bosschase3s.next = wl_act2.s_bosschase4
    wl_act2.s_bosschase4.next = wl_act2.s_bosschase1; wl_act2.s_bosschase4.think = T_BossChase
    wl_act2.s_bossshoot1.next = wl_act2.s_bossshoot2
    wl_act2.s_bossshoot2.next = wl_act2.s_bossshoot3; wl_act2.s_bossshoot2.action = T_Shoot
    wl_act2.s_bossshoot3.next = wl_act2.s_bosschase1
    wl_act2.s_bossdie1.next = wl_act2.s_bossdie2; wl_act2.s_bossdie1.action = A_DeathScream
    wl_act2.s_bossdie2.next = wl_act2.s_bossdie3
    wl_act2.s_bossdie3.next = wl_act2.s_bossdead
    wl_act2.s_bossdead.next = wl_act2.s_bossdead

    -- Schabbs chase/throw/die
    wl_act2.s_schabbchase1.next = wl_act2.s_schabbchase1s; wl_act2.s_schabbchase1.think = T_SchabbChase
    wl_act2.s_schabbchase1s.next = wl_act2.s_schabbchase2
    wl_act2.s_schabbchase2.next = wl_act2.s_schabbchase3; wl_act2.s_schabbchase2.think = T_SchabbChase
    wl_act2.s_schabbchase3.next = wl_act2.s_schabbchase3s; wl_act2.s_schabbchase3.think = T_SchabbChase
    wl_act2.s_schabbchase3s.next = wl_act2.s_schabbchase4
    wl_act2.s_schabbchase4.next = wl_act2.s_schabbchase1; wl_act2.s_schabbchase4.think = T_SchabbChase
    wl_act2.s_schabbshoot1.next = wl_act2.s_schabbshoot2
    wl_act2.s_schabbshoot2.next = wl_act2.s_schabbchase1; wl_act2.s_schabbshoot2.action = T_SchabbThrow
    wl_act2.s_schabbdie1.next = wl_act2.s_schabbdie2; wl_act2.s_schabbdie1.action = A_DeathScream
    wl_act2.s_schabbdie2.next = wl_act2.s_schabbdie3
    wl_act2.s_schabbdie3.next = wl_act2.s_schabbdead
    wl_act2.s_schabbdead.next = wl_act2.s_schabbdead

    -- Needle projectile
    wl_act2.s_needle1.next = wl_act2.s_needle2; wl_act2.s_needle1.think = T_Projectile
    wl_act2.s_needle2.next = wl_act2.s_needle3; wl_act2.s_needle2.think = T_Projectile
    wl_act2.s_needle3.next = wl_act2.s_needle4; wl_act2.s_needle3.think = T_Projectile
    wl_act2.s_needle4.next = wl_act2.s_needle1; wl_act2.s_needle4.think = T_Projectile

    -- Gift chase/shoot/die
    wl_act2.s_giftchase1.next = wl_act2.s_giftchase1s; wl_act2.s_giftchase1.think = T_GiftChase
    wl_act2.s_giftchase1s.next = wl_act2.s_giftchase2
    wl_act2.s_giftchase2.next = wl_act2.s_giftchase3; wl_act2.s_giftchase2.think = T_GiftChase
    wl_act2.s_giftchase3.next = wl_act2.s_giftchase3s; wl_act2.s_giftchase3.think = T_GiftChase
    wl_act2.s_giftchase3s.next = wl_act2.s_giftchase4
    wl_act2.s_giftchase4.next = wl_act2.s_giftchase1; wl_act2.s_giftchase4.think = T_GiftChase
    wl_act2.s_giftshoot1.next = wl_act2.s_giftshoot2
    wl_act2.s_giftshoot2.next = wl_act2.s_giftchase1; wl_act2.s_giftshoot2.action = T_GiftThrow
    wl_act2.s_giftdie1.next = wl_act2.s_giftdie2; wl_act2.s_giftdie1.action = A_DeathScream
    wl_act2.s_giftdie2.next = wl_act2.s_giftdie3
    wl_act2.s_giftdie3.next = wl_act2.s_giftdead
    wl_act2.s_giftdead.next = wl_act2.s_giftdead

    -- Fat chase/shoot/die
    wl_act2.s_fatchase1.next = wl_act2.s_fatchase1s; wl_act2.s_fatchase1.think = T_FatChase
    wl_act2.s_fatchase1s.next = wl_act2.s_fatchase2
    wl_act2.s_fatchase2.next = wl_act2.s_fatchase3; wl_act2.s_fatchase2.think = T_FatChase
    wl_act2.s_fatchase3.next = wl_act2.s_fatchase3s; wl_act2.s_fatchase3.think = T_FatChase
    wl_act2.s_fatchase3s.next = wl_act2.s_fatchase4
    wl_act2.s_fatchase4.next = wl_act2.s_fatchase1; wl_act2.s_fatchase4.think = T_FatChase
    wl_act2.s_fatshoot1.next = wl_act2.s_fatshoot2
    wl_act2.s_fatshoot2.next = wl_act2.s_fatshoot3; wl_act2.s_fatshoot2.action = T_Shoot
    wl_act2.s_fatshoot3.next = wl_act2.s_fatshoot4; wl_act2.s_fatshoot3.action = T_Shoot
    wl_act2.s_fatshoot4.next = wl_act2.s_fatchase1; wl_act2.s_fatshoot4.action = T_Shoot
    wl_act2.s_fatdie1.next = wl_act2.s_fatdie2; wl_act2.s_fatdie1.action = A_DeathScream
    wl_act2.s_fatdie2.next = wl_act2.s_fatdie3
    wl_act2.s_fatdie3.next = wl_act2.s_fatdead
    wl_act2.s_fatdead.next = wl_act2.s_fatdead

    -- Fake Hitler chase/shoot/die
    wl_act2.s_fakechase1.next = wl_act2.s_fakechase1s; wl_act2.s_fakechase1.think = T_FakeChase
    wl_act2.s_fakechase1s.next = wl_act2.s_fakechase2
    wl_act2.s_fakechase2.next = wl_act2.s_fakechase3; wl_act2.s_fakechase2.think = T_FakeChase
    wl_act2.s_fakechase3.next = wl_act2.s_fakechase3s; wl_act2.s_fakechase3.think = T_FakeChase
    wl_act2.s_fakechase3s.next = wl_act2.s_fakechase4
    wl_act2.s_fakechase4.next = wl_act2.s_fakechase1; wl_act2.s_fakechase4.think = T_FakeChase
    wl_act2.s_fakeshoot1.next = wl_act2.s_fakeshoot2
    wl_act2.s_fakeshoot2.next = wl_act2.s_fakeshoot3; wl_act2.s_fakeshoot2.action = T_FakeFire
    wl_act2.s_fakeshoot3.next = wl_act2.s_fakechase1
    wl_act2.s_fakedie1.next = wl_act2.s_fakedie2; wl_act2.s_fakedie1.action = A_DeathScream
    wl_act2.s_fakedie2.next = wl_act2.s_fakedie3
    wl_act2.s_fakedie3.next = wl_act2.s_fakedie4
    wl_act2.s_fakedie4.next = wl_act2.s_fakedie5
    wl_act2.s_fakedie5.next = wl_act2.s_fakedead
    wl_act2.s_fakedead.next = wl_act2.s_fakedead

    -- Mecha Hitler chase/shoot/die -> morphs to Real Hitler
    wl_act2.s_mechachase1.next = wl_act2.s_mechachase1s; wl_act2.s_mechachase1.think = T_MechaChase
    wl_act2.s_mechachase1s.next = wl_act2.s_mechachase2; wl_act2.s_mechachase1s.action = A_MechaSound
    wl_act2.s_mechachase2.next = wl_act2.s_mechachase3; wl_act2.s_mechachase2.think = T_MechaChase
    wl_act2.s_mechachase3.next = wl_act2.s_mechachase3s; wl_act2.s_mechachase3.think = T_MechaChase
    wl_act2.s_mechachase3s.next = wl_act2.s_mechachase4; wl_act2.s_mechachase3s.action = A_MechaSound
    wl_act2.s_mechachase4.next = wl_act2.s_mechachase1; wl_act2.s_mechachase4.think = T_MechaChase
    wl_act2.s_mechashoot1.next = wl_act2.s_mechashoot2
    wl_act2.s_mechashoot2.next = wl_act2.s_mechashoot3; wl_act2.s_mechashoot2.action = T_Shoot
    wl_act2.s_mechashoot3.next = wl_act2.s_mechachase1
    wl_act2.s_mechadie1.next = wl_act2.s_mechadie2; wl_act2.s_mechadie1.action = A_DeathScream
    wl_act2.s_mechadie2.next = wl_act2.s_mechadie3
    wl_act2.s_mechadie3.next = wl_act2.s_mechadead; wl_act2.s_mechadie3.action = A_HitlerMorph
    wl_act2.s_mechadead.next = wl_act2.s_mechadead

    -- Real Hitler chase/shoot/die
    wl_act2.s_hitlerchase1.next = wl_act2.s_hitlerchase1s; wl_act2.s_hitlerchase1.think = T_HitlerChase
    wl_act2.s_hitlerchase1s.next = wl_act2.s_hitlerchase2
    wl_act2.s_hitlerchase2.next = wl_act2.s_hitlerchase3; wl_act2.s_hitlerchase2.think = T_HitlerChase
    wl_act2.s_hitlerchase3.next = wl_act2.s_hitlerchase3s; wl_act2.s_hitlerchase3.think = T_HitlerChase
    wl_act2.s_hitlerchase3s.next = wl_act2.s_hitlerchase4
    wl_act2.s_hitlerchase4.next = wl_act2.s_hitlerchase1; wl_act2.s_hitlerchase4.think = T_HitlerChase
    wl_act2.s_hitlershoot1.next = wl_act2.s_hitlershoot2
    wl_act2.s_hitlershoot2.next = wl_act2.s_hitlershoot3; wl_act2.s_hitlershoot2.action = T_Shoot
    wl_act2.s_hitlershoot3.next = wl_act2.s_hitlerchase1
    wl_act2.s_hitlerdie1.next = wl_act2.s_hitlerdie2; wl_act2.s_hitlerdie1.action = A_DeathScream
    wl_act2.s_hitlerdie2.next = wl_act2.s_hitlerdie3
    wl_act2.s_hitlerdie3.next = wl_act2.s_hitlerdie4
    wl_act2.s_hitlerdie4.next = wl_act2.s_hitlerdie5
    wl_act2.s_hitlerdie5.next = wl_act2.s_hitlerdie6
    wl_act2.s_hitlerdie6.next = wl_act2.s_hitlerdie7
    wl_act2.s_hitlerdie7.next = wl_act2.s_hitlerdead; wl_act2.s_hitlerdie7.action = A_StartDeathCam
    wl_act2.s_hitlerdead.next = wl_act2.s_hitlerdead

    -- Gretel chase/shoot/die
    wl_act2.s_gretelchase1.next = wl_act2.s_gretelchase1s; wl_act2.s_gretelchase1.think = T_GretelChase
    wl_act2.s_gretelchase1s.next = wl_act2.s_gretelchase2
    wl_act2.s_gretelchase2.next = wl_act2.s_gretelchase3; wl_act2.s_gretelchase2.think = T_GretelChase
    wl_act2.s_gretelchase3.next = wl_act2.s_gretelchase3s; wl_act2.s_gretelchase3.think = T_GretelChase
    wl_act2.s_gretelchase3s.next = wl_act2.s_gretelchase4
    wl_act2.s_gretelchase4.next = wl_act2.s_gretelchase1; wl_act2.s_gretelchase4.think = T_GretelChase
    wl_act2.s_gretelshoot1.next = wl_act2.s_gretelshoot2
    wl_act2.s_gretelshoot2.next = wl_act2.s_gretelshoot3; wl_act2.s_gretelshoot2.action = T_Shoot
    wl_act2.s_gretelshoot3.next = wl_act2.s_gretelchase1
    wl_act2.s_greteldie1.next = wl_act2.s_greteldie2; wl_act2.s_greteldie1.action = A_DeathScream
    wl_act2.s_greteldie2.next = wl_act2.s_greteldie3
    wl_act2.s_greteldie3.next = wl_act2.s_greteldead
    wl_act2.s_greteldead.next = wl_act2.s_greteldead

    -- Smoke/boom chain
    wl_act2.s_smoke1.next = wl_act2.s_smoke2
    wl_act2.s_smoke2.next = wl_act2.s_smoke3
    wl_act2.s_smoke3.next = wl_act2.s_smoke4
    wl_act2.s_smoke4.next = nil
    wl_act2.s_boom1.next = wl_act2.s_boom2
    wl_act2.s_boom2.next = wl_act2.s_boom3
    wl_act2.s_boom3.next = nil
    wl_act2.s_rocket.next = wl_act2.s_rocket
    wl_act2.s_rocket.think = T_Projectile; wl_act2.s_rocket.action = A_Smoke

    -- Wire remaining enemy path/chase chains similarly...
    -- (Dog, SS, Officer, Mutant chains follow the same pattern as guard)
    -- Dog
    wl_act2.s_dogpath1.next = wl_act2.s_dogpath1s; wl_act2.s_dogpath1.think = T_Path
    wl_act2.s_dogpath1s.next = wl_act2.s_dogpath2
    wl_act2.s_dogpath2.next = wl_act2.s_dogpath3; wl_act2.s_dogpath2.think = T_Path
    wl_act2.s_dogpath3.next = wl_act2.s_dogpath3s; wl_act2.s_dogpath3.think = T_Path
    wl_act2.s_dogpath3s.next = wl_act2.s_dogpath4
    wl_act2.s_dogpath4.next = wl_act2.s_dogpath1; wl_act2.s_dogpath4.think = T_Path
    wl_act2.s_dogchase1.next = wl_act2.s_dogchase1s; wl_act2.s_dogchase1.think = T_DogChase
    wl_act2.s_dogchase1s.next = wl_act2.s_dogchase2
    wl_act2.s_dogchase2.next = wl_act2.s_dogchase3; wl_act2.s_dogchase2.think = T_DogChase
    wl_act2.s_dogchase3.next = wl_act2.s_dogchase3s; wl_act2.s_dogchase3.think = T_DogChase
    wl_act2.s_dogchase3s.next = wl_act2.s_dogchase4
    wl_act2.s_dogchase4.next = wl_act2.s_dogchase1; wl_act2.s_dogchase4.think = T_DogChase
    wl_act2.s_dogjump1.next = wl_act2.s_dogjump2; wl_act2.s_dogjump1.think = T_DogChase
    wl_act2.s_dogjump2.next = wl_act2.s_dogjump3; wl_act2.s_dogjump2.think = T_DogChase
    wl_act2.s_dogjump3.next = wl_act2.s_dogchase1; wl_act2.s_dogjump3.action = T_Bite
    wl_act2.s_dogdie1.next = wl_act2.s_dogdie2; wl_act2.s_dogdie1.action = A_DeathScream
    wl_act2.s_dogdie2.next = wl_act2.s_dogdie3
    wl_act2.s_dogdie3.next = wl_act2.s_dogdead
    wl_act2.s_dogdead.next = wl_act2.s_dogdead

    -- SS
    wl_act2.s_ssstand.next = wl_act2.s_ssstand; wl_act2.s_ssstand.think = T_Stand
    wl_act2.s_sspath1.next = wl_act2.s_sspath1s; wl_act2.s_sspath1.think = T_Path
    wl_act2.s_sspath1s.next = wl_act2.s_sspath2
    wl_act2.s_sspath2.next = wl_act2.s_sspath3; wl_act2.s_sspath2.think = T_Path
    wl_act2.s_sspath3.next = wl_act2.s_sspath3s; wl_act2.s_sspath3.think = T_Path
    wl_act2.s_sspath3s.next = wl_act2.s_sspath4
    wl_act2.s_sspath4.next = wl_act2.s_sspath1; wl_act2.s_sspath4.think = T_Path
    wl_act2.s_sschase1.next = wl_act2.s_sschase1s; wl_act2.s_sschase1.think = T_Chase
    wl_act2.s_sschase1s.next = wl_act2.s_sschase2
    wl_act2.s_sschase2.next = wl_act2.s_sschase3; wl_act2.s_sschase2.think = T_Chase
    wl_act2.s_sschase3.next = wl_act2.s_sschase3s; wl_act2.s_sschase3.think = T_Chase
    wl_act2.s_sschase3s.next = wl_act2.s_sschase4
    wl_act2.s_sschase4.next = wl_act2.s_sschase1; wl_act2.s_sschase4.think = T_Chase
    wl_act2.s_sspain.next = wl_act2.s_sschase1
    wl_act2.s_sspain1.next = wl_act2.s_sschase1
    wl_act2.s_ssshoot1.next = wl_act2.s_ssshoot2
    wl_act2.s_ssshoot2.next = wl_act2.s_ssshoot3; wl_act2.s_ssshoot2.action = T_Shoot
    wl_act2.s_ssshoot3.next = wl_act2.s_sschase1
    wl_act2.s_ssdie1.next = wl_act2.s_ssdie2; wl_act2.s_ssdie1.action = A_DeathScream
    wl_act2.s_ssdie2.next = wl_act2.s_ssdie3
    wl_act2.s_ssdie3.next = wl_act2.s_ssdead
    wl_act2.s_ssdead.next = wl_act2.s_ssdead

    -- Officer
    wl_act2.s_ofcstand.next = wl_act2.s_ofcstand; wl_act2.s_ofcstand.think = T_Stand
    wl_act2.s_ofcpath1.next = wl_act2.s_ofcpath1s; wl_act2.s_ofcpath1.think = T_Path
    wl_act2.s_ofcpath1s.next = wl_act2.s_ofcpath2
    wl_act2.s_ofcpath2.next = wl_act2.s_ofcpath3; wl_act2.s_ofcpath2.think = T_Path
    wl_act2.s_ofcpath3.next = wl_act2.s_ofcpath3s; wl_act2.s_ofcpath3.think = T_Path
    wl_act2.s_ofcpath3s.next = wl_act2.s_ofcpath4
    wl_act2.s_ofcpath4.next = wl_act2.s_ofcpath1; wl_act2.s_ofcpath4.think = T_Path
    wl_act2.s_ofcchase1.next = wl_act2.s_ofcchase1s; wl_act2.s_ofcchase1.think = T_Chase
    wl_act2.s_ofcchase1s.next = wl_act2.s_ofcchase2
    wl_act2.s_ofcchase2.next = wl_act2.s_ofcchase3; wl_act2.s_ofcchase2.think = T_Chase
    wl_act2.s_ofcchase3.next = wl_act2.s_ofcchase3s; wl_act2.s_ofcchase3.think = T_Chase
    wl_act2.s_ofcchase3s.next = wl_act2.s_ofcchase4
    wl_act2.s_ofcchase4.next = wl_act2.s_ofcchase1; wl_act2.s_ofcchase4.think = T_Chase
    wl_act2.s_ofcpain.next = wl_act2.s_ofcchase1
    wl_act2.s_ofcpain1.next = wl_act2.s_ofcchase1
    wl_act2.s_ofcshoot1.next = wl_act2.s_ofcshoot2
    wl_act2.s_ofcshoot2.next = wl_act2.s_ofcshoot3; wl_act2.s_ofcshoot2.action = T_Shoot
    wl_act2.s_ofcshoot3.next = wl_act2.s_ofcchase1
    wl_act2.s_ofcdie1.next = wl_act2.s_ofcdie2; wl_act2.s_ofcdie1.action = A_DeathScream
    wl_act2.s_ofcdie2.next = wl_act2.s_ofcdie3
    wl_act2.s_ofcdie3.next = wl_act2.s_ofcdie4
    wl_act2.s_ofcdie4.next = wl_act2.s_ofcdead
    wl_act2.s_ofcdead.next = wl_act2.s_ofcdead

    -- Mutant
    wl_act2.s_mutstand.next = wl_act2.s_mutstand; wl_act2.s_mutstand.think = T_Stand
    wl_act2.s_mutpath1.next = wl_act2.s_mutpath1s; wl_act2.s_mutpath1.think = T_Path
    wl_act2.s_mutpath1s.next = wl_act2.s_mutpath2
    wl_act2.s_mutpath2.next = wl_act2.s_mutpath3; wl_act2.s_mutpath2.think = T_Path
    wl_act2.s_mutpath3.next = wl_act2.s_mutpath3s; wl_act2.s_mutpath3.think = T_Path
    wl_act2.s_mutpath3s.next = wl_act2.s_mutpath4
    wl_act2.s_mutpath4.next = wl_act2.s_mutpath1; wl_act2.s_mutpath4.think = T_Path
    wl_act2.s_mutchase1.next = wl_act2.s_mutchase1s; wl_act2.s_mutchase1.think = T_Chase
    wl_act2.s_mutchase1s.next = wl_act2.s_mutchase2
    wl_act2.s_mutchase2.next = wl_act2.s_mutchase3; wl_act2.s_mutchase2.think = T_Chase
    wl_act2.s_mutchase3.next = wl_act2.s_mutchase3s; wl_act2.s_mutchase3.think = T_Chase
    wl_act2.s_mutchase3s.next = wl_act2.s_mutchase4
    wl_act2.s_mutchase4.next = wl_act2.s_mutchase1; wl_act2.s_mutchase4.think = T_Chase
    wl_act2.s_mutpain.next = wl_act2.s_mutchase1
    wl_act2.s_mutpain1.next = wl_act2.s_mutchase1
    wl_act2.s_mutshoot1.next = wl_act2.s_mutshoot2
    wl_act2.s_mutshoot2.next = wl_act2.s_mutshoot3; wl_act2.s_mutshoot2.action = T_Shoot
    wl_act2.s_mutshoot3.next = wl_act2.s_mutshoot4
    wl_act2.s_mutshoot4.next = wl_act2.s_mutchase1
    wl_act2.s_mutdie1.next = wl_act2.s_mutdie2; wl_act2.s_mutdie1.action = A_DeathScream
    wl_act2.s_mutdie2.next = wl_act2.s_mutdie3
    wl_act2.s_mutdie3.next = wl_act2.s_mutdie4
    wl_act2.s_mutdie4.next = wl_act2.s_mutdead
    wl_act2.s_mutdead.next = wl_act2.s_mutdead
end

---------------------------------------------------------------------------
-- Think/Action functions
---------------------------------------------------------------------------

T_Stand = function(ob)
    local wl_state = require("wl_state")
    if wl_state.SightPlayer(ob) then
        wl_state.FirstSighting(ob)
    end
end

T_Path = function(ob)
    local wl_state = require("wl_state")
    local wl_main  = require("wl_main")

    if wl_state.SightPlayer(ob) then
        wl_state.FirstSighting(ob)
        return
    end

    if ob.distance > 0 then
        wl_state.MoveObj(ob, ob.speed * wl_main.tics)
        if ob.distance < 0 then
            ob.distance = 0
        end
        return
    end

    wl_state.SelectChaseDir(ob)
end

T_Chase = function(ob)
    local wl_state = require("wl_state")
    local wl_main  = require("wl_main")
    local wl_play  = require("wl_play")

    if ob.distance < 0 then
        -- Waiting for door to open
        local wl_game = require("wl_game")
        local doornum = -(ob.distance + 1)
        if wl_game.doorobjlist[doornum] and wl_game.doorobjlist[doornum].action == wl_def.dr_open then
            ob.distance = wl_def.TILEGLOBAL
        end
        return
    end

    if ob.distance > 0 then
        wl_state.MoveObj(ob, ob.speed * wl_main.tics)
        if ob.distance <= 0 then
            ob.distance = 0
            ob.tilex = rshift(ob.x, wl_def.TILESHIFT)
            ob.tiley = rshift(ob.y, wl_def.TILESHIFT)
            ob.x = lshift(ob.tilex, wl_def.TILESHIFT) + math.floor(wl_def.TILEGLOBAL / 2)
            ob.y = lshift(ob.tiley, wl_def.TILESHIFT) + math.floor(wl_def.TILEGLOBAL / 2)
        end
        return
    end

    -- At tile center, decide what to do
    local dx = math.abs(ob.tilex - wl_play.player.tilex)
    local dy = math.abs(ob.tiley - wl_play.player.tiley)
    local dist = math.max(dx, dy)

    if wl_state.CheckLine(ob) then
        -- Calculate firing chance based on enemy type (original Wolf3D algorithm)
        -- chance = (tics << shift) / dist, compared against random byte
        local tics = wl_main.tics
        local chance = 0
        local shoot_state = nil

        if dist == 0 then dist = 1 end  -- avoid division by zero

        if ob.obclass == wl_def.guardobj then
            chance = lshift(tics, 4) / dist
            shoot_state = wl_act2.s_grdshoot1
        elseif ob.obclass == wl_def.officerobj then
            chance = lshift(tics, 5) / dist
            shoot_state = wl_act2.s_ofcshoot1
        elseif ob.obclass == wl_def.ssobj then
            chance = lshift(tics, 4) / dist
            shoot_state = wl_act2.s_ssshoot1
        elseif ob.obclass == wl_def.mutantobj then
            chance = lshift(tics, 5) / dist
            shoot_state = wl_act2.s_mutshoot1
        elseif ob.obclass == wl_def.dogobj then
            -- Dogs never shoot (melee only via T_Bite / T_DogChase)
            chance = 0
            shoot_state = nil
        end

        if shoot_state and chance > 0 then
            if chance > 255 then chance = 255 end
            if id_us.US_RndT() < chance then
                wl_state.NewState(ob, shoot_state)
                return
            end
        end
    end

    wl_state.SelectDodgeDir(ob)
end

T_Shoot = function(ob)
    local wl_agent = require("wl_agent")
    local wl_play  = require("wl_play")

    -- Calculate damage
    local dx = math.abs(ob.tilex - wl_play.player.tilex)
    local dy = math.abs(ob.tiley - wl_play.player.tiley)
    local dist = math.max(dx, dy)

    local hitchance = 256 - dist * 16
    if hitchance < 0 then hitchance = 0 end

    if id_us.US_RndT() < hitchance then
        local damage = rshift(id_us.US_RndT(), 4)
        wl_agent.TakeDamage(damage, ob)
    end
end

T_Bite = function(ob)
    local wl_agent = require("wl_agent")
    local wl_play  = require("wl_play")

    local dx = math.abs(ob.tilex - wl_play.player.tilex)
    local dy = math.abs(ob.tiley - wl_play.player.tiley)
    if dx <= 1 and dy <= 1 then
        local damage = rshift(id_us.US_RndT(), 4)
        wl_agent.TakeDamage(damage, ob)
    end
end

T_DogChase = function(ob)
    local wl_state = require("wl_state")
    local wl_main  = require("wl_main")
    local wl_play  = require("wl_play")

    if ob.distance > 0 then
        wl_state.MoveObj(ob, ob.speed * wl_main.tics)
        if ob.distance <= 0 then
            ob.distance = 0
            ob.tilex = rshift(ob.x, wl_def.TILESHIFT)
            ob.tiley = rshift(ob.y, wl_def.TILESHIFT)
        end
        return
    end

    -- At tile center
    local dx = math.abs(ob.tilex - wl_play.player.tilex)
    local dy = math.abs(ob.tiley - wl_play.player.tiley)
    if dx <= 1 and dy <= 1 then
        -- Jump at player
        wl_state.NewState(ob, wl_act2.s_dogjump1)
        return
    end

    wl_state.SelectDodgeDir(ob)
end

T_Ghosts = function(ob)
    local wl_state = require("wl_state")
    local wl_main  = require("wl_main")

    if ob.distance > 0 then
        wl_state.MoveObj(ob, ob.speed * wl_main.tics)
        if ob.distance <= 0 then ob.distance = 0 end
        return
    end

    wl_state.SelectChaseDir(ob)
end

T_Projectile = function(ob)
    local wl_state = require("wl_state")
    local wl_main  = require("wl_main")
    local wl_play  = require("wl_play")

    -- Move projectile in its direction
    local speed = 0x2000  -- projectile speed
    if ob.distance > 0 then
        wl_state.MoveObj(ob, speed * wl_main.tics)
    end

    -- Check for wall collision
    local tx = rshift(ob.x, wl_def.TILESHIFT)
    local ty = rshift(ob.y, wl_def.TILESHIFT)
    if tx < 0 or tx >= wl_def.MAPSIZE or ty < 0 or ty >= wl_def.MAPSIZE then
        -- Hit edge of map
        wl_state.NewState(ob, wl_act2.s_boom1)
        return
    end
    if wl_main.tilemap[tx][ty] ~= 0 then
        -- Hit a wall
        wl_state.NewState(ob, wl_act2.s_boom1)
        return
    end

    -- Check for hitting player
    if wl_play.player then
        local dx = math.abs(ob.x - wl_play.player.x)
        local dy = math.abs(ob.y - wl_play.player.y)
        if dx < wl_def.MINACTORDIST and dy < wl_def.MINACTORDIST then
            local wl_agent = require("wl_agent")
            local damage = rshift(id_us.US_RndT(), 4) + 10
            -- Needle does more damage
            if ob.obclass == wl_def.needleobj then
                damage = rshift(id_us.US_RndT(), 4) + 20
            end
            wl_agent.TakeDamage(damage, ob)
            wl_state.NewState(ob, wl_act2.s_boom1)
            return
        end
    end
end

-- Boss chase: same as T_Chase but uses boss-specific shoot states
T_BossChase = function(ob)
    local wl_state = require("wl_state")
    local wl_main  = require("wl_main")
    local wl_play  = require("wl_play")

    if ob.distance > 0 then
        wl_state.MoveObj(ob, ob.speed * wl_main.tics)
        if ob.distance <= 0 then
            ob.distance = 0
            ob.tilex = rshift(ob.x, wl_def.TILESHIFT)
            ob.tiley = rshift(ob.y, wl_def.TILESHIFT)
            ob.x = lshift(ob.tilex, wl_def.TILESHIFT) + math.floor(wl_def.TILEGLOBAL / 2)
            ob.y = lshift(ob.tiley, wl_def.TILESHIFT) + math.floor(wl_def.TILEGLOBAL / 2)
        end
        return
    end

    local dx = math.abs(ob.tilex - wl_play.player.tilex)
    local dy = math.abs(ob.tiley - wl_play.player.tiley)
    local dist = math.max(dx, dy)
    if dist == 0 then dist = 1 end
    if wl_state.CheckLine(ob) then
        local chance = lshift(wl_main.tics, 5) / dist
        if chance > 255 then chance = 255 end
        if id_us.US_RndT() < chance then
            wl_state.NewState(ob, wl_act2.s_bossshoot1)
            return
        end
    end
    wl_state.SelectDodgeDir(ob)
end

T_SchabbChase = function(ob)
    local wl_state = require("wl_state")
    local wl_main  = require("wl_main")
    local wl_play  = require("wl_play")

    if ob.distance > 0 then
        wl_state.MoveObj(ob, ob.speed * wl_main.tics)
        if ob.distance <= 0 then ob.distance = 0 end
        return
    end
    local dx = math.abs(ob.tilex - (require("wl_play").player.tilex))
    local dy = math.abs(ob.tiley - (require("wl_play").player.tiley))
    local dist = math.max(dx, dy)
    if dist == 0 then dist = 1 end
    if wl_state.CheckLine(ob) then
        local chance = lshift(wl_main.tics, 5) / dist
        if chance > 255 then chance = 255 end
        if id_us.US_RndT() < chance then
            wl_state.NewState(ob, wl_act2.s_schabbshoot1)
            return
        end
    end
    wl_state.SelectDodgeDir(ob)
end

T_SchabbThrow = function(ob)
    -- Spawn a needle projectile toward the player
    local wl_state = require("wl_state")
    local wl_play  = require("wl_play")
    local id_sd_loc = require("id_sd")
    local audiowl6 = require("audiowl6")

    id_sd_loc.SD_PlaySound(audiowl6.SCHABBSTHROWSND)

    local proj = wl_state.SpawnNewObj(ob.tilex, ob.tiley, wl_act2.s_needle1)
    if proj then
        proj.obclass = wl_def.needleobj
        proj.speed = 0x2000
        proj.flags = wl_def.FL_NEVERMARK
        proj.active = wl_def.ac_yes
        proj.distance = wl_def.TILEGLOBAL
        -- Aim at player
        if wl_play.player then
            local dx = wl_play.player.tilex - ob.tilex
            local dy = wl_play.player.tiley - ob.tiley
            if math.abs(dx) > math.abs(dy) then
                proj.dir = dx > 0 and wl_def.dir_east or wl_def.dir_west
            else
                proj.dir = dy > 0 and wl_def.dir_south or wl_def.dir_north
            end
        end
    end
end

T_GiftChase = function(ob)
    local wl_state = require("wl_state")
    local wl_main  = require("wl_main")
    if ob.distance > 0 then
        wl_state.MoveObj(ob, ob.speed * wl_main.tics)
        if ob.distance <= 0 then ob.distance = 0 end
        return
    end
    local dx = math.abs(ob.tilex - (require("wl_play").player.tilex))
    local dy = math.abs(ob.tiley - (require("wl_play").player.tiley))
    local dist = math.max(dx, dy)
    if dist == 0 then dist = 1 end
    if wl_state.CheckLine(ob) then
        local chance = lshift(wl_main.tics, 5) / dist
        if chance > 255 then chance = 255 end
        if id_us.US_RndT() < chance then
            wl_state.NewState(ob, wl_act2.s_giftshoot1)
            return
        end
    end
    wl_state.SelectDodgeDir(ob)
end

T_GiftThrow = function(ob)
    -- Gift fires a rocket
    local wl_state = require("wl_state")
    local wl_play  = require("wl_play")
    local id_sd_loc = require("id_sd")
    local audiowl6 = require("audiowl6")

    id_sd_loc.SD_PlaySound(audiowl6.MISSILEFIRESND)

    local proj = wl_state.SpawnNewObj(ob.tilex, ob.tiley, wl_act2.s_rocket)
    if proj then
        proj.obclass = wl_def.rocketobj
        proj.speed = 0x2000
        proj.flags = wl_def.FL_NEVERMARK
        proj.active = wl_def.ac_yes
        proj.distance = wl_def.TILEGLOBAL
        if wl_play.player then
            local dx = wl_play.player.tilex - ob.tilex
            local dy = wl_play.player.tiley - ob.tiley
            if math.abs(dx) > math.abs(dy) then
                proj.dir = dx > 0 and wl_def.dir_east or wl_def.dir_west
            else
                proj.dir = dy > 0 and wl_def.dir_south or wl_def.dir_north
            end
        end
    end
end

T_FatChase = function(ob)
    local wl_state = require("wl_state")
    local wl_main  = require("wl_main")
    if ob.distance > 0 then
        wl_state.MoveObj(ob, ob.speed * wl_main.tics)
        if ob.distance <= 0 then ob.distance = 0 end
        return
    end
    local dx = math.abs(ob.tilex - (require("wl_play").player.tilex))
    local dy = math.abs(ob.tiley - (require("wl_play").player.tiley))
    local dist = math.max(dx, dy)
    if dist == 0 then dist = 1 end
    if wl_state.CheckLine(ob) then
        local chance = lshift(wl_main.tics, 5) / dist
        if chance > 255 then chance = 255 end
        if id_us.US_RndT() < chance then
            wl_state.NewState(ob, wl_act2.s_fatshoot1)
            return
        end
    end
    wl_state.SelectDodgeDir(ob)
end

T_FakeChase = function(ob)
    -- Fake Hitler: fire cloak (shoots fire projectiles)
    local wl_state = require("wl_state")
    local wl_main  = require("wl_main")
    if ob.distance > 0 then
        wl_state.MoveObj(ob, ob.speed * wl_main.tics)
        if ob.distance <= 0 then ob.distance = 0 end
        return
    end
    local dx = math.abs(ob.tilex - (require("wl_play").player.tilex))
    local dy = math.abs(ob.tiley - (require("wl_play").player.tiley))
    local dist = math.max(dx, dy)
    if dist == 0 then dist = 1 end
    if wl_state.CheckLine(ob) then
        local chance = lshift(wl_main.tics, 5) / dist
        if chance > 255 then chance = 255 end
        if id_us.US_RndT() < chance then
            wl_state.NewState(ob, wl_act2.s_fakeshoot1)
            return
        end
    end
    wl_state.SelectDodgeDir(ob)
end

T_FakeFire = function(ob)
    -- Fake Hitler shoots fire
    local wl_state = require("wl_state")
    local wl_play  = require("wl_play")
    local id_sd_loc = require("id_sd")
    local audiowl6 = require("audiowl6")

    id_sd_loc.SD_PlaySound(audiowl6.FLAMETHROWERSND)

    local proj = wl_state.SpawnNewObj(ob.tilex, ob.tiley, wl_act2.s_rocket)
    if proj then
        proj.obclass = wl_def.fireobj
        proj.speed = 0x1200
        proj.flags = wl_def.FL_NEVERMARK
        proj.active = wl_def.ac_yes
        proj.distance = wl_def.TILEGLOBAL
        if wl_play.player then
            local dx = wl_play.player.tilex - ob.tilex
            local dy = wl_play.player.tiley - ob.tiley
            if math.abs(dx) > math.abs(dy) then
                proj.dir = dx > 0 and wl_def.dir_east or wl_def.dir_west
            else
                proj.dir = dy > 0 and wl_def.dir_south or wl_def.dir_north
            end
        end
    end
end

T_MechaChase = function(ob)
    local wl_state = require("wl_state")
    local wl_main  = require("wl_main")
    if ob.distance > 0 then
        wl_state.MoveObj(ob, ob.speed * wl_main.tics)
        if ob.distance <= 0 then ob.distance = 0 end
        return
    end
    local dx = math.abs(ob.tilex - (require("wl_play").player.tilex))
    local dy = math.abs(ob.tiley - (require("wl_play").player.tiley))
    local dist = math.max(dx, dy)
    if dist == 0 then dist = 1 end
    if wl_state.CheckLine(ob) then
        local chance = lshift(wl_main.tics, 5) / dist
        if chance > 255 then chance = 255 end
        if id_us.US_RndT() < chance then
            wl_state.NewState(ob, wl_act2.s_mechashoot1)
            return
        end
    end
    wl_state.SelectDodgeDir(ob)
end

T_HitlerChase = function(ob)
    -- Real Hitler is faster and shoots more
    local wl_state = require("wl_state")
    local wl_main  = require("wl_main")
    if ob.distance > 0 then
        wl_state.MoveObj(ob, ob.speed * wl_main.tics)
        if ob.distance <= 0 then ob.distance = 0 end
        return
    end
    local dx = math.abs(ob.tilex - (require("wl_play").player.tilex))
    local dy = math.abs(ob.tiley - (require("wl_play").player.tiley))
    local dist = math.max(dx, dy)
    if dist == 0 then dist = 1 end
    if wl_state.CheckLine(ob) then
        local chance = lshift(wl_main.tics, 5) / dist
        if chance > 255 then chance = 255 end
        if id_us.US_RndT() < chance then
            wl_state.NewState(ob, wl_act2.s_hitlershoot1)
            return
        end
    end
    wl_state.SelectDodgeDir(ob)
end

T_GretelChase = function(ob)
    local wl_state = require("wl_state")
    local wl_main  = require("wl_main")
    if ob.distance > 0 then
        wl_state.MoveObj(ob, ob.speed * wl_main.tics)
        if ob.distance <= 0 then ob.distance = 0 end
        return
    end
    local dx = math.abs(ob.tilex - (require("wl_play").player.tilex))
    local dy = math.abs(ob.tiley - (require("wl_play").player.tiley))
    local dist = math.max(dx, dy)
    if dist == 0 then dist = 1 end
    if wl_state.CheckLine(ob) then
        local chance = lshift(wl_main.tics, 5) / dist
        if chance > 255 then chance = 255 end
        if id_us.US_RndT() < chance then
            wl_state.NewState(ob, wl_act2.s_gretelshoot1)
            return
        end
    end
    wl_state.SelectDodgeDir(ob)
end

A_DeathScream = function(ob)
    -- Play appropriate death sound based on enemy type
    local id_sd_loc = require("id_sd")
    local audiowl6 = require("audiowl6")

    if ob.obclass == wl_def.guardobj then
        local scream = audiowl6.DEATHSCREAM1SND + (id_us.US_RndT() % 6)
        id_sd_loc.SD_PlaySound(scream)
    elseif ob.obclass == wl_def.officerobj then
        id_sd_loc.SD_PlaySound(audiowl6.NEINSOVASSND)
    elseif ob.obclass == wl_def.ssobj then
        id_sd_loc.SD_PlaySound(audiowl6.LEBENSND)
    elseif ob.obclass == wl_def.dogobj then
        id_sd_loc.SD_PlaySound(audiowl6.DOGDEATHSND)
    elseif ob.obclass == wl_def.mutantobj then
        id_sd_loc.SD_PlaySound(audiowl6.AHHHGSND)
    elseif ob.obclass == wl_def.bossobj then
        id_sd_loc.SD_PlaySound(audiowl6.DIESND)
    elseif ob.obclass == wl_def.schabbobj then
        id_sd_loc.SD_PlaySound(audiowl6.SCHABBSHASND)
    elseif ob.obclass == wl_def.mechahitlerobj then
        id_sd_loc.SD_PlaySound(audiowl6.HITLERHASND)
    elseif ob.obclass == wl_def.realhitlerobj then
        id_sd_loc.SD_PlaySound(audiowl6.HITLERHASND)
    else
        id_sd_loc.SD_PlaySound(audiowl6.DEATHSCREAM1SND)
    end
end

A_Smoke = function(ob)
    -- Spawn smoke behind rocket (visual only)
    -- Simplified: no-op (smoke states handle it if spawned)
end

A_MechaSound = function(ob)
    local id_sd_loc = require("id_sd")
    local audiowl6 = require("audiowl6")
    id_sd_loc.SD_PlaySound(audiowl6.MECHSTEPSND)
end

A_HitlerMorph = function(ob)
    -- Mecha Hitler dies -> spawn Real Hitler at same position
    local wl_state = require("wl_state")
    local wl_main  = require("wl_main")

    -- Change the object class to real hitler and reset hitpoints
    ob.obclass = wl_def.realhitlerobj
    ob.hitpoints = wl_act2.GetHitPoints(wl_def.en_hitler, wl_main.gamestate.difficulty)
    ob.speed = wl_def.SPDPATROL * 3  -- Real Hitler is fast
    ob.flags = bor(ob.flags, wl_def.FL_SHOOTABLE)
    wl_state.NewState(ob, wl_act2.s_hitlerchase1)
end

A_StartDeathCam = function(ob)
    -- Start the death camera sequence (simplified: just mark victory)
    local wl_main = require("wl_main")
    wl_main.gamestate.victoryflag = true
end

A_Slurpie = function(ob)
    local id_sd_loc = require("id_sd")
    local audiowl6 = require("audiowl6")
    id_sd_loc.SD_PlaySound(audiowl6.SLURPIESND)
end

---------------------------------------------------------------------------
-- Wire up all states now that functions exist
---------------------------------------------------------------------------
wireStates()

---------------------------------------------------------------------------
-- Helper: get stand/path/chase state for an enemy type
---------------------------------------------------------------------------

function wl_act2.GetStandState(enemy)
    if enemy == wl_def.en_guard then return wl_act2.s_grdstand
    elseif enemy == wl_def.en_officer then return wl_act2.s_ofcstand
    elseif enemy == wl_def.en_ss then return wl_act2.s_ssstand
    elseif enemy == wl_def.en_dog then return wl_act2.s_dogpath1  -- dogs don't stand
    elseif enemy == wl_def.en_mutant then return wl_act2.s_mutstand
    else return wl_act2.s_grdstand end
end

function wl_act2.GetPathState(enemy)
    if enemy == wl_def.en_guard then return wl_act2.s_grdpath1
    elseif enemy == wl_def.en_officer then return wl_act2.s_ofcpath1
    elseif enemy == wl_def.en_ss then return wl_act2.s_sspath1
    elseif enemy == wl_def.en_dog then return wl_act2.s_dogpath1
    elseif enemy == wl_def.en_mutant then return wl_act2.s_mutpath1
    else return wl_act2.s_grdpath1 end
end

function wl_act2.GetObjClass(enemy)
    if enemy == wl_def.en_guard then return wl_def.guardobj
    elseif enemy == wl_def.en_officer then return wl_def.officerobj
    elseif enemy == wl_def.en_ss then return wl_def.ssobj
    elseif enemy == wl_def.en_dog then return wl_def.dogobj
    elseif enemy == wl_def.en_mutant then return wl_def.mutantobj
    else return wl_def.guardobj end
end

function wl_act2.GetHitPoints(enemy, difficulty)
    local diff = difficulty or 0
    if diff < 0 then diff = 0 end
    if diff > 3 then diff = 3 end
    if wl_act2.starthitpoints[diff] and wl_act2.starthitpoints[diff][enemy] then
        return wl_act2.starthitpoints[diff][enemy]
    end
    return 25
end

-- Exported think functions
wl_act2.T_Stand = T_Stand
wl_act2.T_Path = T_Path
wl_act2.T_Chase = T_Chase
wl_act2.T_Shoot = T_Shoot
wl_act2.T_Bite = T_Bite
wl_act2.T_DogChase = T_DogChase
wl_act2.T_Ghosts = T_Ghosts
wl_act2.T_Projectile = T_Projectile
wl_act2.T_BossChase = T_BossChase
wl_act2.T_SchabbChase = T_SchabbChase
wl_act2.T_SchabbThrow = T_SchabbThrow
wl_act2.T_GiftChase = T_GiftChase
wl_act2.T_GiftThrow = T_GiftThrow
wl_act2.T_FatChase = T_FatChase
wl_act2.T_FakeChase = T_FakeChase
wl_act2.T_FakeFire = T_FakeFire
wl_act2.T_MechaChase = T_MechaChase
wl_act2.T_HitlerChase = T_HitlerChase
wl_act2.T_GretelChase = T_GretelChase
wl_act2.A_DeathScream = A_DeathScream
wl_act2.A_Smoke = A_Smoke
wl_act2.A_MechaSound = A_MechaSound
wl_act2.A_HitlerMorph = A_HitlerMorph
wl_act2.A_StartDeathCam = A_StartDeathCam
wl_act2.A_Slurpie = A_Slurpie

return wl_act2
