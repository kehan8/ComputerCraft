-- test_blockreader.lua: FossilLab diagnose-script (test 4: Block Reader).
--
-- Advanced Peripherals' Block Reader leest de NBT/state van het blok
-- waar hij fysiek tegenaan geplaatst is (peripheral type "blockReader",
-- alias "block_reader"). Geen coordinaten, geen Command Computer, geen
-- OP nodig -- gewoon tegen de Fossil Analyzer (of Restoration Tank)
-- aanzetten en met Networking Cable naar de computer verbinden.
--
-- Functies (bevestigd via de Advanced Peripherals wiki):
--   getBlockName()   -> string        registry-naam, bv "cobblemon:fossil_analyzer"
--   getBlockData()   -> table | nil   NBT-achtige data (alleen bij tile entity)
--   getBlockStates() -> table | nil   blockstate-properties
--   isTileEntity()   -> boolean | nil
--
-- Dit script verandert NIETS -- puur read-only polling.
--
-- Gebruik: plaats een Block Reader tegen de Fossil Analyzer (en evt. een
-- 2e tegen de Restoration Tank), verbind via Networking Cable, run dit
-- script, start daarna een analyse/restauratie in-game. Druk op een
-- toets om te stoppen.

local INTERVAL = 1

local LOG_FILE = "test_blockreader_output.txt"
local logLines = {}

local function log(str)
    str = tostring(str)
    table.insert(logLines, str)
    print(str)
end

local function saveLog()
    local f = fs.open(LOG_FILE, "w")
    f.write(table.concat(logLines, "\n"))
    f.close()
end

-- Zoek alle Block Reader peripherals. We vertrouwen niet blind op de
-- exacte type-naam (blockReader vs block_reader) -- check op de
-- karakteristieke methods, net als test_redstone.lua doet.
local readers = {}
for _, name in ipairs(peripheral.getNames()) do
    local methods = peripheral.getMethods(name) or {}
    local methodSet = {}
    for _, m in ipairs(methods) do methodSet[m] = true end

    if methodSet.getBlockData and methodSet.getBlockName then
        table.insert(readers, { name = name, p = peripheral.wrap(name), ptype = peripheral.getType(name) })
    end
end

if #readers == 0 then
    log("Geen Block Reader gevonden (geen getBlockData/getBlockName methods).")
    log("Check: zit de Block Reader tegen het blok aan, en verbonden met")
    log("Networking Cable naar dezelfde modem-lijn als de computer?")
    saveLog()
    return
end

log("Gevonden Block Reader(s): " .. #readers)
for _, r in ipairs(readers) do
    log("  - " .. r.name .. " (type: " .. tostring(r.ptype) .. ")")
end
log("Start nu de Fossil Analyzer of Restoration Tank en let op waardes.")
log("Druk op een toets om te stoppen.")
log(string.rep("-", 40))

-- Zoekt recursief naar interessante NBT-velden in de getBlockData()-tabel,
-- ongeacht op welk niveau ze genest zitten (we weten nog niet of ze plat
-- staan of ergens onder genest, bv. onder "tag").
local INTERESTING = {
    OrganicContent = true, TimeLeft = true, ProtectedTimeLeft = true,
    HasCreatedPokemon = true, InsertedFossil = true, ConnectorDirection = true,
    MonitorPos = true, ControllerBlock = true,
}

local function findInteresting(tbl, path, out, seen)
    if type(tbl) ~= "table" then return end
    seen = seen or {}
    if seen[tbl] then return end
    seen[tbl] = true

    for k, v in pairs(tbl) do
        local p = path == "" and tostring(k) or (path .. "." .. tostring(k))
        if INTERESTING[k] then
            table.insert(out, p .. " = " .. tostring(v))
        end
        if type(v) == "table" then
            findInteresting(v, p, out, seen)
        end
    end
end

local running = true
local lastSerialized = {}

parallel.waitForAny(
    function()
        while running do
            local ts = textutils.formatTime(os.time(), true)
            for _, r in ipairs(readers) do
                local okName, blockName = pcall(r.p.getBlockName)
                local okTile, isTile = pcall(r.p.isTileEntity)
                local okData, data = pcall(r.p.getBlockData)

                local dataStr
                if okData and type(data) == "table" then
                    local okSer, ser = pcall(textutils.serialize, data)
                    dataStr = okSer and ser or ("SERIALIZE-FOUT: " .. tostring(ser))
                else
                    dataStr = tostring(data)
                end

                local serialized = tostring(blockName) .. "|" .. tostring(isTile) .. "|" .. dataStr

                if serialized ~= lastSerialized[r.name] then
                    lastSerialized[r.name] = serialized

                    if not okName then
                        log("[" .. ts .. "] " .. r.name .. " getBlockName FOUT: " .. tostring(blockName))
                    end
                    if not okTile then
                        log("[" .. ts .. "] " .. r.name .. " isTileEntity FOUT: " .. tostring(isTile))
                    end

                    log("[" .. ts .. "] " .. r.name .. " name=" .. tostring(blockName) .. " tile=" .. tostring(isTile))

                    if not okData then
                        log("[" .. ts .. "] " .. r.name .. " getBlockData FOUT: " .. tostring(data))
                    elseif type(data) ~= "table" then
                        log("[" .. ts .. "] " .. r.name .. " getBlockData = nil (geen tile entity, of niks te lezen)")
                    else
                        log("[" .. ts .. "] " .. r.name .. " RAW getBlockData: " .. dataStr)
                        local found = {}
                        findInteresting(data, "", found)
                        if #found > 0 then
                            log("[" .. ts .. "] " .. r.name .. " => " .. table.concat(found, ", "))
                        end
                    end
                end
            end
            sleep(INTERVAL)
        end
    end,
    function()
        os.pullEvent("key")
        running = false
    end
)

log(string.rep("-", 40))
log("Gestopt. Alles staat ook in " .. LOG_FILE .. ".")
log("Optioneel: 'pastebin put " .. LOG_FILE .. "' voor een linkje (HTTP nodig).")
saveLog()
