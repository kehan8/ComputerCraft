-- config.lua: local settings. update.lua won't touch this; update_full.lua resets it.

return {
    DETECTOR_NAME = "player_detector_0", -- Player Detector, checks every door box from locations.lua

    CHATBOX_NAME = "chat_box_0", -- Chat Box for the "NO ACCESS" toast

    TOAST_TITLE = "NO ACCESS",
    TOAST_MESSAGE = "You are not authorized to enter.",

    POLL_INTERVAL = 1, -- seconds between detector scans

    -- Wireless modem to report status to ControlRoom. False if no modem.
    MODEM_NAME = "back",
    MODEM_ENABLED = false,
}
