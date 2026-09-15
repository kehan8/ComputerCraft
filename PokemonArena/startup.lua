-- PokemonArena: shows the active (non-balled) Pokemon + HP for each podium,
-- using one Environment Detector per podium. Plain-text v1 - no Basalt2,
-- no colors, no chatbox (by design, see todo.txt). Everything on screen.

-- ====================== CONFIG ======================
local config = require("config")
local RADIUS = config.RADIUS
local OWNED_TAG = config.OWNED_TAG
local POLL_INTERVAL = config.POLL_INTERVAL

local locations = require("locations")

if not locations.PODIUMS or #locations.PODIUMS == 0 then
    error("locations.lua must define PODIUMS with at least one podium table (see locations.lua).")
end

-- self-contained podium tables: label + detector + tracked state together
local podiums = {}
for i, raw in ipairs(locations.PODIUMS) do
    local position = raw.position or ("Podium " .. i)

    if not raw.detector then
        error("locations.lua: podium '" .. position .. "' needs a detector.")
    end

    podiums[i] = {
        position = position,
        detectorName = raw.detector,
        detectorPeripheral = nil, -- wrapped below, once peripherals are set up

        -- last known active Pokemon for this podium, kept across scans that
        -- briefly miss it so the screen doesn't flicker blank
        lastUuid = nil,
        lastName = nil,
        lastHealth = nil,
        lastMaxHealth = nil,
        missCount = 0,
    }
end
-- ======================================================

local function wrapPeripheral(name, label)
    local p = peripheral.wrap(name)
    if not p then
        error("Could not find " .. label .. " '" .. name .. "'. Check the cable/name.")
    end
    return p
end

-- wrap detectors now so a typo'd name fails fast at startup
for _, podium in ipairs(podiums) do
    podium.detectorPeripheral = wrapPeripheral(podium.detectorName, "Environment Detector for podium '" .. podium.position .. "'")
end

-- Cobblemon Pokemon entities always report a "baby" field; players, Loot
-- Balls, etc. never do. Cheap filter, no datapack needed for this part.
local function isPokemon(entity)
    return entity.baby ~= nil
end

local function hasTag(entity, tag)
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

-- Nearest trainer-owned (non-wild) Pokemon to this podium's detector, or nil.
-- Relies on the tag_ownership datapack function tagging entities with
-- OWNED_TAG/WILD_TAG (see ../datapack/) - scanEntities() itself has no
-- ownership info.
local function findActivePokemon(podium)
    local ok, entities = pcall(podium.detectorPeripheral.scanEntities, RADIUS)
    if not ok or type(entities) ~= "table" then
        return nil
    end

    local nearest, nearestDist = nil, nil
    for _, entity in ipairs(entities) do
        if isPokemon(entity) and hasTag(entity, OWNED_TAG) then
            local dist = distanceSquared(entity)
            if not nearest or dist < nearestDist then
                nearest, nearestDist = entity, dist
            end
        end
    end
    return nearest
end

-- ====================== DISPLAY ======================
local BAR_WIDTH = 20

local function healthBar(health, maxHealth)
    if not health or not maxHealth or maxHealth <= 0 then
        return string.rep("-", BAR_WIDTH)
    end
    local filled = math.floor(BAR_WIDTH * math.min(health, maxHealth) / maxHealth + 0.5)
    filled = math.max(0, math.min(BAR_WIDTH, filled))
    return string.rep("#", filled) .. string.rep("-", BAR_WIDTH - filled)
end

local function render()
    term.clear()
    term.setCursorPos(1, 1)
    print("PokemonArena")
    print(string.rep("-", 40))

    for i, podium in ipairs(podiums) do
        print(podium.position .. ":")
        if podium.lastName then
            print("  " .. podium.lastName .. "  HP " .. (podium.lastHealth or 0) .. "/" .. (podium.lastMaxHealth or 0))
            print("  [" .. healthBar(podium.lastHealth, podium.lastMaxHealth) .. "]")
            if podium.lastHealth and podium.lastHealth <= 0 then
                print("  FAINTED")
            end
        else
            print("  (no Pokemon detected)")
        end
        if i < #podiums then
            print()
        end
    end
end

-- ====================== SCAN LOOP ======================
-- A scan briefly missing the active Pokemon (recall animation, scan
-- jitter) shouldn't blank the screen; only clear after MISS_LIMIT
-- consecutive misses.
local MISS_LIMIT = 2

local function update()
    for _, podium in ipairs(podiums) do
        local active = findActivePokemon(podium)
        if active then
            podium.lastUuid = active.uuid
            podium.lastName = active.name
            podium.lastHealth = active.health
            podium.lastMaxHealth = active.maxHealth
            podium.missCount = 0
        else
            podium.missCount = podium.missCount + 1
            if podium.missCount >= MISS_LIMIT then
                podium.lastUuid = nil
                podium.lastName = nil
                podium.lastHealth = nil
                podium.lastMaxHealth = nil
            end
        end
    end
    render()
end

render()
while true do
    update()
    os.sleep(POLL_INTERVAL)
end
