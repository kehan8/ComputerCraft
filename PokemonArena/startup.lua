-- PokemonArena: shows the active (non-balled) Pokemon + trainer + HP for
-- each podium, using one Environment Detector per podium, plus a
-- fainted-count/WINNER-DEFEAT tally per podium (per-podium team size,
-- chosen in the "New Battle" setup screen, persisted in team_sizes.dat --
-- see config.lua). Basalt2 UI: colored HP bars, boxed podium panels, a
-- "New Battle" button (manual reset via a setup screen, no key rebind),
-- an automatic jump to that same setup screen when a brand new Pokemon
-- shows up after a match is already over, and a "History" screen listing
-- the last few completed matches (see match_history.dat / history.lua).

-- ====================== CONFIG ======================
local config = require("config")
local RADIUS = config.RADIUS
local OWNED_TAG = config.OWNED_TAG
local POLL_INTERVAL = config.POLL_INTERVAL
local MONITOR = config.MONITOR
local MONITOR_TEXT_SCALE = config.MONITOR_TEXT_SCALE
local HISTORY_MAX_ENTRIES = config.HISTORY_MAX_ENTRIES or 20

local locations = require("locations")
local matchHistory = require("history")

if not locations.PODIUMS or #locations.PODIUMS == 0 then
    error("locations.lua must define PODIUMS with at least one podium table (see locations.lua).")
end

-- self-contained podium tables: label + detector + tracked state together
local podiums = {}
for i, raw in ipairs(locations.PODIUMS) do
    local position = raw.position or ("Podium " .. i)

    if not raw.detector then
        error("locations.lua: podium '" .. position .. "' needs a detector.")
    end

    podiums[i] = {
        position = position,
        detectorName = raw.detector,
        detectorPeripheral = nil, -- wrapped below, once peripherals are set up

        -- last known active Pokemon for this podium, kept across scans that
        -- briefly miss it so the screen doesn't flicker blank
        lastUuid = nil,
        lastName = nil,
        lastHealth = nil,
        lastMaxHealth = nil,
        lastTrainerName = nil, -- nearest non-Pokemon (player) entity's name
        missCount = 0,

        -- match tracking: how many of this podium's owned Pokemon have
        -- fainted so far (see updateMatchStatus()/teamSizes below)
        faintedCount = 0,
        faintedUuids = {}, -- set of uuids already counted, so a fainted
                           -- Pokemon that stays visible for a couple of
                           -- scans before being recalled isn't double-counted
        seenUuids = {}, -- every distinct owned-Pokemon uuid seen on this
                        -- podium since the last "Start Battle" -- used by
                        -- the auto-detect-new-battle check below
    }
end
-- ======================================================

local function wrapPeripheral(name, label)
    local p = peripheral.wrap(name)
    if not p then
        error("Could not find " .. label .. " '" .. name .. "'. Check the cable/name.")
    end
    return p
end

-- wrap detectors now so a typo'd name fails fast at startup
for _, podium in ipairs(podiums) do
    podium.detectorPeripheral = wrapPeripheral(podium.detectorName, "Environment Detector for podium '" .. podium.position .. "'")
end

-- ====================== BASALT2 UI BOOTSTRAP ======================
-- Same pattern as GymArena/SimonSays: install.lua normally installs Basalt
-- ahead of time, but this is a fallback in case startup.lua ever runs
-- without it (e.g. a partial/manual copy).
if not fs.exists("basalt") and not fs.exists("basalt.lua") then
    print("Installing Basalt UI library...")
    shell.run("wget run https://raw.githubusercontent.com/Pyroxenium/Basalt2/main/install.lua")
end
local basalt = require("basalt")

-- optional: mirror the whole display onto an external Monitor instead of
-- the computer's own terminal. MONITOR = nil (config.lua default) keeps
-- using the computer's screen.
local screen
if MONITOR then
    local monitor = wrapPeripheral(MONITOR, "Monitor")
    if MONITOR_TEXT_SCALE then
        monitor.setTextScale(MONITOR_TEXT_SCALE)
    end
    screen = basalt.createFrame():setTerm(monitor)
else
    screen = basalt.getMainFrame()
end

-- Cobblemon Pokemon entities always report a "baby" field; players, Loot
-- Balls, etc. never do. Cheap filter, no datapack needed for this part.
local function isPokemon(entity)
    return entity.baby ~= nil
end

local function hasTag(entity, tag)
    if not entity.tags then
        return false
    end
    for _, t in ipairs(entity.tags) do
        if t == tag then
            return true
        end
    end
    return false
end

-- scanEntities() coordinates are relative to the detector itself, so this
-- is plain distance-from-detector.
local function distanceSquared(entity)
    return entity.x * entity.x + entity.y * entity.y + entity.z * entity.z
end

-- One scanEntities() call per podium per cycle (the detector has its own
-- ~2s cooldown -- see config.lua's POLL_INTERVAL comment -- so calling it
-- twice per cycle would starve the second call). Returns the nearest
-- trainer-owned Pokemon AND the nearest non-Pokemon entity (the trainer
-- standing at that podium) from the same scan. Ownership tags come from
-- the tag_ownership datapack function (see ../datapack/) -- scanEntities()
-- itself has no ownership info. The "trainer" is a best-effort guess (the
-- nearest entity without a "baby" field); in practice that's almost always
-- the player standing at their own podium, but a stray Loot Ball (which
-- also lacks "baby") could theoretically win instead -- not a concern near
-- a battle podium, no datapack support exists to do this more precisely.
local function scanPodium(podium)
    local ok, entities = pcall(podium.detectorPeripheral.scanEntities, RADIUS)
    if not ok or type(entities) ~= "table" then
        return nil, nil
    end

    local nearestPokemon, nearestPokemonDist = nil, nil
    local nearestTrainer, nearestTrainerDist = nil, nil
    for _, entity in ipairs(entities) do
        local dist = distanceSquared(entity)
        if isPokemon(entity) and hasTag(entity, OWNED_TAG) then
            if not nearestPokemon or dist < nearestPokemonDist then
                nearestPokemon, nearestPokemonDist = entity, dist
            end
        elseif not isPokemon(entity) and entity.name then
            if not nearestTrainer or dist < nearestTrainerDist then
                nearestTrainer, nearestTrainerDist = entity, dist
            end
        end
    end
    return nearestPokemon, nearestTrainer
end

-- ====================== PER-PODIUM TEAM SIZE (team_sizes.dat) ======================
-- Team size is chosen per podium in the "New Battle" setup screen (1-6),
-- not shared and not in config.lua, so update.lua/update_full.lua never
-- clobber it and a config reset doesn't erase an in-progress event's sizes.
local TEAM_SIZES_FILE = "team_sizes.dat"
local TEAM_SIZE_MIN, TEAM_SIZE_MAX = 1, 6

local function clampTeamSize(n)
    n = tonumber(n) or TEAM_SIZE_MIN
    if n < TEAM_SIZE_MIN then return TEAM_SIZE_MIN end
    if n > TEAM_SIZE_MAX then return TEAM_SIZE_MAX end
    return math.floor(n)
end

local function loadTeamSizes()
    local saved = nil
    if fs.exists(TEAM_SIZES_FILE) then
        local file = fs.open(TEAM_SIZES_FILE, "r")
        local contents = file.readAll()
        file.close()
        local ok, data = pcall(textutils.unserialize, contents)
        if ok and type(data) == "table" then
            saved = data
        end
    end

    local fallback = clampTeamSize(config.TEAM_SIZE)
    local sizes = {}
    for i in ipairs(podiums) do
        sizes[i] = clampTeamSize((saved and saved[i]) or fallback)
    end
    return sizes
end

local function saveTeamSizes(sizes)
    local file = fs.open(TEAM_SIZES_FILE, "w")
    file.write(textutils.serialize(sizes))
    file.close()
end

local teamSizes = loadTeamSizes()
local pendingTeamSizes = {} -- working copy edited on the setup screen

-- ====================== MATCH HISTORY (match_history.dat) ======================
local historyEntries = matchHistory.load() -- newest first, capped at HISTORY_MAX_ENTRIES

-- ====================== STATE ======================
-- index into podiums of the winning side once a match resolves, or nil
-- while the match is ongoing (or ended in a mutual KO - no winner shown).
-- Recomputed every scan by updateMatchStatus(), cleared by resetMatch().
local matchWinnerIndex = nil
local matchLogged = false -- true once the current (over) match has been
                          -- written to historyEntries, so update() doesn't
                          -- write a duplicate entry every subsequent scan
                          -- while the match is still showing DEFEAT/WINNER
local screenState = "live" -- "live", "setup", or "history"

-- forward declarations: UI button handlers below reference these before
-- their bodies are assigned further down, and vice versa.
local renderLive, isMatchOver, resetMatch, showScreen, openSetupScreen,
      startBattle, openHistoryScreen, renderHistoryPage, logMatch, update

-- ====================== UI ======================
-- All widgets live directly on `screen` (no intermediate addFrame()
-- nesting) -- this matches the ONLY proven monitor-compatible pattern
-- elsewhere in this repo (GymArena/SimonSays, GymArena/TicTacToe,
-- FossilLab, ControlRoom all add widgets straight onto `screen`, whether
-- `screen` is the computer's basalt.getMainFrame() or a Monitor-backed
-- basalt.createFrame():setTerm(mon)). An earlier version of this file used
-- two child Frames (liveFrame/setupFrame added via screen:addFrame()) to
-- get show/hide "screens" -- that toggled fine on the computer's own
-- terminal (confirmed in-game) but is an untested combination when `screen`
-- itself is a Monitor-backed frame, and is the prime suspect for "the
-- Basalt2 UI renders on the computer but the Monitor stays blank" (user
-- report, session 4). Fix: three flat groups of widgets added directly to
-- `screen` (liveElements/setupElements/historyElements), toggled with
-- individual :setVisible() calls via showScreen() below -- same
-- :setVisible() API already confirmed working in-game (session 3 bugfix),
-- just without the extra Frame layer. STILL NOT VERIFIED against the
-- Basalt2 source (no network access in this session either, same as
-- session 3) -- please retest the Monitor after pulling this update and
-- report back if it's still blank.
local w, h = screen:getSize()
local colWidth = math.floor(w / #podiums)
local BAR_WIDTH = math.max(4, colWidth - 4)

local liveElements = {}
local setupElements = {}
local historyElements = {}

local function setElementsVisible(elements, visible)
    for _, element in ipairs(elements) do
        element:setVisible(visible)
    end
end

showScreen = function(state)
    screenState = state
    setElementsVisible(liveElements, state == "live")
    setElementsVisible(setupElements, state == "setup")
    setElementsVisible(historyElements, state == "history")
end

-- ---------------------- LIVE SCREEN ----------------------
local podiumUI = {}

for i, podium in ipairs(podiums) do
    local x = (i - 1) * colWidth + 1
    local width = (i == #podiums) and (w - x + 1) or colWidth

    local ui = {}
    ui.headerLabel = screen:addLabel()
        :setText(podium.position)
        :setPosition(x, 1):setSize(width, 1)
        :setBackground(colors.gray):setForeground(colors.white)
    ui.trainerLabel = screen:addLabel()
        :setText(""):setPosition(x, 2):setSize(width, 1)
        :setBackground(colors.lightGray):setForeground(colors.gray)
    ui.nameLabel = screen:addLabel()
        :setText(""):setPosition(x, 3):setSize(width, 1)
        :setBackground(colors.lightGray):setForeground(colors.black)
    ui.barLabel = screen:addLabel()
        :setText(""):setPosition(x, 4):setSize(width, 1)
        :setBackground(colors.lightGray):setForeground(colors.black)
    ui.hpLabel = screen:addLabel()
        :setText(""):setPosition(x, 5):setSize(width, 1)
        :setBackground(colors.lightGray):setForeground(colors.black)
    ui.faintedLabel = screen:addLabel()
        :setText(""):setPosition(x, 6):setSize(width, 1)
        :setBackground(colors.lightGray):setForeground(colors.gray)
    ui.bannerLabel = screen:addLabel()
        :setText(""):setPosition(x, 7):setSize(width, 1)
        :setBackground(colors.lightGray):setForeground(colors.yellow)

    podiumUI[i] = ui
    liveElements[#liveElements + 1] = ui.headerLabel
    liveElements[#liveElements + 1] = ui.trainerLabel
    liveElements[#liveElements + 1] = ui.nameLabel
    liveElements[#liveElements + 1] = ui.barLabel
    liveElements[#liveElements + 1] = ui.hpLabel
    liveElements[#liveElements + 1] = ui.faintedLabel
    liveElements[#liveElements + 1] = ui.bannerLabel
end

-- bottom row, split in half: New Battle (left) / History (right)
local bottomHalf = math.floor(w / 2)
local newBattleButton = screen:addButton()
    :setText("New Battle")
    :setPosition(1, h):setSize(bottomHalf, 1)
    :setBackground(colors.orange):setForeground(colors.white)
    :onClick(function() openSetupScreen() end)
liveElements[#liveElements + 1] = newBattleButton

local historyButton = screen:addButton()
    :setText("History")
    :setPosition(bottomHalf + 1, h):setSize(w - bottomHalf, 1)
    :setBackground(colors.cyan):setForeground(colors.white)
    :onClick(function() openHistoryScreen() end)
liveElements[#liveElements + 1] = historyButton

-- ---------------------- SETUP SCREEN ----------------------
local setupTitle = screen:addLabel()
    :setText("New Battle - Team Size (1-6)")
    :setPosition(1, 1):setSize(w, 1)
    :setBackground(colors.black):setForeground(colors.white)
setupElements[#setupElements + 1] = setupTitle

local setupUI = {}
for i, podium in ipairs(podiums) do
    local y = 2 + i
    setupUI[i] = {}

    local label = screen:addLabel()
        :setText(podium.position .. ":")
        :setPosition(2, y):setSize(math.max(4, math.min(10, w - 12)), 1)
        :setBackground(colors.black):setForeground(colors.white)
    setupElements[#setupElements + 1] = label

    local minusButton = screen:addButton()
        :setText("-")
        :setPosition(w - 9, y):setSize(3, 1)
        :setBackground(colors.red):setForeground(colors.white)
        :onClick(function()
            pendingTeamSizes[i] = clampTeamSize(pendingTeamSizes[i] - 1)
            setupUI[i].countLabel:setText(tostring(pendingTeamSizes[i]))
        end)
    setupElements[#setupElements + 1] = minusButton

    setupUI[i].countLabel = screen:addLabel()
        :setText("1")
        :setPosition(w - 6, y):setSize(3, 1)
        :setBackground(colors.black):setForeground(colors.white)
    setupElements[#setupElements + 1] = setupUI[i].countLabel

    local plusButton = screen:addButton()
        :setText("+")
        :setPosition(w - 3, y):setSize(3, 1)
        :setBackground(colors.green):setForeground(colors.white)
        :onClick(function()
            pendingTeamSizes[i] = clampTeamSize(pendingTeamSizes[i] + 1)
            setupUI[i].countLabel:setText(tostring(pendingTeamSizes[i]))
        end)
    setupElements[#setupElements + 1] = plusButton
end

local startBattleButton = screen:addButton()
    :setText("Start Battle")
    :setPosition(1, h):setSize(w, 1)
    :setBackground(colors.green):setForeground(colors.white)
    :onClick(function() startBattle() end)
setupElements[#setupElements + 1] = startBattleButton

-- ---------------------- HISTORY SCREEN ----------------------
-- Fixed, pre-drawn row slots (Basalt widgets should all exist before
-- basalt.run() starts -- see ControlRoom/FossilLab, same convention),
-- refilled per page rather than created/destroyed on demand.
local historyTitle = screen:addLabel()
    :setText("Match History (last " .. HISTORY_MAX_ENTRIES .. ")")
    :setPosition(1, 1):setSize(w, 1)
    :setBackground(colors.black):setForeground(colors.white)
historyElements[#historyElements + 1] = historyTitle

local HISTORY_ROWS_PER_PAGE = math.max(1, h - 3) -- row1 title, rows 2..h-2 list, h-1 pager, h back
local historySlots = {}
for i = 1, HISTORY_ROWS_PER_PAGE do
    historySlots[i] = screen:addLabel()
        :setText("")
        :setPosition(1, 1 + i):setSize(w, 1)
        :setBackground(colors.black):setForeground(colors.white)
    historyElements[#historyElements + 1] = historySlots[i]
end

local historyPagerY = h - 1
local historyPrevButton = screen:addButton()
    :setText("< Prev")
    :setPosition(1, historyPagerY):setSize(8, 1)
    :setBackground(colors.gray):setForeground(colors.white)
historyElements[#historyElements + 1] = historyPrevButton

local historyNextButton = screen:addButton()
    :setText("Next >")
    :setPosition(w - 7, historyPagerY):setSize(8, 1)
    :setBackground(colors.gray):setForeground(colors.white)
historyElements[#historyElements + 1] = historyNextButton

local historyPageLabel = screen:addLabel()
    :setText("")
    :setPosition(10, historyPagerY):setSize(math.max(1, w - 18), 1)
    :setBackground(colors.black):setForeground(colors.white)
historyElements[#historyElements + 1] = historyPageLabel

local historyBackButton = screen:addButton()
    :setText("Back")
    :setPosition(1, h):setSize(w, 1)
    :setBackground(colors.gray):setForeground(colors.white)
    :onClick(function() showScreen("live") end)
historyElements[#historyElements + 1] = historyBackButton

local currentHistoryPage = 1

local function totalHistoryPages()
    return math.max(1, math.ceil(#historyEntries / HISTORY_ROWS_PER_PAGE))
end

-- one line per match: "<time>  <who> F/T vs <who> F/T  -> <winner> won" (or
-- "-> Draw" on a simultaneous mutual KO). Generic over any podium count.
local function formatHistoryEntry(entry)
    local parts = {}
    for _, r in ipairs(entry.results) do
        local who = r.trainer or r.position
        parts[#parts + 1] = who .. " " .. r.fainted .. "/" .. r.teamSize
    end
    local outcome = entry.winner and (entry.winner .. " won") or "Draw"
    return (entry.time or "") .. "  " .. table.concat(parts, " vs ") .. "  -> " .. outcome
end

renderHistoryPage = function()
    local pages = totalHistoryPages()
    if currentHistoryPage > pages then currentHistoryPage = pages end
    if currentHistoryPage < 1 then currentHistoryPage = 1 end

    local startIndex = (currentHistoryPage - 1) * HISTORY_ROWS_PER_PAGE
    for i = 1, HISTORY_ROWS_PER_PAGE do
        local entry = historyEntries[startIndex + i]
        historySlots[i]:setText(entry and formatHistoryEntry(entry) or "")
    end
    if #historyEntries == 0 then
        historySlots[1]:setText("(no matches recorded yet)")
    end
    historyPageLabel:setText("Page " .. currentHistoryPage .. "/" .. pages)
end

historyPrevButton:onClick(function()
    currentHistoryPage = currentHistoryPage - 1
    renderHistoryPage()
end)
historyNextButton:onClick(function()
    currentHistoryPage = currentHistoryPage + 1
    renderHistoryPage()
end)

openHistoryScreen = function()
    currentHistoryPage = 1
    renderHistoryPage()
    showScreen("history")
end

-- start with only the live screen visible
setElementsVisible(setupElements, false)
setElementsVisible(historyElements, false)

-- ====================== DISPLAY / STATE LOGIC ======================
local function healthBar(health, maxHealth)
    if not health or not maxHealth or maxHealth <= 0 then
        return string.rep("-", BAR_WIDTH)
    end
    local filled = math.floor(BAR_WIDTH * math.min(health, maxHealth) / maxHealth + 0.5)
    filled = math.max(0, math.min(BAR_WIDTH, filled))
    return string.rep("#", filled) .. string.rep("-", BAR_WIDTH - filled)
end

-- green >50%, yellow 20-50%, red <20% (as agreed)
local function hpColor(health, maxHealth)
    if not health or not maxHealth or maxHealth <= 0 then
        return colors.gray
    end
    local pct = health / maxHealth
    if pct > 0.5 then
        return colors.green
    elseif pct > 0.2 then
        return colors.yellow
    else
        return colors.red
    end
end

renderLive = function()
    for i, podium in ipairs(podiums) do
        local ui = podiumUI[i]
        local defeated = podium.faintedCount >= teamSizes[i]

        ui.faintedLabel:setText("(" .. podium.faintedCount .. "/" .. teamSizes[i] .. " fainted)")

        if defeated then
            ui.trainerLabel:setText("")
            ui.nameLabel:setText("*** DEFEAT ***"):setForeground(colors.red)
            ui.barLabel:setText("")
            ui.hpLabel:setText("")
        else
            ui.trainerLabel:setText(podium.lastTrainerName and ("Trainer: " .. podium.lastTrainerName) or "")

            if podium.lastName then
                local nameText = podium.lastName
                if podium.lastHealth and podium.lastHealth <= 0 then
                    nameText = nameText .. "  FAINTED"
                end
                ui.nameLabel:setText(nameText):setForeground(colors.black)
                ui.barLabel:setText("[" .. healthBar(podium.lastHealth, podium.lastMaxHealth) .. "]")
                    :setForeground(hpColor(podium.lastHealth, podium.lastMaxHealth))
                ui.hpLabel:setText("HP " .. (podium.lastHealth or 0) .. "/" .. (podium.lastMaxHealth or 0))
            else
                ui.nameLabel:setText("(no Pokemon detected)"):setForeground(colors.gray)
                ui.barLabel:setText("")
                ui.hpLabel:setText("")
            end
        end

        ui.bannerLabel:setText(matchWinnerIndex == i and "*** WINNER ***" or "")
    end
end

-- A podium counts as "defeated" once faintedCount reaches its teamSize; if
-- exactly one podium isn't defeated, it's the winner. Simultaneous mutual
-- KOs (everyone defeated at once) show no winner (all podiums show
-- DEFEAT). Monotonic: faintedCount only goes up between resets, so this
-- never flickers mid-match.
local function updateMatchStatus()
    local aliveIndex, aliveCount = nil, 0
    for i, podium in ipairs(podiums) do
        if podium.faintedCount < teamSizes[i] then
            aliveCount = aliveCount + 1
            aliveIndex = i
        end
    end
    if #podiums > 1 and aliveCount == 1 then
        matchWinnerIndex = aliveIndex
    elseif aliveCount == #podiums then
        matchWinnerIndex = nil -- nobody defeated yet
    end
    -- otherwise (2+ still alive with 3+ podiums, or aliveCount == 0 mutual
    -- KO) leave matchWinnerIndex as-is: no single winner to report.
end

isMatchOver = function()
    for i, podium in ipairs(podiums) do
        if podium.faintedCount >= teamSizes[i] then
            return true
        end
    end
    return false
end

-- Records the just-finished match to historyEntries/match_history.dat.
-- Called exactly once per match, from update() the first scan cycle
-- isMatchOver() goes true (see matchLogged below) -- independent of which
-- screen is currently showing, so a match finishing while the player is on
-- the History or Setup screen still gets logged.
logMatch = function()
    local results = {}
    for i, podium in ipairs(podiums) do
        results[i] = {
            position = podium.position,
            trainer = podium.lastTrainerName,
            fainted = podium.faintedCount,
            teamSize = teamSizes[i],
        }
    end

    local winner = nil
    if matchWinnerIndex then
        local winnerPodium = podiums[matchWinnerIndex]
        winner = winnerPodium.lastTrainerName or winnerPodium.position
    end

    historyEntries = matchHistory.add(historyEntries, {
        time = os.date("%m-%d %H:%M"),
        results = results,
        winner = winner,
    }, HISTORY_MAX_ENTRIES)

    if screenState == "history" then
        renderHistoryPage()
    end
end

-- Clears the fainted tally + seen-uuid tracking on every podium and starts
-- tracking a fresh match. Only called from startBattle() (i.e. after the
-- setup screen's team sizes are committed) -- never directly from a
-- "reset" button, per the agreed New Battle -> setup -> Start Battle flow.
resetMatch = function()
    for _, podium in ipairs(podiums) do
        podium.faintedCount = 0
        podium.faintedUuids = {}
        podium.seenUuids = {}
    end
    matchWinnerIndex = nil
    matchLogged = false
end

-- Opens the team-size setup screen, prefilled with the currently active
-- team sizes (so re-running the same team size is just "New Battle" ->
-- "Start Battle"). Reached either by clicking "New Battle" on the live
-- screen, or automatically once a brand new Pokemon shows up after a
-- match is already over (see update() below) -- either way, "Start
-- Battle" is still required before the tally actually resets.
openSetupScreen = function()
    for i in ipairs(podiums) do
        pendingTeamSizes[i] = teamSizes[i]
        setupUI[i].countLabel:setText(tostring(pendingTeamSizes[i]))
    end
    showScreen("setup")
end

startBattle = function()
    for i in ipairs(podiums) do
        teamSizes[i] = pendingTeamSizes[i]
    end
    saveTeamSizes(teamSizes)
    resetMatch()
    showScreen("live")
    renderLive()
end

-- ====================== SCAN LOOP ======================
-- A scan briefly missing the active Pokemon (recall animation, scan
-- jitter) shouldn't blank the screen; only clear after MISS_LIMIT
-- consecutive misses.
local MISS_LIMIT = 2

update = function()
    for _, podium in ipairs(podiums) do
        local pokemon, trainer = scanPodium(podium)
        if pokemon then
            podium.lastUuid = pokemon.uuid
            podium.lastName = pokemon.name
            podium.lastHealth = pokemon.health
            podium.lastMaxHealth = pokemon.maxHealth
            if trainer then
                podium.lastTrainerName = trainer.name
            end
            podium.missCount = 0

            if pokemon.uuid then
                local isNewUuid = not podium.seenUuids[pokemon.uuid]
                podium.seenUuids[pokemon.uuid] = true

                -- Auto-detect a new battle: the match is already over
                -- (DEFEAT/WINNER showing) and a Pokemon we've never
                -- tracked this match just showed up alive on a podium.
                -- Jump to the setup screen (prefilled with the last-used
                -- team sizes) instead of silently resetting -- "Start
                -- Battle" is still required (agreed auto-detect option).
                if screenState == "live" and isMatchOver() and isNewUuid
                   and pokemon.health and pokemon.health > 0 then
                    openSetupScreen()
                end

                if pokemon.health and pokemon.health <= 0 and not podium.faintedUuids[pokemon.uuid] then
                    podium.faintedUuids[pokemon.uuid] = true
                    podium.faintedCount = podium.faintedCount + 1
                end
            end
        else
            podium.missCount = podium.missCount + 1
            if podium.missCount >= MISS_LIMIT then
                podium.lastUuid = nil
                podium.lastName = nil
                podium.lastHealth = nil
                podium.lastMaxHealth = nil
                podium.lastTrainerName = nil
            end
        end
    end
    updateMatchStatus()

    if isMatchOver() and not matchLogged then
        logMatch()
        matchLogged = true
    end

    if screenState == "live" then
        renderLive()
    end
end

-- Initial paint (blank state, nothing scanned yet), then hand off to
-- Basalt. The scan loop is scheduled through basalt.schedule() rather than
-- parallel.waitForAny(): it's a plain os.sleep()-based timer with no
-- rednet involved, and basalt.schedule() handles that fine (see the
-- rednet-specific gotcha noted in SimonSays/README and this repo's shared
-- memory -- that one only applies when something needs to resume on a
-- rednet_message event, which nothing here does).
renderLive()
basalt.schedule(function()
    while true do
        update()
        os.sleep(POLL_INTERVAL)
    end
end)
basalt.run()
