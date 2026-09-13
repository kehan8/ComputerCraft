-- config.lua: local settings, not touched by update.lua (see README).

return {
    MODEM_NAME = "back",  -- wireless modem used to talk to the other computers
    MODEM_ENABLED = true, -- ControlRoom always needs a modem

    MONITOR_NAME = nil,   -- nil = auto-detect
    MONITOR_SCALE = 0.5,  -- text scale on the monitor

    HEARTBEAT_TIMEOUT = 8, -- seconds without a broadcast before a device shows "offline"
    ROWS_PER_PAGE = 8,     -- device rows per monitor page
    MAX_DEVICES = 32,      -- total distinct devices tracked across all pages
}
