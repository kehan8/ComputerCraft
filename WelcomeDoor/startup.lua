-- WelcomeDoor: opens each door independently and welcomes/says goodbye to
-- players; not admin gated. See README for the multi-door design.

-- ====================== CONFIG ======================
local config = require("config")
local BUILDING_NAME = config.BUILDING_NAME
local DETECTOR_NAME = config.DETECTOR_NAME
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

local locations = require("locations")

-- normalizes each axis so MIN <= MAX
local function normalizeBox(min, max)
    local nmin, nmax = {}, {}
    for _, axis in ipairs({ "x", "y", "z" }) do
        nmin[axis] = math.min(min[axis], max[axis])
        nmax[axis] = math.max(min[axis], max[axis])
    end
    return nmin, nmax
end

-- door box must fit inside the building box (see README)
local function boxContains(outerMin, outerMax, innerMin, innerMax)
    for _, axis in ipairs({ "x", "y", "z" }) do
        if innerMin[axis] < outerMin[axis] or innerMax[axis] > outerMax[axis] then
            return false
        end
    end
    return true
end

if not locations.DOORS or #locations.DOORS == 0 then
    error("locations.lua must define DOORS with at least one door table (see locations.lua).")
end

local BUILDING_MIN, BUILDING_MAX = normalizeBox(locations.BUILDING_MIN, locations.BUILDING_MAX)

-- self-contained door tables: box + wiring together (see README)
local doors = {}
for i, raw in ipairs(locations.DOORS) do
    local name = raw.name or ("Door " .. i)

    if not raw.relay and not raw.computer_side then
        error("locations.lua: door '" .. name .. "' needs a relay or a computer_side (or both).")
    end
    if raw.relay and not raw.relay_side then
        error("locations.lua: door '" .. name .. "' has a relay but no relay_side.")
    end

    local nmin, nmax = normalizeBox(raw.min, raw.max)
    if not boxContains(BUILDING_MIN, BUILDING_MAX, nmin, nmax) then
        error("locations.lua: door '" .. name .. "' box must fit entirely inside BUILDING_MIN/BUILDING_MAX.")
    end

    doors[i] = {
        name = name,
        min = nmin,
        max = nmax,
        relay = raw.relay,
        relay_side = raw.relay_side,
        computer_side = raw.computer_side,
        relayPeripheral = nil, -- wrapped below, once peripherals are set up
    }
end
-- ======================================================

-- Reports status to ControlRoom (see ../ControlRoom).
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

local doorDetector = wrapPeripheral(DETECTOR_NAME, "Player Detector")
local chatBox = wrapPeripheral(CHATBOX_NAME, "Chat Box")

-- wrap relays now so a typo fails fast at startup
for _, door in ipairs(doors) do
    if door.relay then
        door.relayPeripheral = wrapPeripheral(door.relay, "redstone relay for door '" .. door.name .. "'")
    end
end

if MODEM_ENABLED then
    if not peripheral.isPresent(MODEM_NAME) then
        error("Could not find modem '" .. MODEM_NAME .. "'. Check the wireless modem is attached and named correctly.")
    end
    rednet.open(MODEM_NAME)
end

-- ====================== STATE ======================
-- names currently welcomed, not yet said goodbye to (building-wide)
local insideSet = {}
-- Names already sent the closed toast at a door; cleared when they leave.
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

local function setDoorRelay(door, open)
    if door.relayPeripheral then
        door.relayPeripheral.setOutput(door.relay_side, open)
    end
    if door.computer_side then
        redstone.setOutput(door.computer_side, open)
    end
end

local function closeAllDoors()
    for _, door in ipairs(doors) do
        setDoorRelay(door, false)
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

-- Sent to new arrivals at any door while INACTIVE.
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

-- also called remotely from ControlRoom (cmd = "toggle_active")
local function toggleActive()
    active = not active
    if not active then
        closeAllDoors()
        sendClosedNotice()
    else
        closedNotifiedSet = {} -- fresh start so a later close re-notifies everyone
    end
    refreshUI()
end

activeButton:onClick(toggleActive)

refreshUI()

-- ====================== DETECTION LOOP ======================
local function update()
    local buildingPlayers = doorDetector.getPlayersInCoords(BUILDING_MIN, BUILDING_MAX)

    -- per-door scan, plus a deduped union for the welcome/closed logic below
    local unionSeen = {}
    local unionPlayers = {}
    local openDoorNames = {}

    for _, door in ipairs(doors) do
        local playersHere = doorDetector.getPlayersInCoords(door.min, door.max)
        local hasPlayers = #playersHere > 0
        setDoorRelay(door, active and hasPlayers)
        if active and hasPlayers then
            openDoorNames[#openDoorNames + 1] = door.name
        end
        for _, name in ipairs(playersHere) do
            if not unionSeen[name] then
                unionSeen[name] = true
                unionPlayers[#unionPlayers + 1] = name
            end
        end
    end

    if active then
        -- Welcome new arrivals at any door (runs before the goodbye check).
        for _, name in ipairs(unionPlayers) do
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
        -- Closed: new arrivals get a toast instead of welcome; cleared when they leave.
        local atDoor = {}
        for _, name in ipairs(unionPlayers) do
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
        elseif #openDoorNames == 0 then
            statusText = "All doors closed"
        else
            statusText = "Open: " .. table.concat(openDoorNames, ", ")
        end
        rednet.broadcast({ label = os.getComputerLabel(), type = DEVICE_TYPE, status = statusText, active = active }, PROTOCOL)
    end
end

basalt.schedule(function()
    while true do
        update()
        os.sleep(POLL_INTERVAL)
    end
end)

-- parallel, not basalt.schedule (see README)
local function listenForCommands()
    while true do
        local _, msg = rednet.receive(PROTOCOL)
        if msg and msg.cmd == "toggle_active" then
            toggleActive()
        end
    end
end

if MODEM_ENABLED then
    parallel.waitForAny(function() basalt.run() end, listenForCommands)
else
    basalt.run()
end
