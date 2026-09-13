-- config.lua: local settings, not touched by update.lua (see README).

return {
    DETECTOR_NAME = "player_detector_0", -- Player Detector peripheral

    DOOR_RELAY_NAME = { "redstone_relay_0" }, -- relay wired to the door
    DOOR_SIDE = "front",                   -- side of that relay driving the door

    ADMIN_NAMES = { "YourAdminName" }, -- whitelist

    ADMIN_ENABLED = true, -- false = open for anyone, no whitelist

    POLL_INTERVAL = 1, -- seconds between detector scans

    CHATBOX_NAME = "chat_box_0", -- Chat Box peripheral
    TOAST_TITLE = "NO ACCESS",
    TOAST_MESSAGE = "You are not authorized to enter.",

    -- Wireless modem to report status to ControlRoom. False if no modem.
    MODEM_NAME = "back",
    MODEM_ENABLED = false,
}
