-- ControlRoom: shows live status from AdminDoor/GymLock/TicTacToe/SimonSays.
-- Devices claim a row on first broadcast, spilling onto extra pages once full.
-- TicTacToe/SimonSays get a Reset button.

-- ====================== CONFIG ======================
local config = require("config")
local MODEM_NAME = config.MODEM_NAME
local MODEM_ENABLED = config.MODEM_ENABLED
local MONITOR_NAME = config.MONITOR_NAME
local MONITOR_SCALE = config.MONITOR_SCALE
local HEARTBEAT_TIMEOUT = config.HEARTBEAT_TIMEOUT
local ROWS_PER_PAGE = config.ROWS_PER_PAGE or config.MAX_DEVICES or 8 -- fallback for pre-pagination config.lua
local MAX_DEVICES = config.MAX_DEVICES or 32
-- ======================================================

if not fs.exists("basalt") and not fs.exists("basalt.lua") then
    print("Installing Basalt UI library...")
    shell.run("wget run https://raw.githubusercontent.com/Pyroxenium/Basalt2/main/install.lua")
end
local basalt = require("basalt")

print("ControlRoom is running")

-- protocol every satellite broadcasts/listens on
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

if not MODEM_ENABLED then
    error("ControlRoom requires a modem -- set MODEM_ENABLED = true in config.lua.")
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
-- rows pre-drawn blank (Basalt won't reliably draw widgets added after
-- basalt.run() starts), reused/refilled per page. Each row: name + badge +
-- Reset button, status text below.
local ROW_HEIGHT = 3 -- name/badge/button line, status line, blank spacer
local NAME_WIDTH = math.max(1, w - 21)

local slots = {}
for i = 1, ROWS_PER_PAGE do
    local y = 3 + (i - 1) * ROW_HEIGHT
    local slot = { device = nil }

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
            -- reads whichever device this row currently shows (refilled per page)
            if slot.device and slot.device.controllable and slot.device.senderId then
                rednet.send(slot.device.senderId, { cmd = "new_game" }, PROTOCOL)
            end
        end)

    slot.statusLabel = screen:addLabel()
        :setText("")
        :setPosition(2, y + 1)
        :setSize(w - 2, 1)
        :setForeground(colors.lightGray)

    slots[i] = slot
end

-- ====================== PAGINATION BAR ======================
-- Prev/Next buttons + "Page X/Y" label, always drawn (even with 1 page)
local pagerY = 3 + ROWS_PER_PAGE * ROW_HEIGHT

local prevButton = screen:addButton()
    :setText("< Prev")
    :setPosition(2, pagerY)
    :setSize(8, 1)
    :setBackground(colors.gray)
    :setForeground(colors.white)

local nextButton = screen:addButton()
    :setText("Next >")
    :setPosition(w - 9, pagerY)
    :setSize(8, 1)
    :setBackground(colors.gray)
    :setForeground(colors.white)

local pageLabel = screen:addLabel()
    :setText("")
    :setPosition(11, pagerY)
    :setSize(math.max(1, w - 20), 1)
    :setForeground(colors.white)

-- ====================== DEVICE TRACKING ======================
-- ordered by first-seen, keyed by rednet computer ID; keeps its page/row
-- for as long as ControlRoom runs, online or offline
local deviceList = {}
local deviceIndex = {} -- senderId -> index into deviceList
local currentPage = 1

local function totalPages()
    return math.max(1, math.ceil(#deviceList / ROWS_PER_PAGE))
end

-- adds a never-seen device; returns nil once MAX_DEVICES is reached
local function registerDevice(senderId, controllable)
    if #deviceList >= MAX_DEVICES then
        return nil
    end
    local device = {
        senderId = senderId,
        controllable = controllable,
        online = false,
        label = "",
        status = "",
        lastSeen = 0,
    }
    table.insert(deviceList, device)
    deviceIndex[senderId] = #deviceList
    return device
end

-- fills the on-screen rows for page n, refreshes the pager; safe to re-call
local function renderPage(n)
    currentPage = math.min(math.max(n, 1), totalPages())
    local firstIndex = (currentPage - 1) * ROWS_PER_PAGE

    for i, slot in ipairs(slots) do
        local device = deviceList[firstIndex + i]
        slot.device = device

        if device then
            slot.nameLabel:setText(device.label)
            slot.badge
                :setText(device.online and "ONLINE" or "OFFLINE")
                :setBackground(device.online and colors.green or colors.gray)
                :setForeground(device.online and colors.black or colors.white)
            slot.statusLabel
                :setText(device.status or "")
                :setForeground(device.online and colors.lime or colors.gray)
            if device.controllable then
                slot.button:setText("Reset"):setBackground(colors.green)
            else
                slot.button:setText(""):setBackground(colors.black)
            end
        else
            slot.nameLabel:setText("")
            slot.badge:setText(""):setBackground(colors.black):setForeground(colors.white)
            slot.statusLabel:setText("")
            slot.button:setText(""):setBackground(colors.black)
        end
    end

    pageLabel:setText("Page " .. currentPage .. "/" .. totalPages())
end

prevButton:onClick(function() renderPage(currentPage - 1) end)
nextButton:onClick(function() renderPage(currentPage + 1) end)

-- ====================== BACKGROUND TASKS ======================
-- parallel, not basalt.schedule() (doesn't resume on rednet_message)

-- registers/updates a device on each status broadcast
local function listenForStatus()
    while true do
        local senderId, msg = rednet.receive(PROTOCOL)
        if msg and msg.status then
            local label = msg.label or ("Computer " .. senderId) -- unlabeled fallback
            local device = deviceIndex[senderId] and deviceList[deviceIndex[senderId]]
                or registerDevice(senderId, CONTROLLABLE_TYPES[msg.type] == true)
            if device then
                device.label = label
                device.status = msg.status
                device.online = true
                device.lastSeen = os.epoch("utc")
                renderPage(currentPage)
            end
        end
    end
end

-- marks a device offline after HEARTBEAT_TIMEOUT seconds of silence
local function watchForStaleDevices()
    while true do
        os.sleep(1)
        local changed = false
        for _, device in ipairs(deviceList) do
            if device.online and os.epoch("utc") - device.lastSeen > HEARTBEAT_TIMEOUT * 1000 then
                device.online = false
                changed = true
            end
        end
        if changed then
            renderPage(currentPage)
        end
    end
end

renderPage(1)
parallel.waitForAny(function() basalt.run() end, listenForStatus, watchForStaleDevices)
