-- Tic Tac Toe puzzle
-- UI with Basalt2 (https://basalt.madefor.cc/); board.lua and ai.lua hold the game logic.
-- When the player (X) wins, a redstone signal goes high; wiring that to a door is up to you.

-- ====================== CONFIG ======================
local MONITOR_NAME = nil      -- e.g. "monitor_0" to force a specific monitor; nil = auto-detect
local MONITOR_SCALE = 0.5     -- text scale on the monitor; lower = more resolution for the icons, higher = bigger/easier to read from afar
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
local cells, cellPos, icons, statusLabel = {}, {}, {}, nil

-- Cell background and icon (pixel) color per mark
local CELL_STYLE = {
    [""]    = { bg = colors.black, icon = colors.black },
    [HUMAN] = { bg = colors.black, icon = colors.red },
    [AI]    = { bg = colors.black, icon = colors.blue },
}

-- 5x5 pixel-art patterns for the icons (1 = filled pixel)
local ICON_SIZE = 5
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

local pixelW, pixelH -- set once layout is known, used by renderCell below

-- Draws (or clears) the pixel-art icon for one cell. Icon pixels are plain
-- Buttons (Label backgrounds don't render in this Basalt build - confirmed
-- with icontest.lua) and are only ever created for an already-filled cell,
-- so they can never sit on top of a still-clickable empty cell.
local function renderCell(r, c)
    local mark = state[r][c]
    local style = CELL_STYLE[mark]
    cells[r][c]:setBackground(style.bg)

    if icons[r][c] and icons[r][c].mark == mark then
        return
    end

    if icons[r][c] then
        for _, pixel in ipairs(icons[r][c].pixels) do
            pixel:setBackground(colors.black)
        end
    end

    local pattern = ICON_PATTERNS[mark]
    local pixels = {}
    if pattern then
        local pos = cellPos[r][c]
        for pr = 1, ICON_SIZE do
            for pc = 1, ICON_SIZE do
                if pattern[pr][pc] == 1 then
                    local btn = screen:addButton()
                        :setText("")
                        :setPosition(pos.iconX + (pc - 1) * pixelW, pos.iconY + (pr - 1) * pixelH)
                        :setSize(pixelW, pixelH)
                        :setBackground(style.icon)
                    table.insert(pixels, btn)
                end
            end
        end
    end
    icons[r][c] = { mark = mark, pixels = pixels }
end

local function render()
    for r = 1, 3 do
        for c = 1, 3 do
            renderCell(r, c)
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

-- Layout: 3x3 grid of buttons, centered on the screen.
-- A monitor character cell is roughly 1.5-2x taller than it is wide, so cells
-- need proportionally more columns than rows to look square, not "schuin".
local CHAR_ASPECT = 2  -- tweak this if cells still look too tall/wide
local LINE_THICKNESS = 2 -- width/height, in characters, of the grid lines between cells
local w, h = screen:getSize()
local cellHMax = math.max(2, math.floor((h - 4) / 3))
local cellWMax = math.max(3, math.floor((w - 2) / 3))
local cellH = math.min(cellHMax, math.floor(cellWMax / CHAR_ASPECT))
local cellW = cellH * CHAR_ASPECT
local startX = math.floor((w - cellW * 3) / 2) + 1
local startY = 3

statusLabel = screen:addLabel()
    :setText("Your turn (X)")
    :setPosition(2, 1)
    :setSize(w - 2, 1)
    :setBackground(colors.black)
    :setForeground(colors.white)

-- Button size leaves a LINE_THICKNESS-wide gap after each cell for the grid line
local btnW = cellW - LINE_THICKNESS
local btnH = cellH - LINE_THICKNESS

-- Size of one pixel-art "pixel" in characters, derived from cell size so the
-- icon always fits with a small margin.
pixelW = math.max(1, math.floor((btnW - 2) / ICON_SIZE))
pixelH = math.max(1, math.floor((btnH - 2) / ICON_SIZE))
local iconW, iconH = pixelW * ICON_SIZE, pixelH * ICON_SIZE

for r = 1, 3 do
    cells[r] = {}
    cellPos[r] = {}
    icons[r] = {}
    for c = 1, 3 do
        local cellX = startX + (c - 1) * cellW
        local cellY = startY + (r - 1) * cellH

        cells[r][c] = screen:addButton()
            :setText("")
            :setPosition(cellX, cellY)
            :setSize(btnW, btnH)
            :onClick(function() onCellClick(r, c) end)

        cellPos[r][c] = {
            iconX = cellX + math.floor((btnW - iconW) / 2),
            iconY = cellY + math.floor((btnH - iconH) / 2),
        }
    end
end

-- White grid lines between the cells (Buttons, not Labels, so they actually render)
local LINE_COLOR = colors.white
for i = 1, 2 do
    screen:addButton():setText(""):setPosition(startX + i * cellW - LINE_THICKNESS, startY):setSize(LINE_THICKNESS, cellH * 3 - LINE_THICKNESS):setBackground(LINE_COLOR)
    screen:addButton():setText(""):setPosition(startX, startY + i * cellH - LINE_THICKNESS):setSize(cellW * 3 - LINE_THICKNESS, LINE_THICKNESS):setBackground(LINE_COLOR)
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
