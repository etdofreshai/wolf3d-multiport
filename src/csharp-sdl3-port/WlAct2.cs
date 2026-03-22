// WL_ACT2.C -> WlAct2.cs
// Enemy AI - state definitions, think functions, spawn functions for all enemies

using System;

namespace Wolf3D
{
    public static class WlAct2
    {
        // =========================================================================
        //  Hitpoints per enemy, per difficulty
        // =========================================================================

        private static int[,] starthitpoints = {
            // baby   easy   medium hard
            {  25,    25,    25,    25  },  // guard
            {  50,    50,    50,    50  },  // officer
            { 100,   100,   100,   100  },  // SS
            {   1,     1,     1,     1  },  // dog
            { 850,   950,  1050,  1200  },  // boss (Hans)
            { 850,   950,  1050,  1200  },  // schabbs
            { 200,   300,   400,   500  },  // fake hitler
            { 800,   950,  1050,  1200  },  // mecha/real hitler
            {  45,    55,    55,    65  },  // mutant
            {  25,    25,    25,    25  },  // blinky (ghost)
            {  25,    25,    25,    25  },  // clyde
            {  25,    25,    25,    25  },  // pinky
            {  25,    25,    25,    25  },  // inky
            { 850,   950,  1050,  1200  },  // gretel
            { 850,   950,  1050,  1200  },  // gift
            { 850,   950,  1050,  1200  },  // fat
            { 850,   950,  1050,  1200  },  // spectre
            { 850,   950,  1050,  1200  },  // angel
            { 850,   950,  1050,  1200  },  // trans
            { 850,   950,  1050,  1200  },  // uber
            { 850,   950,  1050,  1200  },  // will
            { 850,   950,  1050,  1200  },  // death
        };

        // =========================================================================
        //  State definitions - guard
        // =========================================================================

        public static statetype s_grdstand = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_GRD_S_1, tictime = 0, think = T_Stand };
        public static statetype s_grdpath1 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_GRD_W1_1, tictime = 20, think = T_Path };
        public static statetype s_grdpath1s = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_GRD_W1_1, tictime = 5 };
        public static statetype s_grdpath2 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_GRD_W2_1, tictime = 15, think = T_Path };
        public static statetype s_grdpath3 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_GRD_W3_1, tictime = 20, think = T_Path };
        public static statetype s_grdpath3s = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_GRD_W3_1, tictime = 5 };
        public static statetype s_grdpath4 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_GRD_W4_1, tictime = 15, think = T_Path };

        public static statetype s_grdchase1 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_GRD_W1_1, tictime = 10, think = T_Chase };
        public static statetype s_grdchase1s = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_GRD_W1_1, tictime = 3 };
        public static statetype s_grdchase2 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_GRD_W2_1, tictime = 8, think = T_Chase };
        public static statetype s_grdchase3 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_GRD_W3_1, tictime = 10, think = T_Chase };
        public static statetype s_grdchase3s = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_GRD_W3_1, tictime = 3 };
        public static statetype s_grdchase4 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_GRD_W4_1, tictime = 8, think = T_Chase };

        public static statetype s_grdpain = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_GRD_PAIN_1, tictime = 10 };
        public static statetype s_grdpain1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_GRD_PAIN_2, tictime = 10 };
        public static statetype s_grddie1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_GRD_DIE_1, tictime = 15 };
        public static statetype s_grddie2 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_GRD_DIE_2, tictime = 15 };
        public static statetype s_grddie3 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_GRD_DIE_3, tictime = 15 };
        public static statetype s_grdshoot1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_GRD_SHOOT1, tictime = 20 };
        public static statetype s_grdshoot2 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_GRD_SHOOT2, tictime = 20, action = T_Shoot };
        public static statetype s_grdshoot3 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_GRD_SHOOT3, tictime = 20 };

        // Dog
        public static statetype s_dogchase1 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_DOG_W1_1, tictime = 10, think = T_DogChase };
        public static statetype s_dogchase2 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_DOG_W2_1, tictime = 10, think = T_DogChase };
        public static statetype s_dogchase3 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_DOG_W3_1, tictime = 10, think = T_DogChase };
        public static statetype s_dogchase4 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_DOG_W4_1, tictime = 10, think = T_DogChase };
        public static statetype s_dogdie1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_DOG_DIE_1, tictime = 15 };
        public static statetype s_dogdie2 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_DOG_DIE_2, tictime = 15 };
        public static statetype s_dogdie3 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_DOG_DIE_3, tictime = 15 };

        // Officer
        public static statetype s_ofcstand = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_OFC_S_1, tictime = 0, think = T_Stand };
        public static statetype s_ofcchase1 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_OFC_W1_1, tictime = 10, think = T_Chase };
        public static statetype s_ofcchase2 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_OFC_W2_1, tictime = 10, think = T_Chase };
        public static statetype s_ofcchase3 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_OFC_W3_1, tictime = 10, think = T_Chase };
        public static statetype s_ofcchase4 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_OFC_W4_1, tictime = 10, think = T_Chase };
        public static statetype s_ofcdie1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_OFC_DIE_1, tictime = 11 };
        public static statetype s_ofcdie2 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_OFC_DIE_2, tictime = 11 };
        public static statetype s_ofcdie3 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_OFC_DIE_3, tictime = 11 };
        public static statetype s_ofcpain = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_OFC_PAIN_1, tictime = 10 };
        public static statetype s_ofcpain1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_OFC_PAIN_2, tictime = 10 };
        public static statetype s_ofcshoot1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_OFC_SHOOT1, tictime = 6 };
        public static statetype s_ofcshoot2 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_OFC_SHOOT2, tictime = 20, action = T_Shoot };
        public static statetype s_ofcshoot3 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_OFC_SHOOT3, tictime = 10 };

        // SS
        public static statetype s_ssstand = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_SS_S_1, tictime = 0, think = T_Stand };
        public static statetype s_sschase1 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_SS_W1_1, tictime = 10, think = T_Chase };
        public static statetype s_sschase2 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_SS_W2_1, tictime = 10, think = T_Chase };
        public static statetype s_sschase3 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_SS_W3_1, tictime = 10, think = T_Chase };
        public static statetype s_sschase4 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_SS_W4_1, tictime = 10, think = T_Chase };
        public static statetype s_ssdie1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_SS_DIE_1, tictime = 15 };
        public static statetype s_ssdie2 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_SS_DIE_2, tictime = 15 };
        public static statetype s_ssdie3 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_SS_DIE_3, tictime = 15 };
        public static statetype s_sspain = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_SS_PAIN_1, tictime = 10 };
        public static statetype s_sspain1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_SS_PAIN_2, tictime = 10 };
        public static statetype s_ssshoot1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_SS_SHOOT1, tictime = 20 };
        public static statetype s_ssshoot2 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_SS_SHOOT2, tictime = 20, action = T_Shoot };
        public static statetype s_ssshoot3 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_SS_SHOOT3, tictime = 10 };

        // Mutant
        public static statetype s_mutstand = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_MUT_S_1, tictime = 0, think = T_Stand };
        public static statetype s_mutchase1 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_MUT_W1_1, tictime = 10, think = T_Chase };
        public static statetype s_mutchase2 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_MUT_W2_1, tictime = 10, think = T_Chase };
        public static statetype s_mutchase3 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_MUT_W3_1, tictime = 10, think = T_Chase };
        public static statetype s_mutchase4 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_MUT_W4_1, tictime = 10, think = T_Chase };
        public static statetype s_mutdie1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_MUT_DIE_1, tictime = 7 };
        public static statetype s_mutdie2 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_MUT_DIE_2, tictime = 7 };
        public static statetype s_mutdie3 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_MUT_DIE_3, tictime = 7 };
        public static statetype s_mutpain = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_MUT_PAIN_1, tictime = 10 };
        public static statetype s_mutpain1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_MUT_PAIN_2, tictime = 10 };
        public static statetype s_mutshoot1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_MUT_SHOOT1, tictime = 6, action = T_Shoot };
        public static statetype s_mutshoot2 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_MUT_SHOOT2, tictime = 20 };
        public static statetype s_mutshoot3 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_MUT_SHOOT3, tictime = 10, action = T_Shoot };
        public static statetype s_mutshoot4 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_MUT_SHOOT4, tictime = 20 };

        // Boss states
        public static statetype s_bosschase1 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_BOSS_W1, tictime = 10, think = T_Chase };
        public static statetype s_bossdie1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_BOSS_DIE1, tictime = 15 };

        // Additional boss/enemy states
        public static statetype s_schabbchase1 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_SCHABB_W1, tictime = 10, think = T_Chase };
        public static statetype s_schabbdie1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_SCHABB_DIE1, tictime = 10 };
        public static statetype s_fakechase1 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_FAKE_W1, tictime = 10, think = T_Chase };
        public static statetype s_fakedie1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_FAKE_DIE1, tictime = 10 };
        public static statetype s_mechachase1 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_MECHA_W1, tictime = 10, think = T_Chase };
        public static statetype s_mechadie1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_MECHA_DIE1, tictime = 10 };
        public static statetype s_hitlerchase1 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_HITLER_W1, tictime = 10, think = T_Chase };
        public static statetype s_hitlerdie1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_HITLER_DIE1, tictime = 10 };
        public static statetype s_gretelchase1 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_GRETEL_W1, tictime = 10, think = T_Chase };
        public static statetype s_greteldie1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_GRETEL_DIE1, tictime = 10 };
        public static statetype s_giftchase1 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_GIFT_W1, tictime = 10, think = T_Chase };
        public static statetype s_giftdie1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_GIFT_DIE1, tictime = 10 };
        public static statetype s_fatchase1 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_FAT_W1, tictime = 10, think = T_Chase };
        public static statetype s_fatdie1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_FAT_DIE1, tictime = 10 };
        public static statetype s_spectrechase1 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_BLINKY_W1, tictime = 10, think = T_Chase };
        public static statetype s_spectredie1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_BLINKY_W1, tictime = 10 };
        public static statetype s_angelchase1 = new statetype { rotate = false, shapenum = 0, tictime = 10, think = T_Chase };
        public static statetype s_angeldie1 = new statetype { rotate = false, shapenum = 0, tictime = 10 };
        public static statetype s_transchase1 = new statetype { rotate = false, shapenum = 0, tictime = 10, think = T_Chase };
        public static statetype s_transdie0 = new statetype { rotate = false, shapenum = 0, tictime = 10 };
        public static statetype s_uberchase1 = new statetype { rotate = false, shapenum = 0, tictime = 10, think = T_Chase };
        public static statetype s_uberdie0 = new statetype { rotate = false, shapenum = 0, tictime = 10 };
        public static statetype s_willchase1 = new statetype { rotate = false, shapenum = 0, tictime = 10, think = T_Chase };
        public static statetype s_willdie1 = new statetype { rotate = false, shapenum = 0, tictime = 10 };
        public static statetype s_deathchase1 = new statetype { rotate = false, shapenum = 0, tictime = 10, think = T_Chase };
        public static statetype s_deathdie1 = new statetype { rotate = false, shapenum = 0, tictime = 10 };
        public static statetype s_blinkychase1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_BLINKY_W1, tictime = 10, think = T_Chase };
        public static statetype s_deathcam = new statetype { rotate = false, shapenum = 0, tictime = 0 };
        public static statetype s_schabbdeathcam2 = new statetype { rotate = false, shapenum = 0, tictime = 0 };
        public static statetype s_hitlerdeathcam2 = new statetype { rotate = false, shapenum = 0, tictime = 0 };
        public static statetype s_giftdeathcam2 = new statetype { rotate = false, shapenum = 0, tictime = 0 };
        public static statetype s_fatdeathcam2 = new statetype { rotate = false, shapenum = 0, tictime = 0 };

        static WlAct2()
        {
            // Link state chains
            s_grdchase1.next = s_grdchase2; s_grdchase2.next = s_grdchase3;
            s_grdchase3.next = s_grdchase4; s_grdchase4.next = s_grdchase1;
            s_grdpain.next = s_grdchase1;
            s_grddie1.next = s_grddie2; s_grddie2.next = s_grddie3;
            s_grdshoot1.next = s_grdshoot2; s_grdshoot2.next = s_grdshoot3; s_grdshoot3.next = s_grdchase1;

            s_dogchase1.next = s_dogchase2; s_dogchase2.next = s_dogchase3;
            s_dogchase3.next = s_dogchase4; s_dogchase4.next = s_dogchase1;
            s_dogdie1.next = s_dogdie2; s_dogdie2.next = s_dogdie3;

            s_ofcchase1.next = s_ofcchase2; s_ofcchase2.next = s_ofcchase3;
            s_ofcchase3.next = s_ofcchase4; s_ofcchase4.next = s_ofcchase1;
            s_ofcpain.next = s_ofcchase1;
            s_ofcdie1.next = s_ofcdie2; s_ofcdie2.next = s_ofcdie3;
            s_ofcshoot1.next = s_ofcshoot2; s_ofcshoot2.next = s_ofcshoot3; s_ofcshoot3.next = s_ofcchase1;

            s_sschase1.next = s_sschase2; s_sschase2.next = s_sschase3;
            s_sschase3.next = s_sschase4; s_sschase4.next = s_sschase1;
            s_sspain.next = s_sschase1;
            s_ssdie1.next = s_ssdie2; s_ssdie2.next = s_ssdie3;
            s_ssshoot1.next = s_ssshoot2; s_ssshoot2.next = s_ssshoot3; s_ssshoot3.next = s_sschase1;

            s_mutchase1.next = s_mutchase2; s_mutchase2.next = s_mutchase3;
            s_mutchase3.next = s_mutchase4; s_mutchase4.next = s_mutchase1;
            s_mutpain.next = s_mutchase1;
            s_mutdie1.next = s_mutdie2; s_mutdie2.next = s_mutdie3;
            s_mutshoot1.next = s_mutshoot2; s_mutshoot2.next = s_mutshoot3;
            s_mutshoot3.next = s_mutshoot4; s_mutshoot4.next = s_mutchase1;

            s_bosschase1.next = s_bosschase1;
            s_grdpath1.next = s_grdpath1s; s_grdpath1s.next = s_grdpath2;
            s_grdpath2.next = s_grdpath3; s_grdpath3.next = s_grdpath3s;
            s_grdpath3s.next = s_grdpath4; s_grdpath4.next = s_grdpath1;
        }

        // =========================================================================
        //  AI Think functions
        // =========================================================================

        public static void T_Stand(objtype ob)
        {
            if (WlState.SightPlayer(ob))
            {
                statetype chaseState = GetChaseState(ob);
                ob.flags |= WolfConstants.FL_ATTACKMODE | WolfConstants.FL_FIRSTATTACK;
                WlState.NewState(ob, chaseState);

                // Play alert sound
                switch (ob.obclass)
                {
                    case classtype.guardobj: IdSd.SD_PlaySound(soundnames.HALTSND); break;
                    case classtype.officerobj: IdSd.SD_PlaySound(soundnames.SPIONSND); break;
                    case classtype.ssobj: IdSd.SD_PlaySound(soundnames.SCHUTZADSND); break;
                    case classtype.dogobj: IdSd.SD_PlaySound(soundnames.DOGBARKSND); break;
                    case classtype.mutantobj: break;
                }
            }
        }

        public static void T_Path(objtype ob)
        {
            if (WlState.SightPlayer(ob))
            {
                statetype chaseState = GetChaseState(ob);
                ob.flags |= WolfConstants.FL_ATTACKMODE | WolfConstants.FL_FIRSTATTACK;
                WlState.NewState(ob, chaseState);
                return;
            }

            if (ob.distance < 0) return; // waiting for door

            // Move along path
            if (ob.distance > 0)
            {
                int move = ob.speed * WL_Globals.tics;
                if (move > ob.distance)
                    move = ob.distance;
                WlState.MoveObj(ob, move);
                return;
            }

            // Reached destination tile
            WlState.SelectChaseDir(ob);
        }

        public static void T_Chase(objtype ob)
        {
            int move = ob.speed * WL_Globals.tics;

            // Try to attack if close enough
            int dx = Math.Abs(WL_Globals.player.tilex - ob.tilex);
            int dy = Math.Abs(WL_Globals.player.tiley - ob.tiley);

            if (dx <= 1 && dy <= 1 && ob.obclass != classtype.dogobj)
            {
                // Chance to shoot
                int chance = IdUs.US_RndT();
                if (chance < 60)
                {
                    statetype shootState = GetShootState(ob);
                    if (shootState != null)
                    {
                        WlState.NewState(ob, shootState);
                        return;
                    }
                }
            }

            if (ob.dir == dirtype.nodir)
            {
                WlState.SelectChaseDir(ob);
                if (ob.dir == dirtype.nodir)
                    return;
            }

            if (ob.distance < 0)
            {
                // Waiting for door
                int doornum = -(ob.distance + 1);
                if (doornum >= 0 && doornum < WolfConstants.MAXDOORS &&
                    WL_Globals.doorobjlist[doornum].action == dooraction_t.dr_open)
                {
                    ob.distance = WolfConstants.TILEGLOBAL;
                }
                return;
            }

            if (move > ob.distance)
                move = ob.distance;

            WlState.MoveObj(ob, move);

            if (ob.distance <= 0)
            {
                ob.tilex = ob.x >> WolfConstants.TILESHIFT;
                ob.tiley = ob.y >> WolfConstants.TILESHIFT;
                WlState.SelectChaseDir(ob);
            }
        }

        public static void T_DogChase(objtype ob)
        {
            int move = ob.speed * WL_Globals.tics;

            int dx = Math.Abs(WL_Globals.player.tilex - ob.tilex);
            int dy = Math.Abs(WL_Globals.player.tiley - ob.tiley);

            if (dx <= 1 && dy <= 1)
            {
                // Dog bite!
                WlAgent.TakeDamage(IdUs.US_RndT() >> 4, ob);
                IdSd.SD_PlaySound(soundnames.DOGATTACKSND);
            }

            if (ob.dir == dirtype.nodir)
            {
                WlState.SelectChaseDir(ob);
                if (ob.dir == dirtype.nodir) return;
            }

            if (move > ob.distance) move = ob.distance;
            WlState.MoveObj(ob, move);

            if (ob.distance <= 0)
            {
                ob.tilex = ob.x >> WolfConstants.TILESHIFT;
                ob.tiley = ob.y >> WolfConstants.TILESHIFT;
                WlState.SelectChaseDir(ob);
            }
        }

        public static void T_Shoot(objtype ob)
        {
            if (!WlState.CheckSight(ob)) return;

            int dx = Math.Abs(WL_Globals.player.tilex - ob.tilex);
            int dy = Math.Abs(WL_Globals.player.tiley - ob.tiley);
            int dist = Math.Max(dx, dy);

            int hitchance;
            if (dist <= 1) hitchance = 256;
            else if (dist <= 2) hitchance = 160;
            else if (dist <= 4) hitchance = 100;
            else hitchance = 40;

            if (IdUs.US_RndT() < hitchance)
            {
                int damage;
                if (dist < 2) damage = IdUs.US_RndT() >> 4;
                else if (dist < 4) damage = IdUs.US_RndT() >> 5;
                else damage = IdUs.US_RndT() >> 6;

                WlAgent.TakeDamage(damage, ob);
            }

            switch (ob.obclass)
            {
                case classtype.guardobj: IdSd.SD_PlaySound(soundnames.NAZIFIRESND); break;
                case classtype.officerobj: IdSd.SD_PlaySound(soundnames.NAZIFIRESND); break;
                case classtype.ssobj: IdSd.SD_PlaySound(soundnames.SSFIRESND); break;
                case classtype.mutantobj: IdSd.SD_PlaySound(soundnames.NAZIFIRESND); break;
                case classtype.bossobj: IdSd.SD_PlaySound(soundnames.BOSSFIRESND); break;
            }
        }

        // =========================================================================
        //  Helper: get chase/shoot state for enemy type
        // =========================================================================

        private static statetype GetChaseState(objtype ob)
        {
            switch (ob.obclass)
            {
                case classtype.guardobj: return s_grdchase1;
                case classtype.officerobj: return s_ofcchase1;
                case classtype.ssobj: return s_sschase1;
                case classtype.dogobj: return s_dogchase1;
                case classtype.mutantobj: return s_mutchase1;
                case classtype.bossobj: return s_bosschase1;
                default: return s_grdchase1;
            }
        }

        private static statetype GetShootState(objtype ob)
        {
            switch (ob.obclass)
            {
                case classtype.guardobj: return s_grdshoot1;
                case classtype.officerobj: return s_ofcshoot1;
                case classtype.ssobj: return s_ssshoot1;
                case classtype.mutantobj: return s_mutshoot1;
                default: return null;
            }
        }

        // =========================================================================
        //  Spawn functions
        // =========================================================================

        public static void SpawnStand(enemy_t which, int tilex, int tiley, int dir)
        {
            statetype state;
            switch (which)
            {
                case enemy_t.en_guard: state = s_grdstand; break;
                case enemy_t.en_officer: state = s_ofcstand; break;
                case enemy_t.en_ss: state = s_ssstand; break;
                case enemy_t.en_dog: state = s_grdstand; break;
                case enemy_t.en_mutant: state = s_mutstand; break;
                default: state = s_grdstand; break;
            }

            WlState.SpawnNewObj(tilex, tiley, state);

            int enumIdx = (int)which;
            WL_Globals.new_.obclass = (classtype)(enumIdx + (int)classtype.guardobj);
            WL_Globals.new_.hitpoints = GetHitpoints(enumIdx);
            WL_Globals.new_.flags |= WolfConstants.FL_SHOOTABLE;
            WL_Globals.new_.speed = GetSpeed(which);
            WL_Globals.new_.dir = (dirtype)(dir * 2);

            if (!WL_Globals.loadedgame)
                WL_Globals.gamestate.killtotal++;
        }

        public static void SpawnPatrol(enemy_t which, int tilex, int tiley, int dir)
        {
            SpawnStand(which, tilex, tiley, dir);
            WL_Globals.new_.active = activetype.ac_yes;
            WL_Globals.new_.state = s_grdpath1; // patrol state

            switch (which)
            {
                case enemy_t.en_guard: WL_Globals.new_.state = s_grdpath1; break;
                case enemy_t.en_officer: WL_Globals.new_.state = s_ofcchase1; break;
                case enemy_t.en_ss: WL_Globals.new_.state = s_sschase1; break;
                case enemy_t.en_dog: WL_Globals.new_.state = s_dogchase1; break;
                case enemy_t.en_mutant: WL_Globals.new_.state = s_mutchase1; break;
            }
            WL_Globals.new_.distance = WolfConstants.TILEGLOBAL;
        }

        public static void SpawnDeadGuard(int tilex, int tiley)
        {
            WlState.SpawnNewObj(tilex, tiley, s_grddie3);
            WL_Globals.new_.obclass = classtype.inertobj;
        }

        private static int GetHitpoints(int enemyIdx)
        {
            int diff = WL_Globals.gamestate.difficulty;
            if (diff < 0) diff = 0;
            if (diff > 3) diff = 3;
            if (enemyIdx < 0 || enemyIdx >= starthitpoints.GetLength(0))
                return 25;
            return starthitpoints[enemyIdx, diff];
        }

        private static int GetSpeed(enemy_t which)
        {
            switch (which)
            {
                case enemy_t.en_dog: return WolfConstants.SPDDOG;
                case enemy_t.en_officer: return WolfConstants.SPDPATROL * 2;
                case enemy_t.en_mutant: return WolfConstants.SPDPATROL;
                case enemy_t.en_ss: return WolfConstants.SPDPATROL;
                default: return WolfConstants.SPDPATROL;
            }
        }

        // Boss spawns
        public static void SpawnBoss(int tilex, int tiley)
        {
            WlState.SpawnNewObj(tilex, tiley, s_bosschase1);
            WL_Globals.new_.obclass = classtype.bossobj;
            WL_Globals.new_.hitpoints = GetHitpoints((int)enemy_t.en_boss);
            WL_Globals.new_.flags |= WolfConstants.FL_SHOOTABLE;
            WL_Globals.new_.speed = WolfConstants.SPDPATROL;
            if (!WL_Globals.loadedgame) WL_Globals.gamestate.killtotal++;
        }
        public static void SpawnGretel(int tilex, int tiley) { SpawnBossGeneric(tilex, tiley, classtype.gretelobj, s_gretelchase1, (int)enemy_t.en_gretel); }
        public static void SpawnTrans(int tilex, int tiley) { SpawnBossGeneric(tilex, tiley, classtype.transobj, s_transchase1, (int)enemy_t.en_trans); }
        public static void SpawnUber(int tilex, int tiley) { SpawnBossGeneric(tilex, tiley, classtype.uberobj, s_uberchase1, (int)enemy_t.en_uber); }
        public static void SpawnWill(int tilex, int tiley) { SpawnBossGeneric(tilex, tiley, classtype.willobj, s_willchase1, (int)enemy_t.en_will); }
        public static void SpawnDeath(int tilex, int tiley) { SpawnBossGeneric(tilex, tiley, classtype.deathobj, s_deathchase1, (int)enemy_t.en_death); }
        public static void SpawnAngel(int tilex, int tiley) { SpawnBossGeneric(tilex, tiley, classtype.angelobj, s_angelchase1, (int)enemy_t.en_angel); }
        public static void SpawnSpectre(int tilex, int tiley) { SpawnBossGeneric(tilex, tiley, classtype.spectreobj, s_spectrechase1, (int)enemy_t.en_spectre); }
        public static void SpawnSchabbs(int tilex, int tiley) { SpawnBossGeneric(tilex, tiley, classtype.schabbobj, s_schabbchase1, (int)enemy_t.en_schabbs); }
        public static void SpawnGift(int tilex, int tiley) { SpawnBossGeneric(tilex, tiley, classtype.giftobj, s_giftchase1, (int)enemy_t.en_gift); }
        public static void SpawnFat(int tilex, int tiley) { SpawnBossGeneric(tilex, tiley, classtype.fatobj, s_fatchase1, (int)enemy_t.en_fat); }
        public static void SpawnFakeHitler(int tilex, int tiley) { SpawnBossGeneric(tilex, tiley, classtype.fakeobj, s_fakechase1, (int)enemy_t.en_fake); }
        public static void SpawnHitler(int tilex, int tiley) { SpawnBossGeneric(tilex, tiley, classtype.mechahitlerobj, s_mechachase1, (int)enemy_t.en_hitler); }

        private static void SpawnBossGeneric(int tilex, int tiley, classtype cls, statetype state, int enemyIdx)
        {
            WlState.SpawnNewObj(tilex, tiley, state);
            WL_Globals.new_.obclass = cls;
            WL_Globals.new_.hitpoints = GetHitpoints(enemyIdx);
            WL_Globals.new_.flags |= WolfConstants.FL_SHOOTABLE;
            WL_Globals.new_.speed = WolfConstants.SPDPATROL;
            if (!WL_Globals.loadedgame) WL_Globals.gamestate.killtotal++;
        }

        public static void SpawnGhosts(int which, int tilex, int tiley)
        {
            WlState.SpawnNewObj(tilex, tiley, s_blinkychase1);
            WL_Globals.new_.obclass = classtype.ghostobj;
            WL_Globals.new_.speed = WolfConstants.SPDDOG;
        }

        public static void SpawnBJVictory() { }

        public static void A_DeathScream(objtype ob)
        {
            switch (ob.obclass)
            {
                case classtype.guardobj: IdSd.SD_PlaySound(soundnames.DEATHSCREAM1SND); break;
                case classtype.officerobj: IdSd.SD_PlaySound(soundnames.DEATHSCREAM2SND); break;
                case classtype.ssobj: IdSd.SD_PlaySound(soundnames.DEATHSCREAM3SND); break;
                case classtype.dogobj: IdSd.SD_PlaySound(soundnames.DOGDEATHSND); break;
                case classtype.mutantobj: IdSd.SD_PlaySound(soundnames.AHHHGSND); break;
                default: IdSd.SD_PlaySound(soundnames.DEATHSCREAM1SND); break;
            }
        }
    }
}
