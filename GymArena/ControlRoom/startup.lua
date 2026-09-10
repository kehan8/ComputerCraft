-- ControlRoom
-- Listens on rednet for status broadcasts from the other puzzle/door computers
-- (AdminDoor, GymLock, TicTacToe, SimonSays) and shows them on a monitor. Devices
-- claim a row automatically the moment they broadcast -- nothing to configure per
-- device. TicTacToe and SimonSays get a "Reset" button so you don't have to walk
-- over and press "New game"/"Start" on the puzzle itself.

-- ====================== CONFIG ======================
-- Your local settings live in config.lua (not touched by update.lua).
local config = require("config")
local MODEM_NAME = config.MODEM_NAME
local MONITOR_NAME = config.MONITOR_NAME
local MONITOR_SCALE = config.MONITOR_SCALE
local HEARTBEAT_TIMEOUT = config.HEARTBEAT_TIMEOUT
local MAX_DEVICES = config.MAX_DEVICES
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
-- All MAX_DEVICES rows are created here, up front, blank. Basalt doesn't reliably
-- draw widgets that get added after basalt.run() has already started, so nothing
-- below this point ever calls addLabel()/addButton() again -- only :setText() on
-- these pre-existing widgets.
--
-- Each device gets a 2-line card: name + ONLINE/OFFLINE badge + Reset button on
-- the first line, and the full copied status text on its own line below (so a
-- long status, like GymLock's, never has to fight the button for space).
local ROW_HEIGHT = 3 -- name/badge/button line, status line, blank spacer
local NAME_WIDTH = math.max(1, w - 21)

local slots = {}
for i = 1, MAX_DEVICES do
    local y = 3 + (i - 1) * ROW_HEIGHT
    local slot = { senderId = nil, controllable = false, online = false, label = "", status = "" }

    slot.nameLabel = screen:addLabel()
        :setText("")
        :setPosition(2, y)
        :setSize(NAME_WIDTH, 1)
        :setForeground(colors.white)

    slot.badge = screen:addButton()
        :setText("")
        :setPosition(w - 18, y)
        :setSize(8, 1)
        :setBackground(colors.black)
        :setForeground(colors.white)

    slot.button = screen:addButton()
        :setText("")
        :setPosition(w - 9, y)
        :setSize(8, 1)
        :setBackground(colors.black)
        :setForeground(colors.white)
        :onClick(function()
            if slot.controllable and slot.senderId then
                rednet.send(slot.senderId, { cmd = "new_game" }, PROTOCOL)
            end
        end)

    slot.statusLabel = screen:addLabel()
        :setText("")
        :setPosition(2, y + 1)
        :setSize(w - 2, 1)
        :setForeground(colors.lightGray)

    slots[i] = slot
end

-- Keyed by rednet computer ID (always unique, assigned by CC:Tweaked -- no manual
-- device IDs to keep in sync between this config and each satellite's config).
local deviceSlot = {}
local nextFreeSlot = 1

local function claimSlot(senderId, controllable)
    if nextFreeSlot > MAX_DEVICES then
        return nil -- out of rows; raise MAX_DEVICES in config.lua
    end
    local slot = slots[nextFreeSlot]
    nextFreeSlot = nextFreeSlot + 1

    slot.senderId = senderId
    slot.controllable = controllable
    if controllable then
        slot.button:setText("Reset"):setBackground(colors.green)
    end

    deviceSlot[senderId] = slot
    return slot
end

local function refreshRow(slot)
    slot.nameLabel:setText(slot.label)

    slot.badge
        :setText(slot.online and "ONLINE" or "OFFLINE")
        :setBackground(slot.online and colors.green or colors.gray)
        :setForeground(slot.online and colors.black or colors.white)

    -- Same wording the device shows on its own screen -- never a reworded
    -- summary. Keeps showing the last known text (dimmed) while offline,
    -- rather than replacing it, so you can still see what it was doing.
    slot.statusLabel
        :setText(slot.status or "")
        :setForeground(slot.online and colors.lime or colors.gray)
end

-- ====================== BACKGROUND TASKS ======================
-- basalt.schedule() only resumes its coroutines on event types Basalt itself
-- recognizes (clicks, timers, ...) -- not on "rednet_message". So these run
-- through the OS's own `parallel` API instead, alongside basalt.run(), which
-- forwards every raw event to every branch.

-- Listens for status broadcasts and claims/updates a row per device the first
-- time it hears from it.
local function listenForStatus()
    while true do
        local senderId, msg = rednet.receive(PROTOCOL)
        if msg and msg.status then
            -- Falls back to "Computer <ID>" if that computer never got an
            -- os.setComputerLabel() -- e.g. it was installed before ControlRoom
            -- support was added, since `update`/`update_full` don't re-run install.lua.
            local label = msg.label or ("Computer " .. senderId)
            local slot = deviceSlot[senderId] or claimSlot(senderId, CONTROLLABLE_TYPES[msg.type] == true)
            if slot then
                slot.label = label
                slot.status = msg.status
                slot.online = true
                slot.lastSeen = os.clock()
                refreshRow(slot)
            end
        end
    end
end

-- Marks a device "offline" once it's gone quiet for HEARTBEAT_TIMEOUT seconds.
local function watchForStaleDevices()
    while true do
        os.sleep(1)
        for _, slot in pairs(deviceSlot) do
            if slot.online and os.clock() - slot.lastSeen > HEARTBEAT_TIMEOUT then
                slot.online = false
                refreshRow(slot)
            end
        end
    end
end

parallel.waitForAny(function() basalt.run() end, listenForStatus, watchForStaleDevices)
