-- scan.lua: turns raw Environment Detector scanEntities() output into "which
-- owned Pokemon + which trainer is active per podium", with cross-podium
-- dedup so an empty podium can't borrow another podium's Pokemon.

local scan = {}

-- Cobblemon Pokemon entities always report a "baby" field; players, Loot
-- Balls, etc. never do.
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

-- scanEntities() coordinates are relative to the detector itself
local function distanceSquared(entity)
    return entity.x * entity.x + entity.y * entity.y + entity.z * entity.z
end

-- both entities share the same origin (the detector), so this is just their delta
local function distanceSquaredBetween(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return dx * dx + dy * dy + dz * dz
end

-- One scanEntities() call per podium per cycle (the detector has its own
-- ~2s cooldown -- see config.lua). Trainer candidate must carry PLAYER_TAG
-- (so ordinary mobs never qualify) and is measured from the shown Pokemon
-- rather than the detector, so a bystander walking closer can't outrank the
-- real trainer; update() in startup.lua additionally locks this guess per
-- Pokemon uuid so it's only computed once per send-out.
--
-- Cross-podium dedup: RADIUS is big enough that every detector can see the
-- whole arena, not just its own podium. Each seen Pokemon uuid is resolved
-- to whichever podium's detector reports it as physically closest, so an
-- empty podium never "borrows" the only Pokemon on the field from another.
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

    -- resolve each seen Pokemon uuid to whichever podium's detector is
    -- physically closest to it (smallest reported distance wins)
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
