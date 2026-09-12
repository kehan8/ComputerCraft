-- config.lua: your local settings for this door.
-- update.lua does NOT touch this file, so your changes survive a normal update.
-- Run update_full.lua instead if you ever want this file reset back to the repo defaults.

return {
    -- Shown in the welcome/goodbye/closed messages via %s.
    BUILDING_NAME = "Your Building",

    -- Door detector: small range right at the door. Opens door + sends welcome.
    DETECTOR_NAME = "player_detector_0",
    DETECT_RANGE = 3,

    -- Building detector: large range covering the whole building. Sends goodbye
    -- + resets the player once they drop out of this range. False = door detector
    -- handles both alone (less accurate, no 2nd detector needed).
    BUILDING_DETECTOR_ENABLED = true,
    BUILDING_DETECTOR_NAME = "player_detector_1",
    BUILDING_DETECT_RANGE = 25,

    -- Drive the door via computer redstone side, a Redstone Relay, or both.
    COMPUTER_SIDE = "back",
    COMPUTER_ENABLED = false,

    DOOR_RELAY_NAME = "redstone_relay_0", -- relay wired to the door
    DOOR_SIDE = "front",                   -- side of that relay driving the door
    DOOR_RELAY_ENABLED = true,

    -- Chat Box peripheral used to send welcome/goodbye/closed toasts to players.
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
