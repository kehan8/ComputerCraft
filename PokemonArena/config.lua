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

    MONITOR = nil, -- optional Monitor peripheral name (e.g. "monitor_0") to
                   -- mirror the whole Basalt2 UI onto instead of the
                   -- computer's own terminal. Leave nil to keep using the
                   -- computer's screen (default, what we've been testing
                   -- with). Once the monitor is placed and wired, run
                   -- peripheral.getNames() to find its exact name (numeric
                   -- suffix depends on placement order).
    MONITOR_TEXT_SCALE = 1, -- only used if MONITOR is set; passed to
                            -- monitor.setTextScale(). Lower (e.g. 0.5) fits
                            -- more text on a small monitor; 1 is the
                            -- CC:Tweaked default.
}
