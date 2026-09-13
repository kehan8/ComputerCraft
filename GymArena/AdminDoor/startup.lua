-- AdminDoor
-- Reads player names inside the door box (see locations.lua) via a Player Detector.
-- Admin whitelist -> door opens. Anyone else -> door stays shut + "NO ACCESS" toast via a Chat Box.
-- Plain status text lives on the computer's own screen -- no monitor needed.

-- ====================== CONFIG ======================
-- Your local settings live in config.lua (not touched by update.lua).
local config = require("config")
local locations = require("locations")
local DETECTOR_NAME = config.DETECTOR_NAME
local DOOR_RELAY_NAME = config.DOOR_RELAY_NAME
local DOOR_SIDE = config.DOOR_SIDE
local ADMIN_NAMES = config.ADMIN_NAMES
local POLL_INTERVAL = config.POLL_INTERVAL
local CHATBOX_NAME = config.CHATBOX_NAME
local TOAST_TITLE = config.TOAST_TITLE
local TOAST_MESSAGE = config.TOAST_MESSAGE
local MODEM_NAME = config.MODEM_NAME
local MODEM_ENABLED = config.MODEM_ENABLED

-- Sorts min/max per axis so it doesn't matter which F3 corner you typed first.
local function normalizeBox(min, max)
    local nmin, nmax = {}, {}
    for _, axis in ipairs({ "x", "y", "z" }) do
        nmin[axis] = math.min(min[axis], max[axis])
        nmax[axis] = math.max(min[axis], max[axis])
    end
    return nmin, nmax
end

local DOOR_MIN, DOOR_MAX = normalizeBox(locations.DOOR_MIN, locations.DOOR_MAX)
-- ======================================================

-- Protocol used to report status to the ControlRoom computer (see ../ControlRoom).
local PROTOCOL = "controlroom"
local DEVICE_TYPE = "AdminDoor"

if not fs.exists("basalt") and not fs.exists("basalt.lua") then
    print("Installing Basalt UI library...")
    shell.run("wget run https://raw.githubusercontent.com/Pyroxenium/Basalt2/main/install.lua")
end
local basalt = require("basalt")

local function wrapPeripheral(name, label)
    local p = peripheral.wrap(name)
    if not p then
        error("Could not find " .. label .. " '" .. name .. "'. Check the cable/name.")
    end
    return p
end

local detector = wrapPeripheral(DETECTOR_NAME, "Player Detector")
local doorRelay = wrapPeripheral(DOOR_RELAY_NAME, "redstone relay")
local chatBox = wrapPeripheral(CHATBOX_NAME, "Chat Box")

if MODEM_ENABLED then
    if not peripheral.isPresent(MODEM_NAME) then
        error("Could not find modem '" .. MODEM_NAME .. "'. Check the wireless modem is attached and named correctly.")
    end
    rednet.open(MODEM_NAME)
end

local adminSet = {}
for _, name in ipairs(ADMIN_NAMES) do
    adminSet[name:lower()] = true
end

local function isAdmin(name)
    return adminSet[name:lower()] == true
end

local function setDoor(open)
    doorRelay.setOutput(DOOR_SIDE, open)
end

-- Sends the intruder an in-game toast popup warning them they have no access.
local function warnIntruder(name)
    chatBox.sendToastToPlayer(TOAST_MESSAGE, TOAST_TITLE, name)
end

-- ====================== UI ======================
local screen = basalt.getMainFrame()
local w, _ = screen:getSize()

screen:addLabel()
    :setText("AdminDoor")
    :setPosition(2, 1)
    :setSize(w - 2, 1)
    :setForeground(colors.white)

local nearbyLabel = screen:addLabel()
    :setText("No one nearby.")
    :setPosition(2, 3)
    :setSize(w - 2, 1)
    :setForeground(colors.lightGray)

local statusLabel = screen:addLabel()
    :setText("Door: closed")
    :setPosition(2, 5)
    :setSize(w - 2, 1)
    :setForeground(colors.white)

-- ====================== DETECTION LOOP ======================
-- Only re-sends the toast when the intruder actually changes, so it doesn't
-- spam the same unauthorized player with a toast every single poll.
local lastIntruder = nil

local function update()
    local playersAtDoor = detector.getPlayersInCoords(DOOR_MIN, DOOR_MAX)

    local admin, intruder = nil, nil
    for _, name in ipairs(playersAtDoor) do
        if isAdmin(name) then
            admin = admin or name
        else
            intruder = intruder or name
        end
    end

    setDoor(admin ~= nil)

    if #playersAtDoor == 0 then
        nearbyLabel:setText("No one nearby.")
    else
        nearbyLabel:setText("Nearby: " .. table.concat(playersAtDoor, ", "))
    end

    local statusText
    if admin then
        statusText = "Access granted: " .. admin
        statusLabel:setText(statusText):setForeground(colors.lime)
    elseif intruder then
        statusText = "ACCESS DENIED: " .. intruder
        statusLabel:setText(statusText):setForeground(colors.red)
    else
        statusText = "Door: closed"
        statusLabel:setText(statusText):setForeground(colors.white)
    end

    if intruder and intruder ~= lastIntruder then
        warnIntruder(intruder)
    end
    lastIntruder = intruder

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
