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
-- Older config.lua files (from before this setting existed) won't have this
-- field at all -- nil defaults to true, so the whitelist stays enforced
-- exactly like before unless you explicitly set ADMIN_ENABLED = false.
local ADMIN_ENABLED = config.ADMIN_ENABLED
if ADMIN_ENABLED == nil then
    ADMIN_ENABLED = true
end
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

-- Accepts either 1 value or a list of values, so config.lua never needs special
-- syntax for "just one relay" -- a bare string and a { ... } list both work.
-- Everything downstream loops with ipairs() either way, so 1 or many never errors.
local function toList(v)
    if type(v) == "table" then
        return v
    else
        return { v }
    end
end

-- locations.BOXES is a list of { min = {...}, max = {...} } boxes. 1 box or
-- many both work -- startup.lua checks all of them and merges the results.
if not locations.BOXES or #locations.BOXES == 0 then
    error("locations.lua must define BOXES with at least one { min = ..., max = ... } box.")
end
local doorBoxes = {}
for i, box in ipairs(locations.BOXES) do
    local nmin, nmax = normalizeBox(box.min, box.max)
    doorBoxes[i] = { min = nmin, max = nmax }
end
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
local chatBox = wrapPeripheral(CHATBOX_NAME, "Chat Box")

-- DOOR_RELAY_NAME may be a single string or a { "name1", "name2", ... } list --
-- toList() normalizes either into a list, so 1 relay or many both work with no errors.
local doorRelays = {}
for i, name in ipairs(toList(DOOR_RELAY_NAME)) do
    doorRelays[i] = wrapPeripheral(name, "redstone relay")
end

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
    if not ADMIN_ENABLED then
        return true -- whitelist check disabled: everyone detected counts as admin
    end
    return adminSet[name:lower()] == true
end

local function setDoor(open)
    for _, relay in ipairs(doorRelays) do
        relay.setOutput(DOOR_SIDE, open)
    end
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
    -- Scans every box in doorBoxes (1 by default, more if locations.BOXES is
    -- set) and dedupes -- a player standing where two boxes overlap should only
    -- count once, not trigger the toast/admin logic twice.
    local seen = {}
    local playersAtDoor = {}
    for _, box in ipairs(doorBoxes) do
        for _, name in ipairs(detector.getPlayersInCoords(box.min, box.max)) do
            if not seen[name] then
                seen[name] = true
                playersAtDoor[#playersAtDoor + 1] = name
            end
        end
    end

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
        if ADMIN_ENABLED then
            statusText = "Access granted: " .. admin
        else
            statusText = "Open to all (admin check disabled): " .. admin
        end
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
