-- FossilLab
-- Live status monitor for Cobblemon's Fossil Analyzer / Restoration Tank
-- multiblock, read via an Advanced Peripherals Block Reader placed against the
-- Analyzer (see test_blockreader.lua for how this was confirmed in-game --
-- no coordinates, no Command Computer/OP needed). fossildata.lua interprets
-- the raw NBT into a clean state; fossilhistory.lua remembers past
-- restorations across reboots (the multiblock forgets InsertedFossil itself
-- the moment the Pokemon is claimed).

-- ====================== CONFIG ======================
-- Your local settings live in config.lua (not touched by update.lua).
local config = require("config")
local BLOCKREADER_NAME = config.BLOCKREADER_NAME
local POLL_INTERVAL = config.POLL_INTERVAL
local MONITOR_NAME = config.MONITOR_NAME
local MONITOR_SCALE = config.MONITOR_SCALE
local HISTORY_MAX_ENTRIES = config.HISTORY_MAX_ENTRIES
local MODEM_NAME = config.MODEM_NAME
local MODEM_ENABLED = config.MODEM_ENABLED
local HEARTBEAT_INTERVAL = config.HEARTBEAT_INTERVAL
-- ======================================================

-- Protocol used to report status to the ControlRoom computer (see
-- ../GymArena/ControlRoom). FossilLab isn't "controllable" -- there's no
-- reset/new-game concept for a fossil machine -- so it only ever broadcasts,
-- it never listens for commands.
local PROTOCOL = "controlroom"
local DEVICE_TYPE = "FossilLab"

if not fs.exists("basalt") and not fs.exists("basalt.lua") then
    print("Installing Basalt UI library...")
    shell.run("wget run https://raw.githubusercontent.com/Pyroxenium/Basalt2/main/install.lua")
end
local basalt = require("basalt")

print("FossilLab is running")

local fossildata = require("fossildata")
local fossilhistory = require("fossilhistory")

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

if MODEM_ENABLED then
    if not peripheral.isPresent(MODEM_NAME) then
        error("Could not find modem '" .. MODEM_NAME .. "'. Check the wireless modem is attached and named correctly.")
    end
    rednet.open(MODEM_NAME)
end

-- Not fatal if missing -- unlike the monitor/modem, a Block Reader can be
-- placed/replaced later. The UI just shows "NO SIGNAL" until it's found.
local reader = fossildata.findReader(BLOCKREADER_NAME)
if BLOCKREADER_NAME and not reader then
    print("Warning: could not find Block Reader '" .. BLOCKREADER_NAME .. "'. Check the cable/name.")
end

local history = fossilhistory.load()

-- ====================== UI ======================
-- Colored blocks (progress bar, phase badge) are built from Buttons, not
-- Labels -- Basalt2 Label backgrounds don't render in this setup, only text
-- does (see TicTacToe's icontest.lua finding). Nothing here is clickable;
-- Buttons are used purely for their background color.
local w, h = screen:getSize()

screen:addLabel()
    :setText("FossilLab")
    :setPosition(2, 1)
    :setSize(w - 2, 1)
    :setForeground(colors.white)

local PHASE_INFO = {
    unformed  = { text = "MULTIBLOCK NOT FORMED", bg = colors.red,    fg = colors.white },
    idle      = { text = "IDLE",                  bg = colors.gray,   fg = colors.white },
    analyzing = { text = "ANALYZING...",          bg = colors.orange, fg = colors.black },
    ready     = { text = "READY -- CLAIM ME!",    bg = colors.lime,   fg = colors.black },
}

local phaseBadge = screen:addButton()
    :setText("Connecting...")
    :setPosition(2, 3)
    :setSize(w - 2, 1)
    :setBackground(colors.gray)
    :setForeground(colors.white)

screen:addLabel()
    :setText("Progress")
    :setPosition(2, 5)
    :setSize(w - 2, 1)
    :setForeground(colors.lightGray)

local barY = 6
local barSegments = {}
for i = 1, math.max(1, w - 2) do
    barSegments[i] = screen:addButton()
        :setText("")
        :setPosition(1 + i, barY)
        :setSize(1, 1)
        :setBackground(colors.gray)
end

local percentLabel = screen:addLabel()
    :setText("--")
    :setPosition(2, 7)
    :setSize(w - 2, 1)
    :setForeground(colors.white)

local fossilLabel = screen:addLabel()
    :setText("Fossil: --")
    :setPosition(2, 9)
    :setSize(w - 2, 1)
    :setForeground(colors.white)

local timeLabel = screen:addLabel()
    :setText("Time left: --:--")
    :setPosition(2, 10)
    :setSize(w - 2, 1)
    :setForeground(colors.white)

screen:addLabel()
    :setText("Recent finds:")
    :setPosition(2, 12)
    :setSize(w - 2, 1)
    :setForeground(colors.lightGray)

-- All history rows pre-drawn blank here (same reasoning as ControlRoom's device
-- rows) -- only :setText() runs on them below this point.
local HISTORY_START_Y = 13
local historyLabels = {}
for i = 1, math.max(0, h - HISTORY_START_Y + 1) do
    historyLabels[i] = screen:addLabel()
        :setText("")
        :setPosition(2, HISTORY_START_Y + i - 1)
        :setSize(w - 2, 1)
        :setForeground(colors.white)
end

-- ====================== RENDER ======================
-- Short species name only ("Omanyte" not "cobblemon:omanyte") -- the
-- namespace prefix is just noise on a small monitor.
local function shortSpecies(id)
    if not id then return "--" end
    local short = id:match(":(.+)$") or id
    local capitalized = short:gsub("^%l", string.upper)
    return capitalized
end

local function renderHistory()
    for i, label in ipairs(historyLabels) do
        local entry = history[i]
        if entry then
            label:setText(textutils.formatTime(entry.gameTime, true) .. "  " .. shortSpecies(entry.species))
        else
            label:setText("")
        end
    end
end

local lastStatusText = "Starting up..."
local blinkOn = false

local function renderState(state)
    local info = PHASE_INFO[state.phase] or PHASE_INFO.unformed
    local badgeBg = info.bg
    if state.phase == "ready" then
        -- Blink to grab attention -- alternates every poll tick.
        blinkOn = not blinkOn
        badgeBg = blinkOn and colors.lime or colors.green
    end
    phaseBadge:setText(info.text):setBackground(badgeBg):setForeground(info.fg)

    local filled = math.floor(#barSegments * state.percent / 100 + 0.5)
    for i, seg in ipairs(barSegments) do
        seg:setBackground(i <= filled and colors.lime or colors.gray)
    end
    percentLabel:setText(state.percent .. "%  (" .. state.organicContent .. "/128)")

    if state.phase == "ready" then
        fossilLabel:setText("Fossil: " .. shortSpecies(state.insertedFossil) .. " -- go claim it!")
        timeLabel:setText("Claim window: " .. fossildata.formatTicks(state.protectedTimeLeft))
    elseif state.phase == "analyzing" then
        local firstStack = state.insertedFossilStacks[1]
        fossilLabel:setText("Fossil: " .. shortSpecies(firstStack and firstStack.id))
        timeLabel:setText("Time left: " .. fossildata.formatTicks(state.timeLeft))
    else
        fossilLabel:setText("Fossil: --")
        timeLabel:setText("Time left: --:--")
    end

    lastStatusText = info.text .. " (" .. state.percent .. "%)"
end

local function renderError(message)
    phaseBadge:setText("NO SIGNAL"):setBackground(colors.red):setForeground(colors.white)
    for _, seg in ipairs(barSegments) do seg:setBackground(colors.gray) end
    percentLabel:setText("--")
    fossilLabel:setText("Fossil: --")
    timeLabel:setText("Time left: --:--")
    lastStatusText = "No signal: " .. message
end

renderHistory()

-- ====================== POLL LOOP ======================
-- HasCreatedPokemon flips 0 -> 1 the instant the analysis finishes; edge-detect
-- that (not just "phase == ready" every tick) so it's logged exactly once, and
-- a restart mid-"ready" state doesn't re-log the same find.
local wasReady = false

local function poll()
    if not reader then
        reader = fossildata.findReader(BLOCKREADER_NAME) -- retry, in case it was placed/reconnected after startup
    end
    if not reader then
        renderError("Block Reader not connected")
        return
    end

    local state, err = fossildata.read(reader)
    if not state then
        renderError(err)
        return
    end

    if state.phase == "ready" and not wasReady then
        history = fossilhistory.add(history, state.insertedFossil, HISTORY_MAX_ENTRIES)
        renderHistory()
    end
    wasReady = (state.phase == "ready")

    renderState(state)
end

-- Background loops started immediately (not via basalt.schedule -- that only
-- reliably resumes coroutines registered from inside an existing Basalt event,
-- not ones fired off cold at script start; parallel.waitForAny is the proven
-- pattern for that, same as ControlRoom's listenForStatus/watchForStaleDevices).
local function pollLoop()
    while true do
        poll()
        os.sleep(POLL_INTERVAL)
    end
end

local function reportStatus()
    while true do
        rednet.broadcast({ label = os.getComputerLabel(), type = DEVICE_TYPE, status = lastStatusText }, PROTOCOL)
        os.sleep(HEARTBEAT_INTERVAL)
    end
end

if MODEM_ENABLED then
    parallel.waitForAny(function() basalt.run() end, pollLoop, reportStatus)
else
    parallel.waitForAny(function() basalt.run() end, pollLoop)
end
