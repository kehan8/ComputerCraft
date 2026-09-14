-- locations.lua: door(s) + building box coordinates. Find corners with F3.
-- update.lua won't touch this; update_full.lua resets it.

return {
    -- 1 or more independent doors. Each has its own detection box + its own
    -- wiring, so they open independently -- only the door someone actually
    -- walks up to opens, the rest stay shut.
    DOORS = {
        {
            name = "Front Door",                  -- shown in status / ControlRoom
            min = { x = 0, y = 0, z = 0 },
            max = { x = 0, y = 0, z = 0 },

            relay = "redstone_relay_0",            -- Redstone Relay name, or nil to skip
            relay_side = "front",                  -- side of that relay driving this door

            computer_side = nil,                   -- this computer's own redstone side, or nil to skip
        },
        -- add as many as you want, e.g.:
        -- {
        --     name = "Back Door",
        --     min = { x = 10, y = 0, z = 0 },
        --     max = { x = 10, y = 0, z = 0 },
        --     relay = nil,
        --     relay_side = nil,
        --     computer_side = "back",
        -- },
    },

    -- Box covering the whole building (every door included). Leaving it
    -- triggers goodbye. Every door box above must fit inside this one.
    BUILDING_MIN = { x = 0, y = 0, z = 0 },
    BUILDING_MAX = { x = 0, y = 0, z = 0 },
}
