-- config.lua: your local settings for this door.
-- update.lua does NOT touch this file, so your changes survive a normal update.
-- Run update_full.lua instead if you ever want this file reset back to the repo defaults.

return {
    DETECTOR_NAME = "player_detector_0", -- name of your Player Detector peripheral
    DETECT_RANGE = 3,                    -- max range (blocks) the detector scans for nearby players

    DOOR_RELAY_NAME = "redstone_relay_0", -- relay wired to the door
    DOOR_SIDE = "front",                   -- side of that relay driving the door

    -- Whitelist of player names allowed through. Anyone else detected nearby
    -- gets the "NO ACCESS" toast instead of the door opening.
    ADMIN_NAMES = { "YourAdminName" },

    POLL_INTERVAL = 1, -- seconds between detector scans

    -- Chat Box peripheral used to send the unauthorized player an in-game toast
    -- popup. On MC 1.21.1+ this shows up as "chat_box_N"; on older versions it's
    -- "chatBox_N" -- check with peripheral.getNames() if unsure.
    CHATBOX_NAME = "chat_box_0",
    TOAST_TITLE = "NO ACCESS",
    TOAST_MESSAGE = "You are not authorized to enter.",
}
