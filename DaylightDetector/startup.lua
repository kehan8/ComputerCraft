-- DaylightDetector: flips a redstone signal at dusk/dawn via computer side(s),
-- Redstone Relay(s) and/or Sequenced Gearshift(s). AUTO = timer, ON/OFF = manual override.

-- ====================== CONFIG ======================
local config = require("config")
local COMPUTER_SIDES = config.COMPUTER_SIDES or {}
local RELAYS = config.RELAYS or {}
local GEARSHIFTS = config.GEARSHIFTS or {}
local MODEM_NAME = config.MODEM_NAME
local MODEM_ENABLED = config.MODEM_ENABLED
local POLL_INTERVAL = config.POLL_INTERVAL

-- HOUR/MINUTE -> fractional hour for os.time("ingame")
local DUSK_TIME = config.DUSK_HOUR + config.DUSK_MINUTE / 60
local DAWN_TIME = config.DAWN_HOUR + config.DAWN_MINUTE / 60
-- ======================================================

-- Status reported to ControlRoom (see ../ControlRoom).
local PROTOCOL = "controlroom"
local DEVICE_TYPE = "DaylightDetector"

if not fs.exists("basalt") and not fs.exists("basalt.lua") then
    print("Installing Basalt UI library...")
    shell.run("wget run https://raw.githubusercontent.com/Pyroxenium/Basalt2/main/install.lua")
end
local basalt = require("basalt")

if #COMPUTER_SIDES == 0 and #RELAYS == 0 and #GEARSHIFTS == 0 then
    error("Add at least one entry to COMPUTER_SIDES, RELAYS or GEARSHIFTS in config.lua.")
end

-- Wrap relays immediately -- fail fast with a named error, not a cryptic nil crash later.
local relays = {}
for i, r in ipairs(RELAYS) do
    if not r.name or not r.side then
        error("RELAYS[" .. i .. "] needs both 'name' and 'side' in config.lua.")
    end
    local wrapped = peripheral.wrap(r.name)
    if not wrapped then
        error("Could not find redstone relay '" .. r.name .. "' (RELAYS[" .. i .. "]). Check the cable/name.")
    end
    table.insert(relays, { peripheral = wrapped, side = r.side })
end

-- Wrap gearshifts immediately -- same fail-fast idea.
local gearshifts = {}
for i, g in ipairs(GEARSHIFTS) do
    if not g.side then
        error("GEARSHIFTS[" .. i .. "] needs a 'side' in config.lua.")
    end
    local wrapped = peripheral.wrap(g.side)
    if not wrapped then
        error("No peripheral on side '" .. g.side .. "' (GEARSHIFTS[" .. i .. "]). Check the side in config.lua.")
    end
    if not wrapped.rotate or not wrapped.isRunning then
        error("Peripheral on side '" .. g.side .. "' (GEARSHIFTS[" .. i .. "]) is not a Sequenced Gearshift.")
    end
    table.insert(gearshifts, { peripheral = wrapped, angle = g.angle or 180, speed = g.speed or 1 })
end

if MODEM_ENABLED then
    if not peripheral.isPresent(MODEM_NAME) then
        error("Could not find modem '" .. MODEM_NAME .. "'. Check the wireless modem is attached and named correctly.")
    end
    rednet.open(MODEM_NAME)
end

-- ON from DUSK_TIME until DAWN_TIME, wrapping past midnight.
local function isNight(time)
    return time >= DUSK_TIME or time < DAWN_TIME
end

local function setSignal(on)
    for _, side in ipairs(COMPUTER_SIDES) do
        redstone.setOutput(side, on)
    end
    for _, r in ipairs(relays) do
        r.peripheral.setOutput(r.side, on)
    end
end

-- rotates all gearshifts together on state transitions, capped by GEARSHIFT_TIMEOUT
local GEARSHIFT_TIMEOUT = 3 -- seconds
local function rotateGearshifts(forward)
    for _, g in ipairs(gearshifts) do
        local speed = forward and g.speed or -g.speed
        g.peripheral.rotate(g.angle, speed)
    end
    local waited = 0
    while waited < GEARSHIFT_TIMEOUT do
        local anyRunning = false
        for _, g in ipairs(gearshifts) do
            if g.peripheral.isRunning() then
                anyRunning = true
                break
            end
        end
        if not anyRunning then break end
        os.sleep(0.1)
        waited = waited + 0.1
    end
end

-- "HH:MM" from os.time("ingame")'s fractional 0-24 hour.
local function formatTime(time)
    local hours = math.floor(time)
    local minutes = math.floor((time - hours) * 60)
    return string.format("%02d:%02d", hours, minutes)
end

-- adminMode: "AUTO" (timer decides) or "MANUAL" (manualState decides).
local adminMode = "AUTO"
local manualState = false
local lastSignal = nil -- last applied combined signal; gearshifts only rotate on change
local dirty = true -- true = recompute now (startup + button clicks); skips waiting for POLL_INTERVAL
local nextClickAt = 0 -- os.epoch("utc") ms timestamp; buttons ignored before this

-- ====================== UI ======================
local screen = basalt.getMainFrame()
local w, _ = screen:getSize()

screen:addLabel()
    :setText("DaylightDetector")
    :setPosition(2, 1)
    :setSize(w - 2, 1)
    :setForeground(colors.white)

-- Fixed line, only ever :setText()'d -- no scrolling spam.
local clockLabel = screen:addLabel()
    :setText("--:--")
    :setPosition(2, 3)
    :setSize(w - 2, 1)
    :setForeground(colors.white)

local statusLabel = screen:addLabel()
    :setText("Signal: off")
    :setPosition(2, 5)
    :setSize(w - 2, 1)
    :setForeground(colors.lightGray)

-- AUTO + ON/OFF toggle buttons, with a click cooldown
local BUTTON_COOLDOWN = 1500 -- ms
local function withCooldown(button, action)
    button:onClick(function()
        if os.epoch("utc") < nextClickAt then return end
        action()
        dirty = true
        nextClickAt = os.epoch("utc") + BUTTON_COOLDOWN
    end)
end

local BUTTON_W = math.floor((w - 3) / 2)
local autoButton = screen:addButton()
    :setText("AUTO")
    :setPosition(2, 7)
    :setSize(BUTTON_W, 1)

local toggleButton = screen:addButton()
    :setText("OFF")
    :setPosition(2 + BUTTON_W + 1, 7)
    :setSize(BUTTON_W, 1)

withCooldown(autoButton, function()
    adminMode = "AUTO"
end)
withCooldown(toggleButton, function()
    manualState = not lastSignal
    adminMode = "MANUAL"
end)

-- ====================== SIGNAL LOOP ======================
-- own coroutine, separate from the clock loop below
local function computeAndApply()
    local time = os.time("ingame")
    local night = isNight(time)
    local signalOn = night
    if adminMode == "MANUAL" then
        signalOn = manualState -- explicit if: "manualState and x or y" breaks when manualState is false
    end

    setSignal(signalOn)

    if #gearshifts > 0 and signalOn ~= lastSignal then
        statusLabel:setText("Gearshift: rotating..."):setForeground(colors.yellow)
        rotateGearshifts(signalOn)
    end
    lastSignal = signalOn

    local statusText
    if adminMode == "MANUAL" then
        statusText = "Signal: " .. (signalOn and "ON" or "off") .. " (admin override)"
    else
        statusText = night and "Signal: ON (night)" or "Signal: off (day)"
    end
    if #gearshifts > 0 then
        statusText = statusText .. (signalOn and " | Gearshift: open" or " | Gearshift: closed")
    end
    statusLabel
        :setText(statusText)
        :setForeground(signalOn and colors.lime or colors.lightGray)

    autoButton
        :setBackground(adminMode == "AUTO" and colors.gray or colors.black)
        :setForeground(adminMode == "AUTO" and colors.white or colors.lightGray)
    toggleButton
        :setText(signalOn and "ON" or "OFF")
        :setBackground(signalOn and colors.lime or colors.red)
        :setForeground(adminMode == "MANUAL" and colors.white or colors.gray)

    if MODEM_ENABLED then
        rednet.broadcast({ label = os.getComputerLabel(), type = DEVICE_TYPE, status = statusText }, PROTOCOL)
    end
end

basalt.schedule(function()
    local waited = POLL_INTERVAL -- run once immediately on startup
    while true do
        if dirty or waited >= POLL_INTERVAL then
            local ok, err = pcall(computeAndApply)
            if not ok then
                statusLabel:setText("Error: " .. tostring(err)):setForeground(colors.red)
            end
            dirty = false
            waited = 0
        end
        os.sleep(0.2)
        waited = waited + 0.2
    end
end)

-- ====================== CLOCK LOOP ======================
basalt.schedule(function()
    while true do
        clockLabel:setText(formatTime(os.time("ingame")))
        os.sleep(POLL_INTERVAL)
    end
end)

basalt.run()
