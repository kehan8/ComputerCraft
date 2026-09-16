-- match.lua: HP-bar/color display helpers + match tracking (winner/defeat
-- detection, resetting a podium's tally, logging a finished match to
-- match_history.dat). Split out of startup.lua (session 8 module refactor).
-- No UI code here -- healthBar/hpColor return plain strings/colors.* values
-- for ui.lua to paint; updateStatus/reset/log mutate a small "match state"
-- table (winnerIndex/logged/historyEntries) that startup.lua owns and
-- passes in, so this module has no hidden globals of its own.

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

-- Session 14: 3-step gradient (green/yellow/red) had no orange step, so a
-- Pokemon sitting just under 25% HP (user's screenshot: Archaludon 3/12 =
-- exactly 25%) rendered yellow, not the "dark orange" user expected from
-- Cobblemon's own HP bar (a different, unrelated UI with its own
-- thresholds -- see README). Added an orange step between yellow and red
-- so our gradient reads closer to that: green >50%, yellow 25-50%, orange
-- 10-25%, red <=10%.
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

-- A podium counts as "defeated" once faintedCount reaches its teamSize; if
-- exactly one podium isn't defeated, it's the winner. Simultaneous mutual
-- KOs (everyone defeated at once) show no winner (all podiums show
-- DEFEAT). Monotonic: faintedCount only goes up between resets, so this
-- never flickers mid-match.
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
    -- otherwise (2+ still alive with 3+ podiums, or aliveCount == 0 mutual
    -- KO) leave state.winnerIndex as-is: no single winner to report.
end

-- Clears the fainted tally + seen-uuid tracking on every podium and starts
-- tracking a fresh match. Only called after the setup screen's team sizes
-- are committed (Start Battle) -- never directly from a "reset" button.
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

-- Records the just-finished match to state.historyEntries/match_history.dat.
-- Called exactly once per match by startup.lua's update() (guarded by
-- state.logged), independent of which screen is currently showing, so a
-- match finishing while the player is on the History or Setup screen still
-- gets logged. Returns the (possibly trimmed) historyEntries list.
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
