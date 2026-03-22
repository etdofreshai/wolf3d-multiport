-- WL_ACT2.lua
-- Actor behavior/AI - ported from WL_ACT2.C
-- Contains state definitions and think/action functions for all enemies

local wl_def = require("wl_def")

local wl_act2 = {}

-- All state definitions would go here
-- Each enemy type has states for standing, walking, attacking, dying, etc.
-- For now these are stubs.

-- Guard states (example structure)
wl_act2.s_grdstand = wl_def.new_statetype(true, wl_def.SPR_GRD_S_1, 0, nil, nil, nil)

-- T_Stand: standing guard think function
function wl_act2.T_Stand(ob)
    -- Check if player is visible, switch to chase if so
end

-- T_Path: patrolling guard think function
function wl_act2.T_Path(ob)
    -- Follow patrol path
end

-- T_Chase: chasing think function
function wl_act2.T_Chase(ob)
    -- Chase player
end

-- T_Shoot: shooting action
function wl_act2.T_Shoot(ob)
    -- Fire at player
end

-- T_DogChase: dog chasing
function wl_act2.T_DogChase(ob)
end

-- A_DeathScream: death scream action
function wl_act2.A_DeathScream(ob)
end

return wl_act2
