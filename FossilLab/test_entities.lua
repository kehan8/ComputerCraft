-- test_entities.lua: FossilLab diagnose-script (test 1b: scanEntities).
--
-- Doel: uitzoeken of de Environment Detector iets ziet verschijnen zodra
-- de Restoration Tank een fossiel begint te restaureren (een echte
-- server-entity die scanEntities kan oppikken).
-- Dit script verandert NIETS aan de wereld -- scanEntities is een pure
-- read-only scan.
--
-- Gebruik: laat dit script draaien VOORDAT je een restauratie start in de
-- Restoration Tank. Start daarna de restauratie in-game terwijl dit
-- script blijft lopen. Druk op een toets om te stoppen.
-- Radius is 8 (binnen de "maxFreeRadius" van de Detector volgens
-- getConfiguration -- dus gratis, geen fuel/kosten).

local RADIUS = 8
local INTERVAL = 2.2 -- iets boven de cooldown van 2000ms

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

-- Vind de Environment Detector (type "environment_detector").
local detectorName
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "environment_detector" then
        detectorName = name
        break
    end
end

if not detectorName then
    log("Geen Environment Detector gevonden! Check de wired connectie.")
    saveLog()
    return
end

local detector = peripheral.wrap(detectorName)
log("Environment Detector gevonden op: " .. detectorName)
log("Scan-radius: " .. RADIUS .. " (gratis volgens getConfiguration)")
log("Start nu de restauratie in de Restoration Tank en laat dit lopen.")
log("Druk op een toets om te stoppen.")
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
                log("[" .. ts .. "] #" .. scanCount .. " scanEntities FOUT: " .. tostring(result))
            elseif type(result) ~= "table" or #result == 0 then
                log("[" .. ts .. "] #" .. scanCount .. " geen entities gevonden")
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
log("Gestopt. Alles staat ook in " .. LOG_FILE .. ".")
log("Optioneel: 'pastebin put " .. LOG_FILE .. "' voor een linkje (HTTP nodig).")
saveLog()
