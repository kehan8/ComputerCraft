-- scan.lua: turns raw Environment Detector scanEntities() output into
-- "which owned Pokemon + which trainer is active per podium", with
-- cross-podium dedup (see scanAllPodiums below). Split out of startup.lua
-- (session 8 module refactor) -- pure scan/detection logic, no UI, no
-- match-tracking state. update.lua/update_full.lua redownload this file
-- like any other code file.

local scan = {}

-- Cobblemon Pokemon entities always report a "baby" field; players, Loot
-- Balls, etc. never do. Cheap filter, no datapack needed for this part.
function scan.isPokemon(entity)
    return entity.baby ~= nil
end

function scan.hasTag(entity, tag)
    if not entity.tags then
        return false
    end
    for _, t in ipairs(entity.tags) do
        if t == tag then
            return true
        end
    end
    return false
end

-- scanEntities() coordinates are relative to the detector itself, so this
-- is plain distance-from-detector.
local function distanceSquared(entity)
    return entity.x * entity.x + entity.y * entity.y + entity.z * entity.z
end

-- Distance between two scanned entities (both coordinates are relative to
-- the same detector, i.e. the same origin, so this is just their delta).
-- Used to find the player standing closest to the Pokemon actually being
-- shown, not just closest to the detector block in general.
local function distanceSquaredBetween(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return dx * dx + dy * dy + dz * dz
end

-- One scanEntities() call per podium per cycle (the detector has its own
-- ~2s cooldown -- see config.lua's POLL_INTERVAL comment -- so calling it
-- twice per cycle would starve the second call).
--
-- Trainer candidate: used to require "nearest entity without a baby
-- field", but that also matches ordinary mobs (confirmed in-game: a
-- wandering Bat got shown as "Trainer: Bat"). Now requires the PLAYER_TAG
-- (set on every real player by the datapack, see ../datapack/), and is
-- measured from the shown Pokemon rather than from the detector, so a
-- second player merely walking closer to the podium than the real trainer
-- can't outrank them. update() (startup.lua) additionally *locks* this
-- guess per Pokemon uuid so it's only computed once per send-out, not
-- re-guessed every scan.
--
-- Cross-podium ownership: RADIUS is documented (config.lua) to see the
-- *whole* arena from every detector on a small setup, not just its own
-- podium. That's normally harmless -- each detector's own "nearest owned
-- Pokemon" is naturally its own podium's Pokemon -- but confirmed in-game
-- to break down when one side is genuinely empty (no active Pokemon of its
-- own): the empty podium's "nearest owned Pokemon" then resolves to the
-- *other* podium's Pokemon (the only one on the field), which that empty
-- podium happily displayed as its own and then never cleared, since as
-- far as its own scan is concerned that Pokemon never leaves. Reported as
-- "2 identical trainer names" / a stale name that only "New Battle" could
-- clear. Fixed by resolving each Pokemon uuid to exactly one podium --
-- whichever podium's detector reports it as physically closer -- across
-- ALL podiums first, so every other podium simply never sees it as a
-- candidate and correctly falls through to its own miss-count/clear path.
function scan.scanAllPodiums(podiums, radius, ownedTag, playerTag)
    local raw = {}
    for i, podium in ipairs(podiums) do
        local ok, entities = pcall(podium.detectorPeripheral.scanEntities, radius)
        local candidates, players = {}, {}
        if ok and type(entities) == "table" then
            for _, entity in ipairs(entities) do
                if scan.isPokemon(entity) and scan.hasTag(entity, ownedTag) then
                    candidates[#candidates + 1] = { entity = entity, dist = distanceSquared(entity) }
                elseif scan.hasTag(entity, playerTag) then
                    players[#players + 1] = entity
                end
            end
        end
        raw[i] = { candidates = candidates, players = players }
    end

    -- Resolve each seen Pokemon uuid to whichever podium's detector is
    -- physically closest to it (smallest reported distance wins). Entities
    -- with no uuid (shouldn't normally happen for a real Cobblemon Pokemon)
    -- are never deduplicated, so they can't accidentally starve every
    -- podium of a candidate.
    local bestPodiumForUuid = {} -- uuid -> podium index
    for i, r in ipairs(raw) do
        for _, c in ipairs(r.candidates) do
            local uuid = c.entity.uuid
            if uuid then
                local best = bestPodiumForUuid[uuid]
                if not best or c.dist < best.dist then
                    bestPodiumForUuid[uuid] = { index = i, dist = c.dist }
                end
            end
        end
    end

    local results = {}
    for i, r in ipairs(raw) do
        local nearestPokemon, nearestPokemonDist = nil, nil
        for _, c in ipairs(r.candidates) do
            local uuid = c.entity.uuid
            local ownedByThisPodium = (not uuid) or (bestPodiumForUuid[uuid].index == i)
            if ownedByThisPodium and (not nearestPokemon or c.dist < nearestPokemonDist) then
                nearestPokemon, nearestPokemonDist = c.entity, c.dist
            end
        end

        local nearestTrainer, nearestTrainerDist = nil, nil
        for _, player in ipairs(r.players) do
            local dist = nearestPokemon and distanceSquaredBetween(player, nearestPokemon) or distanceSquared(player)
            if not nearestTrainer or dist < nearestTrainerDist then
                nearestTrainer, nearestTrainerDist = player, dist
            end
        end

        results[i] = { pokemon = nearestPokemon, trainer = nearestTrainer }
    end
    return results
end

return scan
