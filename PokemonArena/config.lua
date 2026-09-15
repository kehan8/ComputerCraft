-- config.lua: local settings. update.lua won't touch this; update_full.lua resets it.

return {
    RADIUS = 8, -- scanEntities() radius per detector, NOT a cube side: this
                 -- is a half-width, so scanEntities(16) scans a 32x32x32
                 -- cube (2*RADIUS per side) centered on the detector.
                 -- Confirmed in-game: both podiums see entities across the
                 -- whole arena at this radius; it's the "nearest owned tag
                 -- per podium" logic in startup.lua (not the radius itself)
                 -- that makes each side show its own Pokemon. 16 is also
                 -- the practical max we've measured (17+ always returns "no
                 -- entities found", even standing still with the same
                 -- entities present, and getConfiguration() doesn't show
                 -- this cap). Raise this only if the server admin raises
                 -- the underlying limit.

    -- Tags set by the tag_ownership datapack function (see ../datapack/) on
    -- every Cobblemon Pokemon, based on Pokemon.PokemonOriginalTrainerType.
    -- scanEntities() itself has no ownership info, hence the datapack.
    OWNED_TAG = "pa_owned", -- trainer-owned Pokemon; this is what gets shown
    WILD_TAG = "pa_wild",   -- wild-spawned Pokemon; currently unused by startup.lua, kept for debugging/future use

    POLL_INTERVAL = 2.2, -- seconds between scans; slightly above the detector's own ~2s cooldown (see Test_Debug/test_entities.lua)

    TEAM_SIZE = 1, -- default/fallback team size (1-6), used only the very
                   -- first time this computer runs (before team_sizes.dat
                   -- exists) and for any podium missing from a stale
                   -- team_sizes.dat (e.g. after adding a podium to
                   -- locations.lua). Once you've clicked "New Battle" ->
                   -- chosen sizes -> "Start Battle" at least once in-game,
                   -- the real per-podium team sizes live in team_sizes.dat
                   -- instead (see startup.lua) and this value is ignored.
                   -- team_sizes.dat is NOT touched by update.lua/
                   -- update_full.lua, same reasoning as config.lua itself.

    MONITOR_NAME = nil, -- e.g. "monitor_0" to force a specific monitor;
                        -- nil = auto-detect via peripheral.find("monitor")
                        -- -- same convention as GymArena/SimonSays and
                        -- GymArena/TicTacToe, so any wired Advanced Monitor
                        -- is picked up automatically with zero config, no
                        -- need to look up peripheral.getNames(). Falls back
                        -- to the computer's own screen only if no monitor
                        -- is found at all. Set this only if you have
                        -- multiple monitors and need to pick a specific one.
    MONITOR_SCALE = 1, -- passed to monitor.setTextScale() when a monitor is
                       -- in use. Lower (e.g. 0.5) fits more text on a small
                       -- monitor; 1 is the CC:Tweaked default.

    HISTORY_MAX_ENTRIES = 20, -- how many recent matches match_history.dat
                              -- remembers (oldest drop off first), shown on
                              -- the "History" screen (New Battle's neighbor
                              -- button on the live screen). Same convention
                              -- as FossilLab's HISTORY_MAX_ENTRIES.
}
