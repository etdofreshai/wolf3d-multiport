-- ID_MM.lua
-- Memory Manager - ported from ID_MM.C
-- In Lua, memory is managed by the garbage collector.
-- This module provides the same API as a thin wrapper.

local id_mm = {}

id_mm.SAVENEARHEAP = 0x400
id_mm.SAVEFARHEAP  = 0
id_mm.BUFFERSIZE   = 0x1000
id_mm.MAXBLOCKS    = 700

-- mminfotype
id_mm.mminfo = {
    nearheap = 0,
    farheap  = 0,
    EMSmem   = 0,
    XMSmem   = 0,
    mainmem  = 512 * 1024,  -- Report plenty of memory
}

id_mm.bufferseg = {}  -- Generic buffer
id_mm.mmerror   = false

id_mm.beforesort = nil
id_mm.aftersort  = nil

function id_mm.MM_Startup()
    -- In Lua, memory is managed by GC. Just report available memory.
    id_mm.mminfo.mainmem = 512 * 1024
    -- Initialize bufferseg as a generic byte buffer
    id_mm.bufferseg = {}
    for i = 0, id_mm.BUFFERSIZE - 1 do
        id_mm.bufferseg[i] = 0
    end
end

function id_mm.MM_Shutdown()
    -- Nothing to do
end

function id_mm.MM_MapEMS()
    -- No-op (no EMS in modern systems)
end

function id_mm.MM_GetPtr(size)
    -- Allocate a new table/buffer. Returns the buffer.
    local buf = {}
    return buf
end

function id_mm.MM_FreePtr(ptr)
    -- Let GC handle it
    -- In C this takes memptr*, in Lua we just nil out
end

function id_mm.MM_SetPurge(ptr, purge)
    -- No-op (GC handles everything)
end

function id_mm.MM_SetLock(ptr, locked)
    -- No-op
end

function id_mm.MM_SortMem()
    -- No-op (no memory fragmentation in Lua)
    if id_mm.beforesort then id_mm.beforesort() end
    if id_mm.aftersort then id_mm.aftersort() end
end

function id_mm.MM_ShowMemory()
    -- Debug display - stub
end

function id_mm.MM_UnusedMemory()
    return 256 * 1024
end

function id_mm.MM_TotalFree()
    return 256 * 1024
end

function id_mm.MM_BombOnError(bomb)
    -- No-op
end

function id_mm.MML_UseSpace(segstart, seglength)
    -- No-op
end

return id_mm
