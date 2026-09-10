-- DaylightDetector
-- Tracks the in-game clock and flips a redstone signal at dusk/dawn -- no physical
-- Daylight Detector block needed, just os.time("ingame"). The signal can be driven
-- straight off this computer's own redstone side, through a Redstone Relay
-- peripheral, and/or through a Create Sequenced Gearshift (for switching a
-- high-amperage HV Switch that plain redstone can't drive) -- toggle each
-- independently in config.lua (handy since the computer itself can't always reach
-- where the signal needs to go, or plain redstone can't handle the circuit).
-- Also shows a live in-game clock on the computer's own screen -- one fixed line
-- that just keeps counting, no monitor needed and no scrolling spam.

-- ====================== CONFIG ======================
-- Your local settings live in config.lua (not touched by update.lua).
local config = require("config")
local COMPUTER_SIDE = config.COMPUTER_SIDE
local COMPUTER_ENABLED = config.COMPUTER_ENABLED
local REDSTONE_RELAY_NAME = config.REDSTONE_RELAY_NAME
local REDSTONE_SIDE = config.REDSTONE_SIDE
local REDSTONE_RELAY_ENABLED = config.REDSTONE_RELAY_ENABLED
local GEARSHIFT_NAME = config.GEARSHIFT_NAME
local GEARSHIFT_ENABLED = config.GEARSHIFT_ENABLED
local GEARSHIFT_ANGLE = config.GEARSHIFT_ANGLE
local GEARSHIFT_SPEED = config.GEARSHIFT_SPEED
local MODEM_NAME = config.MODEM_NAME
local MODEM_ENABLED = config.MODEM_ENABLED
local POLL_INTERVAL = config.POLL_INTERVAL

-- config.lua stores dusk/dawn as plain HOUR/MINUTE (a normal clock, no decimals to
-- misread) -- convert to the fractional-hour decimal os.time("ingame") itself uses.
-- Reminder: this is Minecraft's in-game daylight clock, NOT your real/IRL time --
-- see the comment in config.lua.
local DUSK_TIME = config.DUSK_HOUR + config.DUSK_MINUTE / 60
local DAWN_TIME = config.DAWN_HOUR + config.DAWN_MINUTE / 60
-- ======================================================

-- Protocol used to report status to the ControlRoom computer (see ../ControlRoom).
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
    gearshift = peripheral.wrap(GEARSHIFT_NAME)
    if not gearshift then
        error("Could not find sequenced gearshift '" .. GEARSHIFT_NAME .. "'. Check the cable/name.")
    end
end

if MODEM_ENABLED then
    if not peripheral.isPresent(MODEM_NAME) then
        error("Could not find modem '" .. MODEM_NAME .. "'. Check the wireless modem is attached and named correctly.")
    end
    rednet.open(MODEM_NAME)
end

-- os.time("ingame") returns a fractional 0-24 hour (Minecraft's own daylight-cycle
-- clock, not IRL time). The signal is ON from DUSK_TIME until DAWN_TIME, wrapping
-- past midnight (converted from config.lua's DUSK_HOUR:DUSK_MINUTE / DAWN_HOUR:DAWN_MINUTE).
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

-- Rotates the gearshift to physically switch state: forward at dusk, back at dawn.
-- Unlike setSignal() above, this is edge-triggered (called only when night flips),
-- not every poll -- a Sequenced Gearshift re-triggered while already mid-rotation
-- would just interrupt itself. Blocks briefly until the rotation finishes (same as
-- the tested example): fine since a 180 degree turn is well under a second, and this
-- only runs once per transition, so the clock/UI only freezes for a moment, not
-- continuously.
local function rotateGearshift(forward)
    local speed = forward and GEARSHIFT_SPEED or -GEARSHIFT_SPEED
    gearshift.rotate(GEARSHIFT_ANGLE, speed)
    while gearshift.isRunning() do
        os.sleep(0.1)
    end
end

-- Formats os.time("ingame")'s fractional 0-24 hour into a fixed "HH:MM" clock string.
local function formatTime(time)
    local hours = math.floor(time)
    local minutes = math.floor((time - hours) * 60)
    return string.format("%02d:%02d", hours, minutes)
end

-- ====================== UI ======================
local screen = basalt.getMainFrame()
local w, _ = screen:getSize()

screen:addLabel()
    :setText("DaylightDetector")
    :setPosition(2, 1)
    :setSize(w - 2, 1)
    :setForeground(colors.white)

-- One fixed line for the clock -- only ever :setText()'d on the same label, so it
-- just keeps counting in place instead of scrolling new lines every tick.
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

-- ====================== UPDATE LOOP ======================
-- Tracks the previous night state so the gearshift only rotates on an actual
-- dusk/dawn transition, not on every poll. Starts as nil so the very first update
-- always rotates once, syncing the gearshift's physical position to the computed
-- state (handy after a restart, in case they'd drifted out of sync).
local lastNight = nil

local function update()
    local time = os.time("ingame")
    local night = isNight(time)

    setSignal(night)

    if GEARSHIFT_ENABLED and night ~= lastNight then
        rotateGearshift(night)
    end
    lastNight = night

    clockLabel:setText(formatTime(time))

    local statusText = night and "Signal: ON (night)" or "Signal: off (day)"
    if GEARSHIFT_ENABLED then
        statusText = statusText .. (night and " | Gearshift: open" or " | Gearshift: closed")
    end
    statusLabel
        :setText(statusText)
        :setForeground(night and colors.lime or colors.lightGray)

    if MODEM_ENABLED then
        rednet.broadcast({ label = os.getComputerLabel(), type = DEVICE_TYPE, status = statusText }, PROTOCOL)
    end
end

basalt.schedule(function()
    while true do
        update()
        os.sleep(POLL_INTERVAL)
    end
end)

basalt.run()
