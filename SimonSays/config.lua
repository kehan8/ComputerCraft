-- config.lua: your local settings for this puzzle.
-- update.lua does NOT touch this file, so your changes survive a normal update.
-- Run update_full.lua instead if you ever want this file reset back to the repo defaults.

return {
    MONITOR_NAME = nil,        -- e.g. "monitor_0" to force a specific monitor; nil = auto-detect
    MONITOR_SCALE = 0.5,       -- text scale on the monitor
    REDSTONE_RELAY_NAME = "redstone_relay_0", -- name of your Redstone Relay peripheral
    REDSTONE_SIDE = "back",                   -- side of the relay that goes high once solved

    WIN_LENGTH = 6,            -- pattern length (rounds) needed to solve the puzzle
    FLASH_TIME = 0.6,          -- seconds a pad stays lit during playback
    GAP_TIME = 0.25,           -- seconds between pads during playback
    ROUND_START_DELAY = 1,     -- pause before playback starts each round
    NEXT_ROUND_DELAY = 0.8,    -- pause after a correct round before the next one plays
    CLICK_FLASH_TIME = 0.15,   -- how long a pad stays lit when the player taps it
    WRONG_FLASH_TIME = 0.2,    -- on/off timing for the red "wrong" flash
}
