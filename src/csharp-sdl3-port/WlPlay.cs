// WL_PLAY.C -> WlPlay.cs
// Main gameplay loop - polling controls, moving objects, drawing

using System;

namespace Wolf3D
{
    public static class WlPlay
    {
        // Palette shift tables
        private static int damagecount;
        private static int bonuscount;
        private static int palession;

        // Movement constants
        private const int BASEMOVE = 35;
        private const int RUNMOVE = 70;
        private const int BASETURN = 35;
        private const int RUNTURN = 70;

        public static ControlInfo c = new ControlInfo();

        // =========================================================================
        //  InitActorList
        // =========================================================================

        public static void InitActorList()
        {
            for (int i = 0; i < WolfConstants.MAXACTORS; i++)
            {
                WL_Globals.objlist[i] = new objtype();
                WL_Globals.objlist[i].active = activetype.ac_no;
            }

            WL_Globals.player = WL_Globals.objlist[0];
            WL_Globals.player.active = activetype.ac_yes;
            WL_Globals.lastobj = WL_Globals.player;

            WL_Globals.objfreelist = WL_Globals.objlist[1];
            for (int i = 1; i < WolfConstants.MAXACTORS - 1; i++)
                WL_Globals.objlist[i].next = WL_Globals.objlist[i + 1];
        }

        // =========================================================================
        //  GetNewActor
        // =========================================================================

        public static void GetNewActor()
        {
            if (WL_Globals.objfreelist == null)
                WlMain.Quit("GetNewActor: No free actors!");

            WL_Globals.new_ = WL_Globals.objfreelist;
            WL_Globals.objfreelist = WL_Globals.objfreelist.next;

            // Clear the object
            WL_Globals.new_.active = activetype.ac_no;
            WL_Globals.new_.ticcount = 0;
            WL_Globals.new_.obclass = classtype.nothing;
            WL_Globals.new_.state = null;
            WL_Globals.new_.flags = 0;
            WL_Globals.new_.distance = 0;
            WL_Globals.new_.dir = dirtype.nodir;
            WL_Globals.new_.x = 0;
            WL_Globals.new_.y = 0;
            WL_Globals.new_.tilex = 0;
            WL_Globals.new_.tiley = 0;
            WL_Globals.new_.viewx = 0;
            WL_Globals.new_.viewheight = 0;
            WL_Globals.new_.angle = 0;
            WL_Globals.new_.hitpoints = 0;
            WL_Globals.new_.speed = 0;
            WL_Globals.new_.temp1 = 0;
            WL_Globals.new_.temp2 = 0;
            WL_Globals.new_.temp3 = 0;

            // Add to active list
            WL_Globals.new_.prev = WL_Globals.lastobj;
            WL_Globals.lastobj.next = WL_Globals.new_;
            WL_Globals.new_.next = null;
            WL_Globals.lastobj = WL_Globals.new_;
        }

        // =========================================================================
        //  RemoveObj
        // =========================================================================

        public static void RemoveObj(objtype gone)
        {
            if (gone == WL_Globals.player)
                WlMain.Quit("RemoveObj: Tried to remove player!");

            gone.state = null;

            if (gone.prev != null)
                gone.prev.next = gone.next;
            if (gone.next != null)
                gone.next.prev = gone.prev;
            if (gone == WL_Globals.lastobj)
                WL_Globals.lastobj = gone.prev;

            // Put back on free list
            gone.next = WL_Globals.objfreelist;
            WL_Globals.objfreelist = gone;
        }

        // =========================================================================
        //  PollControls - get user or demo input
        // =========================================================================

        public static void PollControls()
        {
            int max, min;

            // Handle demo playback/recording timing
            if (WL_Globals.demoplayback)
            {
                while (WL_Globals.TimeCount < WL_Globals.lasttimecount + WolfConstants.DEMOTICS)
                {
                    IdIn.IN_ProcessEvents();
                    SDL.SDL_Delay(1);
                }
                WL_Globals.TimeCount = WL_Globals.lasttimecount + WolfConstants.DEMOTICS;
                WL_Globals.lasttimecount += WolfConstants.DEMOTICS;
                WL_Globals.tics = WolfConstants.DEMOTICS;
            }
            else if (WL_Globals.demorecord)
            {
                while (WL_Globals.TimeCount < WL_Globals.lasttimecount + WolfConstants.DEMOTICS)
                {
                    IdIn.IN_ProcessEvents();
                    SDL.SDL_Delay(1);
                }
                WL_Globals.TimeCount = WL_Globals.lasttimecount + WolfConstants.DEMOTICS;
                WL_Globals.lasttimecount += WolfConstants.DEMOTICS;
                WL_Globals.tics = WolfConstants.DEMOTICS;
            }
            else
                WlDraw.CalcTics();

            WL_Globals.controlx = 0;
            WL_Globals.controly = 0;

            // Copy buttonstate to buttonheld, then clear
            Array.Copy(WL_Globals.buttonstate, WL_Globals.buttonheld, WL_Globals.buttonstate.Length);
            for (int i = 0; i < WL_Globals.buttonstate.Length; i++)
                WL_Globals.buttonstate[i] = false;

            // Demo playback - read commands from buffer
            if (WL_Globals.demoplayback && WL_Globals.demobuffer != null)
            {
                int ofs = WL_Globals.demoptr_offset;
                if (ofs + 2 < WL_Globals.demobuffer.Length)
                {
                    byte buttonbits = WL_Globals.demobuffer[ofs++];
                    for (int i = 0; i < WolfConstants.NUMBUTTONS; i++)
                    {
                        WL_Globals.buttonstate[i] = (buttonbits & 1) != 0;
                        buttonbits >>= 1;
                    }
                    WL_Globals.controlx = (sbyte)WL_Globals.demobuffer[ofs++];
                    WL_Globals.controly = (sbyte)WL_Globals.demobuffer[ofs++];
                    WL_Globals.demoptr_offset = ofs;

                    if (ofs >= WL_Globals.demobuffer.Length)
                        WL_Globals.playstate = exit_t.ex_completed;

                    WL_Globals.controlx *= WL_Globals.tics;
                    WL_Globals.controly *= WL_Globals.tics;
                }
                else
                    WL_Globals.playstate = exit_t.ex_completed;

                return;
            }

            // Poll keyboard buttons
            for (int i = 0; i < WolfConstants.NUMBUTTONS; i++)
            {
                if (WL_Globals.buttonscan[i] < WL_Globals.Keyboard.Length &&
                    WL_Globals.Keyboard[WL_Globals.buttonscan[i]])
                    WL_Globals.buttonstate[i] = true;
            }

            // Poll mouse buttons
            if (WL_Globals.mouseenabled)
            {
                int buttons = IdIn.IN_MouseButtons();
                if ((buttons & 1) != 0 && WL_Globals.buttonmouse[0] < WolfConstants.NUMBUTTONS)
                    WL_Globals.buttonstate[WL_Globals.buttonmouse[0]] = true;
                if ((buttons & 2) != 0 && WL_Globals.buttonmouse[1] < WolfConstants.NUMBUTTONS)
                    WL_Globals.buttonstate[WL_Globals.buttonmouse[1]] = true;
                if ((buttons & 4) != 0 && WL_Globals.buttonmouse[2] < WolfConstants.NUMBUTTONS)
                    WL_Globals.buttonstate[WL_Globals.buttonmouse[2]] = true;
            }

            // Poll keyboard movement
            if (WL_Globals.buttonstate[WolfConstants.bt_run])
            {
                if (WL_Globals.Keyboard[WL_Globals.dirscan[0]]) // north
                    WL_Globals.controly -= RUNMOVE * WL_Globals.tics;
                if (WL_Globals.Keyboard[WL_Globals.dirscan[2]]) // south
                    WL_Globals.controly += RUNMOVE * WL_Globals.tics;
                if (WL_Globals.Keyboard[WL_Globals.dirscan[3]]) // west
                    WL_Globals.controlx -= RUNMOVE * WL_Globals.tics;
                if (WL_Globals.Keyboard[WL_Globals.dirscan[1]]) // east
                    WL_Globals.controlx += RUNMOVE * WL_Globals.tics;
            }
            else
            {
                if (WL_Globals.Keyboard[WL_Globals.dirscan[0]])
                    WL_Globals.controly -= BASEMOVE * WL_Globals.tics;
                if (WL_Globals.Keyboard[WL_Globals.dirscan[2]])
                    WL_Globals.controly += BASEMOVE * WL_Globals.tics;
                if (WL_Globals.Keyboard[WL_Globals.dirscan[3]])
                    WL_Globals.controlx -= BASEMOVE * WL_Globals.tics;
                if (WL_Globals.Keyboard[WL_Globals.dirscan[1]])
                    WL_Globals.controlx += BASEMOVE * WL_Globals.tics;
            }

            // Poll mouse movement
            if (WL_Globals.mouseenabled)
            {
                int mx, my;
                IdIn.IN_GetMouseDelta(out mx, out my);
                WL_Globals.controlx += mx * 10 / (13 - WL_Globals.mouseadjustment);
                WL_Globals.controly += my * 20 / (13 - WL_Globals.mouseadjustment);
            }

            // Bound movement
            max = 100 * WL_Globals.tics;
            min = -max;
            if (WL_Globals.controlx > max) WL_Globals.controlx = max;
            else if (WL_Globals.controlx < min) WL_Globals.controlx = min;
            if (WL_Globals.controly > max) WL_Globals.controly = max;
            else if (WL_Globals.controly < min) WL_Globals.controly = min;

            // Demo recording - save commands
            if (WL_Globals.demorecord && WL_Globals.demobuffer != null)
            {
                int cx = WL_Globals.controlx / WL_Globals.tics;
                int cy = WL_Globals.controly / WL_Globals.tics;

                byte buttonbits = 0;
                for (int i = WolfConstants.NUMBUTTONS - 1; i >= 0; i--)
                {
                    buttonbits <<= 1;
                    if (WL_Globals.buttonstate[i]) buttonbits |= 1;
                }

                int ofs = WL_Globals.demoptr_offset;
                if (ofs + 2 < WL_Globals.demobuffer.Length)
                {
                    WL_Globals.demobuffer[ofs++] = buttonbits;
                    WL_Globals.demobuffer[ofs++] = (byte)cx;
                    WL_Globals.demobuffer[ofs++] = (byte)cy;
                    WL_Globals.demoptr_offset = ofs;
                }

                WL_Globals.controlx = cx * WL_Globals.tics;
                WL_Globals.controly = cy * WL_Globals.tics;
            }
        }

        // =========================================================================
        //  CheckKeys - F-key handlers and cheat code detection
        // =========================================================================

        public static void CheckKeys()
        {
            if (WL_Globals.screenfaded || WL_Globals.demoplayback)
                return;

            byte scan = WL_Globals.LastScan;

            // MLI cheat code
            if (WL_Globals.Keyboard[ScanCodes.sc_M] &&
                WL_Globals.Keyboard[ScanCodes.sc_L] &&
                WL_Globals.Keyboard[ScanCodes.sc_I])
            {
                WL_Globals.gamestate.health = 100;
                WL_Globals.gamestate.ammo = 99;
                WL_Globals.gamestate.keys = 3;
                WL_Globals.gamestate.score = 0;
                WL_Globals.gamestate.TimeCount += 42000;
                WlAgent.GiveWeapon((int)weapontype.wp_chaingun);
                WlAgent.DrawWeapon();
                WlAgent.DrawHealth();
                WlAgent.DrawKeys();
                WlAgent.DrawAmmo();
                WlAgent.DrawScore();

                WlInter.ClearSplitVWB();
                WlMenu.Message(
                    "You just got all\nthe stuff! But\nyou're a cheater!");
                IdIn.IN_ClearKeysDown();
                IdIn.IN_Ack();
                WlGame.DrawAllPlayBorder();
            }

            // Debug key activation: Backspace + LShift + Alt
            if (WL_Globals.Keyboard[ScanCodes.sc_BackSpace] &&
                WL_Globals.Keyboard[ScanCodes.sc_LShift] &&
                WL_Globals.Keyboard[ScanCodes.sc_Alt])
            {
                WlInter.ClearSplitVWB();
                WlMenu.Message("Debugging keys are\nnow available!");
                IdIn.IN_ClearKeysDown();
                IdIn.IN_Ack();
                WlGame.DrawAllPlayBorderSides();
                WL_Globals.DebugOk = 1;
            }

            // Pause key
            if (WL_Globals.Paused)
            {
                IdVh.LatchDrawPic(20 - 4, 80 - 16, (int)graphicnums.PAUSEDPIC);
                IdSd.SD_MusicOff();
                IdIn.IN_Ack();
                IdIn.IN_ClearKeysDown();
                IdSd.SD_MusicOn();
                WL_Globals.Paused = false;
                if (WL_Globals.mouseenabled)
                    IdIn.IN_GetMouseDelta(out _, out _);
                return;
            }

            // F7/F8/F9/F10 pop up quit dialog
            if (scan == ScanCodes.sc_F10 || scan == ScanCodes.sc_F9 ||
                scan == ScanCodes.sc_F7 || scan == ScanCodes.sc_F8)
            {
                WlInter.ClearSplitVWB();
                WlMenu.US_ControlPanel(scan);
                WlGame.DrawAllPlayBorderSides();
                if (scan == ScanCodes.sc_F9)
                    StartMusic();
                IdIn.IN_ClearKeysDown();
                return;
            }

            // F1-F6 and ESC open control panel with fade
            if ((scan >= ScanCodes.sc_F1 && scan <= ScanCodes.sc_F6) || scan == ScanCodes.sc_Escape)
            {
                StopMusic();
                IdVl.VL_FadeOut();
                WlMenu.US_ControlPanel(scan);
                WL_Globals.fontcolor = (byte)0;
                IdIn.IN_ClearKeysDown();
                WlGame.DrawPlayScreen();
                if (!WL_Globals.startgame && !WL_Globals.loadedgame)
                {
                    IdVl.VL_FadeIn();
                    StartMusic();
                }
                if (WL_Globals.loadedgame)
                    WL_Globals.playstate = exit_t.ex_abort;
                WL_Globals.lasttimecount = WL_Globals.TimeCount;
                if (WL_Globals.mouseenabled)
                    IdIn.IN_GetMouseDelta(out _, out _);
                return;
            }

            // TAB + key = debug keys
            if (WL_Globals.Keyboard[ScanCodes.sc_Tab] && WL_Globals.DebugOk != 0)
            {
                IdCa.CA_CacheGrChunk(GfxConstants.STARTFONT);
                WL_Globals.fontnumber = 0;
                WL_Globals.fontcolor = (byte)0;
                WlDebug.DebugKeys();
                if (WL_Globals.mouseenabled)
                    IdIn.IN_GetMouseDelta(out _, out _);
                WL_Globals.lasttimecount = WL_Globals.TimeCount;
                return;
            }
        }

        // =========================================================================
        //  PlayLoop - main gameplay loop
        // =========================================================================

        public static void PlayLoop()
        {
            WL_Globals.playstate = exit_t.ex_stillplaying;
            WL_Globals.frameon = 0;
            WL_Globals.lasttimecount = WL_Globals.TimeCount;

            WlDraw.BuildTables();

            do
            {
                IdIn.IN_ProcessEvents();

                // Update time
                IdSd.SD_TimeCountUpdate();

                // Poll keyboard/mouse
                PollControls();

                // Move player
                WlAgent.T_Player(WL_Globals.player);

                // Move objects
                DoActors();

                // Move doors
                WlAct1.MoveDoors();

                // Push walls
                WlAct1.MovePWalls();

                // Update palette effects
                UpdatePaletteShifts();

                // Draw the 3D view
                WlDraw.ThreeDRefresh();

                // Check for F-keys, debug, pause, cheat codes
                CheckKeys();

                // Check for ESC (handled in CheckKeys now)
                if (WL_Globals.LastScan == ScanCodes.sc_Escape)
                {
                    WL_Globals.LastScan = ScanCodes.sc_None;
                    // CheckKeys handles ESC, but if we get here, go to menu
                    if (WL_Globals.playstate == exit_t.ex_stillplaying)
                    {
                        WlMenu.US_ControlPanel(ScanCodes.sc_Escape);
                        if (WL_Globals.playstate != exit_t.ex_stillplaying)
                            return;
                    }
                }

                WL_Globals.frameon++;

            } while (WL_Globals.playstate == exit_t.ex_stillplaying);
        }

        // =========================================================================
        //  DoActors - process all active actors
        // =========================================================================

        private static void DoActors()
        {
            var obj = WL_Globals.player.next;
            while (obj != null)
            {
                var next = obj.next;

                if (obj.active != activetype.ac_no)
                {
                    if (obj.ticcount > 0)
                    {
                        obj.ticcount -= WL_Globals.tics;
                        while (obj.ticcount <= 0)
                        {
                            if (obj.state != null && obj.state.action != null)
                                obj.state.action(obj);

                            if (obj.state != null && obj.state.next != null)
                            {
                                obj.state = obj.state.next;
                                if (obj.state.tictime != 0)
                                    obj.ticcount += obj.state.tictime;
                                else
                                    break;
                            }
                            else
                                break;
                        }
                    }

                    if (obj.state != null && obj.state.think != null)
                        obj.state.think(obj);
                }

                obj = next;
            }
        }

        // =========================================================================
        //  Palette shift effects (damage flash, bonus flash)
        // =========================================================================

        public static void InitRedShifts()
        {
            damagecount = 0;
            bonuscount = 0;
            palession = 0;
        }

        public static void StartDamageFlash(int damage)
        {
            damagecount += damage;
            if (damagecount > 100) damagecount = 100;
        }

        public static void StartBonusFlash()
        {
            bonuscount = 15;
        }

        public static void UpdatePaletteShifts()
        {
            // Decay damage flash
            if (damagecount > 0)
            {
                damagecount -= 1;
                if (damagecount < 0) damagecount = 0;
                // Apply red tint to palette (simplified)
                int red = damagecount * 2;
                if (red > 63) red = 63;
                // In a full implementation, this would shift the VGA palette
            }

            // Decay bonus flash
            if (bonuscount > 0)
            {
                bonuscount -= 1;
                if (bonuscount < 0) bonuscount = 0;
                // Apply white tint to palette (simplified)
            }
        }

        public static void FinishPaletteShifts()
        {
            damagecount = 0;
            bonuscount = 0;
            // Restore normal palette
        }

        // =========================================================================
        //  Centering window helper
        // =========================================================================

        public static void CenterWindow(int w, int h)
        {
            WlDraw.FixOfs();
            IdUs.US_DrawWindow(((320 / 8) - w) / 2, ((160 / 8) - h) / 2, w, h);
        }

        // =========================================================================
        //  Music control
        // =========================================================================

        public static void StopMusic()
        {
            IdSd.SD_MusicOff();
        }

        public static void StartMusic()
        {
            IdSd.SD_MusicOn();
        }
    }
}
