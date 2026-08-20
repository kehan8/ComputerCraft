-- Simon Says puzzle
-- UI with Basalt2 (https://basalt.madefor.cc/); simon.lua holds the pattern state.
-- Repeat the growing color pattern correctly enough times in a row and a redstone signal
-- goes high; wiring that to a door is up to you.

-- ====================== CONFIG ======================
local MONITOR_NAME = nil        -- e.g. "monitor_0" to force a specific monitor; nil = auto-detect
local MONITOR_SCALE = 0.5       -- text scale on the monitor
local REDSTONE_RELAY_NAME = "redstone_relay_0" -- name of your Redstone Relay peripheral
local REDSTONE_SIDE = "back"                   -- side of the relay that goes high once solved

local WIN_LENGTH = 6            -- pattern length (rounds) needed to solve the puzzle
local FLASH_TIME = 0.6          -- seconds a pad stays lit during playback
local GAP_TIME = 0.25           -- seconds between pads during playback
local ROUND_START_DELAY = 1     -- pause before playback starts each round
local NEXT_ROUND_DELAY = 0.8    -- pause after a correct round before the next one plays
local CLICK_FLASH_TIME = 0.15   -- how long a pad stays lit when the player taps it
local WRONG_FLASH_TIME = 0.2    -- on/off timing for the red "wrong" flash
-- ======================================================

if not fs.exists("basalt") and not fs.exists("basalt.lua") then
    print("Installing Basalt UI library...")
    shell.run("wget run https://raw.githubusercontent.com/Pyroxenium/Basalt2/main/install.lua")
end
local basalt = require("basalt")

local simon = require("simon")

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

local relay = peripheral.wrap(REDSTONE_RELAY_NAME)
if not relay then
    error("Could not find redstone relay '" .. REDSTONE_RELAY_NAME .. "'. Check the cable/name.")
end

local function setDoorSignal(on)
    relay.setOutput(REDSTONE_SIDE, on)
end

math.randomseed(os.time())

-- ====================== GAME STATE ======================
local pattern = simon.new()
local round = 0
local playerIndex = 1
local isPlayerTurn = false
local gameOver = false
local token = 0 -- bumped on every reset so stale scheduled coroutines bail out
local mode = "idle" -- "idle" (showing "Start") or "playing" (showing "New game")

-- ====================== UI ======================
local statusLabel, startButton, pads = nil, nil, {}

local PAD_COLORS = {
    [1] = { dim = colors.brown,  lit = colors.red },
    [2] = { dim = colors.blue,   lit = colors.lightBlue },
    [3] = { dim = colors.green,  lit = colors.lime },
    [4] = { dim = colors.orange, lit = colors.yellow },
}

local function setPad(i, lit)
    pads[i]:setBackground(lit and PAD_COLORS[i].lit or PAD_COLORS[i].dim)
end

local function setAllPads(lit)
    for i = 1, 4 do setPad(i, lit) end
end

local function setStatus(text, color)
    statusLabel:setText(text):setForeground(color or colors.white)
end

-- Plays back the current pattern (flash, pause, flash, ...), then hands control to the player.
-- myToken must still match the live `token` after every wait, otherwise a newer
-- reset/round has started and this stale coroutine should just stop.
local function playDemo(myToken)
    isPlayerTurn = false
    setStatus("Watch the pattern...", colors.white)
    os.sleep(ROUND_START_DELAY)

    for _, i in ipairs(pattern) do
        if myToken ~= token then return end
        setPad(i, true)
        os.sleep(FLASH_TIME)
        if myToken ~= token then return end
        setPad(i, false)
        os.sleep(GAP_TIME)
    end

    if myToken ~= token then return end
    playerIndex = 1
    isPlayerTurn = true
    setStatus("Your turn: repeat the pattern", colors.white)
end

local function nextRound(myToken)
    round = round + 1
    simon.addStep(pattern)
    basalt.schedule(function() playDemo(myToken) end)
end

local function winGame()
    gameOver = true
    isPlayerTurn = false
    setStatus("Solved! Opening the door...", colors.lime)
    setDoorSignal(true)
end

local function onWrong()
    isPlayerTurn = false
    setStatus("Wrong! Watch again...", colors.red)
    local myToken = token

    basalt.schedule(function()
        for _ = 1, 2 do
            for i = 1, 4 do pads[i]:setBackground(colors.red) end
            os.sleep(WRONG_FLASH_TIME)
            setAllPads(false)
            os.sleep(WRONG_FLASH_TIME)
        end
        if myToken ~= token then return end

        pattern = simon.new()
        round = 0
        nextRound(myToken)
    end)
end

-- Stops any running/won game and returns to the idle "press Start" state.
local function goIdle()
    token = token + 1
    mode = "idle"

    pattern = simon.new()
    round = 0
    playerIndex = 1
    isPlayerTurn = false
    gameOver = false
    setDoorSignal(false)
    setAllPads(false)
    setStatus("Press Start to begin", colors.white)
    startButton:setText("Start")
end

-- Starts a fresh game from the idle state.
local function beginGame()
    token = token + 1
    local myToken = token
    mode = "playing"

    pattern = simon.new()
    round = 0
    playerIndex = 1
    isPlayerTurn = false
    gameOver = false
    setDoorSignal(false)
    setAllPads(false)
    startButton:setText("New game")

    nextRound(myToken)
end

local function onStartButtonClick()
    if mode == "idle" then
        beginGame()
    else
        goIdle()
    end
end

local function onPadClick(i)
    if gameOver or not isPlayerTurn then return end

    if pattern[playerIndex] ~= i then
        onWrong()
        return
    end

    setPad(i, true)
    local myToken = token
    basalt.schedule(function()
        os.sleep(CLICK_FLASH_TIME)
        if myToken ~= token then return end
        setPad(i, false)
    end)

    playerIndex = playerIndex + 1
    if playerIndex > #pattern then
        isPlayerTurn = false
        if round >= WIN_LENGTH then
            winGame()
        else
            setStatus("Correct! Next round...", colors.lime)
            basalt.schedule(function()
                os.sleep(NEXT_ROUND_DELAY)
                if myToken ~= token then return end
                nextRound(myToken)
            end)
        end
    end
end

-- Layout: status label on top, a 2x2 grid of large color pads filling the rest,
-- a Start/Reset button on the last row.
local w, h = screen:getSize()
local startY = 3
local usableH = math.max(2, h - startY - 1) -- leave the last row for the Start button
local padH = math.floor(usableH / 2)
local padW = math.floor(w / 2)

statusLabel = screen:addLabel()
    :setText("Press Start to begin")
    :setPosition(2, 1)
    :setSize(w - 2, 1)
    :setBackground(colors.black)
    :setForeground(colors.white)

local PAD_LAYOUT = {
    { x = 1,          y = startY,          w = padW,     h = padH },
    { x = padW + 1,    y = startY,          w = w - padW, h = padH },
    { x = 1,          y = startY + padH,   w = padW,     h = usableH - padH },
    { x = padW + 1,    y = startY + padH,   w = w - padW, h = usableH - padH },
}

for i = 1, 4 do
    local pos = PAD_LAYOUT[i]
    pads[i] = screen:addButton()
        :setText("")
        :setPosition(pos.x, pos.y)
        :setSize(pos.w, pos.h)
        :setBackground(PAD_COLORS[i].dim)
        :onClick(function() onPadClick(i) end)
end

startButton = screen:addButton()
    :setText("Start")
    :setPosition(2, h)
    :setSize(12, 1)
    :setBackground(colors.green)
    :setForeground(colors.white)
    :onClick(onStartButtonClick)

basalt.run()
