-- WelcomeDoor
-- Opens the door + welcomes players at the door box, says goodbye when they
-- leave the building box. Not admin gated.

-- ====================== CONFIG ======================
-- Local settings: config.lua (not touched by update.lua).
local config = require("config")
local BUILDING_NAME = config.BUILDING_NAME
local DETECTOR_NAME = config.DETECTOR_NAME
local COMPUTER_SIDE = config.COMPUTER_SIDE
local COMPUTER_ENABLED = config.COMPUTER_ENABLED
local DOOR_RELAY_NAME = config.DOOR_RELAY_NAME
local DOOR_SIDE = config.DOOR_SIDE
local DOOR_RELAY_ENABLED = config.DOOR_RELAY_ENABLED
local CHATBOX_NAME = config.CHATBOX_NAME
local WELCOME_TITLE = config.WELCOME_TITLE
local WELCOME_MESSAGES = config.WELCOME_MESSAGES
local BYE_TITLE = config.BYE_TITLE
local BYE_MESSAGES = config.BYE_MESSAGES
local CLOSED_TITLE = config.CLOSED_TITLE
local CLOSED_MESSAGE = config.CLOSED_MESSAGE
local POLL_INTERVAL = config.POLL_INTERVAL
local MODEM_NAME = config.MODEM_NAME
local MODEM_ENABLED = config.MODEM_ENABLED

-- Local coordinates: locations.lua (not touched by update.lua).
local locations = require("locations")

-- Sorts each axis so MIN <= MAX, no matter which corner the user typed first.
local function normalizeBox(min, max)
    local nmin, nmax = {}, {}
    for _, axis in ipairs({ "x", "y", "z" }) do
        nmin[axis] = math.min(min[axis], max[axis])
        nmax[axis] = math.max(min[axis], max[axis])
    end
    return nmin, nmax
end

local DOOR_MIN, DOOR_MAX = normalizeBox(locations.DOOR_MIN, locations.DOOR_MAX)
local BUILDING_MIN, BUILDING_MAX = normalizeBox(locations.BUILDING_MIN, locations.BUILDING_MAX)
-- ======================================================

-- Door box must fit inside the building box, or welcome+goodbye spam every tick.
local function boxContains(outerMin, outerMax, innerMin, innerMax)
    for _, axis in ipairs({ "x", "y", "z" }) do
        if innerMin[axis] < outerMin[axis] or innerMax[axis] > outerMax[axis] then
            return false
        end
    end
    return true
end

if not boxContains(BUILDING_MIN, BUILDING_MAX, DOOR_MIN, DOOR_MAX) then
    error("locations.lua: DOOR_MIN/DOOR_MAX must fit entirely inside BUILDING_MIN/BUILDING_MAX.")
end

-- Reports status to ControlRoom (see ../GymArena/ControlRoom).
local PROTOCOL = "controlroom"
local DEVICE_TYPE = "WelcomeDoor"

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

if not COMPUTER_ENABLED and not DOOR_RELAY_ENABLED then
    error("Enable at least one of COMPUTER_ENABLED or DOOR_RELAY_ENABLED in config.lua.")
end

local doorDetector = wrapPeripheral(DETECTOR_NAME, "Player Detector")
local doorRelay = nil
if DOOR_RELAY_ENABLED then
    doorRelay = wrapPeripheral(DOOR_RELAY_NAME, "redstone relay")
end
local chatBox = wrapPeripheral(CHATBOX_NAME, "Chat Box")

if MODEM_ENABLED then
    if not peripheral.isPresent(MODEM_NAME) then
        error("Could not find modem '" .. MODEM_NAME .. "'. Check the wireless modem is attached and named correctly.")
    end
    rednet.open(MODEM_NAME)
end

-- ====================== STATE ======================
-- Names currently welcomed, not yet said goodbye to.
local insideSet = {}
-- Names already sent the closed toast at the door; cleared when they leave.
local closedNotifiedSet = {}
local active = true
local lastEvent = ""

local function insideNames()
    local list = {}
    for name in pairs(insideSet) do
        table.insert(list, name)
    end
    table.sort(list)
    return list
end

local function setDoor(open)
    if COMPUTER_ENABLED then
        redstone.setOutput(COMPUTER_SIDE, open)
    end
    if DOOR_RELAY_ENABLED then
        doorRelay.setOutput(DOOR_SIDE, open)
    end
end

local function pickMessage(list)
    return list[math.random(#list)]
end

-- pcall: player may leave before the toast lands.
local function sendWelcome(name)
    pcall(function()
        chatBox.sendToastToPlayer(string.format(pickMessage(WELCOME_MESSAGES), BUILDING_NAME), WELCOME_TITLE, name)
    end)
    lastEvent = "Welcomed " .. name
end

local function sendBye(name)
    pcall(function()
        chatBox.sendToastToPlayer(string.format(pickMessage(BYE_MESSAGES), BUILDING_NAME), BYE_TITLE, name)
    end)
    lastEvent = "Bye " .. name
end

-- Sent once to everyone inside when the button flips to INACTIVE.
local function sendClosedNotice()
    for name in pairs(insideSet) do
        pcall(function()
            chatBox.sendToastToPlayer(CLOSED_MESSAGE, CLOSED_TITLE, name)
        end)
    end
    lastEvent = "Closed notice sent"
end

-- Sent to new arrivals at the door while INACTIVE.
local function sendClosedNoticeToPlayer(name)
    pcall(function()
        chatBox.sendToastToPlayer(CLOSED_MESSAGE, CLOSED_TITLE, name)
    end)
    lastEvent = "Closed notice to " .. name
end

-- ====================== UI ======================
local screen = basalt.getMainFrame()
local w, _ = screen:getSize()

screen:addLabel()
    :setText("WelcomeDoor")
    :setPosition(2, 1)
    :setSize(w - 2, 1)
    :setForeground(colors.white)

screen:addLabel()
    :setText("Building: " .. BUILDING_NAME)
    :setPosition(2, 3)
    :setSize(w - 2, 1)
    :setForeground(colors.lightGray)

local insideLabel = screen:addLabel()
    :setText("No one inside.")
    :setPosition(2, 5)
    :setSize(w - 2, 1)
    :setForeground(colors.white)

local lastEventLabel = screen:addLabel()
    :setText("")
    :setPosition(2, 7)
    :setSize(w - 2, 1)
    :setForeground(colors.lightGray)

local activeButton = screen:addButton()
    :setText("ACTIVE")
    :setPosition(2, 9)
    :setSize(10, 1)
    :setBackground(colors.green)
    :setForeground(colors.black)

local function refreshUI()
    local names = insideNames()
    if #names == 0 then
        insideLabel:setText("No one inside.")
    else
        insideLabel:setText("Inside: " .. table.concat(names, ", "))
    end

    lastEventLabel:setText(lastEvent)

    activeButton
        :setText(active and "ACTIVE" or "INACTIVE")
        :setBackground(active and colors.green or colors.red)
        :setForeground(active and colors.black or colors.white)
end

activeButton:onClick(function()
    active = not active
    if not active then
        setDoor(false)
        sendClosedNotice()
    else
        closedNotifiedSet = {} -- fresh start so a later close re-notifies everyone
    end
    refreshUI()
end)

refreshUI()

-- ====================== DETECTION LOOP ======================
local function update()
    local doorPlayers = doorDetector.getPlayersInCoords(DOOR_MIN, DOOR_MAX)
    local buildingPlayers = doorDetector.getPlayersInCoords(BUILDING_MIN, BUILDING_MAX)

    if active then
        setDoor(#doorPlayers > 0)

        -- Welcome new arrivals at the door (runs before the goodbye check).
        for _, name in ipairs(doorPlayers) do
            if not insideSet[name] then
                insideSet[name] = true
                sendWelcome(name)
            end
        end

        -- Goodbye: anyone who was inside but dropped out of the watched area.
        local stillPresent = {}
        for _, name in ipairs(buildingPlayers) do
            stillPresent[name] = true
        end

        for name in pairs(insideSet) do
            if not stillPresent[name] then
                sendBye(name)
                insideSet[name] = nil -- reset immediately, even if the toast above failed
            end
        end
    else
        setDoor(false)

        -- Closed: new arrivals get a toast instead of welcome; cleared when they leave.
        local atDoor = {}
        for _, name in ipairs(doorPlayers) do
            atDoor[name] = true
            if not closedNotifiedSet[name] then
                closedNotifiedSet[name] = true
                sendClosedNoticeToPlayer(name)
            end
        end
        for name in pairs(closedNotifiedSet) do
            if not atDoor[name] then
                closedNotifiedSet[name] = nil
            end
        end
    end

    refreshUI()

    if MODEM_ENABLED then
        local statusText
        if not active then
            statusText = "Closed"
        elseif next(insideSet) == nil then
            statusText = "No one inside."
        else
            statusText = "Inside: " .. table.concat(insideNames(), ", ")
        end
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
