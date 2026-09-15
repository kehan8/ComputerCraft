-- locations.lua: podium wiring. Each podium is one Environment Detector
-- placed near that trainer's spot; the nearest trainer-owned (non-wild)
-- Pokemon to that detector is shown as the active battler for that side.
-- update.lua won't touch this; update_full.lua resets it.

return {
    -- 1 or more independent podiums, each with its own detector. No wiring
    -- "side" field needed here: an Environment Detector is wrapped by its
    -- network name only, exactly like a Player Detector (unlike a Redstone
    -- Relay/computer redstone side elsewhere in this repo, which is a
    -- different concept entirely).
    PODIUMS = {
        {
            position = "Left",                    -- shown on screen; purely a label, doesn't affect wiring
            detector = "environmentDetector_0",   -- Environment Detector peripheral name
        },
        {
            position = "Right",
            detector = "environmentDetector_1",
        },
        -- add as many as you want, e.g. a 3rd podium for a triple battle:
        -- {
        --     position = "Middle",
        --     detector = "environmentDetector_2",
        -- },
    },
}
