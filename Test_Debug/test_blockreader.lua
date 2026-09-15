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

-- Find all Block Reader peripherals. Don't blindly trust the exact type
-- name (blockReader vs block_reader) -- check for the characteristic
-- methods instead, same as test_redstone_relay.lua does.
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
    log("No Block Reader found (no getBlockData/getBlockName methods).")
    log("Check: is the Block Reader attached to the block, and connected via")
    log("Networking Cable to the same modem line as the computer?")
    saveLog()
    return
end

log("Found Block Reader(s): " .. #readers)
for _, r in ipairs(readers) do
    log("  - " .. r.name .. " (type: " .. tostring(r.ptype) .. ")")
end
log("Point this at whatever block/item you want to test and watch for changes.")
log("Press any key to stop.")
log(string.rep("-", 40))

-- Recursively flattens every scalar (non-table) field out of the
-- getBlockData() table into "path = value" lines, whatever the block
-- type is and however deep the NBT is nested (e.g. under "tag"). This
-- is intentionally generic -- it doesn't assume any particular block's
-- field names, so it works for any peripheral block/item you point it at.
local function flattenScalars(tbl, path, out, seen)
    if type(tbl) ~= "table" then return end
    seen = seen or {}
    if seen[tbl] then return end
    seen[tbl] = true

    for k, v in pairs(tbl) do
        local p = path == "" and tostring(k) or (path .. "." .. tostring(k))
        if type(v) == "table" then
            flattenScalars(v, p, out, seen)
        else
            table.insert(out, p .. " = " .. tostring(v))
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
                    dataStr = okSer and ser or ("SERIALIZE ERROR: " .. tostring(ser))
                else
                    dataStr = tostring(data)
                end

                local serialized = tostring(blockName) .. "|" .. tostring(isTile) .. "|" .. dataStr

                if serialized ~= lastSerialized[r.name] then
                    lastSerialized[r.name] = serialized

                    if not okName then
                        log("[" .. ts .. "] " .. r.name .. " getBlockName ERROR: " .. tostring(blockName))
                    end
                    if not okTile then
                        log("[" .. ts .. "] " .. r.name .. " isTileEntity ERROR: " .. tostring(isTile))
                    end

                    log("[" .. ts .. "] " .. r.name .. " name=" .. tostring(blockName) .. " tile=" .. tostring(isTile))

                    if not okData then
                        log("[" .. ts .. "] " .. r.name .. " getBlockData ERROR: " .. tostring(data))
                    elseif type(data) ~= "table" then
                        log("[" .. ts .. "] " .. r.name .. " getBlockData = nil (not a tile entity, or nothing to read)")
                    else
                        log("[" .. ts .. "] " .. r.name .. " RAW getBlockData: " .. dataStr)
                        local found = {}
                        flattenScalars(data, "", found)
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
log("Stopped. Everything is also saved in " .. LOG_FILE .. ".")
log("Optional: 'pastebin put " .. LOG_FILE .. "' for a shareable link (needs HTTP).")
saveLog()
