-- Tic Tac Toe puzzle
-- UI with Basalt2 (https://basalt.madefor.cc/); board.lua and ai.lua hold the game logic.
-- When the player (X) wins, a redstone signal goes high; wiring that to a door is up to you.

-- ====================== CONFIG ======================
local MONITOR_NAME = nil      -- e.g. "monitor_0" to force a specific monitor; nil = auto-detect
local MONITOR_SCALE = 1       -- text scale on the monitor; try 2-3 if text is too small to read from afar
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

-- Adjacent monitors of the same type auto-merge into one peripheral in
-- CC:Tweaked, so a multi-block monitor wall is found the same way as a single one.
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

math.randomseed(os.time())

-- ====================== GAME STATE ======================
local state, gameOver

-- ====================== UI ======================
local cells, icons, statusLabel = {}, {}, nil

-- Cell background and icon (pixel) color per mark
local CELL_STYLE = {
    [""]    = { bg = colors.black, icon = colors.black },
    [HUMAN] = { bg = colors.black, icon = colors.red },
    [AI]    = { bg = colors.black, icon = colors.blue },
}

-- 5x5 pixel-art patterns for the icons (1 = filled pixel)
local ICON_PATTERNS = {
    [HUMAN] = {
        {1,0,0,0,1},
        {0,1,0,1,0},
        {0,0,1,0,0},
        {0,1,0,1,0},
        {1,0,0,0,1},
    },
    [AI] = {
        {0,1,1,1,0},
        {1,0,0,0,1},
        {1,0,0,0,1},
        {1,0,0,0,1},
        {0,1,1,1,0},
    },
}

local function render()
    for r = 1, 3 do
        for c = 1, 3 do
            local mark = state[r][c]
            local style = CELL_STYLE[mark]
            cells[r][c]:setBackground(style.bg)

            local pattern = ICON_PATTERNS[mark]
            for pr = 1, 5 do
                for pc = 1, 5 do
                    local pixel = icons[r][c][pr][pc]
                    if pixel then
                        local on = pattern and pattern[pr][pc] == 1
                        pixel:setBackground(on and style.icon or style.bg)
                    end
                end
            end
        end
    end
end

local function setStatus(text, color)
    statusLabel:setText(text):setForeground(color or colors.white)
end

local function endGame(result)
    gameOver = true
    if result == AI then
        -- Only an actual AI win is a loss; draw counts as a win, same as beating it.
        setStatus("The AI wins. Try again!", colors.red)
    elseif result == HUMAN then
        setStatus("You win! Opening the door...", colors.lime)
        redstone.setOutput(REDSTONE_SIDE, true)
    else
        setStatus("Draw! Opening the door...", colors.lime)
        redstone.setOutput(REDSTONE_SIDE, true)
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
    setStatus("Your turn (X)", colors.white)
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

statusLabel = screen:addLabel()
    :setText("Your turn (X)")
    :setPosition(2, 1)
    :setSize(w - 2, 1)
    :setBackground(colors.black)
    :setForeground(colors.white)

-- Size of one pixel-art "pixel" in characters, derived from cell size so the
-- 5x5 icon always fits with a small margin (raise/lower the "- 3" margin to
-- taste; bigger pixels = thicker-looking lines in the icon).
local pixelW = math.max(1, math.floor((cellW - 3) / 5))
local pixelH = math.max(1, math.floor((cellH - 3) / 5))
local iconW, iconH = pixelW * 5, pixelH * 5

for r = 1, 3 do
    cells[r] = {}
    icons[r] = {}
    for c = 1, 3 do
        local cellX = startX + (c - 1) * cellW
        local cellY = startY + (r - 1) * cellH

        cells[r][c] = screen:addButton()
            :setText("")
            :setPosition(cellX, cellY)
            :setSize(cellW - 1, cellH - 1)
            :onClick(function() onCellClick(r, c) end)

        local iconX = cellX + math.floor((cellW - 1 - iconW) / 2)
        local iconY = cellY + math.floor((cellH - 1 - iconH) / 2)

        local grid = {}
        for pr = 1, 5 do
            grid[pr] = {}
            for pc = 1, 5 do
                -- Only create a pixel where at least one mark actually uses it
                if ICON_PATTERNS[HUMAN][pr][pc] == 1 or ICON_PATTERNS[AI][pr][pc] == 1 then
                    grid[pr][pc] = screen:addLabel()
                        :setText("")
                        :setAutoSize(false)
                        :setPosition(iconX + (pc - 1) * pixelW, iconY + (pr - 1) * pixelH)
                        :setSize(pixelW, pixelH)
                        :setBackground(colors.black)
                end
            end
        end
        icons[r][c] = grid
    end
end

-- White grid lines between the cells
local LINE_COLOR = colors.white
for i = 1, 2 do
    screen:addLabel():setText(""):setAutoSize(false):setPosition(startX + i * cellW - 1, startY):setSize(1, cellH * 3 - 1):setBackground(LINE_COLOR)
    screen:addLabel():setText(""):setAutoSize(false):setPosition(startX, startY + i * cellH - 1):setSize(cellW * 3 - 1, 1):setBackground(LINE_COLOR)
end

screen:addButton()
    :setText("New game")
    :setPosition(2, h)
    :setSize(12, 1)
    :setBackground(colors.green)
    :setForeground(colors.white)
    :onClick(resetGame)

resetGame()
basalt.run()
