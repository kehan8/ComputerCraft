-- WelcomeDoor
-- Door detector opens the door + welcomes new players. Building detector notices
-- when a welcomed player drops out of range and sends a goodbye + resets them.
-- Not admin gated -- everyone gets the same treatment.

-- ====================== CONFIG ======================
-- Your local settings live in config.lua (not touched by update.lua).
local config = require("config")
local BUILDING_NAME = config.BUILDING_NAME
local DETECTOR_NAME = config.DETECTOR_NAME
local DETECT_RANGE = config.DETECT_RANGE
local BUILDING_DETECTOR_ENABLED = config.BUILDING_DETECTOR_ENABLED
local BUILDING_DETECTOR_NAME = config.BUILDING_DETECTOR_NAME
local BUILDING_DETECT_RANGE = config.BUILDING_DETECT_RANGE
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
-- ======================================================

-- Protocol used to report status to the ControlRoom computer (see ../GymArena/ControlRoom).
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

local doorDetector = wrapPeripheral(DETECTOR_NAME, "door Player Detector")
local buildingDetector = nil
if BUILDING_DETECTOR_ENABLED then
    buildingDetector = wrapPeripheral(BUILDING_DETECTOR_NAME, "building Player Detector")
end
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
-- Names currently marked "inside" (welcomed, not yet said goodbye to).
local insideSet = {}
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

-- pcall-wrapped: player may go offline/teleport away before the toast lands.
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

-- Sent once to everyone currently "inside" the moment the button flips to INACTIVE.
local function sendClosedNotice()
    for name in pairs(insideSet) do
        pcall(function()
            chatBox.sendToastToPlayer(CLOSED_MESSAGE, CLOSED_TITLE, name)
        end)
    end
    lastEvent = "Closed notice sent"
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
    end
    refreshUI()
end)

refreshUI()

-- ====================== DETECTION LOOP ======================
local function update()
    local doorPlayers = doorDetector.getPlayersInRange(DETECT_RANGE)
    local buildingPlayers = nil
    if BUILDING_DETECTOR_ENABLED then
        buildingPlayers = buildingDetector.getPlayersInRange(BUILDING_DETECT_RANGE)
    end

    if active then
        setDoor(#doorPlayers > 0)

        -- Welcome: anyone new showing up at the door. Runs BEFORE the goodbye
        -- check below, so a name can never get a goodbye before its welcome.
        for _, name in ipairs(doorPlayers) do
            if not insideSet[name] then
                insideSet[name] = true
                sendWelcome(name)
            end
        end

        -- Goodbye: anyone who was inside but dropped out of the watched area.
        -- Falls back to the door detector alone if no 2nd detector is enabled.
        local stillPresent = {}
        for _, name in ipairs(BUILDING_DETECTOR_ENABLED and buildingPlayers or doorPlayers) do
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
