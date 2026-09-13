-- fossildata.lua: reads the Fossil Analyzer/Restoration Tank multiblock state
-- via a Block Reader peripheral (Advanced Peripherals). NBT shape and state
-- machine: see FossilLab/README.md.

local fossildata = {}

local MAX_ORGANIC_CONTENT = 128
local TICKS_PER_SECOND = 20

-- finds the Block Reader by name, else auto-detects by method signature
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

-- ticks -> "m:ss", "--:--" for -1/nil
function fossildata.formatTicks(ticks)
    if not ticks or ticks < 0 then return "--:--" end
    local totalSeconds = math.floor(ticks / TICKS_PER_SECOND)
    local m = math.floor(totalSeconds / 60)
    local s = totalSeconds % 60
    return string.format("%d:%02d", m, s)
end

-- reads a clean state snapshot; returns nil + error string on soft failure
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
