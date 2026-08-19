-- Tic Tac Toe puzzle
-- UI with Basalt2 (https://basalt.madefor.cc/); board.lua and ai.lua hold the game logic.
-- When the player (X) wins, a redstone signal goes high; wiring that to a door is up to you.

-- ====================== CONFIG ======================
local MONITOR_NAME = nil      -- e.g. "monitor_0"; nil = play on the computer's own screen
local REDSTONE_SIDE = "back"  -- side that goes high once the player wins
-- ======================================================

if not fs.exists("basalt") and not fs.exists("basalt.lua") then
    print("Installing Basalt UI library...")
    shell.run("wget run https://raw.githubusercontent.com/Pyroxenium/Basalt2/main/install.lua")
end
local basalt = require("basalt")

local board = require("board")
local ai = require("ai")
local HUMAN, AI = board.HUMAN, board.AI

local screen
if MONITOR_NAME then
    local mon = peripheral.wrap(MONITOR_NAME)
    if not mon then
        error("Could not find monitor '" .. MONITOR_NAME .. "'. Check the cable/name.")
    end
    mon.setTextScale(1)
    screen = basalt.createFrame():setTerm(mon)
else
    screen = basalt.getMainFrame()
end

math.randomseed(os.time())

-- ====================== GAME STATE ======================
local state, gameOver

-- ====================== UI ======================
local cells, statusLabel = {}, nil

local function render()
    for r = 1, 3 do
        for c = 1, 3 do
            cells[r][c]:setText(state[r][c] == "" and " " or state[r][c])
        end
    end
end

local function setStatus(text)
    statusLabel:setText(text)
end

local function endGame(result)
    gameOver = true
    if result == HUMAN then
        setStatus("You win! Opening the door...")
        redstone.setOutput(REDSTONE_SIDE, true)
    elseif result == AI then
        setStatus("The AI wins. Try again!")
    else
        setStatus("Draw. Try again!")
    end
end

local function checkEnd()
    local w = board.winner(state)
    if w then
        endGame(w)
        return true
    elseif board.isFull(state) then
        endGame("draw")
        return true
    end
    return false
end

local function resetGame()
    state = board.new()
    gameOver = false
    redstone.setOutput(REDSTONE_SIDE, false)
    render()
    setStatus("Your turn (X)")
end

local function onCellClick(r, c)
    if gameOver or state[r][c] ~= "" then return end

    state[r][c] = HUMAN
    render()
    if checkEnd() then return end

    ai.move(state)
    render()
    if checkEnd() then return end

    setStatus("Your turn (X)")
end

-- Layout: 3x3 grid of buttons, centered on the screen
local w, h = screen:getSize()
local cellW = math.max(3, math.floor((w - 2) / 3))
local cellH = math.max(2, math.floor((h - 4) / 3))
local startX = math.floor((w - cellW * 3) / 2) + 1
local startY = 3

statusLabel = screen:addLabel():setText("Your turn (X)"):setPosition(2, 1):setSize(w - 2, 1)

for r = 1, 3 do
    cells[r] = {}
    for c = 1, 3 do
        cells[r][c] = screen:addButton()
            :setText(" ")
            :setPosition(startX + (c - 1) * cellW, startY + (r - 1) * cellH)
            :setSize(cellW - 1, cellH - 1)
            :onClick(function() onCellClick(r, c) end)
    end
end

screen:addButton()
    :setText("New game")
    :setPosition(2, h)
    :setSize(12, 1)
    :onClick(resetGame)

resetGame()
basalt.run()
