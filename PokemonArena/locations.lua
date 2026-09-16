-- locations.lua: podium wiring. Each podium is one Environment Detector near
-- that trainer's spot. update.lua won't touch this; update_full.lua resets it.

return {
    -- 1 or more independent podiums, each with its own detector (wrapped by
    -- network name only, like a Player Detector -- no wiring "side" field).
    PODIUMS = {
        {
            position = "Left",                    -- shown on screen; purely a label
            detector = "environment_detector_0",  -- 1.21.1+ name; older MC uses "environmentDetector_0"
        },
        {
            position = "Right",
            detector = "environment_detector_1",
        },
        -- add as many as you want, e.g. a 3rd podium for a triple battle:
        -- { position = "Middle", detector = "environment_detector_2" },
    },
}
