-- Tic Tac Toe puzzle
-- UI with Basalt2 (https://basalt.madefor.cc/); board.lua and ai.lua hold the game logic.
-- When the player (X) wins, a redstone signal goes high; wiring that to a door is up to you.

-- ====================== CONFIG ======================
local MONITOR_NAME = nil      -- e.g. "monitor_0" to force a specific monitor; nil = auto-detect
local MONITOR_SCALE = 1       -- text scale on the monitor; try 2-3 if text is too small to read from afar
local ICON_FONT_SIZE = 2      -- size of the X/O icons; try 1-3 depending on cell size
local REDSTONE_SIDE = "back"  -- side that goes high once the player wins
-- ======================================================

if not fs.exists("basalt") and not fs.exists("basalt.lua") then
    print("Installing Basalt UI library...")
    shell.run("wget run https://raw.githubusercontent.com/Pyroxenium/Basalt2/main/install.lua")
end
local basalt = require("basalt")

-- BigFont isn't bundled by default; let Basalt auto-load it (from disk cache or remotely) on first use
basalt.getElementManager().configure({
    autoLoadMissing = true,
    allowRemoteLoading = true,
    allowDiskLoading = true,
    useGlobalCache = true,
})

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

-- Cell styling per mark: cell background, icon color and icon symbol
local CELL_STYLE = {
    [""]     = { bg = colors.gray,  fg = colors.lightGray, icon = "" },
    [HUMAN]  = { bg = colors.blue,  fg = colors.white,     icon = "X" },
    [AI]     = { bg = colors.red,   fg = colors.white,     icon = "O" },
}

local function render()
    for r = 1, 3 do
        for c = 1, 3 do
            local style = CELL_STYLE[state[r][c]]
            cells[r][c]:setBackground(style.bg):setForeground(style.fg)
            icons[r][c]:setText(style.icon):setForeground(style.fg)
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

for r = 1, 3 do
    cells[r] = {}
    icons[r] = {}
    for c = 1, 3 do
        cells[r][c] = screen:addButton()
            :setText(" ")
            :setPosition(startX + (c - 1) * cellW, startY + (r - 1) * cellH)
            :setSize(cellW - 1, cellH - 1)
            :onClick(function() onCellClick(r, c) end)

        -- Big pixel-art X/O icon, transparent so the button's color shows through
        icons[r][c] = screen:addBigFont()
            :setFontSize(ICON_FONT_SIZE)
            :setBackgroundEnabled(false)
            :centerIn(cells[r][c])
    end
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
