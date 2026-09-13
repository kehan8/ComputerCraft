-- locations.lua: coordinates for this building's door-zone and building-zone boxes.
-- Find corners with F3. update.lua does NOT touch this file; update_full.lua resets it.

return {
    -- Small box right at the door. Anyone inside it: door opens + welcome.
    DOOR_MIN = { x = 0, y = 0, z = 0 },
    DOOR_MAX = { x = 0, y = 0, z = 0 },

    -- Box covering the whole building. Anyone who drops out of it gets a goodbye.
    -- Read by the door detector itself if BUILDING_DETECTOR_ENABLED = false in config.lua.
    BUILDING_MIN = { x = 0, y = 0, z = 0 },
    BUILDING_MAX = { x = 0, y = 0, z = 0 },
}
