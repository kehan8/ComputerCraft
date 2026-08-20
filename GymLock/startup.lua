-- GymLock
-- Reads the "solved" redstone signal from the SimonSays and TicTacToe puzzle computers
-- (one relay input each) and, once BOTH are high, opens the main door (2 relay outputs,
-- since it's a piston door). No monitor/UI needed -- status is just printed on this computer.

-- ====================== CONFIG ======================
-- Your local settings live in config.lua (not touched by update.lua).
local config = require("config")
local SIMON_RELAY_NAME = config.SIMON_RELAY_NAME
local SIMON_SIDE = config.SIMON_SIDE
local TICTACTOE_RELAY_NAME = config.TICTACTOE_RELAY_NAME
local TICTACTOE_SIDE = config.TICTACTOE_SIDE
local DOOR_RELAY_NAME_1 = config.DOOR_RELAY_NAME_1
local DOOR_SIDE_1 = config.DOOR_SIDE_1
local DOOR_RELAY_NAME_2 = config.DOOR_RELAY_NAME_2
local DOOR_SIDE_2 = config.DOOR_SIDE_2
-- ======================================================

local function wrapRelay(name)
    local relay = peripheral.wrap(name)
    if not relay then
        error("Could not find redstone relay '" .. name .. "'. Check the cable/name.")
    end
    return relay
end

local simonRelay = wrapRelay(SIMON_RELAY_NAME)
local tictactoeRelay = wrapRelay(TICTACTOE_RELAY_NAME)
local doorRelay1 = wrapRelay(DOOR_RELAY_NAME_1)
local doorRelay2 = wrapRelay(DOOR_RELAY_NAME_2)

local function isSimonSolved()
    return simonRelay.getInput(SIMON_SIDE)
end

local function isTicTacToeSolved()
    return tictactoeRelay.getInput(TICTACTOE_SIDE)
end

local function setMainDoor(open)
    doorRelay1.setOutput(DOOR_SIDE_1, open)
    doorRelay2.setOutput(DOOR_SIDE_2, open)
end

local function printStatus(simonSolved, tictactoeSolved, doorOpen)
    term.clear()
    term.setCursorPos(1, 1)
    print("GymLock")
    print("")
    print("Simon Says:  " .. (simonSolved and "SOLVED" or "locked"))
    print("Tic Tac Toe: " .. (tictactoeSolved and "SOLVED" or "locked"))
    print("")
    print("Main door:   " .. (doorOpen and "OPEN" or "closed"))
end

-- Only re-draws/re-writes the relays when something actually changed.
local lastState = nil

local function update()
    local simonSolved = isSimonSolved()
    local tictactoeSolved = isTicTacToeSolved()
    local doorOpen = simonSolved and tictactoeSolved

    local state = (simonSolved and "1" or "0") .. (tictactoeSolved and "1" or "0")
    if state == lastState then return end
    lastState = state

    setMainDoor(doorOpen)
    printStatus(simonSolved, tictactoeSolved, doorOpen)
end

update()
while true do
    os.pullEvent("redstone")
    update()
end
