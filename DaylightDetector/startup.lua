-- DaylightDetector
-- Tracks the in-game clock, flips a redstone signal at dusk/dawn. Drives it via
-- computer side, Redstone Relay, and/or Create Sequenced Gearshift (toggle each
-- in config.lua). Clock and signal/gearshift logic run on separate loops, so a
-- slow gearshift rotation never freezes the clock. AUTO button = timer control,
-- ON/OFF button = manual override (toggles, previews live value while in AUTO).

-- ====================== CONFIG ======================
local config = require("config")
local COMPUTER_SIDE = config.COMPUTER_SIDE
local COMPUTER_ENABLED = config.COMPUTER_ENABLED
local REDSTONE_RELAY_NAME = config.REDSTONE_RELAY_NAME
local REDSTONE_SIDE = config.REDSTONE_SIDE
local REDSTONE_RELAY_ENABLED = config.REDSTONE_RELAY_ENABLED
local GEARSHIFT_SIDE = config.GEARSHIFT_SIDE
local GEARSHIFT_ENABLED = config.GEARSHIFT_ENABLED
local GEARSHIFT_ANGLE = config.GEARSHIFT_ANGLE
local GEARSHIFT_SPEED = config.GEARSHIFT_SPEED
local MODEM_NAME = config.MODEM_NAME
local MODEM_ENABLED = config.MODEM_ENABLED
local POLL_INTERVAL = config.POLL_INTERVAL

-- Convert config.lua's plain HOUR/MINUTE into the fractional hour os.time("ingame")
-- uses. In-game clock, NOT real time.
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

if not COMPUTER_ENABLED and not REDSTONE_RELAY_ENABLED and not GEARSHIFT_ENABLED then
    error("Enable at least one of COMPUTER_ENABLED, REDSTONE_RELAY_ENABLED or GEARSHIFT_ENABLED in config.lua.")
end

local relay = nil
if REDSTONE_RELAY_ENABLED then
    relay = peripheral.wrap(REDSTONE_RELAY_NAME)
    if not relay then
        error("Could not find redstone relay '" .. REDSTONE_RELAY_NAME .. "'. Check the cable/name.")
    end
end

local gearshift = nil
if GEARSHIFT_ENABLED then
    gearshift = peripheral.wrap(GEARSHIFT_SIDE)
    if not gearshift then
        error("No peripheral on side '" .. GEARSHIFT_SIDE .. "'. Check GEARSHIFT_SIDE in config.lua.")
    end
    if not gearshift.rotate or not gearshift.isRunning then
        error("Peripheral on side '" .. GEARSHIFT_SIDE .. "' is not a Sequenced Gearshift.")
    end
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
    if COMPUTER_ENABLED then
        redstone.setOutput(COMPUTER_SIDE, on)
    end
    if REDSTONE_RELAY_ENABLED then
        relay.setOutput(REDSTONE_SIDE, on)
    end
end

-- Rotates the gearshift on state transitions only (not every poll), forward when
-- the signal turns on, back when it turns off. Blocks until done, capped by
-- GEARSHIFT_TIMEOUT so a stuck/misidentified peripheral can't freeze the UI.
local GEARSHIFT_TIMEOUT = 3 -- seconds
local BUTTON_COOLDOWN = 1500 -- ms; blocks rapid clicks from double-commanding the gearshift mid-rotation
local function rotateGearshift(forward)
    local speed = forward and GEARSHIFT_SPEED or -GEARSHIFT_SPEED
    gearshift.rotate(GEARSHIFT_ANGLE, speed)
    local waited = 0
    while gearshift.isRunning() and waited < GEARSHIFT_TIMEOUT do
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
local lastSignal = nil -- last applied combined signal; gearshift only rotates on change
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

-- AUTO button + one ON/OFF toggle button. Toggle always shows the live signal
-- value (previews the timer's value while in AUTO); clicking it flips that
-- value and switches to MANUAL. Cooldown blocks rapid double-clicks so the
-- gearshift never gets a second rotate() command mid-rotation.
local BUTTON_W = math.floor((w - 3) / 2)
local autoButton = screen:addButton()
    :setText("AUTO")
    :setPosition(2, 7)
    :setSize(BUTTON_W, 1)
    :onClick(function()
        if os.epoch("utc") < nextClickAt then return end
        adminMode = "AUTO"
        dirty = true
        nextClickAt = os.epoch("utc") + BUTTON_COOLDOWN
    end)

local toggleButton = screen:addButton()
    :setText("OFF")
    :setPosition(2 + BUTTON_W + 1, 7)
    :setSize(BUTTON_W, 1)
    :onClick(function()
        if os.epoch("utc") < nextClickAt then return end
        manualState = not lastSignal
        adminMode = "MANUAL"
        dirty = true
        nextClickAt = os.epoch("utc") + BUTTON_COOLDOWN
    end)

-- ====================== SIGNAL LOOP ======================
-- Runs the timer/manual decision, drives the outputs and rotates the gearshift.
-- Separate coroutine from the clock loop below -- a slow/blocked gearshift only
-- stalls this loop, never the on-screen clock. pcall so a peripheral error
-- shows on screen instead of killing the loop.
local function computeAndApply()
    local time = os.time("ingame")
    local night = isNight(time)
    local signalOn = night
    if adminMode == "MANUAL" then
        signalOn = manualState -- explicit if: "manualState and x or y" breaks when manualState is false
    end

    setSignal(signalOn)

    if GEARSHIFT_ENABLED and signalOn ~= lastSignal then
        statusLabel:setText("Gearshift: rotating..."):setForeground(colors.yellow)
        rotateGearshift(signalOn)
    end
    lastSignal = signalOn

    local statusText
    if adminMode == "MANUAL" then
        statusText = "Signal: " .. (signalOn and "ON" or "off") .. " (admin override)"
    else
        statusText = night and "Signal: ON (night)" or "Signal: off (day)"
    end
    if GEARSHIFT_ENABLED then
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
-- Own coroutine, no peripheral/gearshift calls -- always ticks, never freezes.
basalt.schedule(function()
    while true do
        clockLabel:setText(formatTime(os.time("ingame")))
        os.sleep(POLL_INTERVAL)
    end
end)

basalt.run()
