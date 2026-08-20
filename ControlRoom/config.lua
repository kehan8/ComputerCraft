-- config.lua: your local settings for this computer.
-- update.lua does NOT touch this file, so your changes survive a normal update.
-- Run update_full.lua instead if you ever want this file reset back to the repo defaults.

return {
    MODEM_NAME = "back",  -- wireless modem used to talk to the other computers

    MONITOR_NAME = nil,   -- e.g. "monitor_0" to force a specific monitor; nil = auto-detect
    MONITOR_SCALE = 0.5,  -- text scale on the monitor

    -- Seconds without a status broadcast from a device before it's shown as "offline".
    HEARTBEAT_TIMEOUT = 8,
}
