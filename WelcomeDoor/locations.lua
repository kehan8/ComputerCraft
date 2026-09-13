-- locations.lua: door/building box coordinates. Find corners with F3.
-- update.lua won't touch this; update_full.lua resets it.

return {
    -- Box at the door. Anyone inside: door opens + welcome.
    DOOR_MIN = { x = 0, y = 0, z = 0 },
    DOOR_MAX = { x = 0, y = 0, z = 0 },

    -- Box covering the building. Leaving it triggers goodbye. DOOR box must fit inside.
    BUILDING_MIN = { x = 0, y = 0, z = 0 },
    BUILDING_MAX = { x = 0, y = 0, z = 0 },
}
