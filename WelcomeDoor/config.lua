-- config.lua: your local settings for this door.
-- update.lua does NOT touch this file, so your changes survive a normal update.
-- Run update_full.lua instead if you ever want this file reset back to the repo defaults.

return {
    -- Shown in the welcome/goodbye/closed messages via %s.
    BUILDING_NAME = "Your Building",

    -- Door Player Detector. Checks the DOOR_MIN/DOOR_MAX box from locations.lua.
    -- Value can be a redstone side ("left", "right", ...) if placed directly against
    -- the computer, or a network name ("player_detector_0") if via Wired Modem.
    -- Run peripheral.getNames() from the Lua prompt to see what your computer sees.
    DETECTOR_NAME = "player_detector_0",

    -- Building detector: checks the BUILDING_MIN/BUILDING_MAX box, covering the whole
    -- building. Sends goodbye + resets the player once they drop out of that box.
    -- False = door detector reads that same box itself, no 2nd peripheral needed.
    BUILDING_DETECTOR_ENABLED = false,
    BUILDING_DETECTOR_NAME = "player_detector_1", -- side or network name, same as above

    -- Drive the door via computer redstone side, a Redstone Relay, or both.
    COMPUTER_SIDE = "back",
    COMPUTER_ENABLED = true,

    DOOR_RELAY_NAME = "redstone_relay_0", -- relay wired to the door (side or network name)
    DOOR_SIDE = "front",                   -- side of that relay driving the door
    DOOR_RELAY_ENABLED = false,

    -- Chat Box peripheral used to send welcome/goodbye/closed toasts to players.
    -- Side or network name, same rule as DETECTOR_NAME above.
    CHATBOX_NAME = "chat_box_0",

    WELCOME_TITLE = "Welcome!",
    -- Random pick each visit, %s = BUILDING_NAME.
    WELCOME_MESSAGES = {
        "Welcome to %s!",
        "Welcome to %s -- have a great day!",
        "Hey, welcome to %s!",
        "Glad to have you at %s!",
        "Welcome aboard -- enjoy your stay at %s!",
    },

    BYE_TITLE = "Goodbye!",
    BYE_MESSAGES = {
        "Thanks for visiting %s, see you soon!",
        "Goodbye! Come back to %s anytime.",
        "See you later!",
        "Safe travels, thanks for stopping by %s!",
        "Bye! Hope to see you at %s again.",
    },

    -- Toast to everyone "inside" when the on-screen button flips to INACTIVE.
    CLOSED_TITLE = "Closed",
    CLOSED_MESSAGE = "We are closed.",

    POLL_INTERVAL = 1, -- seconds between detector scans

    -- Wireless modem to report status to ControlRoom. False if no modem.
    MODEM_NAME = "back",
    MODEM_ENABLED = false,
}
