-- config.lua: your local settings for this puzzle.
-- update.lua does NOT touch this file, so your changes survive a normal update.
-- Run update_full.lua instead if you ever want this file reset back to the repo defaults.

return {
    -- Signal via THIS computer's redstone side (no peripheral, limited reach).
    COMPUTER_SIDE = "back",
    COMPUTER_ENABLED = true,

    -- Signal via a Redstone Relay peripheral (for Wired Modem setups).
    REDSTONE_RELAY_NAME = "redstone_relay_0",
    REDSTONE_SIDE = "front",
    REDSTONE_RELAY_ENABLED = false,

    -- Signal via a Create "Sequenced Gearshift" (rotates a switch, e.g. HV
    -- Switch 100A -- for when redstone's ~16A cap is too low). Rotates at
    -- dusk, back at dawn.
    GEARSHIFT_NAME = "right",
    GEARSHIFT_ENABLED = false,
    GEARSHIFT_ANGLE = 180,  -- degrees per rotation
    GEARSHIFT_SPEED = 1,    -- sign = direction

    -- Wireless modem to report status to ControlRoom. False if no modem.
    MODEM_NAME = "back",
    MODEM_ENABLED = false,

    -- Dusk/dawn clock (HH:MM). Signal is ON from dusk until dawn.
    -- NOTE: in-game Minecraft clock, NOT real time (1 day ~= 20 IRL min).
    DUSK_HOUR = 18,
    DUSK_MINUTE = 32,
    DAWN_HOUR = 5,
    DAWN_MINUTE = 27,

    POLL_INTERVAL = 1, -- seconds between clock/signal updates
}
