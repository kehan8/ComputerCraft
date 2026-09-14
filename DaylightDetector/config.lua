-- Your local settings. update.lua leaves this alone; update_full.lua resets it.

return {
    -- This computer's own redstone output side(s). Empty list = none.
    COMPUTER_SIDES = { "back" },

    -- Redstone Relay peripherals (Wired Modem setups). Each relay is its own
    -- self-contained {name, side} pair, so name/side can never get mismatched
    -- when you add more. Empty list = none.
    RELAYS = {
        -- { name = "redstone_relay_0", side = "front" },
    },

    -- Create Sequenced Gearshifts, each attached directly to a side. angle/speed
    -- live per-gearshift since different contraptions may need different
    -- rotation amounts. Empty list = none.
    GEARSHIFTS = {
        -- { side = "back", angle = 180, speed = 1 },
    },

    -- Wireless modem to report status to ControlRoom. False if no modem.
    MODEM_NAME = "back",
    MODEM_ENABLED = false,

    -- Dusk/dawn clock (HH:MM, in-game time). Signal is ON from dusk until dawn.
    DUSK_HOUR = 18,
    DUSK_MINUTE = 32,
    DAWN_HOUR = 5,
    DAWN_MINUTE = 27,

    POLL_INTERVAL = 1, -- seconds between clock/signal updates
}
