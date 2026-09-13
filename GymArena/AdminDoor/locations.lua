-- locations.lua: door box coordinates. Find corners with F3.
-- update.lua won't touch this; update_full.lua resets it.

return {
    -- Box at the door. Anyone inside gets checked against the admin whitelist.
    DOOR_MIN = { x = 0, y = 0, z = 0 },
    DOOR_MAX = { x = 0, y = 0, z = 0 },
}
