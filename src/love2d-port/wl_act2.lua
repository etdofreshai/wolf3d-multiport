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
local T_Ghosts, T_Projectile, T_Schabb, T_SchabbThrow
local T_Fake, T_FakeFire
local A_DeathScream, A_Smoke, A_Slurpie, A_HitlerMorph, A_MechaSound

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

-- Boss/special enemy stand states (simplified - just standing)
wl_act2.s_bossstand    = S(false, wl_def.SPR_BOSS_W1, 0, nil, nil)
wl_act2.s_gretelstand  = S(false, wl_def.SPR_GRETEL_W1, 0, nil, nil)
wl_act2.s_schabbstand  = S(false, wl_def.SPR_SCHABB_W1, 0, nil, nil)
wl_act2.s_giftstand    = S(false, wl_def.SPR_GIFT_W1, 0, nil, nil)
wl_act2.s_fatstand     = S(false, wl_def.SPR_FAT_W1, 0, nil, nil)
wl_act2.s_fakestand    = S(false, wl_def.SPR_FAKE_W1, 0, nil, nil)
wl_act2.s_mechastand   = S(false, wl_def.SPR_MECHA_W1, 0, nil, nil)

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
    local dx = math.abs(ob.tilex - (require("wl_play").player.tilex))
    local dy = math.abs(ob.tiley - (require("wl_play").player.tiley))

    if wl_state.CheckLine(ob) then
        -- Can see player, maybe shoot
        local chance = id_us.US_RndT()
        if ob.obclass == wl_def.guardobj then
            if chance < 128 and dx < 3 and dy < 3 then
                -- Shoot
                local wl_state_mod = require("wl_state")
                wl_state_mod.NewState(ob, wl_act2.s_grdshoot1)
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
    -- Projectile movement handled elsewhere
end

A_DeathScream = function(ob)
    -- Play death sound (simplified)
end

A_Smoke = function(ob)
    -- Spawn smoke behind rocket
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
wl_act2.A_DeathScream = A_DeathScream
wl_act2.A_Smoke = A_Smoke

return wl_act2
