-- fossildata.lua: reads and interprets the Fossil Analyzer / Restoration Tank
-- multiblock state via a Block Reader peripheral (Advanced Peripherals).
--
-- The Block Reader must be placed directly against the Fossil Analyzer (or the
-- Restoration Tank -- either works, they share one MultiblockStore) and
-- connected to the network via Networking Cable. It reports the full NBT of
-- whichever block it physically touches through getBlockData(); see
-- test_blockreader.lua for how this was confirmed in-game.
--
-- Confirmed NBT shape (live-tested 2026-09):
--   Formed                               -- 1 once the multiblock is fully assembled
--   MultiblockStore.OrganicContent       -- 0-128 progress scale during analysis
--   MultiblockStore.TimeLeft             -- ticks left in the analysis, -1 if none running
--   MultiblockStore.ProtectedTimeLeft    -- ticks left to claim a created Pokemon, -1 if n/a
--   MultiblockStore.HasCreatedPokemon    -- 0/1, 1 once a Pokemon exists (until claimed)
--   MultiblockStore.InsertedFossil       -- species id string, only present once created
--   MultiblockStore.InsertedFossilStacks -- { {id=, count=}, ... } fossils currently inserted
--   MultiblockStore.ConnectorDirection
--
-- Observed state machine (4 phases, see project memory for the full log trail):
--   idle      -- nothing inserted, nothing to claim
--   analyzing -- fossil(s) inserted, OrganicContent climbing 0->128, TimeLeft counting down
--   ready     -- HasCreatedPokemon=1, InsertedFossil set, ProtectedTimeLeft counting down
--   unformed  -- Formed ~= 1, multiblock isn't fully built right now

local fossildata = {}

local MAX_ORGANIC_CONTENT = 128
local TICKS_PER_SECOND = 20

-- Finds the Block Reader peripheral. Prefers `name` if given (from config.lua's
-- BLOCKREADER_NAME), otherwise auto-detects by method signature -- the exact
-- peripheral type string ("blockReader" vs "block_reader") isn't trustworthy
-- across Advanced Peripherals versions, so this checks for the methods
-- themselves instead, same approach as test_blockreader.lua.
function fossildata.findReader(name)
    if name then
        local p = peripheral.wrap(name)
        if p and p.getBlockData and p.getBlockName then
            return p
        end
        return nil
    end

    for _, n in ipairs(peripheral.getNames()) do
        local methods = peripheral.getMethods(n) or {}
        local methodSet = {}
        for _, m in ipairs(methods) do methodSet[m] = true end
        if methodSet.getBlockData and methodSet.getBlockName then
            return peripheral.wrap(n)
        end
    end
    return nil
end

-- Converts ticks (TimeLeft/ProtectedTimeLeft, confirmed 20 ticks/sec against a
-- ~12-minute in-game analysis) into "m:ss". Returns "--:--" for -1/nil (nothing
-- running/protected right now).
function fossildata.formatTicks(ticks)
    if not ticks or ticks < 0 then return "--:--" end
    local totalSeconds = math.floor(ticks / TICKS_PER_SECOND)
    local m = math.floor(totalSeconds / 60)
    local s = totalSeconds % 60
    return string.format("%d:%02d", m, s)
end

-- Reads the current state from the Block Reader and returns a clean snapshot.
-- Returns nil + an error string for any soft failure (Block Reader unplugged,
-- not touching a tile entity, wrong block, ...) -- never throws, so callers
-- can just show the error string instead of crashing the UI loop.
function fossildata.read(reader)
    local okName, blockName = pcall(reader.getBlockName)
    if not okName then return nil, "getBlockName error: " .. tostring(blockName) end

    local okData, data = pcall(reader.getBlockData)
    if not okData then return nil, "getBlockData error: " .. tostring(data) end
    if type(data) ~= "table" then return nil, "no block data (not touching a tile entity?)" end

    local store = data.MultiblockStore
    if type(store) ~= "table" then return nil, "no MultiblockStore (wrong block?)" end

    local formed = (data.Formed == 1 or data.Formed == true)
    local organicContent = tonumber(store.OrganicContent) or 0
    local timeLeft = tonumber(store.TimeLeft) or -1
    local protectedTimeLeft = tonumber(store.ProtectedTimeLeft) or -1
    local hasCreatedPokemon = (tonumber(store.HasCreatedPokemon) or 0) ~= 0
    local stacks = store.InsertedFossilStacks or {}

    local phase
    if not formed then
        phase = "unformed"
    elseif hasCreatedPokemon then
        phase = "ready" -- Pokemon created, waiting to be claimed
    elseif timeLeft > 0 or organicContent > 0 or #stacks > 0 then
        phase = "analyzing"
    else
        phase = "idle"
    end

    return {
        blockName = blockName,
        formed = formed,
        phase = phase,
        organicContent = organicContent,
        percent = math.floor(organicContent / MAX_ORGANIC_CONTENT * 100 + 0.5),
        timeLeft = timeLeft,
        protectedTimeLeft = protectedTimeLeft,
        hasCreatedPokemon = hasCreatedPokemon,
        insertedFossil = store.InsertedFossil, -- only present once phase == "ready"
        insertedFossilStacks = stacks,
        connectorDirection = store.ConnectorDirection,
    }
end

return fossildata
