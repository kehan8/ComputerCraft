-- config.lua: your local settings for this door.
-- update.lua does NOT touch this file, so your changes survive a normal update.
-- Run update_full.lua instead if you ever want this file reset back to the repo defaults.

return {
    DETECTOR_NAME = "playerDetector_0", -- name of your Player Detector peripheral
    DETECT_RANGE = 3,                    -- max range (blocks) the detector scans for nearby players

    DOOR_RELAY_NAME = "redstone_relay_0", -- relay wired to the door
    DOOR_SIDE = "front",                   -- side of that relay driving the door

    -- Whitelist of player names allowed through. Anyone else detected nearby
    -- triggers the "NO ACCESS" popup instead of opening the door.
    ADMIN_NAMES = { "YourAdminName" },

    POLL_INTERVAL = 1, -- seconds between detector scans
    WARNING_TIME = 2,  -- seconds the "NO ACCESS" popup stays on screen
}
