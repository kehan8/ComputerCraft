-- config.lua: local settings. update.lua won't touch this; update_full.lua resets it.

return {
    -- Shown in messages via %s.
    BUILDING_NAME = "Your Building",

    -- Player Detector, checks both boxes from locations.lua.
    -- Side name or network name; see peripheral.getNames().
    DETECTOR_NAME = "player_detector_0",

    -- Drives the door: computer redstone, a Redstone Relay, or both.
    COMPUTER_SIDE = "back",
    COMPUTER_ENABLED = true,

    DOOR_RELAY_NAME = "redstone_relay_0", -- relay wired to the door (side or network name)
    DOOR_SIDE = "front",                   -- side of that relay driving the door
    DOOR_RELAY_ENABLED = false,

    -- Chat Box for welcome/goodbye/closed toasts. Side or network name.
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

    -- Toast while INACTIVE: once on close, plus to new arrivals at the door.
    CLOSED_TITLE = "Closed",
    CLOSED_MESSAGE = "We are closed.",

    POLL_INTERVAL = 1, -- seconds between scans

    -- Wireless modem for ControlRoom status.
    MODEM_NAME = "back",
    MODEM_ENABLED = false,
}
