-- AdminDoor: Player Detector at the door box -> admin whitelist opens it,
-- anyone else gets a "NO ACCESS" toast via Chat Box.

-- ====================== CONFIG ======================
local config = require("config")
local locations = require("locations")
local DETECTOR_NAME = config.DETECTOR_NAME
local DOOR_RELAY_NAME = config.DOOR_RELAY_NAME
local DOOR_SIDE = config.DOOR_SIDE
local ADMIN_NAMES = config.ADMIN_NAMES
local ADMIN_ENABLED = config.ADMIN_ENABLED -- nil (old config) defaults to true
if ADMIN_ENABLED == nil then
    ADMIN_ENABLED = true
end
local POLL_INTERVAL = config.POLL_INTERVAL
local CHATBOX_NAME = config.CHATBOX_NAME
local TOAST_TITLE = config.TOAST_TITLE
local TOAST_MESSAGE = config.TOAST_MESSAGE
local MODEM_NAME = config.MODEM_NAME
local MODEM_ENABLED = config.MODEM_ENABLED

-- normalizes min/max per axis regardless of corner order
local function normalizeBox(min, max)
    local nmin, nmax = {}, {}
    for _, axis in ipairs({ "x", "y", "z" }) do
        nmin[axis] = math.min(min[axis], max[axis])
        nmax[axis] = math.max(min[axis], max[axis])
    end
    return nmin, nmax
end

-- normalizes 1 value or a list of values into a list
local function toList(v)
    if type(v) == "table" then
        return v
    else
        return { v }
    end
end

-- locations.BOXES: 1 or more { min = {...}, max = {...} } boxes
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

-- 1 relay or many, via toList()
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
        return true -- whitelist disabled
    end
    return adminSet[name:lower()] == true
end

local function setDoor(open)
    for _, relay in ipairs(doorRelays) do
        relay.setOutput(DOOR_SIDE, open)
    end
end

-- sends the intruder a "NO ACCESS" toast
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
local lastIntruder = nil -- re-sends toast only when the intruder changes

local function update()
    -- scans all doorBoxes, deduped across overlaps
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
