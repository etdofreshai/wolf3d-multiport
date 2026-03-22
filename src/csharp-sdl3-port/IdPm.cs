// ID_PM.C -> IdPm.cs
// Page Manager - loads all VSWAP pages into memory at startup

using System;
using System.IO;

namespace Wolf3D
{
    public static class IdPm
    {
        private static bool PMStarted;
        private static int PMFrameCount;
        private static bool PMPanicMode;
        private static bool PMThrashing;

        public static void PM_Startup()
        {
            if (PMStarted) return;

            PML_OpenPageFile();
            PMStarted = true;
        }

        public static void PM_Shutdown()
        {
            if (!PMStarted) return;
            PMStarted = false;
            WL_Globals.PMPages = null;
            WL_Globals.PMPageData = null;
        }

        private static void PML_OpenPageFile()
        {
            string filename = WL_Globals.PageFileName + WL_Globals.extension;
            if (!File.Exists(filename))
            {
                // Try without extension
                filename = WL_Globals.PageFileName;
                if (!File.Exists(filename))
                {
                    // Try various paths
                    string[] paths = { ".", "assets", "../assets", "../../assets" };
                    bool found = false;
                    foreach (string path in paths)
                    {
                        string test = Path.Combine(path, WL_Globals.PageFileName + WL_Globals.extension);
                        if (File.Exists(test)) { filename = test; found = true; break; }
                        test = Path.Combine(path, "VSWAP.WL6");
                        if (File.Exists(test)) { filename = test; found = true; break; }
                    }
                    if (!found)
                        WlMain.Quit("PML_OpenPageFile: Unable to open page file");
                }
            }

            using (var fs = File.OpenRead(filename))
            using (var br = new BinaryReader(fs))
            {
                // Read header
                WL_Globals.ChunksInFile = br.ReadUInt16();
                WL_Globals.PMSpriteStart = br.ReadUInt16();
                WL_Globals.PMSoundStart = br.ReadUInt16();

                int numChunks = WL_Globals.ChunksInFile;

                // Read offsets
                uint[] offsets = new uint[numChunks];
                for (int i = 0; i < numChunks; i++)
                    offsets[i] = br.ReadUInt32();

                // Read lengths
                ushort[] lengths = new ushort[numChunks];
                for (int i = 0; i < numChunks; i++)
                    lengths[i] = br.ReadUInt16();

                // Allocate page structures
                WL_Globals.PMPages = new PageListStruct[numChunks];
                WL_Globals.PMPageData = new byte[numChunks][];

                for (int i = 0; i < numChunks; i++)
                {
                    WL_Globals.PMPages[i] = new PageListStruct
                    {
                        offset = offsets[i],
                        length = lengths[i],
                        locked = PMLockType.pml_Unlocked,
                        mainPage = -1,
                        emsPage = -1,
                        xmsPage = -1,
                        lastHit = 0
                    };

                    if (offsets[i] != 0 && lengths[i] != 0)
                    {
                        fs.Seek(offsets[i], SeekOrigin.Begin);
                        WL_Globals.PMPageData[i] = br.ReadBytes(lengths[i]);
                        WL_Globals.PMPages[i].mainPage = 0;
                    }
                }
            }
        }

        public static byte[] PM_GetPageAddress(int pagenum)
        {
            if (pagenum < 0 || pagenum >= WL_Globals.ChunksInFile)
                return null;
            return WL_Globals.PMPageData[pagenum];
        }

        public static byte[] PM_GetPage(int pagenum)
        {
            if (pagenum < 0 || pagenum >= WL_Globals.ChunksInFile)
                WlMain.Quit("PM_GetPage: Invalid page request");

            byte[] result = WL_Globals.PMPageData[pagenum];
            if (result == null)
                WlMain.Quit("PM_GetPage: Page not in memory!");

            WL_Globals.PMPages[pagenum].lastHit = (uint)PMFrameCount;
            return result;
        }

        public static byte[] PM_GetSoundPage(int v)
        {
            return PM_GetPage(WL_Globals.PMSoundStart + v);
        }

        public static byte[] PM_GetSpritePage(int v)
        {
            return PM_GetPage(WL_Globals.PMSpriteStart + v);
        }

        public static void PM_SetPageLock(int pagenum, PMLockType lockType)
        {
            if (pagenum >= 0 && pagenum < WL_Globals.ChunksInFile)
                WL_Globals.PMPages[pagenum].locked = lockType;
        }

        public static void PM_NextFrame()
        {
            PMFrameCount++;
            if (PMFrameCount >= int.MaxValue - 4)
            {
                for (int i = 0; i < WL_Globals.ChunksInFile; i++)
                    WL_Globals.PMPages[i].lastHit = 0;
                PMFrameCount = 0;
            }
        }

        public static void PM_Reset()
        {
            PMPanicMode = false;
        }

        public static void PM_Preload(Func<int, int, bool> update)
        {
            update?.Invoke(1, 1);
        }

        public static void PM_SetMainMemPurge(int level)
        {
            // No-op - all pages always in memory
        }

        public static void PM_SetMainPurge(int level)
        {
            // No-op
        }

        public static void PM_CheckMainMem()
        {
            // No-op
        }
    }
}
