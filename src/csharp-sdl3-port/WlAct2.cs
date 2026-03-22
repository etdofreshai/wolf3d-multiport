// WL_ACT2.C -> WlAct2.cs
// Enemy AI - state definitions and spawn functions for all enemies

using System;

namespace Wolf3D
{
    public static class WlAct2
    {
        // =========================================================================
        //  State definitions (simplified - full game needs complete state tables)
        // =========================================================================

        public static statetype s_grdstand = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_GRD_S_1, tictime = 0, think = T_Stand, next = null };
        public static statetype s_grdchase1 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_GRD_W1_1, tictime = 10, think = T_Chase, next = null };
        public static statetype s_grddie1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_GRD_DIE_1, tictime = 15, next = null };
        public static statetype s_grdpain = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_GRD_PAIN_1, tictime = 10, next = null };
        public static statetype s_grdpain1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_GRD_PAIN_2, tictime = 10, next = null };

        public static statetype s_dogchase1 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_DOG_W1_1, tictime = 10, think = T_Chase, next = null };
        public static statetype s_dogdie1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_DOG_DIE_1, tictime = 15, next = null };

        public static statetype s_ofcchase1 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_OFC_W1_1, tictime = 10, think = T_Chase, next = null };
        public static statetype s_ofcdie1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_OFC_DIE_1, tictime = 15, next = null };
        public static statetype s_ofcpain = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_OFC_PAIN_1, tictime = 10, next = null };
        public static statetype s_ofcpain1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_OFC_PAIN_2, tictime = 10, next = null };

        public static statetype s_sschase1 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_SS_W1_1, tictime = 10, think = T_Chase, next = null };
        public static statetype s_ssdie1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_SS_DIE_1, tictime = 15, next = null };
        public static statetype s_sspain = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_SS_PAIN_1, tictime = 10, next = null };
        public static statetype s_sspain1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_SS_PAIN_2, tictime = 10, next = null };

        public static statetype s_mutchase1 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_MUT_W1_1, tictime = 10, think = T_Chase, next = null };
        public static statetype s_mutdie1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_MUT_DIE_1, tictime = 15, next = null };
        public static statetype s_mutpain = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_MUT_PAIN_1, tictime = 10, next = null };
        public static statetype s_mutpain1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_MUT_PAIN_2, tictime = 10, next = null };

        public static statetype s_bosschase1 = new statetype { rotate = true, shapenum = (int)SpriteEnum.SPR_BOSS_W1, tictime = 10, think = T_Chase, next = null };
        public static statetype s_bossdie1 = new statetype { rotate = false, shapenum = (int)SpriteEnum.SPR_BOSS_DIE1, tictime = 15, next = null };

        // Additional boss/enemy states (stubs for compilation)
        public static statetype s_schabbchase1, s_schabbdie1, s_fakechase1, s_fakedie1;
        public static statetype s_mechachase1, s_mechadie1, s_hitlerchase1, s_hitlerdie1;
        public static statetype s_gretelchase1, s_greteldie1, s_giftchase1, s_giftdie1;
        public static statetype s_fatchase1, s_fatdie1;
        public static statetype s_spectrechase1, s_spectredie1;
        public static statetype s_angelchase1, s_angeldie1;
        public static statetype s_transchase1, s_transdie0;
        public static statetype s_uberchase1, s_uberdie0;
        public static statetype s_willchase1, s_willdie1;
        public static statetype s_deathchase1, s_deathdie1;
        public static statetype s_blinkychase1;
        public static statetype s_deathcam;
        public static statetype s_schabbdeathcam2, s_hitlerdeathcam2;
        public static statetype s_giftdeathcam2, s_fatdeathcam2;

        static WlAct2()
        {
            // Link chase states to themselves for looping
            s_grdchase1.next = s_grdchase1;
            s_dogchase1.next = s_dogchase1;
            s_ofcchase1.next = s_ofcchase1;
            s_sschase1.next = s_sschase1;
            s_mutchase1.next = s_mutchase1;
            s_bosschase1.next = s_bosschase1;

            s_grdpain.next = s_grdchase1;
            s_ofcpain.next = s_ofcchase1;
            s_sspain.next = s_sschase1;
            s_mutpain.next = s_mutchase1;
        }

        // =========================================================================
        //  AI Think functions
        // =========================================================================

        public static void T_Stand(objtype ob)
        {
            if (WlState.SightPlayer(ob))
            {
                ob.flags |= WolfConstants.FL_ATTACKMODE;
                WlState.NewState(ob, s_grdchase1);
            }
        }

        public static void T_Chase(objtype ob)
        {
            int move = ob.speed * WL_Globals.tics;
            WlState.SelectChaseDir(ob);
            WlState.MoveObj(ob, move);
        }

        // =========================================================================
        //  Spawn functions
        // =========================================================================

        public static void SpawnStand(enemy_t which, int tilex, int tiley, int dir)
        {
            statetype state = s_grdstand;
            switch (which)
            {
                case enemy_t.en_guard: state = s_grdstand; break;
                case enemy_t.en_officer: state = s_grdstand; break;
                case enemy_t.en_ss: state = s_grdstand; break;
                case enemy_t.en_dog: state = s_grdstand; break;
                case enemy_t.en_mutant: state = s_grdstand; break;
            }

            WlState.SpawnNewObj(tilex, tiley, state);
            WL_Globals.new_.obclass = (classtype)(which + 3); // guardobj = 3
            WL_Globals.new_.hitpoints = 25;
            WL_Globals.new_.flags |= WolfConstants.FL_SHOOTABLE;
            WL_Globals.new_.speed = WolfConstants.SPDPATROL;
            WL_Globals.new_.dir = (dirtype)(dir * 2);
        }

        public static void SpawnPatrol(enemy_t which, int tilex, int tiley, int dir)
        {
            SpawnStand(which, tilex, tiley, dir);
            WL_Globals.new_.active = activetype.ac_yes;
        }

        public static void SpawnDeadGuard(int tilex, int tiley)
        {
            WlState.SpawnNewObj(tilex, tiley, s_grddie1);
            WL_Globals.new_.obclass = classtype.inertobj;
        }

        // Boss spawn stubs
        public static void SpawnBoss(int tilex, int tiley) { SpawnStand(enemy_t.en_boss, tilex, tiley, 0); }
        public static void SpawnGretel(int tilex, int tiley) { SpawnStand(enemy_t.en_gretel, tilex, tiley, 0); }
        public static void SpawnTrans(int tilex, int tiley) { SpawnStand(enemy_t.en_trans, tilex, tiley, 0); }
        public static void SpawnUber(int tilex, int tiley) { SpawnStand(enemy_t.en_uber, tilex, tiley, 0); }
        public static void SpawnWill(int tilex, int tiley) { SpawnStand(enemy_t.en_will, tilex, tiley, 0); }
        public static void SpawnDeath(int tilex, int tiley) { SpawnStand(enemy_t.en_death, tilex, tiley, 0); }
        public static void SpawnAngel(int tilex, int tiley) { SpawnStand(enemy_t.en_angel, tilex, tiley, 0); }
        public static void SpawnSpectre(int tilex, int tiley) { SpawnStand(enemy_t.en_spectre, tilex, tiley, 0); }
        public static void SpawnGhosts(int which, int tilex, int tiley) { }
        public static void SpawnSchabbs(int tilex, int tiley) { SpawnStand(enemy_t.en_schabbs, tilex, tiley, 0); }
        public static void SpawnGift(int tilex, int tiley) { SpawnStand(enemy_t.en_gift, tilex, tiley, 0); }
        public static void SpawnFat(int tilex, int tiley) { SpawnStand(enemy_t.en_fat, tilex, tiley, 0); }
        public static void SpawnFakeHitler(int tilex, int tiley) { SpawnStand(enemy_t.en_fake, tilex, tiley, 0); }
        public static void SpawnHitler(int tilex, int tiley) { SpawnStand(enemy_t.en_hitler, tilex, tiley, 0); }
        public static void SpawnBJVictory() { }

        public static void A_DeathScream(objtype ob)
        {
            IdSd.SD_PlaySound(soundnames.DEATHSCREAM1SND);
        }
    }
}
