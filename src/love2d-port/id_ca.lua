-- ID_CA.lua
-- Cache Manager - ported from ID_CA.C
-- Loads graphics, maps, and audio from WL6 data files

local bit = require("bit")
local band, bor, bxor, lshift, rshift = bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift
local ffi = require("ffi")

local gfx = require("gfxv_wl6")
local audiowl6 = require("audiowl6")

local id_ca = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------
id_ca.NUMMAPS    = 60
id_ca.MAPPLANES  = 2
id_ca.FILEPOSSIZE = 3   -- THREEBYTEGRSTARTS

---------------------------------------------------------------------------
-- Global state
---------------------------------------------------------------------------
id_ca.tinf     = nil
id_ca.mapon    = 0

-- Map segments: mapsegs[1] and mapsegs[2] (1-indexed planes)
id_ca.mapsegs      = {nil, nil}
-- Map headers: mapheaderseg[i] indexed 0..NUMMAPS-1
id_ca.mapheaderseg = {}
-- Audio segments
id_ca.audiosegs    = {}
-- Graphics segments: grsegs[chunk] = table of bytes or raw data
id_ca.grsegs       = {}
-- Graphics needed flags
id_ca.grneeded     = {}
id_ca.ca_levelbit  = 1
id_ca.ca_levelnum  = 0

-- File names
id_ca.extension  = "WL6"
id_ca.gheadname  = "VGAHEAD.WL6"
id_ca.gfilename  = "VGAGRAPH.WL6"
id_ca.gdictname  = "VGADICT.WL6"
id_ca.mheadname  = "MAPHEAD.WL6"
id_ca.mfilename  = "GAMEMAPS.WL6"
id_ca.aheadname  = "AUDIOHED.WL6"
id_ca.afilename  = "AUDIOT.WL6"

-- Internal state
local grstarts    = {}   -- array of file offsets for graphics
local audiostarts = {}   -- array of file offsets for audio
local grhuffman   = {}   -- Huffman tree for graphics decompression
local audiohuffman = {}  -- Huffman tree for audio decompression

local grhandle    = nil  -- graphics file data (string)
local maphandle   = nil  -- maps file data (string)
local audiohandle = nil  -- audio file data (string)

-- pictable: array of {width, height} for each pic
id_ca.pictable = {}

-- Hooks for cache dialogs
id_ca.drawcachebox    = nil
id_ca.updatecachebox  = nil
id_ca.finishcachebox  = nil

---------------------------------------------------------------------------
-- Binary reading helpers
---------------------------------------------------------------------------
local function read_uint8(data, offset)
    return string.byte(data, offset + 1)
end

local function read_uint16(data, offset)
    local lo = string.byte(data, offset + 1) or 0
    local hi = string.byte(data, offset + 2) or 0
    return lo + hi * 256
end

local function read_int16(data, offset)
    local v = read_uint16(data, offset)
    if v >= 32768 then v = v - 65536 end
    return v
end

local function read_uint32(data, offset)
    local b0 = string.byte(data, offset + 1) or 0
    local b1 = string.byte(data, offset + 2) or 0
    local b2 = string.byte(data, offset + 3) or 0
    local b3 = string.byte(data, offset + 4) or 0
    return b0 + b1 * 256 + b2 * 65536 + b3 * 16777216
end

local function read_int32(data, offset)
    local v = read_uint32(data, offset)
    if v >= 2147483648 then v = v - 4294967296 end
    return v
end

-- Read a 3-byte file position (for THREEBYTEGRSTARTS)
local function read_filepos3(data, offset)
    local b0 = string.byte(data, offset + 1) or 0
    local b1 = string.byte(data, offset + 2) or 0
    local b2 = string.byte(data, offset + 3) or 0
    local value = b0 + b1 * 256 + b2 * 65536
    if value == 0xFFFFFF then
        return -1
    end
    return value
end

---------------------------------------------------------------------------
-- Huffman decompression
---------------------------------------------------------------------------

local function CAL_HuffExpand(source, src_offset, dest_size, huffman)
    -- source: string of compressed data starting at src_offset (0-based)
    -- Returns a table of decompressed bytes (1-indexed)
    local dest = {}
    local written = 0
    local src_idx = src_offset + 1  -- 1-indexed into string
    local src_len = #source

    -- Head node is node 254 (last node in the 255-node tree)
    local headnode = 254

    local bit_pos = 0
    local cur_byte = 0

    local node = headnode

    while written < dest_size and src_idx <= src_len do
        if bit_pos == 0 then
            cur_byte = string.byte(source, src_idx)
            src_idx = src_idx + 1
            bit_pos = 8
        end

        local bit_val = band(cur_byte, 1)
        cur_byte = rshift(cur_byte, 1)
        bit_pos = bit_pos - 1

        local child
        if bit_val == 0 then
            child = huffman[node * 2 + 0]    -- bit0
        else
            child = huffman[node * 2 + 1]    -- bit1
        end

        if child < 256 then
            -- Leaf node: output the byte
            written = written + 1
            dest[written] = child
            node = headnode
        else
            -- Internal node: continue traversal
            node = child - 256
        end
    end

    -- Pad if needed
    while written < dest_size do
        written = written + 1
        dest[written] = 0
    end

    return dest
end

---------------------------------------------------------------------------
-- RLEW decompression
---------------------------------------------------------------------------

function id_ca.CA_RLEWexpand(source, src_start, dest_size_words, rlewtag)
    -- source: table of uint16 values (1-indexed), starting at src_start
    -- Returns: table of uint16 values (1-indexed), dest_size_words entries
    local dest = {}
    local src_idx = src_start
    local written = 0

    while written < dest_size_words do
        local val = source[src_idx]
        src_idx = src_idx + 1

        if val == rlewtag then
            local count = source[src_idx]
            src_idx = src_idx + 1
            local fill = source[src_idx]
            src_idx = src_idx + 1
            for i = 1, count do
                written = written + 1
                dest[written] = fill
            end
        else
            written = written + 1
            dest[written] = val
        end
    end

    return dest
end

---------------------------------------------------------------------------
-- Carmack decompression
---------------------------------------------------------------------------

local NEARTAG = 0xA7
local FARTAG  = 0xA8

function id_ca.CAL_CarmackExpand(source, dest_size_words)
    -- source: table of uint16 (1-indexed)
    -- Returns: table of uint16 (1-indexed)
    local dest = {}
    local src_idx = 1
    local written = 0

    while written < dest_size_words do
        local val = source[src_idx]
        if val == nil then break end  -- source exhausted
        src_idx = src_idx + 1

        local hi = rshift(val, 8)
        local lo = band(val, 0xFF)

        if hi == NEARTAG then
            if lo == 0 then
                -- Literal: next byte is the actual high byte
                local next_val = source[src_idx] or 0
                src_idx = src_idx + 1
                written = written + 1
                dest[written] = bor(NEARTAG * 256, band(next_val, 0xFF))
            else
                -- Near pointer
                local count = lo
                local offset_byte = source[src_idx] or 0
                src_idx = src_idx + 1
                local back_idx = written - band(offset_byte, 0xFF) + 1
                for i = 1, count do
                    written = written + 1
                    dest[written] = dest[back_idx] or 0
                    back_idx = back_idx + 1
                end
            end
        elseif hi == FARTAG then
            if lo == 0 then
                -- Literal
                local next_val = source[src_idx] or 0
                src_idx = src_idx + 1
                written = written + 1
                dest[written] = bor(FARTAG * 256, band(next_val, 0xFF))
            else
                -- Far pointer
                local count = lo
                local far_offset = source[src_idx] or 0
                src_idx = src_idx + 1
                local back_idx = far_offset + 1  -- 1-indexed
                for i = 1, count do
                    written = written + 1
                    dest[written] = dest[back_idx] or 0
                    back_idx = back_idx + 1
                end
            end
        else
            written = written + 1
            dest[written] = val
        end
    end

    return dest
end

---------------------------------------------------------------------------
-- CA_Startup - Load all headers
---------------------------------------------------------------------------

function id_ca.CA_Startup()
    -- Initialize grneeded
    for i = 0, gfx.NUMCHUNKS - 1 do
        id_ca.grneeded[i] = 0
    end

    -- Load graphics dictionary (Huffman tree)
    local dictdata = love.filesystem.read(id_ca.gdictname)
    if dictdata then
        -- 255 nodes, each with two 16-bit values (bit0, bit1)
        for i = 0, 254 do
            local bit0 = read_uint16(dictdata, i * 4)
            local bit1 = read_uint16(dictdata, i * 4 + 2)
            grhuffman[i * 2 + 0] = bit0
            grhuffman[i * 2 + 1] = bit1
        end
    else
        print("WARNING: Could not load " .. id_ca.gdictname)
    end

    -- Load graphics header (offsets into VGAGRAPH)
    local headdata = love.filesystem.read(id_ca.gheadname)
    if headdata then
        -- 3 bytes per entry (THREEBYTEGRSTARTS)
        local numEntries = math.floor(#headdata / 3)
        for i = 0, numEntries - 1 do
            grstarts[i] = read_filepos3(headdata, i * 3)
        end
    else
        print("WARNING: Could not load " .. id_ca.gheadname)
    end

    -- Load graphics file into memory
    grhandle = love.filesystem.read(id_ca.gfilename)
    if not grhandle then
        print("WARNING: Could not load " .. id_ca.gfilename)
    end

    -- Load audio header
    local aheaddata = love.filesystem.read(id_ca.aheadname)
    if aheaddata then
        local numEntries = math.floor(#aheaddata / 4)
        for i = 0, numEntries - 1 do
            audiostarts[i] = read_uint32(aheaddata, i * 4)
        end
    end

    -- Load audio file
    audiohandle = love.filesystem.read(id_ca.afilename)

    -- Load map header
    local mheaddata = love.filesystem.read(id_ca.mheadname)
    if mheaddata then
        local rlewtag = read_uint16(mheaddata, 0)
        id_ca._rlewtag = rlewtag

        -- Read map header offsets (100 entries, each 4 bytes, starting at offset 2)
        id_ca._mapHeaderOffsets = {}
        for i = 0, 99 do
            id_ca._mapHeaderOffsets[i] = read_int32(mheaddata, 2 + i * 4)
        end
    end

    -- Load maps file
    maphandle = love.filesystem.read(id_ca.mfilename)

    -- Load pic table (STRUCTPIC chunk)
    id_ca.CA_CacheGrChunk(gfx.STRUCTPIC)
    if id_ca.grsegs[gfx.STRUCTPIC] then
        local data = id_ca.grsegs[gfx.STRUCTPIC]
        -- Each entry is 4 bytes: int16 width, int16 height
        local numpics = gfx.NUMPICS
        for i = 0, numpics - 1 do
            local w = data[i * 4 + 1] + data[i * 4 + 2] * 256
            local h = data[i * 4 + 3] + data[i * 4 + 4] * 256
            -- Sign extend if needed
            if w >= 32768 then w = w - 65536 end
            if h >= 32768 then h = h - 65536 end
            id_ca.pictable[i] = {width = w, height = h}
        end
    end
end

function id_ca.CA_Shutdown()
    grhandle = nil
    maphandle = nil
    audiohandle = nil
end

---------------------------------------------------------------------------
-- Graphics caching
---------------------------------------------------------------------------

function id_ca.CA_CacheGrChunk(chunk)
    if id_ca.grsegs[chunk] then
        return  -- Already cached
    end

    if not grhandle then return end

    local pos = grstarts[chunk]
    if not pos or pos < 0 then return end

    -- Find next valid position to determine compressed length
    local next_pos = nil
    for i = chunk + 1, gfx.NUMCHUNKS - 1 do
        if grstarts[i] and grstarts[i] >= 0 then
            next_pos = grstarts[i]
            break
        end
    end
    if not next_pos then
        next_pos = #grhandle
    end

    local compressed_len = next_pos - pos

    -- For pics and fonts, the first 4 bytes are the expanded length
    local expanded_len = 0
    local data_start = pos

    -- Check if this chunk has an explicit length header
    if chunk >= gfx.STARTTILE8 and chunk < gfx.STARTEXTERNS then
        -- Tile8s have no explicit length
        expanded_len = compressed_len
    else
        -- Read expanded length from first 4 bytes
        expanded_len = read_uint32(grhandle, pos)
        data_start = pos + 4
        compressed_len = compressed_len - 4
    end

    if expanded_len <= 0 then
        expanded_len = compressed_len
    end

    -- Huffman decompress
    local decompressed = CAL_HuffExpand(grhandle, data_start, expanded_len, grhuffman)
    id_ca.grsegs[chunk] = decompressed
end

function id_ca.UNCACHEGRCHUNK(chunk)
    id_ca.grsegs[chunk] = nil
    id_ca.grneeded[chunk] = band(id_ca.grneeded[chunk] or 0, bit.bnot(id_ca.ca_levelbit))
end

function id_ca.CA_MarkGrChunk(chunk)
    id_ca.grneeded[chunk] = bor(id_ca.grneeded[chunk] or 0, id_ca.ca_levelbit)
end

---------------------------------------------------------------------------
-- CA_CacheScreen - load a full-screen graphic
---------------------------------------------------------------------------

function id_ca.CA_CacheScreen(chunk)
    local id_vl = require("id_vl")

    id_ca.CA_CacheGrChunk(chunk)
    local data = id_ca.grsegs[chunk]
    if not data then return end

    -- MungePic then MemToScreen
    id_vl.VL_MungePic(data, 320, 200)
    id_vl.VL_MemToScreen(data, 320, 200, 0, 0)
end

---------------------------------------------------------------------------
-- Map caching
---------------------------------------------------------------------------

function id_ca.CA_CacheMap(mapnum)
    if not maphandle then return end
    if not id_ca._mapHeaderOffsets then return end

    local headerOffset = id_ca._mapHeaderOffsets[mapnum]
    if not headerOffset or headerOffset < 0 then return end

    -- Read map header from GAMEMAPS file
    -- Layout: 3x int32 planestart, 3x uint16 planelength, uint16 width, uint16 height, 16 chars name
    local planestart = {}
    local planelength = {}
    for i = 0, 2 do
        planestart[i] = read_int32(maphandle, headerOffset + i * 4)
    end
    for i = 0, 2 do
        planelength[i] = read_uint16(maphandle, headerOffset + 12 + i * 2)
    end
    local mapwidth = read_uint16(maphandle, headerOffset + 18)
    local mapheight = read_uint16(maphandle, headerOffset + 20)

    -- Store map header
    id_ca.mapheaderseg[mapnum] = {
        planestart = planestart,
        planelength = planelength,
        width = mapwidth,
        height = mapheight,
    }

    local rlewtag = id_ca._rlewtag or 0xABCD

    -- Load each map plane (0 and 1 are the important ones)
    for plane = 0, id_ca.MAPPLANES - 1 do
        local start = planestart[plane]
        local length = planelength[plane]

        if start > 0 and length > 0 and start + length <= #maphandle then
            -- Read compressed data as uint16 words
            local compressed = {}
            for i = 0, math.floor(length / 2) - 1 do
                compressed[i + 1] = read_uint16(maphandle, start + i * 2)
            end

            -- First word is the expanded size in bytes
            local expandedSize = compressed[1]
            local expandedWords = math.floor(expandedSize / 2)

            -- Carmack decompress (skip the size word)
            local carmacked = id_ca.CAL_CarmackExpand(
                {unpack(compressed, 2)},
                expandedWords
            )

            -- RLEW decompress
            local mapdata = id_ca.CA_RLEWexpand(
                carmacked,
                2,  -- skip size word
                mapwidth * mapheight,
                rlewtag
            )

            id_ca.mapsegs[plane + 1] = mapdata  -- 1-indexed plane
        end
    end

    id_ca.mapon = mapnum
end

---------------------------------------------------------------------------
-- Audio caching
---------------------------------------------------------------------------

function id_ca.CA_CacheAudioChunk(chunk)
    if not audiohandle then return end
    if not audiostarts[chunk] then return end

    local start = audiostarts[chunk]
    local next_start = audiostarts[chunk + 1] or #audiohandle

    if start >= next_start then return end

    local len = next_start - start
    local data = {}
    for i = 0, len - 1 do
        data[i + 1] = string.byte(audiohandle, start + i + 1)
    end
    id_ca.audiosegs[chunk] = data
end

function id_ca.CA_LoadAllSounds()
    -- Cache all digitized sounds
    local startDigiSounds = audiowl6.STARTDIGISOUNDS
    for i = 0, audiowl6.NUMSOUNDS - 1 do
        id_ca.CA_CacheAudioChunk(startDigiSounds + i)
    end
end

---------------------------------------------------------------------------
-- Level management
---------------------------------------------------------------------------

function id_ca.CA_UpLevel()
    if id_ca.ca_levelnum < 7 then
        id_ca.ca_levelnum = id_ca.ca_levelnum + 1
        id_ca.ca_levelbit = lshift(1, id_ca.ca_levelnum)
    end
end

function id_ca.CA_DownLevel()
    if id_ca.ca_levelnum > 0 then
        id_ca.ca_levelnum = id_ca.ca_levelnum - 1
        id_ca.ca_levelbit = lshift(1, id_ca.ca_levelnum)
    end
end

function id_ca.CA_SetAllPurge()
    for i = 0, gfx.NUMCHUNKS - 1 do
        id_ca.grsegs[i] = nil
    end
end

function id_ca.CA_ClearMarks()
    for i = 0, gfx.NUMCHUNKS - 1 do
        id_ca.grneeded[i] = band(id_ca.grneeded[i] or 0, bit.bnot(id_ca.ca_levelbit))
    end
end

function id_ca.CA_ClearAllMarks()
    for i = 0, gfx.NUMCHUNKS - 1 do
        id_ca.grneeded[i] = 0
    end
end

function id_ca.CA_SetGrPurge()
    -- Mark all graphics as purgeable
end

function id_ca.CA_CacheMarks()
    -- Cache all marked chunks
    for i = 0, gfx.NUMCHUNKS - 1 do
        if id_ca.grneeded[i] and id_ca.grneeded[i] ~= 0 and not id_ca.grsegs[i] then
            id_ca.CA_CacheGrChunk(i)
            if id_ca.updatecachebox then
                id_ca.updatecachebox()
            end
        end
    end
    if id_ca.finishcachebox then
        id_ca.finishcachebox()
    end
end

---------------------------------------------------------------------------
-- File I/O helpers
---------------------------------------------------------------------------

function id_ca.CA_ReadFile(filename)
    return love.filesystem.read(filename)
end

function id_ca.CA_LoadFile(filename)
    local data = love.filesystem.read(filename)
    if data then
        local bytes = {}
        for i = 1, #data do
            bytes[i] = string.byte(data, i)
        end
        return bytes
    end
    return nil
end

function id_ca.CA_FarRead(file, dest, length)
    -- Stub for compatibility
    return true
end

function id_ca.CA_FarWrite(file, source, length)
    -- Stub for compatibility
    return true
end

return id_ca
