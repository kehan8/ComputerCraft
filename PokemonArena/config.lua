-- config.lua: local settings. update.lua won't touch this; update_full.lua resets it.

return {
    RADIUS = 16, -- scanEntities() cube radius per detector. 16 is the practical
                 -- max we've measured (17+ always returns "no entities found",
                 -- even standing still with the same entities present, and
                 -- getConfiguration() doesn't show this cap). Raise this only
                 -- if the server admin raises the underlying limit.

    -- Tags set by the tag_ownership datapack function (see ../datapack/) on
    -- every Cobblemon Pokemon, based on Pokemon.PokemonOriginalTrainerType.
    -- scanEntities() itself has no ownership info, hence the datapack.
    OWNED_TAG = "pa_owned", -- trainer-owned Pokemon; this is what gets shown
    WILD_TAG = "pa_wild",   -- wild-spawned Pokemon; currently unused by startup.lua, kept for debugging/future use

    POLL_INTERVAL = 2.2, -- seconds between scans; slightly above the detector's own ~2s cooldown (see Test_Debug/test_entities.lua)
}
