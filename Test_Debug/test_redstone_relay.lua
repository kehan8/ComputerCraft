local INTERVAL = 0.5
local SIDES = { "top", "bottom", "front", "back", "right", "left" }

local LOG_FILE = "test_redstone_output.txt"
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

-- Collect all peripherals that look redstone-ish (Redstone Relay or
-- similar), without needing to guess the exact peripheral type name.
local relays = {}
for _, name in ipairs(peripheral.getNames()) do
    local methods = peripheral.getMethods(name) or {}
    local methodSet = {}
    for _, m in ipairs(methods) do methodSet[m] = true end

    if methodSet.getAnalogInput or methodSet.getInput or methodSet.getRedstoneInput then
        table.insert(relays, { name = name, p = peripheral.wrap(name), methods = methodSet })
    end
end

if #relays == 0 then
    log("No redstone-ish peripheral found (no getAnalogInput/getInput).")
    log("Check: is the Redstone Relay attached to the block, and connected")
    log("via Networking Cable to the same modem line as the computer?")
    saveLog()
    return
end

log("Found redstone-ish peripherals: " .. #relays)
for _, r in ipairs(relays) do
    log("  - " .. r.name)
end
log("Trigger whatever redstone-emitting block/machine you want to test and watch the values.")
log("Press any key to stop.")
log(string.rep("-", 40))

local running = true
local lastValues = {}

parallel.waitForAny(
    function()
        while running do
            local ts = textutils.formatTime(os.time(), true)
            for _, r in ipairs(relays) do
                for _, side in ipairs(SIDES) do
                    local ok, val
                    if r.methods.getAnalogInput then
                        ok, val = pcall(r.p.getAnalogInput, side)
                    elseif r.methods.getInput then
                        ok, val = pcall(r.p.getInput, side)
                    elseif r.methods.getRedstoneInput then
                        ok, val = pcall(r.p.getRedstoneInput, side)
                    end

                    if ok and val ~= nil then
                        local key = r.name .. ":" .. side
                        if lastValues[key] ~= val then
                            log("[" .. ts .. "] " .. key .. " = " .. tostring(val))
                            lastValues[key] = val
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
