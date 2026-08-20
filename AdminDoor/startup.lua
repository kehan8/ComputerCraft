-- AdminDoor
-- Reads nearby player names from a Player Detector. If a detected player is on the
-- admin whitelist, opens the door (one relay output). Anyone else detected nearby
-- keeps the door closed and gets a "NO ACCESS" toast popup in-game via a Chat Box.
-- Plain status text lives on the computer's own screen -- no monitor needed.

-- ====================== CONFIG ======================
-- Your local settings live in config.lua (not touched by update.lua).
local config = require("config")
local DETECTOR_NAME = config.DETECTOR_NAME
local DETECT_RANGE = config.DETECT_RANGE
local DOOR_RELAY_NAME = config.DOOR_RELAY_NAME
local DOOR_SIDE = config.DOOR_SIDE
local ADMIN_NAMES = config.ADMIN_NAMES
local POLL_INTERVAL = config.POLL_INTERVAL
local CHATBOX_NAME = config.CHATBOX_NAME
local TOAST_TITLE = config.TOAST_TITLE
local TOAST_MESSAGE = config.TOAST_MESSAGE
-- ======================================================

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
    local playersInRange = detector.getPlayersInRange(DETECT_RANGE)

    local admin, intruder = nil, nil
    for _, name in ipairs(playersInRange) do
        if isAdmin(name) then
            admin = admin or name
        else
            intruder = intruder or name
        end
    end

    setDoor(admin ~= nil)

    if #playersInRange == 0 then
        nearbyLabel:setText("No one nearby.")
    else
        nearbyLabel:setText("Nearby: " .. table.concat(playersInRange, ", "))
    end

    if admin then
        statusLabel:setText("Access granted: " .. admin):setForeground(colors.lime)
    elseif intruder then
        statusLabel:setText("ACCESS DENIED: " .. intruder):setForeground(colors.red)
    else
        statusLabel:setText("Door: closed"):setForeground(colors.white)
    end

    if intruder and intruder ~= lastIntruder then
        warnIntruder(intruder)
    end
    lastIntruder = intruder
end

basalt.schedule(function()
    while true do
        update()
        os.sleep(POLL_INTERVAL)
    end
end)

basalt.run()
