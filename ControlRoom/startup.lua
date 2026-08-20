-- ControlRoom
-- Listens on rednet for status broadcasts from the other puzzle/door computers
-- (AdminDoor, GymLock, TicTacToe, SimonSays) and shows them on a monitor. Devices
-- show up automatically the moment they broadcast -- nothing to configure per device.
-- TicTacToe and SimonSays get a "Reset" button so you don't have to walk over and
-- press "New game"/"Start" on the puzzle itself.

-- ====================== CONFIG ======================
-- Your local settings live in config.lua (not touched by update.lua).
local config = require("config")
local MODEM_NAME = config.MODEM_NAME
local MONITOR_NAME = config.MONITOR_NAME
local MONITOR_SCALE = config.MONITOR_SCALE
local HEARTBEAT_TIMEOUT = config.HEARTBEAT_TIMEOUT
-- ======================================================

if not fs.exists("basalt") and not fs.exists("basalt.lua") then
    print("Installing Basalt UI library...")
    shell.run("wget run https://raw.githubusercontent.com/Pyroxenium/Basalt2/main/install.lua")
end
local basalt = require("basalt")

print("ControlRoom is running")

-- Matches the protocol string every satellite (AdminDoor/GymLock/TicTacToe/SimonSays)
-- broadcasts on and listens for commands on.
local PROTOCOL = "controlroom"
local CONTROLLABLE_TYPES = { TicTacToe = true, SimonSays = true }

local mon = MONITOR_NAME and peripheral.wrap(MONITOR_NAME) or peripheral.find("monitor")
if MONITOR_NAME and not mon then
    error("Could not find monitor '" .. MONITOR_NAME .. "'. Check the cable/name.")
end

local screen
if mon then
    mon.setTextScale(MONITOR_SCALE)
    screen = basalt.createFrame():setTerm(mon)
else
    screen = basalt.getMainFrame()
end

if not peripheral.isPresent(MODEM_NAME) then
    error("Could not find modem '" .. MODEM_NAME .. "'. Check the wireless modem is attached and named correctly.")
end
rednet.open(MODEM_NAME)

local w, _ = screen:getSize()

screen:addLabel()
    :setText("ControlRoom")
    :setPosition(2, 1)
    :setSize(w - 2, 1)
    :setForeground(colors.white)

-- ====================== DEVICE ROWS ======================
-- Keyed by rednet computer ID (always unique, assigned by CC:Tweaked -- no manual
-- device IDs to keep in sync between this config and each satellite's config).
local deviceState = {}
local nextRowY = 3

-- Same wording the device shows on its own screen -- never a reworded summary.
local function rowText(state)
    if state.online then
        return state.label .. ": " .. (state.status or "")
    else
        return state.label .. ": offline"
    end
end

local function createRow(id, controllable)
    local y = nextRowY
    nextRowY = nextRowY + 2

    local labelWidth = controllable and (w - 12) or (w - 2)
    local row = {
        text = screen:addLabel()
            :setPosition(2, y)
            :setSize(labelWidth, 1)
            :setForeground(colors.lightGray),
    }

    if controllable then
        row.button = screen:addButton()
            :setText("Reset")
            :setPosition(w - 9, y)
            :setSize(8, 1)
            :setBackground(colors.green)
            :setForeground(colors.white)
            :onClick(function()
                rednet.send(id, { cmd = "new_game" }, PROTOCOL)
            end)
    end

    return row
end

local function refreshRow(id)
    local state = deviceState[id]
    state.row.text
        :setText(rowText(state))
        :setForeground(state.online and colors.lime or colors.gray)
end

-- ====================== BACKGROUND TASKS ======================
-- basalt.schedule() only resumes its coroutines on event types Basalt itself
-- recognizes (clicks, timers, ...) -- not on "rednet_message". So these run
-- through the OS's own `parallel` API instead, alongside basalt.run(), which
-- forwards every raw event to every branch.

-- Listens for status broadcasts and creates/updates a row per device the first
-- time it hears from it.
local function listenForStatus()
    while true do
        local senderId, msg = rednet.receive(PROTOCOL)
        if msg and msg.label then
            local state = deviceState[senderId]
            if not state then
                state = { row = createRow(senderId, CONTROLLABLE_TYPES[msg.type] == true) }
                deviceState[senderId] = state
            end
            state.label = msg.label
            state.status = msg.status
            state.online = true
            state.lastSeen = os.clock()
            refreshRow(senderId)
        end
    end
end

-- Marks a device "offline" once it's gone quiet for HEARTBEAT_TIMEOUT seconds.
local function watchForStaleDevices()
    while true do
        os.sleep(1)
        for id, state in pairs(deviceState) do
            if state.online and os.clock() - state.lastSeen > HEARTBEAT_TIMEOUT then
                state.online = false
                refreshRow(id)
            end
        end
    end
end

parallel.waitForAny(function() basalt.run() end, listenForStatus, watchForStaleDevices)
