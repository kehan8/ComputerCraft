-- config.lua: your local settings for this puzzle.
-- update.lua does NOT touch this file, so your changes survive a normal update.
-- Run update_full.lua instead if you ever want this file reset back to the repo defaults.

return {
    -- Signal via THIS computer's own redstone output -- no peripheral needed,
    -- but only works if the computer itself is physically wired to what you want
    -- to drive (can't reach everywhere).
    COMPUTER_SIDE = "back",  -- side of this computer that goes high during the signal
    COMPUTER_ENABLED = true,

    -- Signal via a Redstone Relay peripheral instead -- use this when the computer
    -- can't be wired directly and you route through a Wired Modem + relay instead.
    REDSTONE_RELAY_NAME = "redstone_relay_0", -- name of your Redstone Relay peripheral
    REDSTONE_SIDE = "front",                   -- side of the relay that goes high during the signal
    REDSTONE_RELAY_ENABLED = false,

    -- Wireless modem used to report status to the ControlRoom computer (see ../ControlRoom).
    -- Set MODEM_ENABLED = false if this computer has no modem attached.
    MODEM_NAME = "back",
    MODEM_ENABLED = false,

    -- Dusk/dawn clock thresholds for when the signal turns on. Wraps past midnight:
    -- signal is ON from dusk until dawn.
    --
    -- IMPORTANT: this is Minecraft's own in-game daylight-cycle clock, NOT your real
    -- (IRL) wall-clock time! A full Minecraft day/night cycle only takes ~20 real-life
    -- minutes, so this clock races by much faster than a real clock -- it does not
    -- stay at e.g. 18:32 for a real hour like your actual clock would.
    -- Format is normal HH:MM (minutes 0-59), same as any clock -- no decimals to
    -- misread (os.time("ingame") itself uses a fractional-hour decimal internally,
    -- e.g. 18.54 actually means 18:32, NOT 18:54 -- startup.lua converts these
    -- HOUR/MINUTE fields for you so you never have to deal with that).
    DUSK_HOUR = 18,   -- signal turns on at/after this time (evening)
    DUSK_MINUTE = 32,
    DAWN_HOUR = 5,    -- signal turns off once time reaches this (morning)
    DAWN_MINUTE = 27,

    POLL_INTERVAL = 1, -- seconds between clock/signal updates
}
