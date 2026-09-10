-- Your local settings. update.lua leaves this alone; update_full.lua resets it.

return {
    -- This computer's own redstone side.
    COMPUTER_SIDE = "back",
    COMPUTER_ENABLED = true,

    -- Redstone Relay peripheral (Wired Modem setups).
    REDSTONE_RELAY_NAME = "redstone_relay_0",
    REDSTONE_SIDE = "front",
    REDSTONE_RELAY_ENABLED = false,

    -- Create Sequenced Gearshift, attached directly to a side (not a wired
    -- network name). Rotates a switch (e.g. HV Switch 100A) at dusk/dawn,
    -- for when redstone's ~16A cap is too low.
    GEARSHIFT_SIDE = "back",
    GEARSHIFT_ENABLED = false,
    GEARSHIFT_ANGLE = 180,  -- degrees per rotation
    GEARSHIFT_SPEED = 1,    -- sign = direction

    -- Wireless modem to report status to ControlRoom. False if no modem.
    MODEM_NAME = "back",
    MODEM_ENABLED = false,

    -- Dusk/dawn clock (HH:MM). Signal is ON from dusk until dawn.
    -- In-game clock, NOT real time (1 day ~= 20 IRL min).
    DUSK_HOUR = 18,
    DUSK_MINUTE = 32,
    DAWN_HOUR = 5,
    DAWN_MINUTE = 27,

    POLL_INTERVAL = 1, -- seconds between clock/signal updates
}
