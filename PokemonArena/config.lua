-- config.lua: local settings. update.lua won't touch this; update_full.lua resets it.

return {
    RADIUS = 8, -- scanEntities() half-width per detector; 16 is the practical max (17+ returns nothing)

    -- Tags set by the tag_ownership datapack function (see ../pokemonarena/)
    OWNED_TAG = "pa_owned",   -- trainer-owned Pokemon; this is what gets shown
    WILD_TAG = "pa_wild",     -- wild-spawned Pokemon; unused by startup.lua, kept for debugging
    PLAYER_TAG = "pa_player", -- set on every real player; used to pick the "Trainer:" name

    POLL_INTERVAL = 2.2, -- seconds between scans; slightly above the detector's own ~2s cooldown

    TEAM_SIZE = 1, -- fallback team size (1-6), only used before the first "Start Battle" (see team_sizes.dat)

    -- Monitor is always auto-detected via peripheral.find("monitor"); falls back to the computer's own screen
    MONITOR_SCALE = 1, -- passed to monitor.setTextScale()

    HISTORY_MAX_ENTRIES = 20, -- how many recent matches match_history.dat remembers

    -- Frame background. Must be one of the 16 named CC:Tweaked colors.* values
    -- (white/orange/magenta/lightBlue/yellow/lime/pink/gray/lightGray/cyan/
    -- purple/blue/brown/green/red/black) -- no arbitrary RGB.
    BACKGROUND_COLOR = colors.lightGray,
}
