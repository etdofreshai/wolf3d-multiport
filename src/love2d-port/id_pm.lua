-- ID_PM.lua
-- Page Manager - ported from ID_PM.C
-- Manages paged-in wall/sprite data from VSWAP.WL6
-- In original code, this swapped 4K pages in from disk.
-- We load the entire VSWAP file into memory.

local bit = require("bit")
local band, bor, lshift, rshift = bit.band, bit.bor, bit.lshift, bit.rshift

local id_pm = {}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
id_pm.PMSoundStart = 0       -- Page number where sound data begins
id_pm.PMPages      = nil     -- Array of page data (each is a string or table)
id_pm.PMPageCount  = 0       -- Total number of pages
id_pm.ChunksInFile = 0
id_pm.PMSpriteStart = 0
id_pm.PMSoundStart  = 0

-- Page data cache
local pageOffsets = {}
local pageLengths = {}
local fileData = nil

---------------------------------------------------------------------------
-- Helpers for reading binary data
---------------------------------------------------------------------------
local function read_uint16(data, offset)
    local lo = string.byte(data, offset + 1)
    local hi = string.byte(data, offset + 2)
    return lo + hi * 256
end

local function read_uint32(data, offset)
    local b0 = string.byte(data, offset + 1)
    local b1 = string.byte(data, offset + 2)
    local b2 = string.byte(data, offset + 3)
    local b3 = string.byte(data, offset + 4)
    return b0 + b1 * 256 + b2 * 65536 + b3 * 16777216
end

---------------------------------------------------------------------------
-- Startup / Shutdown
---------------------------------------------------------------------------

function id_pm.PM_Startup()
    -- Load VSWAP.WL6
    local vswap_path = "VSWAP.WL6"
    local data = love.filesystem.read(vswap_path)
    if not data then
        print("WARNING: Could not load " .. vswap_path)
        return
    end

    fileData = data

    -- Parse VSWAP header
    local numChunks   = read_uint16(data, 0)
    local spriteStart = read_uint16(data, 2)
    local soundStart  = read_uint16(data, 4)

    id_pm.ChunksInFile  = numChunks
    id_pm.PMSpriteStart = spriteStart
    id_pm.PMSoundStart  = soundStart
    id_pm.PMPageCount   = numChunks

    -- Read page offsets (uint32 each, starting at offset 6)
    for i = 0, numChunks - 1 do
        pageOffsets[i] = read_uint32(data, 6 + i * 4)
    end

    -- Read page lengths (uint16 each, starting after offsets)
    local lengthBase = 6 + numChunks * 4
    for i = 0, numChunks - 1 do
        pageLengths[i] = read_uint16(data, lengthBase + i * 2)
    end

    -- Extract page data
    id_pm.PMPages = {}
    for i = 0, numChunks - 1 do
        local off = pageOffsets[i]
        local len = pageLengths[i]
        if off > 0 and len > 0 and off + len <= #data then
            id_pm.PMPages[i] = string.sub(data, off + 1, off + len)
        else
            id_pm.PMPages[i] = nil
        end
    end
end

function id_pm.PM_Shutdown()
    id_pm.PMPages = nil
    fileData = nil
end

function id_pm.PM_UnlockMainMem()
    -- No-op (no XMS/EMS)
end

function id_pm.PM_CheckMainMem()
    -- No-op
end

-- Get a page of data. Returns a string.
function id_pm.PM_GetPage(pagenum)
    if id_pm.PMPages and id_pm.PMPages[pagenum] then
        return id_pm.PMPages[pagenum]
    end
    return nil
end

-- Get page as a table of bytes (1-indexed)
function id_pm.PM_GetPageBytes(pagenum)
    local page = id_pm.PM_GetPage(pagenum)
    if not page then return nil end
    local bytes = {}
    for i = 1, #page do
        bytes[i] = string.byte(page, i)
    end
    return bytes
end

-- Get sound page
function id_pm.PM_GetSoundPage(pagenum)
    return id_pm.PM_GetPage(id_pm.PMSoundStart + pagenum)
end

return id_pm
