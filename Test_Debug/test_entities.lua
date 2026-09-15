local RADIUS = 8
local INTERVAL = 2.2 -- slightly above the detector's ~2000ms cooldown

local LOG_FILE = "test_entities_output.txt"
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

-- Find the Environment Detector (type "environment_detector").
local detectorName
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "environment_detector" then
        detectorName = name
        break
    end
end

if not detectorName then
    log("No Environment Detector found! Check the wired connection.")
    saveLog()
    return
end

local detector = peripheral.wrap(detectorName)
log("Environment Detector found on: " .. detectorName)
log("Scan radius: " .. RADIUS .. " (free according to getConfiguration)")
log("Trigger/spawn whatever entity you want to test nearby and let this run.")
log("Press any key to stop.")
log(string.rep("-", 40))

local running = true
local scanCount = 0

parallel.waitForAny(
    function()
        while running do
            scanCount = scanCount + 1
            local ok, result = pcall(detector.scanEntities, RADIUS)
            local ts = textutils.formatTime(os.time(), true)

            if not ok then
                log("[" .. ts .. "] #" .. scanCount .. " scanEntities ERROR: " .. tostring(result))
            elseif type(result) ~= "table" or #result == 0 then
                log("[" .. ts .. "] #" .. scanCount .. " no entities found")
            else
                log("[" .. ts .. "] #" .. scanCount .. " " .. #result .. " entity/entities:")
                for i, ent in ipairs(result) do
                    log("   " .. i .. ". " .. textutils.serialize(ent))
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
