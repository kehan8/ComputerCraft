-- ControlRoom
-- Shows live status from AdminDoor/GymLock/TicTacToe/SimonSays. Devices claim a
-- row automatically on first broadcast, spilling onto extra pages (Prev/Next
-- buttons) once there are more devices than fit on one screen. TicTacToe/
-- SimonSays get a Reset button.

-- ====================== CONFIG ======================
-- Your local settings live in config.lua (not touched by update.lua).
local config = require("config")
local MODEM_NAME = config.MODEM_NAME
local MODEM_ENABLED = config.MODEM_ENABLED
local MONITOR_NAME = config.MONITOR_NAME
local MONITOR_SCALE = config.MONITOR_SCALE
local HEARTBEAT_TIMEOUT = config.HEARTBEAT_TIMEOUT
-- Fall back to sane defaults if you're updating from an older config.lua that
-- predates pagination (update.lua never rewrites config.lua) -- ROWS_PER_PAGE
-- didn't exist yet, and MAX_DEVICES used to mean "rows to pre-draw" (a much
-- smaller number than its new meaning, "total devices tracked"), so an old
-- value there is still safe to reuse as ROWS_PER_PAGE's fallback too.
local ROWS_PER_PAGE = config.ROWS_PER_PAGE or config.MAX_DEVICES or 8
local MAX_DEVICES = config.MAX_DEVICES or 32
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
-- All rows pre-drawn blank here -- Basalt won't reliably draw widgets added
-- after basalt.run() starts, so only :setText() runs below this point. These
-- rows are one PAGE worth of slots and get reused/refilled as you flip pages --
-- a row is no longer permanently tied to one device.
-- Each row: name + ONLINE/OFFLINE badge + Reset button, status text below.
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
            -- Reads whichever device this row currently shows, not a fixed one --
            -- the row gets refilled every time the page changes.
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
-- One extra row below the device rows: "< Prev" / "Next >" buttons plus a
-- "Page X/Y" label. Always drawn, even with a single page -- clicking Prev/Next
-- when there's nothing else to show is a harmless no-op (see renderPage below).
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
-- Ordered by first-seen (append-only) and keyed by rednet computer ID (always
-- unique, assigned by CC:Tweaked -- no manual device IDs to keep in sync between
-- this config and each satellite's config). A device keeps its place in this
-- list -- and therefore its page and row -- for as long as ControlRoom runs,
-- whether it's online or offline.
local deviceList = {}
local deviceIndex = {} -- senderId -> index into deviceList
local currentPage = 1

local function totalPages()
    return math.max(1, math.ceil(#deviceList / ROWS_PER_PAGE))
end

-- Appends a never-seen-before device to the tracking list. Returns nil (and the
-- broadcast is silently dropped) once MAX_DEVICES total devices are tracked.
local function registerDevice(senderId, controllable)
    if #deviceList >= MAX_DEVICES then
        return nil -- out of tracking slots; raise MAX_DEVICES in config.lua
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

-- Fills the on-screen rows with whichever page's worth of devices belongs
-- there, and refreshes the "Page X/Y" bar. Safe to call repeatedly (e.g. on
-- every status update) -- it just redraws the current page.
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
            -- Same wording the device shows itself; stays visible (dimmed) while offline.
            slot.statusLabel
                :setText(device.status or "")
                :setForeground(device.online and colors.lime or colors.gray)
            if device.controllable then
                slot.button:setText("Reset"):setBackground(colors.green)
            else
                slot.button:setText(""):setBackground(colors.black)
            end
        else
            -- Past the end of the device list on this page -- blank row.
            slot.nameLabel:setText("")
            slot.badge:setText(""):setBackground(colors.black):setForeground(colors.white)
            slot.statusLabel:setText("")
            slot.button:setText(""):setBackground(colors.black)
        end
    end

    -- Always shown, even with a single page -- clicking Prev/Next on page 1/1
    -- just re-renders the same page (clamped above), so there's nothing to hide.
    pageLabel:setText("Page " .. currentPage .. "/" .. totalPages())
end

prevButton:onClick(function() renderPage(currentPage - 1) end)
nextButton:onClick(function() renderPage(currentPage + 1) end)

-- ====================== BACKGROUND TASKS ======================
-- basalt.schedule() doesn't resume on "rednet_message" -- these run via
-- `parallel` alongside basalt.run() instead.

-- Listens for status broadcasts and registers/updates a device the first
-- time it hears from it.
local function listenForStatus()
    while true do
        local senderId, msg = rednet.receive(PROTOCOL)
        if msg and msg.status then
            -- Falls back to "Computer <ID>" if never labeled via os.setComputerLabel().
            local label = msg.label or ("Computer " .. senderId)
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

-- Marks a device "offline" once it's gone quiet for HEARTBEAT_TIMEOUT seconds.
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
