-- config.lua: your local settings for this computer.
-- update.lua does NOT touch this file, so your changes survive a normal update.
-- Run update_full.lua instead if you ever want this file reset back to the repo defaults.

return {
    MODEM_NAME = "back",  -- wireless modem used to talk to the other computers
    MODEM_ENABLED = true, -- ControlRoom needs a modem; this is here for consistency, not optional

    MONITOR_NAME = nil,   -- e.g. "monitor_0" to force a specific monitor; nil = auto-detect
    MONITOR_SCALE = 0.5,  -- text scale on the monitor

    -- Seconds without a status broadcast from a device before it's shown as "offline".
    HEARTBEAT_TIMEOUT = 8,

    -- How many device rows fit on ONE page of the monitor. All rows for a page
    -- are created up front (blank) at startup and filled in as devices broadcast
    -- -- Basalt doesn't reliably draw widgets added after basalt.run() has started.
    ROWS_PER_PAGE = 8,

    -- Safety cap on the total number of *distinct* devices ControlRoom will ever
    -- track, across ALL pages combined. Raise this if you have more devices than
    -- this in total -- extra devices beyond ROWS_PER_PAGE just land on page 2, 3, ...
    -- reachable via the "< Prev" / "Next >" buttons, no monitor resize needed.
    MAX_DEVICES = 32,
}
