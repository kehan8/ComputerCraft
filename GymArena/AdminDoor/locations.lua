-- locations.lua: door box coordinates. Find corners with F3.
-- update.lua won't touch this; update_full.lua resets it.

return {
    -- Box at the door. Anyone inside gets checked against the admin whitelist.
    DOOR_MIN = { x = 0, y = 0, z = 0 },
    DOOR_MAX = { x = 0, y = 0, z = 0 },

    -- Optional: got a wider door, or two separate detection zones? Uncomment
    -- BOXES below and list as many boxes as you want -- startup.lua checks all
    -- of them and merges the results, so 1 box (above) or many (below) both
    -- work with no errors. When BOXES is set, DOOR_MIN/DOOR_MAX above are ignored.
    -- BOXES = {
    --     { min = { x = 0, y = 0, z = 0 }, max = { x = 0, y = 0, z = 0 } },
    --     { min = { x = 10, y = 0, z = 0 }, max = { x = 10, y = 0, z = 0 } },
    -- },
}
