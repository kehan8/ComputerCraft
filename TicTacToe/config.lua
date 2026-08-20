-- config.lua: your local settings for this puzzle.
-- update.lua does NOT touch this file, so your changes survive a normal update.
-- Run update_full.lua instead if you ever want this file reset back to the repo defaults.

return {
    MONITOR_NAME = nil,        -- e.g. "monitor_0" to force a specific monitor; nil = auto-detect
    MONITOR_SCALE = 0.5,       -- text scale on the monitor; lower = more resolution for the icons, higher = bigger/easier to read from afar
    REDSTONE_RELAY_NAME = "redstone_relay_0", -- name of your Redstone Relay peripheral
    REDSTONE_SIDE = "back",                   -- side of the relay that goes high once the player wins
}
