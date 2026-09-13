-- test_redstone.lua: FossilLab diagnose-script (test 2: redstone/comparator).
--
-- Alleen nodig als test.lua + test_entities.lua geen bruikbaar percentage
-- opleveren. Vereist een Redstone Relay (Advanced Peripherals) die je
-- tegen de Fossil Analyzer en/of Restoration Tank aan plaatst en met
-- Networking Cable naar de computer verbindt.
--
-- Dit script verandert NIETS -- het leest alleen analoge/digitale input
-- op elke zijde van elke Redstone Relay die het vindt, doorlopend, zodat
-- je live kan zien of het signaal verandert tijdens een restauratie of
-- analyse.
--
-- Gebruik: run dit script, start daarna de Fossil Analyzer of Restoration
-- Tank in-game, en kijk of een van de zijden een niet-nul waarde laat
-- zien die oploopt/verandert. Druk op een toets om te stoppen.

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

-- Verzamel alle peripherals die op redstone-achtige methods lijken
-- (Redstone Relay of vergelijkbaar), zonder de exacte peripheral-type
-- naam te hoeven raden.
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
    log("Geen redstone-achtige peripheral gevonden (geen getAnalogInput/getInput).")
    log("Check: zit de Redstone Relay tegen het block aan, en verbonden")
    log("met Networking Cable naar dezelfde modem-lijn als de computer?")
    saveLog()
    return
end

log("Gevonden redstone-achtige peripherals: " .. #relays)
for _, r in ipairs(relays) do
    log("  - " .. r.name)
end
log("Start nu de Fossil Analyzer of Restoration Tank en let op waardes.")
log("Druk op een toets om te stoppen.")
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
log("Gestopt. Alles staat ook in " .. LOG_FILE .. ".")
log("Optioneel: 'pastebin put " .. LOG_FILE .. "' voor een linkje (HTTP nodig).")
saveLog()
