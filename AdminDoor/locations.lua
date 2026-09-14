-- locations.lua: door(s) coordinates + wiring + admin whitelist. Find corners with F3.
-- update.lua won't touch this; update_full.lua resets it.

return {
    -- 1 or more independent doors. Each has its own detection box, its own
    -- wiring, and its own admin whitelist, so they open independently and
    -- can each allow different people through.
    DOORS = {
        {
            name = "Front Door",                  -- shown in status / ControlRoom
            min = { x = 0, y = 0, z = 0 },
            max = { x = 0, y = 0, z = 0 },

            relay = "redstone_relay_0",            -- Redstone Relay name, or nil to skip
            relay_side = "front",                  -- side of that relay driving this door

            computer_side = nil,                   -- this computer's own redstone side, or nil to skip

            admin_names = { "YourAdminName" },     -- whitelist for this door, or nil to skip the check
        },
        -- add as many as you want, e.g.:
        -- {
        --     name = "Back Door",
        --     min = { x = 10, y = 0, z = 0 },
        --     max = { x = 10, y = 0, z = 0 },
        --     relay = nil,
        --     relay_side = nil,
        --     computer_side = "back",
        --     admin_names = nil, -- nil = open to anyone detected at this door
        -- },
    },
}
