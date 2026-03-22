// WL_AGENT.C -> WlAgent.cs
// Player actions, HUD drawing, pickup handling

using System;

namespace Wolf3D
{
    public static class WlAgent
    {
        // =========================================================================
        //  SpawnPlayer
        // =========================================================================

        public static void SpawnPlayer(int tilex, int tiley, int dir)
        {
            WL_Globals.player.obclass = classtype.playerobj;
            WL_Globals.player.active = activetype.ac_yes;
            WL_Globals.player.tilex = tilex;
            WL_Globals.player.tiley = tiley;
            WL_Globals.player.x = (tilex << WolfConstants.TILESHIFT) + WolfConstants.TILEGLOBAL / 2;
            WL_Globals.player.y = (tiley << WolfConstants.TILESHIFT) + WolfConstants.TILEGLOBAL / 2;
            WL_Globals.player.angle = dir;
            WL_Globals.player.flags = 0;
            WL_Globals.player.hitpoints = 100;
            WL_Globals.player.speed = WolfConstants.PLAYERSPEED;
        }

        // =========================================================================
        //  T_Player - main player think
        // =========================================================================

        public static void T_Player()
        {
            int angle = WL_Globals.player.angle;

            // Turning
            if (WL_Globals.controlx != 0)
            {
                angle -= WL_Globals.controlx;
                while (angle < 0) angle += WolfConstants.ANGLES;
                while (angle >= WolfConstants.ANGLES) angle -= WolfConstants.ANGLES;
                WL_Globals.player.angle = angle;
            }

            // Movement
            if (WL_Globals.controly != 0)
            {
                int speed = -WL_Globals.controly;
                if (WL_Globals.buttonstate[WolfConstants.bt_run])
                    speed *= 2;

                Thrust(angle, speed);
            }

            // Strafing
            if (WL_Globals.buttonstate[WolfConstants.bt_strafe])
            {
                if (WL_Globals.controlx > 0)
                    Thrust(angle - WolfConstants.ANGLEQUAD, WL_Globals.controlx);
                else if (WL_Globals.controlx < 0)
                    Thrust(angle + WolfConstants.ANGLEQUAD, -WL_Globals.controlx);
            }

            // Attack
            if (WL_Globals.buttonstate[WolfConstants.bt_attack])
            {
                // Handle weapon firing
            }

            // Use
            if (WL_Globals.buttonstate[WolfConstants.bt_use])
            {
                // Check for doors/switches
            }

            WL_Globals.controlx = 0;
            WL_Globals.controly = 0;
        }

        // =========================================================================
        //  Thrust
        // =========================================================================

        public static void Thrust(int angle, int speed)
        {
            while (angle < 0) angle += WolfConstants.ANGLES;
            while (angle >= WolfConstants.ANGLES) angle -= WolfConstants.ANGLES;

            int xmove = 0, ymove = 0;

            if (WL_Globals.costable != null && angle < WL_Globals.costable.Length)
                xmove = (int)(((long)speed * WL_Globals.costable[angle]) >> 16);

            if (angle < WL_Globals.sintable.Length)
                ymove = (int)(((long)speed * -WL_Globals.sintable[angle]) >> 16);

            int newx = WL_Globals.player.x + xmove;
            int newy = WL_Globals.player.y + ymove;

            // Clip to walls
            int tilex = newx >> WolfConstants.TILESHIFT;
            int tiley = newy >> WolfConstants.TILESHIFT;

            if (tilex >= 0 && tilex < WolfConstants.MAPSIZE &&
                tiley >= 0 && tiley < WolfConstants.MAPSIZE)
            {
                if (WL_Globals.tilemap[tilex, tiley] == 0)
                {
                    WL_Globals.player.x = newx;
                    WL_Globals.player.y = newy;
                }
            }

            WL_Globals.player.tilex = WL_Globals.player.x >> WolfConstants.TILESHIFT;
            WL_Globals.player.tiley = WL_Globals.player.y >> WolfConstants.TILESHIFT;
        }

        // =========================================================================
        //  HUD drawing
        // =========================================================================

        public static void DrawFace() { }
        public static void DrawHealth() { }
        public static void DrawLives() { }
        public static void DrawLevel() { }
        public static void DrawAmmo() { }
        public static void DrawKeys() { }
        public static void DrawWeapon() { }
        public static void DrawScore() { }

        // =========================================================================
        //  Damage / Healing
        // =========================================================================

        public static void TakeDamage(int points, objtype attacker)
        {
            WL_Globals.gamestate.health -= points;
            if (WL_Globals.gamestate.health <= 0)
            {
                WL_Globals.gamestate.health = 0;
                WL_Globals.playstate = exit_t.ex_died;
                WL_Globals.killerobj = attacker;
            }
            WlPlay.StartDamageFlash(points);
        }

        public static void HealSelf(int points)
        {
            WL_Globals.gamestate.health += points;
            if (WL_Globals.gamestate.health > 100)
                WL_Globals.gamestate.health = 100;
        }

        public static void GiveExtraMan()
        {
            WL_Globals.gamestate.lives++;
            IdSd.SD_PlaySound(soundnames.BONUS1UPSND);
        }

        public static void GivePoints(int points)
        {
            WL_Globals.gamestate.score += points;
            while (WL_Globals.gamestate.score >= WL_Globals.gamestate.nextextra)
            {
                WL_Globals.gamestate.nextextra += WolfConstants.EXTRAPOINTS;
                GiveExtraMan();
            }
        }

        public static void GiveWeapon(int weapon)
        {
            WL_Globals.gamestate.weapon = (weapontype)weapon;
            if (weapon > (int)WL_Globals.gamestate.bestweapon)
                WL_Globals.gamestate.bestweapon = (weapontype)weapon;
        }

        public static void GiveAmmo(int ammo)
        {
            WL_Globals.gamestate.ammo += ammo;
            if (WL_Globals.gamestate.ammo > 99)
                WL_Globals.gamestate.ammo = 99;
        }

        public static void GiveKey(int key)
        {
            WL_Globals.gamestate.keys |= (1 << key);
        }

        public static void GetBonus(statobj_t check)
        {
            // Handle pickup items based on itemnumber
        }
    }
}
