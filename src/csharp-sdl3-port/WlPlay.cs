// WL_PLAY.C -> WlPlay.cs
// Main gameplay loop - polling controls, moving objects, drawing

using System;

namespace Wolf3D
{
    public static class WlPlay
    {
        private static byte[] redshifts;
        private static byte[] whiteshifts;

        private static int damagecount;
        private static int bonuscount;
        private static int palession;

        public static ControlInfo c = new ControlInfo();

        // =========================================================================
        //  InitActorList
        // =========================================================================

        public static void InitActorList()
        {
            // Initialize actor linked list
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
        //  PollControls
        // =========================================================================

        public static void PollControls()
        {
            IdIn.IN_ReadControl(0, c);

            // Process keyboard-bound buttons
            for (int i = 0; i < WolfConstants.NUMBUTTONS; i++)
            {
                WL_Globals.buttonstate[i] = WL_Globals.Keyboard[WL_Globals.buttonscan[i]];
            }

            // Get movement from mouse
            if (WL_Globals.mouseenabled)
            {
                int mx, my;
                IdIn.IN_GetMouseDelta(out mx, out my);
                WL_Globals.controlx += mx * (WL_Globals.mouseadjustment + 3) / 10;
                WL_Globals.controly += my;
            }

            // Keyboard movement
            if (c.dir != Direction.dir_None)
            {
                if (c.x < 0) WL_Globals.controlx -= WolfConstants.PLAYERSPEED * WL_Globals.tics;
                else if (c.x > 0) WL_Globals.controlx += WolfConstants.PLAYERSPEED * WL_Globals.tics;
                if (c.y < 0) WL_Globals.controly -= WolfConstants.PLAYERSPEED * WL_Globals.tics;
                else if (c.y > 0) WL_Globals.controly += WolfConstants.PLAYERSPEED * WL_Globals.tics;
            }
        }

        // =========================================================================
        //  PlayLoop
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

                // Calculate tics elapsed
                WlDraw.CalcTics();

                // Move player
                WlAgent.T_Player(WL_Globals.player);

                // Move objects
                DoActors();

                // Move doors
                WlAct1.MoveDoors();

                // Push walls
                WlAct1.MovePWalls();

                // Draw the 3D view
                WlDraw.ThreeDRefresh();

                // Check for pause/debug
                if (WL_Globals.Paused)
                {
                    // Handle pause
                    WL_Globals.Paused = false;
                }

                // Check for ESC
                if (WL_Globals.LastScan == ScanCodes.sc_Escape)
                {
                    WL_Globals.LastScan = ScanCodes.sc_None;
                    WlMenu.US_ControlPanel(ScanCodes.sc_Escape);
                    if (WL_Globals.playstate != exit_t.ex_stillplaying)
                        return;
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
                            // Advance to next state
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
        //  Palette effects
        // =========================================================================

        public static void InitRedShifts()
        {
            // Initialize damage flash palette shift tables
        }

        public static void FinishPaletteShifts()
        {
            // Restore normal palette
        }

        public static void StartDamageFlash(int damage)
        {
            damagecount += damage;
        }

        public static void StartBonusFlash()
        {
            bonuscount = 15;
        }

        // =========================================================================
        //  Centering window helper
        // =========================================================================

        public static void CenterWindow(int w, int h)
        {
            IdUs.US_CenterWindow(w, h);
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
