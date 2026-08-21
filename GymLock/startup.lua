-- GymLock
-- Reads the "solved" redstone signal from the SimonSays and TicTacToe puzzle computers
-- (one relay input each) and, once BOTH are high, opens the main door (2 relay outputs,
-- since it's a piston door). An admin lever (its own relay input) can force the door
-- open regardless of the puzzles -- it only affects the main door, never the puzzles
-- themselves. A Player Detector at the exit acts as an anti-cheat gate: anyone spotted
-- there force-closes the door and resets both puzzles. No monitor/UI needed -- status
-- is just printed on this computer.

-- ====================== CONFIG ======================
-- Your local settings live in config.lua (not touched by update.lua).
local config = require("config")
local SIMON_RELAY_NAME = config.SIMON_RELAY_NAME
local SIMON_SIDE = config.SIMON_SIDE
local TICTACTOE_RELAY_NAME = config.TICTACTOE_RELAY_NAME
local TICTACTOE_SIDE = config.TICTACTOE_SIDE
local ADMIN_RELAY_NAME = config.ADMIN_RELAY_NAME
local ADMIN_SIDE = config.ADMIN_SIDE
local DOOR_RELAY_NAME_1 = config.DOOR_RELAY_NAME_1
local DOOR_SIDE_1 = config.DOOR_SIDE_1
local DOOR_RELAY_NAME_2 = config.DOOR_RELAY_NAME_2
local DOOR_SIDE_2 = config.DOOR_SIDE_2
local MODEM_NAME = config.MODEM_NAME
local HEARTBEAT_INTERVAL = config.HEARTBEAT_INTERVAL
local GATE_ENABLED = config.GATE_ENABLED
local GATE_DETECTOR_NAME = config.GATE_DETECTOR_NAME
local GATE_DETECT_RANGE = config.GATE_DETECT_RANGE
local GATE_POLL_INTERVAL = config.GATE_POLL_INTERVAL
-- ======================================================

-- Protocol used to report status to the ControlRoom computer (see ../ControlRoom).
local PROTOCOL = "controlroom"
local DEVICE_TYPE = "GymLock"

local function wrapRelay(name)
    local relay = peripheral.wrap(name)
    if not relay then
        error("Could not find redstone relay '" .. name .. "'. Check the cable/name.")
    end
    return relay
end

local simonRelay = wrapRelay(SIMON_RELAY_NAME)
local tictactoeRelay = wrapRelay(TICTACTOE_RELAY_NAME)
local adminRelay = wrapRelay(ADMIN_RELAY_NAME)
local doorRelay1 = wrapRelay(DOOR_RELAY_NAME_1)
local doorRelay2 = wrapRelay(DOOR_RELAY_NAME_2)

local gateDetector = nil
if GATE_ENABLED then
    gateDetector = peripheral.wrap(GATE_DETECTOR_NAME)
    if not gateDetector then
        error("Could not find Player Detector '" .. GATE_DETECTOR_NAME .. "'. Check the cable/name, or set GATE_ENABLED = false in config.lua if you don't have one.")
    end
end

if not peripheral.isPresent(MODEM_NAME) then
    error("Could not find modem '" .. MODEM_NAME .. "'. Check the wireless modem is attached and named correctly.")
end
rednet.open(MODEM_NAME)

local function isSimonSolved()
    return simonRelay.getInput(SIMON_SIDE)
end

local function isTicTacToeSolved()
    return tictactoeRelay.getInput(TICTACTOE_SIDE)
end

local function isAdminOverride()
    return adminRelay.getInput(ADMIN_SIDE)
end

local function setMainDoor(open)
    doorRelay1.setOutput(DOOR_SIDE_1, open)
    doorRelay2.setOutput(DOOR_SIDE_2, open)
end

local function isSomeoneAtGate()
    return #gateDetector.getPlayersInRange(GATE_DETECT_RANGE) > 0
end

-- Force-closes the door and resets both puzzles. Broadcasting (rather than
-- targeting a specific computer ID) works because SimonSays/TicTacToe already
-- listen for {cmd="new_game"} on this same protocol -- no need to know their IDs.
local function triggerGateLockdown()
    print("Gate crossing detected -- closing door and resetting puzzles")
    setMainDoor(false)
    rednet.broadcast({ cmd = "new_game" }, PROTOCOL)
end

local function printStatus(simonSolved, tictactoeSolved, adminOverride, doorOpen)
    term.clear()
    term.setCursorPos(1, 1)
    print("GymLock")
    print("")
    print("Simon Says:  " .. (simonSolved and "SOLVED" or "locked"))
    print("Tic Tac Toe: " .. (tictactoeSolved and "SOLVED" or "locked"))
    print("Admin lever: " .. (adminOverride and "ON" or "off"))
    print("")
    print("Main door:   " .. (doorOpen and "OPEN" or "closed"))
end

-- Same wording as printStatus() above, joined onto one line for the ControlRoom status field.
local function statusLine(simonSolved, tictactoeSolved, adminOverride, doorOpen)
    return "Simon Says: " .. (simonSolved and "SOLVED" or "locked")
        .. " | Tic Tac Toe: " .. (tictactoeSolved and "SOLVED" or "locked")
        .. " | Admin lever: " .. (adminOverride and "ON" or "off")
        .. " | Main door: " .. (doorOpen and "OPEN" or "closed")
end

-- Only re-draws/re-writes the relays when something actually changed.
local lastState = nil

local function update()
    local simonSolved = isSimonSolved()
    local tictactoeSolved = isTicTacToeSolved()
    local adminOverride = isAdminOverride()
    local doorOpen = adminOverride or (simonSolved and tictactoeSolved)

    rednet.broadcast({
        label = os.getComputerLabel(),
        type = DEVICE_TYPE,
        status = statusLine(simonSolved, tictactoeSolved, adminOverride, doorOpen),
    }, PROTOCOL)

    local state = (simonSolved and "1" or "0") .. (tictactoeSolved and "1" or "0") .. (adminOverride and "1" or "0")
    if state == lastState then return end
    lastState = state

    setMainDoor(doorOpen)
    printStatus(simonSolved, tictactoeSolved, adminOverride, doorOpen)
end

update()
parallel.waitForAny(
    function()
        while true do
            os.pullEvent("redstone")
            update()
        end
    end,
    function()
        while true do
            os.sleep(HEARTBEAT_INTERVAL)
            update()
        end
    end,
    function()
        -- Keeps looping (never returns) even when disabled, so parallel.waitForAny
        -- -- which stops as soon as ANY branch returns -- doesn't exit the program early.
        local wasAtGate = false
        while true do
            os.sleep(GATE_POLL_INTERVAL)
            if GATE_ENABLED then
                local atGate = isSomeoneAtGate()
                if atGate and not wasAtGate and not isAdminOverride() then
                    triggerGateLockdown()
                end
                wasAtGate = atGate
            end
        end
    end
)
