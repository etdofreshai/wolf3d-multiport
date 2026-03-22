-- WL_TEXT.lua
-- Text display routines - ported from WL_TEXT.C
-- Handles help text, end-game text screens

local id_vl = require("id_vl")
local id_vh = require("id_vh")
local id_in = require("id_in")
local id_ca = require("id_ca")
local gfx   = require("gfxv_wl6")

local wl_text = {}

---------------------------------------------------------------------------
-- HelpScreens
---------------------------------------------------------------------------

function wl_text.HelpScreens()
    -- Display help text screens
    -- Loads T_HELPART chunk and displays pages
end

---------------------------------------------------------------------------
-- OrderingInfo
---------------------------------------------------------------------------

function wl_text.OrderingInfo()
    -- Display ordering information
end

---------------------------------------------------------------------------
-- EndText (end-game text screens)
---------------------------------------------------------------------------

function wl_text.EndText()
    -- Display end-of-episode text
end

return wl_text
