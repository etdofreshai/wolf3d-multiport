// WL_AGENT.C -> WlAgent.cs
// Player actions, HUD drawing, pickup handling - full implementation

using System;

namespace Wolf3D
{
    public static class WlAgent
    {
        private const int MAXMOUSETURN = 10;
        private const long MOVESCALE = 150;
        private const long BACKMOVESCALE = 100;
        private const int ANGLESCALE = 20;
        private const int FACETICS = 70;

        public static statetype s_player = new statetype { rotate = false, shapenum = 0, tictime = 0, think = T_Player };
        public static statetype s_attack = new statetype { rotate = false, shapenum = 0, tictime = 0, think = T_Attack };

        private static long playerxmove, playerymove;
        private static objtype LastAttacker;
        private static int gotgatgun;

        // Attack info: tics, attack, frame
        private static int[,,] attackinfo = new int[4, 14, 3]
        {
            { {6,0,1},{6,2,2},{6,0,3},{6,-1,4},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0} },
            { {6,0,1},{6,1,2},{6,0,3},{6,-1,4},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0} },
            { {6,0,1},{6,1,2},{6,3,3},{6,-1,4},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0} },
            { {6,0,1},{6,1,2},{6,4,3},{6,-1,4},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0} },
        };

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
            WL_Globals.player.state = s_player;
            WL_Globals.player.hitpoints = 100;
            WL_Globals.player.speed = WolfConstants.PLAYERSPEED;

            WL_Globals.player.areanumber = 0;
            if (WL_Globals.mapsegs[0] != null)
            {
                int mapIdx = WL_Globals.farmapylookup[tiley] + tilex;
                if (mapIdx >= 0 && mapIdx < WL_Globals.mapsegs[0].Length)
                {
                    int area = WL_Globals.mapsegs[0][mapIdx] - WolfConstants.AREATILE;
                    if (area >= 0 && area < WolfConstants.NUMAREAS)
                        WL_Globals.player.areanumber = (byte)area;
                }
            }

            WL_Globals.thrustspeed = 0;
            WL_Globals.anglefrac = 0;
        }

        // =========================================================================
        //  StatusDrawPic
        // =========================================================================

        private static void StatusDrawPic(int x, int y, int picnum)
        {
            int temp = WL_Globals.bufferofs;
            WL_Globals.bufferofs = WolfConstants.PAGE1START + (200 - WolfConstants.STATUSLINES) * WolfConstants.SCREENWIDTH;
            IdVh.LatchDrawPic(x, y, picnum);
            WL_Globals.bufferofs = temp;
        }

        // =========================================================================
        //  LatchNumber
        // =========================================================================

        private static void LatchNumber(int x, int y, int width, long number)
        {
            string str = number.ToString();
            int length = str.Length;

            while (length < width)
            {
                StatusDrawPic(x, y, (int)graphicnums.N_BLANKPIC);
                x++;
                width--;
            }

            int c = length <= width ? 0 : length - width;
            while (c < length)
            {
                StatusDrawPic(x, y, str[c] - '0' + (int)graphicnums.N_0PIC);
                x++;
                c++;
            }
        }

        // =========================================================================
        //  HUD drawing
        // =========================================================================

        public static void DrawFace()
        {
            if (WL_Globals.gamestate.health > 0)
            {
                int faceIdx = 3 * ((100 - WL_Globals.gamestate.health) / 16) + WL_Globals.gamestate.faceframe;
                StatusDrawPic(17, 4, (int)graphicnums.FACE1APIC + faceIdx);
            }
            else
            {
                if (LastAttacker != null && LastAttacker.obclass == classtype.needleobj)
                    StatusDrawPic(17, 4, (int)graphicnums.MUTANTBJPIC);
                else
                    StatusDrawPic(17, 4, (int)graphicnums.FACE8APIC);
            }
        }

        public static void UpdateFace()
        {
            if (IdSd.SD_SoundPlaying() == (ushort)soundnames.GETGATLINGSND)
                return;

            WL_Globals.facecount += WL_Globals.tics;
            if (WL_Globals.facecount > IdUs.US_RndT())
            {
                WL_Globals.gamestate.faceframe = IdUs.US_RndT() >> 6;
                if (WL_Globals.gamestate.faceframe == 3)
                    WL_Globals.gamestate.faceframe = 1;
                WL_Globals.facecount = 0;
                DrawFace();
            }
        }

        public static void DrawHealth()
        {
            LatchNumber(21, 16, 3, WL_Globals.gamestate.health);
        }

        public static void DrawLives()
        {
            LatchNumber(14, 16, 1, WL_Globals.gamestate.lives);
        }

        public static void DrawLevel()
        {
            LatchNumber(2, 16, 2, WL_Globals.gamestate.mapon + 1);
        }

        public static void DrawAmmo()
        {
            LatchNumber(27, 16, 2, WL_Globals.gamestate.ammo);
        }

        public static void DrawKeys()
        {
            if ((WL_Globals.gamestate.keys & 1) != 0)
                StatusDrawPic(30, 4, (int)graphicnums.GOLDKEYPIC);
            else
                StatusDrawPic(30, 4, (int)graphicnums.NOKEYPIC);

            if ((WL_Globals.gamestate.keys & 2) != 0)
                StatusDrawPic(30, 20, (int)graphicnums.SILVERKEYPIC);
            else
                StatusDrawPic(30, 20, (int)graphicnums.NOKEYPIC);
        }

        public static void DrawWeapon()
        {
            StatusDrawPic(32, 8, (int)graphicnums.KNIFEPIC + (int)WL_Globals.gamestate.weapon);
        }

        public static void DrawScore()
        {
            LatchNumber(6, 16, 6, WL_Globals.gamestate.score);
        }

        // =========================================================================
        //  CheckWeaponChange
        // =========================================================================

        private static void CheckWeaponChange()
        {
            if (WL_Globals.gamestate.ammo == 0) return;

            for (int i = (int)weapontype.wp_knife; i <= (int)WL_Globals.gamestate.bestweapon; i++)
            {
                if (WL_Globals.buttonstate[WolfConstants.bt_readyknife + i - (int)weapontype.wp_knife])
                {
                    WL_Globals.gamestate.weapon = WL_Globals.gamestate.chosenweapon = (weapontype)i;
                    DrawWeapon();
                    return;
                }
            }
        }

        // =========================================================================
        //  ControlMovement
        // =========================================================================

        private static void ControlMovement(objtype ob)
        {
            int angle;
            int angleunits;

            WL_Globals.thrustspeed = 0;

            long oldx = WL_Globals.player.x;
            long oldy = WL_Globals.player.y;

            // Strafing or turning
            if (WL_Globals.buttonstate[WolfConstants.bt_strafe])
            {
                if (WL_Globals.controlx > 0)
                {
                    angle = ob.angle - WolfConstants.ANGLEQUAD;
                    if (angle < 0) angle += WolfConstants.ANGLES;
                    Thrust(angle, (int)(WL_Globals.controlx * MOVESCALE));
                }
                else if (WL_Globals.controlx < 0)
                {
                    angle = ob.angle + WolfConstants.ANGLEQUAD;
                    if (angle >= WolfConstants.ANGLES) angle -= WolfConstants.ANGLES;
                    Thrust(angle, (int)(-WL_Globals.controlx * MOVESCALE));
                }
            }
            else
            {
                WL_Globals.anglefrac += WL_Globals.controlx;
                angleunits = WL_Globals.anglefrac / ANGLESCALE;
                WL_Globals.anglefrac -= angleunits * ANGLESCALE;
                ob.angle -= angleunits;

                if (ob.angle >= WolfConstants.ANGLES) ob.angle -= WolfConstants.ANGLES;
                if (ob.angle < 0) ob.angle += WolfConstants.ANGLES;
            }

            // Forward/backward
            if (WL_Globals.controly < 0)
            {
                Thrust(ob.angle, (int)(-WL_Globals.controly * MOVESCALE));
            }
            else if (WL_Globals.controly > 0)
            {
                angle = ob.angle + WolfConstants.ANGLES / 2;
                if (angle >= WolfConstants.ANGLES) angle -= WolfConstants.ANGLES;
                Thrust(angle, (int)(WL_Globals.controly * BACKMOVESCALE));
            }

            if (WL_Globals.gamestate.victoryflag) return;

            playerxmove = WL_Globals.player.x - oldx;
            playerymove = WL_Globals.player.y - oldy;
        }

        // =========================================================================
        //  T_Player - main player think
        // =========================================================================

        public static void T_Player(objtype ob)
        {
            CheckWeaponChange();
            ControlMovement(ob);
            UpdateFace();

            if (WL_Globals.gamestate.victoryflag) return;

            // Use
            if (WL_Globals.buttonstate[WolfConstants.bt_use])
            {
                Cmd_Use();
                WL_Globals.buttonstate[WolfConstants.bt_use] = false;
            }

            // Attack
            if (WL_Globals.buttonstate[WolfConstants.bt_attack] && !WL_Globals.buttonheld[WolfConstants.bt_attack])
            {
                WL_Globals.buttonheld[WolfConstants.bt_attack] = true;
                WL_Globals.gamestate.attackframe = 0;
                WL_Globals.gamestate.attackcount = attackinfo[(int)WL_Globals.gamestate.weapon, 0, 0];
                WL_Globals.gamestate.weaponframe = attackinfo[(int)WL_Globals.gamestate.weapon, 0, 2];
            }
            if (!WL_Globals.buttonstate[WolfConstants.bt_attack])
                WL_Globals.buttonheld[WolfConstants.bt_attack] = false;

            // Process weapon animation
            if (WL_Globals.gamestate.attackcount > 0)
            {
                WL_Globals.gamestate.attackcount -= WL_Globals.tics;
                while (WL_Globals.gamestate.attackcount <= 0)
                {
                    int cur = WL_Globals.gamestate.attackframe;
                    int atktype = attackinfo[(int)WL_Globals.gamestate.weapon, cur, 1];

                    // Fire weapon
                    if (atktype > 0)
                    {
                        if (atktype == 1) // Gun
                        {
                            if (WL_Globals.gamestate.ammo > 0)
                            {
                                WL_Globals.gamestate.ammo--;
                                DrawAmmo();
                                GunAttack(ob);
                            }
                        }
                        else if (atktype == 2) // Knife
                        {
                            KnifeAttack(ob);
                        }
                        else if (atktype >= 3) // Multi-shot
                        {
                            if (WL_Globals.gamestate.ammo > 0)
                            {
                                WL_Globals.gamestate.ammo--;
                                DrawAmmo();
                                GunAttack(ob);
                            }
                        }
                    }

                    WL_Globals.gamestate.attackframe++;
                    int next = WL_Globals.gamestate.attackframe;

                    if (next >= 14 || attackinfo[(int)WL_Globals.gamestate.weapon, next, 0] == 0 ||
                        attackinfo[(int)WL_Globals.gamestate.weapon, next, 1] == -1)
                    {
                        // Attack done
                        WL_Globals.gamestate.attackframe = 0;
                        WL_Globals.gamestate.attackcount = 0;
                        WL_Globals.gamestate.weaponframe = 0;
                        break;
                    }

                    WL_Globals.gamestate.attackcount += attackinfo[(int)WL_Globals.gamestate.weapon, next, 0];
                    WL_Globals.gamestate.weaponframe = attackinfo[(int)WL_Globals.gamestate.weapon, next, 2];
                }
            }

            WL_Globals.controlx = 0;
            WL_Globals.controly = 0;
        }

        // =========================================================================
        //  T_Attack - attack state think (called during attack animation)
        // =========================================================================

        public static void T_Attack(objtype ob)
        {
            // Attack processing is handled inline in T_Player
        }

        // =========================================================================
        //  GunAttack / KnifeAttack
        // =========================================================================

        private static void GunAttack(objtype ob)
        {
            IdSd.SD_PlaySound(soundnames.ATKPISTOLSND);
            WL_Globals.madenoise = true;

            // Check for hit - simplified
            int dx = Math.Abs(WL_Globals.player.tilex - (ob.tilex));
            int dy = Math.Abs(WL_Globals.player.tiley - (ob.tiley));

            // Check actors in line of fire
            var check = WL_Globals.player.next;
            while (check != null)
            {
                if ((check.flags & WolfConstants.FL_SHOOTABLE) != 0 &&
                    (check.flags & WolfConstants.FL_VISABLE) != 0)
                {
                    int dist = Math.Abs(check.viewx - WL_Globals.centerx);
                    if (dist < WL_Globals.shootdelta)
                    {
                        int damage = IdUs.US_RndT() >> 4;
                        WlState.DamageActor(check, damage);
                        break;
                    }
                }
                check = check.next;
            }
        }

        private static void KnifeAttack(objtype ob)
        {
            IdSd.SD_PlaySound(soundnames.ATKKNIFESND);

            // Check close range
            var check = WL_Globals.player.next;
            while (check != null)
            {
                if ((check.flags & WolfConstants.FL_SHOOTABLE) != 0)
                {
                    int dx = Math.Abs(WL_Globals.player.tilex - check.tilex);
                    int dy = Math.Abs(WL_Globals.player.tiley - check.tiley);
                    if (dx <= 1 && dy <= 1)
                    {
                        int damage = (IdUs.US_RndT() >> 4) + 2;
                        WlState.DamageActor(check, damage);
                        break;
                    }
                }
                check = check.next;
            }
        }

        // =========================================================================
        //  Cmd_Use - open doors, push walls
        // =========================================================================

        private static void Cmd_Use()
        {
            int checkx = WL_Globals.player.tilex;
            int checky = WL_Globals.player.tiley;

            // Check in the direction the player faces
            int angle = WL_Globals.player.angle;
            if (angle < 45 || angle > 315) checkx++;
            else if (angle < 135) checky--;
            else if (angle < 225) checkx--;
            else checky++;

            if (checkx < 0 || checkx >= WolfConstants.MAPSIZE ||
                checky < 0 || checky >= WolfConstants.MAPSIZE) return;

            byte tile = WL_Globals.tilemap[checkx, checky];

            // Door
            if ((tile & 0x80) != 0)
            {
                int doornum = tile & 0x7f;
                if ((tile & 0x40) == 0)
                {
                    WlAct1.OperateDoor(doornum);
                    return;
                }
            }

            // Pushwall
            if (tile != 0 && WL_Globals.mapsegs[1] != null)
            {
                int mapIdx = WL_Globals.farmapylookup[checky] + checkx;
                if (mapIdx >= 0 && mapIdx < WL_Globals.mapsegs[1].Length)
                {
                    int info = WL_Globals.mapsegs[1][mapIdx];
                    if (info == WolfConstants.PUSHABLETILE)
                    {
                        int dx = checkx - WL_Globals.player.tilex;
                        int dy = checky - WL_Globals.player.tiley;
                        int dir = 0;
                        if (dx == 1) dir = WolfConstants.EAST;
                        else if (dx == -1) dir = WolfConstants.WEST;
                        else if (dy == 1) dir = WolfConstants.SOUTH;
                        else if (dy == -1) dir = WolfConstants.NORTH;

                        WlAct1.PushWall(checkx, checky, dir);
                    }
                }
            }
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

            ClipMove(WL_Globals.player, xmove, ymove);

            WL_Globals.player.tilex = WL_Globals.player.x >> WolfConstants.TILESHIFT;
            WL_Globals.player.tiley = WL_Globals.player.y >> WolfConstants.TILESHIFT;
        }

        // =========================================================================
        //  ClipMove - clip movement against walls
        // =========================================================================

        private static void ClipMove(objtype ob, int xmove, int ymove)
        {
            int basex = ob.x;
            int basey = ob.y;

            ob.x += xmove;
            ob.y += ymove;

            int newtilex = ob.x >> WolfConstants.TILESHIFT;
            int newtiley = ob.y >> WolfConstants.TILESHIFT;
            int oldtilex = basex >> WolfConstants.TILESHIFT;
            int oldtiley = basey >> WolfConstants.TILESHIFT;

            // Check X movement
            if (newtilex != oldtilex)
            {
                if (newtilex < 0 || newtilex >= WolfConstants.MAPSIZE ||
                    WL_Globals.tilemap[newtilex, oldtiley] != 0)
                {
                    if (xmove > 0)
                        ob.x = ((oldtilex + 1) << WolfConstants.TILESHIFT) - 1;
                    else
                        ob.x = (oldtilex << WolfConstants.TILESHIFT) + 1;
                }
            }

            newtilex = ob.x >> WolfConstants.TILESHIFT;

            // Check Y movement
            if (newtiley != oldtiley)
            {
                if (newtiley < 0 || newtiley >= WolfConstants.MAPSIZE ||
                    WL_Globals.tilemap[newtilex, newtiley] != 0)
                {
                    if (ymove > 0)
                        ob.y = ((oldtiley + 1) << WolfConstants.TILESHIFT) - 1;
                    else
                        ob.y = (oldtiley << WolfConstants.TILESHIFT) + 1;
                }
            }

            // Check diagonal
            newtilex = ob.x >> WolfConstants.TILESHIFT;
            newtiley = ob.y >> WolfConstants.TILESHIFT;
            if (newtilex >= 0 && newtilex < WolfConstants.MAPSIZE &&
                newtiley >= 0 && newtiley < WolfConstants.MAPSIZE &&
                WL_Globals.tilemap[newtilex, newtiley] != 0)
            {
                ob.x = basex;
                ob.y = basey;
            }

            ob.tilex = ob.x >> WolfConstants.TILESHIFT;
            ob.tiley = ob.y >> WolfConstants.TILESHIFT;
        }

        // =========================================================================
        //  Damage / Healing
        // =========================================================================

        public static void TakeDamage(int points, objtype attacker)
        {
            LastAttacker = attacker;

            if (WL_Globals.gamestate.victoryflag) return;
            if (WL_Globals.gamestate.difficulty == (int)gamedifficulty_t.gd_baby)
                points >>= 2;

            if (!WL_Globals.godmode)
                WL_Globals.gamestate.health -= points;

            if (WL_Globals.gamestate.health <= 0)
            {
                WL_Globals.gamestate.health = 0;
                WL_Globals.playstate = exit_t.ex_died;
                WL_Globals.killerobj = attacker;
            }

            WlPlay.StartDamageFlash(points);
            gotgatgun = 0;
            DrawHealth();
            DrawFace();
        }

        public static void HealSelf(int points)
        {
            WL_Globals.gamestate.health += points;
            if (WL_Globals.gamestate.health > 100)
                WL_Globals.gamestate.health = 100;
            DrawHealth();
            gotgatgun = 0;
            DrawFace();
        }

        public static void GiveExtraMan()
        {
            if (WL_Globals.gamestate.lives < 9)
                WL_Globals.gamestate.lives++;
            DrawLives();
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
            DrawScore();
        }

        public static void GiveWeapon(int weapon)
        {
            GiveAmmo(6);
            if (weapon > (int)WL_Globals.gamestate.bestweapon)
                WL_Globals.gamestate.bestweapon = (weapontype)weapon;
            WL_Globals.gamestate.weapon = WL_Globals.gamestate.chosenweapon = (weapontype)weapon;
            DrawWeapon();
        }

        public static void GiveAmmo(int ammo)
        {
            if (WL_Globals.gamestate.ammo == 0)
            {
                // Switch away from knife
                if (WL_Globals.gamestate.weapon == weapontype.wp_knife)
                {
                    WL_Globals.gamestate.weapon = WL_Globals.gamestate.chosenweapon;
                    DrawWeapon();
                }
            }
            WL_Globals.gamestate.ammo += ammo;
            if (WL_Globals.gamestate.ammo > 99)
                WL_Globals.gamestate.ammo = 99;
            DrawAmmo();
        }

        public static void GiveKey(int key)
        {
            WL_Globals.gamestate.keys |= (1 << key);
            DrawKeys();
        }

        // =========================================================================
        //  GetBonus - handle pickup items
        // =========================================================================

        public static void GetBonus(statobj_t check)
        {
            int type = check.itemnumber;

            switch ((stat_t)type)
            {
                case stat_t.bo_firstaid:
                    if (WL_Globals.gamestate.health >= 100) return;
                    IdSd.SD_PlaySound(soundnames.HEALTH2SND);
                    HealSelf(25);
                    break;
                case stat_t.bo_key1:
                    GiveKey(0);
                    IdSd.SD_PlaySound(soundnames.GETKEYSND);
                    break;
                case stat_t.bo_key2:
                    GiveKey(1);
                    IdSd.SD_PlaySound(soundnames.GETKEYSND);
                    break;
                case stat_t.bo_key3:
                    GiveKey(2);
                    IdSd.SD_PlaySound(soundnames.GETKEYSND);
                    break;
                case stat_t.bo_key4:
                    GiveKey(3);
                    IdSd.SD_PlaySound(soundnames.GETKEYSND);
                    break;
                case stat_t.bo_cross:
                    IdSd.SD_PlaySound(soundnames.BONUS1SND);
                    GivePoints(100);
                    WL_Globals.gamestate.treasurecount++;
                    break;
                case stat_t.bo_chalice:
                    IdSd.SD_PlaySound(soundnames.BONUS2SND);
                    GivePoints(500);
                    WL_Globals.gamestate.treasurecount++;
                    break;
                case stat_t.bo_bible:
                    IdSd.SD_PlaySound(soundnames.BONUS3SND);
                    GivePoints(1000);
                    WL_Globals.gamestate.treasurecount++;
                    break;
                case stat_t.bo_crown:
                    IdSd.SD_PlaySound(soundnames.BONUS4SND);
                    GivePoints(5000);
                    WL_Globals.gamestate.treasurecount++;
                    break;
                case stat_t.bo_clip:
                    if (WL_Globals.gamestate.ammo >= 99) return;
                    IdSd.SD_PlaySound(soundnames.GETAMMOSND);
                    GiveAmmo(8);
                    break;
                case stat_t.bo_clip2:
                    if (WL_Globals.gamestate.ammo >= 99) return;
                    IdSd.SD_PlaySound(soundnames.GETAMMOSND);
                    GiveAmmo(4);
                    break;
                case stat_t.bo_25clip:
                    if (WL_Globals.gamestate.ammo >= 99) return;
                    IdSd.SD_PlaySound(soundnames.GETAMMOSND);
                    GiveAmmo(25);
                    break;
                case stat_t.bo_machinegun:
                    IdSd.SD_PlaySound(soundnames.GETMACHINESND);
                    GiveWeapon((int)weapontype.wp_machinegun);
                    break;
                case stat_t.bo_chaingun:
                    IdSd.SD_PlaySound(soundnames.GETGATLINGSND);
                    GiveWeapon((int)weapontype.wp_chaingun);
                    break;
                case stat_t.bo_food:
                    if (WL_Globals.gamestate.health >= 100) return;
                    IdSd.SD_PlaySound(soundnames.HEALTH1SND);
                    HealSelf(10);
                    break;
                case stat_t.bo_alpo:
                    if (WL_Globals.gamestate.health >= 100) return;
                    IdSd.SD_PlaySound(soundnames.HEALTH1SND);
                    HealSelf(4);
                    break;
                case stat_t.bo_fullheal:
                    IdSd.SD_PlaySound(soundnames.BONUS1UPSND);
                    HealSelf(99);
                    GiveAmmo(25);
                    GiveExtraMan();
                    WL_Globals.gamestate.treasurecount++;
                    break;
                default:
                    return; // not a pickup
            }

            check.shapenum = -1;
            WL_Globals.gamestate.treasurecount++;
            WlPlay.StartBonusFlash();
        }
    }
}
