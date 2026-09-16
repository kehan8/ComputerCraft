-- match.lua: HP-bar/color helpers + match tracking (winner/defeat detection,
-- resetting a podium's tally, logging a finished match to match_history.dat).
-- No UI code here -- ui.lua paints using these; startup.lua owns the
-- matchState table (winnerIndex/logged/historyEntries) passed in.

local matchHistory = require("history")

local match = {}

function match.healthBar(health, maxHealth, barWidth)
    if not health or not maxHealth or maxHealth <= 0 then
        return string.rep("-", barWidth)
    end
    local filled = math.floor(barWidth * math.min(health, maxHealth) / maxHealth + 0.5)
    filled = math.max(0, math.min(barWidth, filled))
    return string.rep("#", filled) .. string.rep("-", barWidth - filled)
end

-- 4-step HP gradient: green >50%, yellow 25-50%, orange 10-25%, red <=10%.
-- Drives both the bar color and the HP text color.
function match.hpColor(health, maxHealth)
    if not health or not maxHealth or maxHealth <= 0 then
        return colors.gray
    end
    local pct = health / maxHealth
    if pct > 0.5 then
        return colors.green
    elseif pct > 0.25 then
        return colors.yellow
    elseif pct > 0.1 then
        return colors.orange
    else
        return colors.red
    end
end

function match.isOver(podiums, teamSizes)
    for i, podium in ipairs(podiums) do
        if podium.faintedCount >= teamSizes[i] then
            return true
        end
    end
    return false
end

-- Winner = the only podium not yet defeated. A simultaneous mutual KO
-- (everyone defeated at once) shows no winner (all podiums show DEFEAT).
function match.updateStatus(state, podiums, teamSizes)
    local aliveIndex, aliveCount = nil, 0
    for i, podium in ipairs(podiums) do
        if podium.faintedCount < teamSizes[i] then
            aliveCount = aliveCount + 1
            aliveIndex = i
        end
    end
    if #podiums > 1 and aliveCount == 1 then
        state.winnerIndex = aliveIndex
    elseif aliveCount == #podiums then
        state.winnerIndex = nil -- nobody defeated yet
    end
    -- otherwise leave state.winnerIndex as-is: no single winner to report
end

-- Clears the fainted tally + seen-uuid tracking on every podium and starts a
-- fresh match. Only called after "Start Battle" on the setup screen.
function match.reset(state, podiums)
    for _, podium in ipairs(podiums) do
        podium.faintedCount = 0
        podium.faintedUuids = {}
        podium.seenUuids = {}
        podium.trainerLock = { uuid = nil, name = nil }
    end
    state.winnerIndex = nil
    state.logged = false
end

-- Records the just-finished match. Called exactly once per match by
-- startup.lua's update() (guarded by state.logged).
function match.log(state, podiums, teamSizes, historyMaxEntries)
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
    if state.winnerIndex then
        local winnerPodium = podiums[state.winnerIndex]
        winner = winnerPodium.lastTrainerName or winnerPodium.position
    end

    state.historyEntries = matchHistory.add(state.historyEntries, {
        time = os.date("%m-%d %H:%M"),
        results = results,
        winner = winner,
    }, historyMaxEntries)

    return state.historyEntries
end

return match
