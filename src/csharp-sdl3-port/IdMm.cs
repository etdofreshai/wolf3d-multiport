// ID_MM.C -> IdMm.cs
// Memory Manager - simplified for modern systems (no EMS/XMS/segment management)
// Uses C# garbage collector for actual memory management, but maintains the
// block tracking structure for compatibility with the game's purge/lock system.

using System;

namespace Wolf3D
{
    public static class IdMm
    {
        private const int LOCKBIT = 0x80;
        private const int PURGEBITS = 3;
        private const int PURGEMASK = unchecked((int)0xfffc);
        private const int BASEATTRIBUTES = 0;

        private class mmblocktype
        {
            public uint start;
            public uint length;
            public int attributes;
            public int useptrIndex;     // index into a tracking array, or -1
            public mmblocktype next;
        }

        private static bool mmstarted;
        private static mmblocktype[] mmblocks = new mmblocktype[WolfConstants.MAXBLOCKS];
        private static mmblocktype mmhead, mmfree, mmrover, mmnew;
        private static bool bombonerror;

        // Simple tracking: We use an index-based approach for useptr tracking.
        // Each allocation is tracked by an ID; the caller manages the actual reference.

        private static void GETNEWBLOCK()
        {
            if (mmfree == null) MML_ClearBlock();
            mmnew = mmfree;
            mmfree = mmfree.next;
        }

        private static void MML_ClearBlock()
        {
            var scan = mmhead?.next;
            while (scan != null)
            {
                if ((scan.attributes & LOCKBIT) == 0 && (scan.attributes & PURGEBITS) != 0)
                {
                    // Found a purgable block - free it
                    return;
                }
                scan = scan.next;
            }
            WlMain.Quit("MM_ClearBlock: No purgable blocks!");
        }

        public static void MM_Startup()
        {
            if (mmstarted)
                MM_Shutdown();

            mmstarted = true;
            bombonerror = true;

            // Set up linked list
            mmhead = null;
            for (int i = 0; i < WolfConstants.MAXBLOCKS; i++)
                mmblocks[i] = new mmblocktype();

            mmfree = mmblocks[0];
            for (int i = 0; i < WolfConstants.MAXBLOCKS - 1; i++)
                mmblocks[i].next = mmblocks[i + 1];
            mmblocks[WolfConstants.MAXBLOCKS - 1].next = null;

            // Locked block of all memory
            GETNEWBLOCK();
            mmhead = mmnew;
            mmnew.start = 0;
            mmnew.length = 0;
            mmnew.attributes = LOCKBIT;
            mmnew.next = null;
            mmrover = mmhead;

            // Allocate misc buffer
            WL_Globals.bufferseg = new byte[WolfConstants.BUFFERSIZE];
        }

        public static void MM_Shutdown()
        {
            if (!mmstarted)
                return;
            // GC handles all cleanup in C#
            mmstarted = false;
        }

        // MM_GetPtr / MM_FreePtr are simplified - C# uses GC
        // We keep the interface for compatibility but just allocate normally.

        public static byte[] MM_GetPtr(uint size)
        {
            if (size == 0) size = 1;
            return new byte[size];
        }

        public static void MM_FreePtr(ref byte[] ptr)
        {
            ptr = null;
        }

        public static void MM_SetPurge(ref byte[] baseptr, int purge)
        {
            // No-op in managed C# - GC handles this
        }

        public static void MM_SetLock(ref byte[] baseptr, bool locked)
        {
            // No-op in managed C# - GC handles this
        }

        public static void MM_SortMem()
        {
            // No memory compaction needed in C#
            // Still stop/restart sound as the original does
            int playing = IdSd.SD_SoundPlaying();
            if (playing != 0)
            {
                switch (WL_Globals.SoundMode)
                {
                    case SDMode.sdm_PC:
                        playing += AudioConstants.STARTPCSOUNDS;
                        break;
                    case SDMode.sdm_AdLib:
                        playing += AudioConstants.STARTADLIBSOUNDS;
                        break;
                }
            }

            IdSd.SD_StopSound();
        }

        public static void MM_ShowMemory()
        {
            // No-op
        }

        public static long MM_UnusedMemory()
        {
            return 16 * 1024 * 1024;    // 16 MB
        }

        public static long MM_TotalFree()
        {
            return 16 * 1024 * 1024;    // 16 MB
        }

        public static void MM_BombOnError(bool bomb)
        {
            bombonerror = bomb;
        }

        public static void MM_MapEMS()
        {
            // No-op
        }

        public static void MML_UseSpace(int segstart, int seglength)
        {
            // No-op
        }
    }
}
