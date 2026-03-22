// WL_STATE.C -> WlState.cs
// Actor state machine, movement, collision

using System;

namespace Wolf3D
{
    public static class WlState
    {
        public static readonly dirtype[] opposite = {
            dirtype.west, dirtype.southwest, dirtype.south, dirtype.southeast,
            dirtype.east, dirtype.northeast, dirtype.north, dirtype.northwest,
            dirtype.nodir
        };

        public static readonly dirtype[,] diagonal = new dirtype[9, 9];

        // =========================================================================
        //  InitHitRect
        // =========================================================================

        public static void InitHitRect(objtype ob, int radius)
        {
            // Set up the collision rectangle based on radius
        }

        // =========================================================================
        //  SpawnNewObj
        // =========================================================================

        public static void SpawnNewObj(int tilex, int tiley, statetype state)
        {
            WlPlay.GetNewActor();
            WL_Globals.new_.state = state;
            if (state != null)
                WL_Globals.new_.ticcount = state.tictime;
            WL_Globals.new_.tilex = tilex;
            WL_Globals.new_.tiley = tiley;
            WL_Globals.new_.x = (tilex << WolfConstants.TILESHIFT) + WolfConstants.TILEGLOBAL / 2;
            WL_Globals.new_.y = (tiley << WolfConstants.TILESHIFT) + WolfConstants.TILEGLOBAL / 2;
            WL_Globals.new_.dir = dirtype.nodir;
            WL_Globals.new_.active = activetype.ac_no;
        }

        // =========================================================================
        //  NewState
        // =========================================================================

        public static void NewState(objtype ob, statetype state)
        {
            ob.state = state;
            if (state != null)
                ob.ticcount = state.tictime;
        }

        // =========================================================================
        //  Movement
        // =========================================================================

        public static bool TryWalk(objtype ob)
        {
            // Check if the actor can walk in its current direction
            int dx = 0, dy = 0;

            switch (ob.dir)
            {
                case dirtype.north: dy = -1; break;
                case dirtype.east: dx = 1; break;
                case dirtype.south: dy = 1; break;
                case dirtype.west: dx = -1; break;
                case dirtype.northeast: dx = 1; dy = -1; break;
                case dirtype.northwest: dx = -1; dy = -1; break;
                case dirtype.southeast: dx = 1; dy = 1; break;
                case dirtype.southwest: dx = -1; dy = 1; break;
            }

            int tilex = ob.tilex + dx;
            int tiley = ob.tiley + dy;

            if (tilex < 0 || tilex >= WolfConstants.MAPSIZE || tiley < 0 || tiley >= WolfConstants.MAPSIZE)
                return false;

            if (WL_Globals.tilemap[tilex, tiley] != 0)
                return false;

            return true;
        }

        public static void SelectChaseDir(objtype ob)
        {
            int deltax = WL_Globals.player.tilex - ob.tilex;
            int deltay = WL_Globals.player.tiley - ob.tiley;

            if (deltax > 0) ob.dir = dirtype.east;
            else if (deltax < 0) ob.dir = dirtype.west;
            else if (deltay > 0) ob.dir = dirtype.south;
            else if (deltay < 0) ob.dir = dirtype.north;
        }

        public static void SelectDodgeDir(objtype ob)
        {
            SelectChaseDir(ob);
        }

        public static void SelectRunDir(objtype ob)
        {
            // Run away from player
            int deltax = WL_Globals.player.tilex - ob.tilex;
            int deltay = WL_Globals.player.tiley - ob.tiley;

            if (deltax > 0) ob.dir = dirtype.west;
            else if (deltax < 0) ob.dir = dirtype.east;
            else if (deltay > 0) ob.dir = dirtype.north;
            else if (deltay < 0) ob.dir = dirtype.south;
        }

        public static void MoveObj(objtype ob, int move)
        {
            switch (ob.dir)
            {
                case dirtype.north: ob.y -= move; break;
                case dirtype.east: ob.x += move; break;
                case dirtype.south: ob.y += move; break;
                case dirtype.west: ob.x -= move; break;
                case dirtype.northeast: ob.x += move; ob.y -= move; break;
                case dirtype.northwest: ob.x -= move; ob.y -= move; break;
                case dirtype.southeast: ob.x += move; ob.y += move; break;
                case dirtype.southwest: ob.x -= move; ob.y += move; break;
            }

            ob.tilex = ob.x >> WolfConstants.TILESHIFT;
            ob.tiley = ob.y >> WolfConstants.TILESHIFT;
        }

        // =========================================================================
        //  Sight / combat
        // =========================================================================

        public static bool SightPlayer(objtype ob)
        {
            // Can the actor see the player?
            return CheckLine(ob);
        }

        public static bool CheckLine(objtype ob)
        {
            // Check line of sight from ob to player
            // Simplified - would do actual tile-based LOS check
            int dx = Math.Abs(WL_Globals.player.tilex - ob.tilex);
            int dy = Math.Abs(WL_Globals.player.tiley - ob.tiley);
            return (dx + dy < 20);
        }

        public static bool CheckSight(objtype ob)
        {
            return CheckLine(ob);
        }

        // =========================================================================
        //  Damage
        // =========================================================================

        public static void KillActor(objtype ob)
        {
            ob.flags &= unchecked((byte)~WolfConstants.FL_SHOOTABLE);
            ob.flags &= unchecked((byte)~WolfConstants.FL_ATTACKMODE);
            ob.active = activetype.ac_no;
        }

        public static void DamageActor(objtype ob, int damage)
        {
            ob.hitpoints -= damage;
            if (ob.hitpoints <= 0)
            {
                KillActor(ob);
                WL_Globals.gamestate.killcount++;
            }
        }
    }
}
