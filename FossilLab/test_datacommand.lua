-- test_datacommand.lua: FossilLab diagnose-script (test 3: /data get block).
--
-- Al BEWEZEN te werken: OrganicContent in de NBT van de Fossil Analyzer
-- correleert 1-op-1 met het waterpercentage in de Restoration Tank
-- (OrganicContent 32 = 25%, 64 = 50% -> schaal 0-128 = 0-100%).
-- De Analyzer is blijkbaar de "controller" van de multiblock: Tank en
-- Monitor droppen alleen een ControllerBlock-verwijzing terug, de echte
-- state (OrganicContent, TimeLeft, InsertedFossil, HasCreatedPokemon, ...)
-- zit op de Analyzer-positie zelf.
--
-- BELANGRIJK: dit script heeft de `commands` API nodig. Die bestaat alleen
-- op een Command Computer (niet een gewone/advanced computer). Zet er een
-- neer met bv. "/give @p computercraft:command_computer" en run dit script
-- daarop.
--
-- Dit script verandert NIETS aan de wereld -- "data get" is altijd
-- read-only, ongeacht wie het uitvoert.
--
-- Posities komen uit config.lua (FOSSIL_ANALYZER_POS / RESTORATION_TANK_POS
-- / FOSSIL_MONITOR_POS / RESTORATION_TANK_TOP_POS). Pas die aan als jouw
-- multiblock ergens anders staat (F3 in-game, of lees ze uit een eerdere
-- "/data get block" dump zelf).
--
-- FOSSIL_MONITOR_POS is de "MonitorPos" NBT-waarde uit de Analyzer zelf.
-- RESTORATION_TANK_TOP_POS is het blok fysiek boven de Tank (andere x!) --
-- dat testen we apart omdat die twee niet noodzakelijk hetzelfde blok zijn.
--
-- Gebruik: run dit script, start daarna een analyse/restauratie in-game,
-- en kijk of OrganicContent/TimeLeft/InsertedFossil/HasCreatedPokemon
-- veranderen. Druk op een toets om te stoppen.

local INTERVAL = 2

local config = require("config")

local TARGETS = {
    { label = "Analyzer", pos = config.FOSSIL_ANALYZER_POS },
    { label = "Tank", pos = config.RESTORATION_TANK_POS },
    { label = "Monitor", pos = config.FOSSIL_MONITOR_POS },
    { label = "TankTop", pos = config.RESTORATION_TANK_TOP_POS },
}

local LOG_FILE = "test_datacommand_output.txt"
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

if not commands then
    log("Geen 'commands' API gevonden!")
    log("Dit script werkt alleen op een Command Computer, geen gewone/advanced computer.")
    log("Zet er een neer met: /give @p computercraft:command_computer")
    log("en run dit script daarop opnieuw.")
    saveLog()
    return
end

local haveTarget = false
for _, t in ipairs(TARGETS) do
    if t.pos then haveTarget = true end
end
if not haveTarget then
    log("Geen posities geconfigureerd in config.lua!")
    log("Zet FOSSIL_ANALYZER_POS = { x = .., y = .., z = .. } (en evt.")
    log("RESTORATION_TANK_POS / FOSSIL_MONITOR_POS) en run opnieuw.")
    saveLog()
    return
end

log("Command Computer gevonden. Doelen:")
for _, t in ipairs(TARGETS) do
    if t.pos then
        log(("  - %s: %d %d %d"):format(t.label, t.pos.x, t.pos.y, t.pos.z))
    end
end
log("Start nu de Fossil Analyzer of Restoration Tank en let op waardes.")
log("Druk op een toets om te stoppen.")
log(string.rep("-", 40))

-- Haalt losse velden uit de ruwe SNBT-string, puur voor leesbare logging.
-- De ruwe string zelf wordt sowieso ook gelogd bij elke verandering, dus
-- dit mist nooit iets -- het is enkel een samenvatting bovenop de raw dump.
local FIELDS = {
    { key = "OrganicContent", pattern = "OrganicContent:(%-?%d+)" },
    { key = "TimeLeft", pattern = "TimeLeft:(%-?%d+)" },
    { key = "ProtectedTimeLeft", pattern = "ProtectedTimeLeft:(%-?%d+)" },
    { key = "HasCreatedPokemon", pattern = "HasCreatedPokemon:(%d)b" },
    { key = "InsertedFossil", pattern = "InsertedFossil:\"([%w_:]+)\"" },
    { key = "ConnectorDirection", pattern = "ConnectorDirection:\"([%w_]+)\"" },
}

local function summarize(raw)
    local parts = {}
    for _, f in ipairs(FIELDS) do
        local val = raw:match(f.pattern)
        if val then
            table.insert(parts, f.key .. "=" .. val)
            if f.key == "OrganicContent" then
                local pct = math.floor(tonumber(val) / 128 * 100 + 0.5)
                table.insert(parts, "OrganicContent%=" .. pct .. "%")
            end
        end
    end
    return table.concat(parts, ", ")
end

local running = true
local lastRaw = {}

parallel.waitForAny(
    function()
        while running do
            local ts = textutils.formatTime(os.time(), true)
            for _, t in ipairs(TARGETS) do
                if t.pos then
                    local cmd = ("data get block %d %d %d"):format(t.pos.x, t.pos.y, t.pos.z)
                    local success, output = commands.exec(cmd)
                    local raw = (success and output) and table.concat(output, " ") or nil

                    if not success then
                        if lastRaw[t.label] ~= "ERR" then
                            log("[" .. ts .. "] " .. t.label .. " FOUT: " .. textutils.serialize(output))
                            lastRaw[t.label] = "ERR"
                        end
                    elseif raw and raw ~= lastRaw[t.label] then
                        log("[" .. ts .. "] " .. t.label .. " RAW: " .. raw)
                        local summary = summarize(raw)
                        if summary ~= "" then
                            log("[" .. ts .. "] " .. t.label .. " => " .. summary)
                        end
                        lastRaw[t.label] = raw
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
