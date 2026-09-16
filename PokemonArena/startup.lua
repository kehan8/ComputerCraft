-- PokemonArena: shows the active (non-balled) Pokemon + trainer + HP for
-- each podium, using one Environment Detector per podium, plus a
-- fainted-count/WINNER-DEFEAT tally per podium (per-podium team size,
-- chosen in the "New Battle" setup screen, persisted in team_sizes.dat --
-- see config.lua). Basalt2 UI: colored HP bars, boxed podium panels, a
-- "New Battle" button (manual reset via a setup screen), an automatic jump
-- to that same setup screen when a brand new Pokemon shows up after a match
-- is already over, and a "History" screen listing recent matches (see
-- match_history.dat / history.lua).
--
-- Split into modules (scan.lua/teamsizes.lua/match.lua/ui.lua) -- this file
-- is purely orchestration: load config, build the podium table, bootstrap
-- Basalt2 + the monitor, wire the modules together, and run the scan loop.

-- ====================== CONFIG ======================
local config = require("config")
local RADIUS = config.RADIUS
local OWNED_TAG = config.OWNED_TAG
local PLAYER_TAG = config.PLAYER_TAG
local POLL_INTERVAL = config.POLL_INTERVAL
local MONITOR_SCALE = config.MONITOR_SCALE
local HISTORY_MAX_ENTRIES = config.HISTORY_MAX_ENTRIES or 20
local BACKGROUND_COLOR = config.BACKGROUND_COLOR or colors.lightGray
local MODEM_NAME = config.MODEM_NAME
local MODEM_ENABLED = config.MODEM_ENABLED

local locations = require("locations")
local matchHistory = require("history")
local scan = require("scan")
local teamsizes = require("teamsizes")
local match = require("match")

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
        lastTrainerName = nil, -- locked trainer name for the currently shown Pokemon (see trainerLock)
        missCount = 0,

        -- locked trainer guess for whichever Pokemon uuid is currently
        -- shown: computed once when that Pokemon first appears, then reused
        -- every scan (re-guessing let a bystander who merely walked closer
        -- steal the label mid-battle). Cleared whenever the active Pokemon
        -- changes (a new send-out) or on match.reset().
        trainerLock = { uuid = nil, name = nil },

        -- match tracking: how many of this podium's owned Pokemon have
        -- fainted so far (see match.lua)
        faintedCount = 0,
        faintedUuids = {}, -- already-counted uuids, so a fainted Pokemon
                           -- still visible for a couple scans isn't double-counted
        seenUuids = {}, -- every distinct owned-Pokemon uuid seen since the
                        -- last "Start Battle" -- drives the auto-new-battle check below
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
if not fs.exists("basalt") and not fs.exists("basalt.lua") then
    print("Installing Basalt UI library...")
    shell.run("wget run https://raw.githubusercontent.com/Pyroxenium/Basalt2/main/install.lua")
end
local basalt = require("basalt")

-- Auto-detect a wired Advanced Monitor and mirror the whole display onto
-- it, falling back to the computer's own terminal if none is present.
local mon = peripheral.find("monitor")

local screen, paletteTarget
if mon then
    if MONITOR_SCALE then
        mon.setTextScale(MONITOR_SCALE)
    end
    screen = basalt.createFrame():setTerm(mon)
    paletteTarget = mon
else
    screen = basalt.getMainFrame()
    paletteTarget = term
end

-- ====================== CONTROLROOM (rednet) ======================
-- Reports a bare "Running" status to ControlRoom (see ../ControlRoom) --
-- no podium/trainer/Pokemon info goes out, and there's no command to
-- receive either, so read-only there, no Reset/toggle button.
local PROTOCOL = "controlroom"
local DEVICE_TYPE = "PokemonArena"

if MODEM_ENABLED then
    if not peripheral.isPresent(MODEM_NAME) then
        error("Could not find modem '" .. MODEM_NAME .. "'. Check the wireless modem is attached and named correctly.")
    end
    rednet.open(MODEM_NAME)
end

-- ====================== PER-PODIUM TEAM SIZE (team_sizes.dat) ======================
local teamSizes = teamsizes.load(#podiums)

-- ====================== MATCH HISTORY (match_history.dat) ======================
-- matchState: winnerIndex (nil while ongoing/no single winner), logged
-- (guards against double-logging), historyEntries (newest first, capped at
-- HISTORY_MAX_ENTRIES) -- handed to ui.build() once and stays valid for the run.
local matchState = {
    winnerIndex = nil,
    logged = false,
    historyEntries = matchHistory.load(),
}

-- ====================== UI ======================
local ui = require("ui")
local screenUI = ui.build(screen, paletteTarget, podiums, teamSizes, matchState.historyEntries, {
    historyMaxEntries = HISTORY_MAX_ENTRIES,
    backgroundColor = BACKGROUND_COLOR,
    onStartBattle = function(pendingSizes)
        for i in ipairs(podiums) do
            teamSizes[i] = pendingSizes[i]
        end
        teamsizes.save(teamSizes)
        match.reset(matchState, podiums)
    end,
})

-- ====================== SCAN LOOP ======================
-- A scan briefly missing the active Pokemon (recall animation, scan
-- jitter) shouldn't blank the screen; only clear after MISS_LIMIT
-- consecutive misses.
local MISS_LIMIT = 2

local function update()
    local scans = scan.scanAllPodiums(podiums, RADIUS, OWNED_TAG, PLAYER_TAG)
    for i, podium in ipairs(podiums) do
        local pokemon, trainer = scans[i].pokemon, scans[i].trainer
        if pokemon then
            podium.lastUuid = pokemon.uuid
            podium.lastName = pokemon.name
            podium.lastHealth = pokemon.health
            podium.lastMaxHealth = pokemon.maxHealth

            -- lock the trainer guess to this Pokemon's uuid: forget the old
            -- lock the moment a different Pokemon becomes active (new
            -- send-out), then adopt the first trainer candidate found and
            -- keep it, never overwritten by a closer bystander
            if podium.trainerLock.uuid ~= pokemon.uuid then
                podium.trainerLock = { uuid = pokemon.uuid, name = nil }
            end
            if not podium.trainerLock.name and trainer then
                podium.trainerLock.name = trainer.name
            end
            podium.lastTrainerName = podium.trainerLock.name

            podium.missCount = 0

            if pokemon.uuid then
                local isNewUuid = not podium.seenUuids[pokemon.uuid]
                podium.seenUuids[pokemon.uuid] = true

                -- Auto-detect a new battle: the match is already over
                -- (DEFEAT/WINNER showing) and a never-tracked Pokemon just
                -- showed up alive. Jump to the setup screen (prefilled with
                -- the last-used team sizes) -- "Start Battle" is still required.
                if screenUI.getState() == "live" and match.isOver(podiums, teamSizes) and isNewUuid
                   and pokemon.health and pokemon.health > 0 then
                    screenUI.openSetupScreen()
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
    match.updateStatus(matchState, podiums, teamSizes)

    if match.isOver(podiums, teamSizes) and not matchState.logged then
        match.log(matchState, podiums, teamSizes, HISTORY_MAX_ENTRIES)
        matchState.logged = true
        if screenUI.getState() == "history" then
            screenUI.renderHistoryPage()
        end
    end

    if screenUI.getState() == "live" then
        screenUI.renderLive(matchState.winnerIndex)
    end

    if MODEM_ENABLED then
        rednet.broadcast({ label = os.getComputerLabel(), type = DEVICE_TYPE, status = "Running" }, PROTOCOL)
    end
end

-- Initial paint, then hand off to Basalt. The scan loop uses
-- basalt.schedule() rather than parallel.waitForAny(): it's a plain
-- os.sleep()-based timer with no rednet involved, and basalt.schedule()
-- handles that fine (rednet needs parallel.waitForAny instead -- see repo memory).
screenUI.renderLive(matchState.winnerIndex)
basalt.schedule(function()
    while true do
        update()
        os.sleep(POLL_INTERVAL)
    end
end)
basalt.run()
