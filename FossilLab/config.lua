-- config.lua: local settings. update.lua won't touch this; update_full.lua resets it.

return {
    -- Block Reader (Advanced Peripherals) placed against the Fossil Analyzer or
    -- Restoration Tank -- either works, they share one MultiblockStore.
    -- e.g. "block_reader_0" to force a specific one; nil = auto-detect.
    BLOCKREADER_NAME = nil,

    -- Seconds between reads of the Block Reader / UI refreshes.
    POLL_INTERVAL = 1,

    -- Monitor for the public "cool" status display.
    -- e.g. "monitor_0" to force a specific monitor; nil = auto-detect.
    -- No touch support needed (nothing on screen is clickable), so a plain
    -- Monitor is fine -- doesn't have to be an Advanced Monitor.
    MONITOR_NAME = nil,
    MONITOR_SCALE = 0.5,

    -- How many past restorations fossil_history.txt remembers (oldest drop off).
    HISTORY_MAX_ENTRIES = 20,

    -- Wireless modem for ControlRoom status.
    MODEM_NAME = "back",
    MODEM_ENABLED = false,
    HEARTBEAT_INTERVAL = 2, -- seconds between status broadcasts to ControlRoom
}
