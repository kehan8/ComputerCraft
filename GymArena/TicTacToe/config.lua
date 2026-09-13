-- config.lua: local settings, not touched by update.lua (see README).

return {
    MONITOR_NAME = nil,        -- nil = auto-detect
    MONITOR_SCALE = 0.5,       -- text scale on the monitor
    REDSTONE_RELAY_NAME = "redstone_relay_0", -- Redstone Relay peripheral
    REDSTONE_SIDE = "front",                   -- side of the relay that goes high once the player wins

    -- Wireless modem to report status to ControlRoom. False if no modem.
    MODEM_NAME = "back",
    MODEM_ENABLED = false,
}
