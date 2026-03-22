// ID_CA.C -> IdCa.cs
// Cache Manager - loads graphics, maps, audio from WL6 data files

using System;
using System.IO;

namespace Wolf3D
{
    // Huffman node for decompression
    public struct huffnode
    {
        public int bit0, bit1;  // 0-255 = char, > 255 = node pointer
    }

    public static class IdCa
    {
        private const int FILEPOSSIZE = 3;  // THREEBYTEGRSTARTS

        private static huffnode[] grhuffman = new huffnode[255];
        private static huffnode[] audiohuffman = new huffnode[255];

        private static FileStream grhandle;
        private static FileStream maphandle;
        private static FileStream audiohandle;

        private static int chunkcomplen, chunkexplen;

        // Map file header
        private static ushort RLEWtag;
        private static int[] headeroffsets = new int[100];

        // =========================================================================
        //  File path resolution
        // =========================================================================

        private static string FindFile(string basename)
        {
            string ext = WL_Globals.extension;
            string[] candidates = {
                basename + ext,
                basename,
                Path.Combine("assets", basename + ext),
                Path.Combine("..", "assets", basename + ext),
                Path.Combine("..", "..", "assets", basename + ext),
                Path.Combine("assets", basename),
            };
            foreach (var c in candidates)
                if (File.Exists(c)) return c;
            return basename + ext;  // let caller fail with proper error
        }

        // =========================================================================
        //  GRFILEPOS - 3-byte file positions
        // =========================================================================

        private static int GRFILEPOS(int c)
        {
            if (WL_Globals.grstarts == null) return -1;
            // grstarts is stored as raw bytes interpreted as 3-byte values
            // but we've already decoded them into int[] at startup
            if (c < 0 || c >= WL_Globals.grstarts.Length) return -1;
            return WL_Globals.grstarts[c];
        }

        // =========================================================================
        //  Huffman decompression
        // =========================================================================

        private static void CAL_HuffExpand(byte[] source, int srcOfs, byte[] dest, int destOfs, int length, huffnode[] hufftable)
        {
            int headptr = 254;  // head of huffman tree
            int nodeptr = headptr;
            int written = 0;
            int srcPos = srcOfs;
            int dstPos = destOfs;

            if (length == 0) return;

            byte val = (srcPos < source.Length) ? source[srcPos++] : (byte)0;
            byte mask = 1;

            while (written < length)
            {
                int branch;
                if ((val & mask) != 0)
                    branch = hufftable[nodeptr].bit1;
                else
                    branch = hufftable[nodeptr].bit0;

                if (branch < 256)
                {
                    // Leaf node - output character
                    if (dstPos < dest.Length)
                        dest[dstPos++] = (byte)branch;
                    written++;
                    nodeptr = headptr;
                }
                else
                {
                    // Internal node - continue traversal
                    nodeptr = branch - 256;
                }

                mask <<= 1;
                if (mask == 0)
                {
                    mask = 1;
                    val = (srcPos < source.Length) ? source[srcPos++] : (byte)0;
                }
            }
        }

        // =========================================================================
        //  Carmack decompression
        // =========================================================================

        public static void CAL_CarmackExpand(byte[] source, int srcOfs, ushort[] dest, int destOfs, int length)
        {
            int inptr = srcOfs;
            int outptr = destOfs;
            int outlength = length / 2;  // word count
            int written = 0;

            while (written < outlength && inptr + 1 < source.Length)
            {
                ushort ch = (ushort)(source[inptr] | (source[inptr + 1] << 8));
                inptr += 2;
                int chhigh = ch >> 8;

                if (chhigh == 0xA7) // near pointer
                {
                    int count = ch & 0xFF;
                    if (count == 0)
                    {
                        // Escape: literal value 0xA7xx
                        byte lo = (inptr < source.Length) ? source[inptr++] : (byte)0;
                        dest[outptr + written] = (ushort)(lo | (0xA7 << 8));
                        written++;
                    }
                    else
                    {
                        int offset = (inptr < source.Length) ? source[inptr++] : 0;
                        int srcptr = outptr + written - offset;
                        for (int i = 0; i < count && written < outlength; i++)
                        {
                            if (srcptr + i >= destOfs && srcptr + i < dest.Length)
                                dest[outptr + written] = dest[srcptr + i];
                            written++;
                        }
                    }
                }
                else if (chhigh == 0xA8) // far pointer
                {
                    int count = ch & 0xFF;
                    if (count == 0)
                    {
                        byte lo = (inptr < source.Length) ? source[inptr++] : (byte)0;
                        dest[outptr + written] = (ushort)(lo | (0xA8 << 8));
                        written++;
                    }
                    else
                    {
                        int offset = 0;
                        if (inptr + 1 < source.Length)
                        {
                            offset = source[inptr] | (source[inptr + 1] << 8);
                            inptr += 2;
                        }
                        for (int i = 0; i < count && written < outlength; i++)
                        {
                            if (destOfs + offset + i < dest.Length)
                                dest[outptr + written] = dest[destOfs + offset + i];
                            written++;
                        }
                    }
                }
                else
                {
                    dest[outptr + written] = ch;
                    written++;
                }
            }
        }

        // =========================================================================
        //  RLEW decompression
        // =========================================================================

        public static void CA_RLEWexpand(ushort[] source, int srcOfs, ushort[] dest, int destOfs, int length, ushort rlewtag)
        {
            int end = destOfs + length / 2;
            int si = srcOfs;
            int di = destOfs;

            while (di < end && si < source.Length)
            {
                ushort val = source[si++];
                if (val == rlewtag)
                {
                    if (si + 1 >= source.Length) break;
                    int count = source[si++];
                    ushort fillval = source[si++];
                    for (int i = 0; i < count && di < end; i++)
                        dest[di++] = fillval;
                }
                else
                {
                    dest[di++] = val;
                }
            }
        }

        // =========================================================================
        //  File I/O helpers
        // =========================================================================

        public static bool CA_FarRead(FileStream handle, byte[] dest, int length)
        {
            int total = 0;
            while (total < length)
            {
                int read = handle.Read(dest, total, length - total);
                if (read <= 0) return false;
                total += read;
            }
            return true;
        }

        public static bool CA_ReadFile(string filename, out byte[] ptr)
        {
            ptr = null;
            string path = FindFile(filename);
            if (!File.Exists(path)) return false;
            ptr = File.ReadAllBytes(path);
            return true;
        }

        public static bool CA_LoadFile(string filename, out byte[] ptr)
        {
            return CA_ReadFile(filename, out ptr);
        }

        // =========================================================================
        //  Graphics loading
        // =========================================================================

        private static void CAL_SetupGrFile()
        {
            // Load dictionary
            string dictPath = FindFile(WL_Globals.gdictname);
            if (File.Exists(dictPath))
            {
                byte[] dictData = File.ReadAllBytes(dictPath);
                for (int i = 0; i < 255 && i * 4 + 3 < dictData.Length; i++)
                {
                    grhuffman[i].bit0 = (ushort)(dictData[i * 4] | (dictData[i * 4 + 1] << 8));
                    grhuffman[i].bit1 = (ushort)(dictData[i * 4 + 2] | (dictData[i * 4 + 3] << 8));
                }
            }

            // Load header (3-byte offsets)
            string headPath = FindFile(WL_Globals.gheadname);
            if (File.Exists(headPath))
            {
                byte[] headData = File.ReadAllBytes(headPath);
                int numStarts = headData.Length / FILEPOSSIZE;
                WL_Globals.grstarts = new int[numStarts + 1];
                for (int i = 0; i < numStarts; i++)
                {
                    int offset = i * FILEPOSSIZE;
                    int val = headData[offset] | (headData[offset + 1] << 8) | (headData[offset + 2] << 16);
                    if (val == 0xFFFFFF) val = -1;
                    WL_Globals.grstarts[i] = val;
                }
            }
            else
            {
                WL_Globals.grstarts = new int[GfxConstants.NUMCHUNKS + 1];
            }

            // Open graphics file
            string grPath = FindFile(WL_Globals.gfilename);
            if (File.Exists(grPath))
                grhandle = File.OpenRead(grPath);

            // Load pic table (STRUCTPIC chunk)
            CAL_SetupPicTable();
        }

        private static void CAL_SetupPicTable()
        {
            // Cache the STRUCTPIC chunk which contains pictable data
            if (grhandle == null) return;

            int chunk = GfxConstants.STRUCTPIC;
            int pos = GRFILEPOS(chunk);
            int nextpos = GRFILEPOS(chunk + 1);
            if (pos < 0 || nextpos < 0) return;

            int complen = nextpos - pos;
            grhandle.Seek(pos, SeekOrigin.Begin);

            // Read compressed length and expanded length
            byte[] header = new byte[4];
            grhandle.Read(header, 0, 4);
            int explen = header[0] | (header[1] << 8) | (header[2] << 16) | (header[3] << 24);

            byte[] compData = new byte[complen - 4];
            grhandle.Read(compData, 0, compData.Length);

            byte[] expanded = new byte[explen];
            CAL_HuffExpand(compData, 0, expanded, 0, explen, grhuffman);

            // Parse pictable entries (4 bytes each: int16 width, int16 height)
            int numPics = explen / 4;
            WL_Globals.pictable = new pictabletype[numPics];
            for (int i = 0; i < numPics; i++)
            {
                WL_Globals.pictable[i].width = (short)(expanded[i * 4] | (expanded[i * 4 + 1] << 8));
                WL_Globals.pictable[i].height = (short)(expanded[i * 4 + 2] | (expanded[i * 4 + 3] << 8));
            }
        }

        private static void CAL_SetupMapFile()
        {
            string headPath = FindFile(WL_Globals.mheadname);
            if (!File.Exists(headPath)) return;

            byte[] headData = File.ReadAllBytes(headPath);
            if (headData.Length < 2) return;

            RLEWtag = (ushort)(headData[0] | (headData[1] << 8));

            // Read header offsets (100 x int32)
            for (int i = 0; i < 100 && (2 + i * 4 + 3) < headData.Length; i++)
            {
                int off = 2 + i * 4;
                headeroffsets[i] = headData[off] | (headData[off + 1] << 8) |
                                   (headData[off + 2] << 16) | (headData[off + 3] << 24);
            }

            // Open map file
            string useFilename = "GAMEMAPS";
            string mapPath = FindFile(useFilename);
            if (File.Exists(mapPath))
                maphandle = File.OpenRead(mapPath);
        }

        private static void CAL_SetupAudioFile()
        {
            string headPath = FindFile(WL_Globals.aheadname);
            if (!File.Exists(headPath)) return;

            byte[] headData = File.ReadAllBytes(headPath);

            // Audio header is array of int32 offsets
            int numStarts = headData.Length / 4;
            WL_Globals.audiostarts = new int[numStarts];
            for (int i = 0; i < numStarts; i++)
            {
                int off = i * 4;
                WL_Globals.audiostarts[i] = headData[off] | (headData[off + 1] << 8) |
                                             (headData[off + 2] << 16) | (headData[off + 3] << 24);
            }

            string audioPath = FindFile(WL_Globals.afilename);
            if (File.Exists(audioPath))
                audiohandle = File.OpenRead(audioPath);
        }

        // =========================================================================
        //  Public API
        // =========================================================================

        public static void CA_Startup()
        {
            CAL_SetupGrFile();
            CAL_SetupMapFile();
            CAL_SetupAudioFile();

            WL_Globals.mapon = -1;
            WL_Globals.ca_levelbit = 1;
            WL_Globals.ca_levelnum = 0;
        }

        public static void CA_Shutdown()
        {
            grhandle?.Close();
            grhandle = null;
            maphandle?.Close();
            maphandle = null;
            audiohandle?.Close();
            audiohandle = null;
        }

        public static void CA_CacheGrChunk(int chunk)
        {
            if (chunk < 0 || chunk >= GfxConstants.NUMCHUNKS) return;
            if (WL_Globals.grsegs[chunk] != null) return;  // already cached

            int pos = GRFILEPOS(chunk);
            if (pos < 0) return;

            int nextChunk = chunk + 1;
            while (nextChunk < GfxConstants.NUMCHUNKS && GRFILEPOS(nextChunk) == -1)
                nextChunk++;

            int nextpos = (nextChunk < GfxConstants.NUMCHUNKS) ? GRFILEPOS(nextChunk) : (int)grhandle.Length;
            int complen = nextpos - pos;

            if (grhandle == null || complen <= 0) return;

            grhandle.Seek(pos, SeekOrigin.Begin);

            // For tiles (no explicit length header)
            if (chunk >= GfxConstants.STARTTILE8 && chunk < GfxConstants.STARTEXTERNS)
            {
                byte[] data = new byte[complen];
                grhandle.Read(data, 0, complen);
                WL_Globals.grsegs[chunk] = data;
                return;
            }

            // Read expanded length header (4 bytes)
            byte[] header = new byte[4];
            grhandle.Read(header, 0, 4);
            int explen = header[0] | (header[1] << 8) | (header[2] << 16) | (header[3] << 24);

            byte[] compData = new byte[complen - 4];
            if (compData.Length > 0)
                grhandle.Read(compData, 0, compData.Length);

            byte[] expanded = new byte[Math.Max(explen, 1)];
            CAL_HuffExpand(compData, 0, expanded, 0, explen, grhuffman);

            WL_Globals.grsegs[chunk] = expanded;
        }

        public static void CA_CacheScreen(int chunk)
        {
            CA_CacheGrChunk(chunk);
            if (WL_Globals.grsegs[chunk] != null)
            {
                byte[] data = WL_Globals.grsegs[chunk];
                // Screen-sized chunk, de-plane and draw
                IdVl.VL_MungePic(data, 320, 200);
                IdVl.VL_MemToScreen(data, 320, 200, 0, 0);
            }
        }

        public static void CA_CacheMap(int mapnum)
        {
            if (maphandle == null) return;
            if (mapnum < 0 || mapnum >= WolfConstants.NUMMAPS) return;

            int offset = headeroffsets[mapnum];
            if (offset <= 0) return;

            // Read map header (38 bytes: 3 int32 planestart + 3 uint16 planelength + 2 uint16 size + 16 char name)
            maphandle.Seek(offset, SeekOrigin.Begin);
            var br = new BinaryReader(maphandle);

            int[] planestart = new int[3];
            ushort[] planelength = new ushort[3];
            for (int i = 0; i < 3; i++) planestart[i] = br.ReadInt32();
            for (int i = 0; i < 3; i++) planelength[i] = br.ReadUInt16();
            ushort mapWidth = br.ReadUInt16();
            ushort mapHeight = br.ReadUInt16();

            WL_Globals.mapheaderseg_data[mapnum] = new maptype
            {
                planestart0 = planestart[0],
                planestart1 = planestart[1],
                planestart2 = planestart[2],
                planelength0 = planelength[0],
                planelength1 = planelength[1],
                planelength2 = planelength[2],
                width = mapWidth,
                height = mapHeight
            };
            WL_Globals.mapheaderseg_valid[mapnum] = true;

            int size = mapWidth * mapHeight * 2;  // in bytes

            // Load and decompress each plane
            for (int plane = 0; plane < WolfConstants.MAPPLANES; plane++)
            {
                int ps = planestart[plane];
                int pl = planelength[plane];
                if (ps <= 0 || pl <= 0) continue;

                maphandle.Seek(ps, SeekOrigin.Begin);
                byte[] compData = new byte[pl];
                maphandle.Read(compData, 0, pl);

                // Carmack expand first
                ushort expandedSize = (ushort)(compData[0] | (compData[1] << 8));
                ushort[] carmackExpanded = new ushort[expandedSize / 2 + 1];
                CAL_CarmackExpand(compData, 2, carmackExpanded, 0, expandedSize);

                // Then RLEW expand
                ushort[] mapPlane = new ushort[mapWidth * mapHeight];
                CA_RLEWexpand(carmackExpanded, 1, mapPlane, 0, size, RLEWtag);

                WL_Globals.mapsegs[plane] = mapPlane;
            }

            WL_Globals.mapon = mapnum;
        }

        public static void CA_CacheAudioChunk(int chunk)
        {
            if (audiohandle == null) return;
            if (chunk < 0) return;
            if (WL_Globals.audiostarts == null) return;
            if (chunk >= WL_Globals.audiostarts.Length - 1) return;

            int pos = WL_Globals.audiostarts[chunk];
            int nextpos = WL_Globals.audiostarts[chunk + 1];
            if (pos < 0 || nextpos < 0) return;

            int length = nextpos - pos;
            if (length <= 0) return;

            audiohandle.Seek(pos, SeekOrigin.Begin);
            byte[] data = new byte[length];
            audiohandle.Read(data, 0, length);

            if (chunk < WL_Globals.audiosegs.Length)
                WL_Globals.audiosegs[chunk] = data;
        }

        public static void CA_LoadAllSounds()
        {
            // Load all sound chunks
            for (int i = 0; i < AudioConstants.NUMSNDCHUNKS; i++)
                CA_CacheAudioChunk(i);
        }

        public static void CA_UpLevel()
        {
            if (WL_Globals.ca_levelnum == 7)
                WlMain.Quit("CA_UpLevel: Too many levels!");
            WL_Globals.ca_levelnum++;
            WL_Globals.ca_levelbit <<= 1;
        }

        public static void CA_DownLevel()
        {
            if (WL_Globals.ca_levelnum == 0)
                WlMain.Quit("CA_DownLevel: Already at lowest level!");
            WL_Globals.ca_levelnum--;
            WL_Globals.ca_levelbit >>= 1;
        }

        public static void CA_SetGrPurge()
        {
            for (int i = 0; i < GfxConstants.NUMCHUNKS; i++)
            {
                if (WL_Globals.grsegs[i] != null && (WL_Globals.grneeded[i] & WL_Globals.ca_levelbit) == 0)
                    WL_Globals.grsegs[i] = null;
            }
        }

        public static void CA_SetAllPurge()
        {
            for (int i = 0; i < GfxConstants.NUMCHUNKS; i++)
                WL_Globals.grsegs[i] = null;
        }

        public static void CA_ClearMarks()
        {
            for (int i = 0; i < GfxConstants.NUMCHUNKS; i++)
                WL_Globals.grneeded[i] &= (byte)~WL_Globals.ca_levelbit;
        }

        public static void CA_ClearAllMarks()
        {
            Array.Clear(WL_Globals.grneeded, 0, WL_Globals.grneeded.Length);
        }

        public static void CA_CacheMarks()
        {
            for (int i = 0; i < GfxConstants.NUMCHUNKS; i++)
            {
                if ((WL_Globals.grneeded[i] & WL_Globals.ca_levelbit) != 0 && WL_Globals.grsegs[i] == null)
                    CA_CacheGrChunk(i);
            }
        }
    }
}
