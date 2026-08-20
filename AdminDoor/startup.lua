-- AdminDoor
-- Reads nearby player names from a Player Detector. If a detected player is on the
-- admin whitelist, opens the door (one relay output). Anyone else detected nearby
-- keeps the door closed and pops a "NO ACCESS" warning on screen. Plain status text
-- lives on the computer's own screen -- no monitor needed.

-- ====================== CONFIG ======================
-- Your local settings live in config.lua (not touched by update.lua).
local config = require("config")
local DETECTOR_NAME = config.DETECTOR_NAME
local DETECT_RANGE = config.DETECT_RANGE
local DOOR_RELAY_NAME = config.DOOR_RELAY_NAME
local DOOR_SIDE = config.DOOR_SIDE
local ADMIN_NAMES = config.ADMIN_NAMES
local POLL_INTERVAL = config.POLL_INTERVAL
local WARNING_TIME = config.WARNING_TIME
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

-- ====================== UI ======================
local screen = basalt.getMainFrame()
local w, h = screen:getSize()

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

-- Warning popup, hidden until an unauthorized player is detected nearby.
-- Basalt2 Label backgrounds don't reliably render on this setup (only the text
-- does), so the colored box is a Button and the text is two Labels drawn on top.
local BOX_W, BOX_H = 18, 3
local boxX = math.floor((w - BOX_W) / 2) + 1
local boxY = math.floor((h - BOX_H) / 2) + 1

local popupBg = screen:addButton()
    :setText("")
    :setPosition(boxX, boxY)
    :setSize(BOX_W, BOX_H)
    :setBackground(colors.red)
    :hide()

local popupTitleLabel = screen:addLabel()
    :setText("NO ACCESS")
    :setPosition(boxX + 1, boxY + 1)
    :setSize(BOX_W - 2, 1)
    :setForeground(colors.white)
    :hide()

local popupNameLabel = screen:addLabel()
    :setText("")
    :setPosition(boxX + 1, boxY + 2)
    :setSize(BOX_W - 2, 1)
    :setForeground(colors.white)
    :hide()

local popupElements = { popupBg, popupTitleLabel, popupNameLabel }

local function setPopupVisible(visible)
    for _, el in ipairs(popupElements) do
        if visible then el:show() else el:hide() end
    end
end

-- Bumped on every popup so a stale scheduled hide() can't close a newer warning.
local popupToken = 0

local function showWarning(name)
    popupToken = popupToken + 1
    local myToken = popupToken
    popupNameLabel:setText(name)
    setPopupVisible(true)
    basalt.schedule(function()
        os.sleep(WARNING_TIME)
        if myToken == popupToken then
            setPopupVisible(false)
        end
    end)
end

-- ====================== DETECTION LOOP ======================
-- Only re-triggers the popup when the intruder actually changes, so it doesn't
-- re-flash every poll while the same unauthorized player just stands there.
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
        showWarning(intruder)
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
