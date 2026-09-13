-- test.lua: FossilLab diagnose-script (test 1: peripherals).
--
-- Doel: uitzoeken of de Fossil Analyzer, Restoration Tank en Data Monitor
-- uberhaupt iets prijsgeven aan CC:Tweaked, en zo ja wat.
-- Dit script verandert NIETS aan de wereld -- het probeert alleen methods
-- zonder argumenten aan te roepen (de "getters") en print het resultaat.
-- Een paar overduidelijk state-changing method-namen worden overgeslagen,
-- voor de zekerheid.
--
-- Gebruik: leg een Wired Modem op de computer + Networking Cable naar de
-- 3 Cobblemon-blocks (en evt. een Environment Detector), run "test".
-- Het scherm pauzeert vanzelf voor het volloopt ("druk op toets voor meer")
-- zodat niks wegscrollt. De volledige output wordt ook weggeschreven naar
-- test_output.txt -- als HTTP aan staat kan je daarna "pastebin put
-- test_output.txt" runnen voor een linkje, in plaats van alles overtypen.

local LOG_FILE = "test_output.txt"

local UNSAFE = {
    turnOn = true, turnOff = true, reboot = true, shutdown = true,
    eject = true, drop = true, dropAll = true, open = true, close = true,
    unlock = true, lock = true, craft = true, activate = true,
    deactivate = true, reset = true, clear = true, remove = true,
    delete = true, ["scanEntities"] = false, -- keep scanEntities (safe read)
}

local isColor = term.isColor and term.isColor() or false
local W, H = term.getSize()
local rowsSincePause = 0
local logLines = {}

-- Prints a line, buffers it for the log file, and pauses + clears the
-- screen right before it would overflow -- so nothing scrolls off unread.
local function out(str)
    str = tostring(str)
    table.insert(logLines, str)
    print(str)
    rowsSincePause = rowsSincePause + math.max(1, math.ceil(#str / W))
    if rowsSincePause >= H - 2 then
        if isColor then term.setTextColor(colors.yellow) end
        io.write("-- druk op toets voor meer --")
        if isColor then term.setTextColor(colors.white) end
        os.pullEvent("key")
        term.clear()
        term.setCursorPos(1, 1)
        rowsSincePause = 0
    end
end

local function line()
    out(string.rep("-", 26))
end

local function saveLog()
    local f = fs.open(LOG_FILE, "w")
    f.write(table.concat(logLines, "\n"))
    f.close()
end

local names = peripheral.getNames()

if #names == 0 then
    out("Geen peripherals gevonden!")
    out("Check: zit er een Wired Modem op de computer (rechtermuisklik")
    out("om aan te zetten -- moet oranje/rood licht geven), en lopen er")
    out("Networking Cables van die modem naar de 3 Cobblemon-blocks?")
    saveLog()
    return
end

out("Gevonden peripherals: " .. #names)
line()

for _, name in ipairs(names) do
    local ptype = peripheral.getType(name)
    out("Naam : " .. name)
    out("Type : " .. tostring(ptype))

    local p = peripheral.wrap(name)
    local methods = peripheral.getMethods(name) or {}

    if #methods == 0 then
        out("(geen methods)")
    else
        out("Methods (" .. #methods .. "):")
        for _, m in ipairs(methods) do
            if UNSAFE[m] then
                out("  - " .. m .. "  => (overgeslagen, kan state veranderen)")
            else
                local ok, result = pcall(p[m])
                local shown
                if not ok then
                    shown = "(kon niet zonder argumenten aanroepen)"
                elseif type(result) == "table" then
                    shown = textutils.serialize(result)
                elseif result == nil then
                    shown = "(niks / ok)"
                else
                    shown = tostring(result)
                end
                out("  - " .. m .. "  => " .. shown)
            end
        end
    end
    line()
end

saveLog()
out("Klaar. Alles staat ook in " .. LOG_FILE .. ".")
out("Optioneel: 'pastebin put " .. LOG_FILE .. "' voor een linkje (HTTP nodig).")
