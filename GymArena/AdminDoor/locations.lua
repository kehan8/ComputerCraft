-- locations.lua: door box coordinates. Find corners with F3.
-- update.lua won't touch this; update_full.lua resets it.

return {
    -- List of detection boxes at the door. Anyone inside any of them gets
    -- checked against the admin whitelist. 1 box or many both work --
    -- startup.lua checks all of them and merges the results (a player
    -- standing where two boxes overlap only counts once).
    BOXES = {
        { min = { x = 0, y = 0, z = 0 }, max = { x = 0, y = 0, z = 0 } },
        -- { min = { x = 10, y = 0, z = 0 }, max = { x = 10, y = 0, z = 0 } },  -- optional 2nd box
    },
}
