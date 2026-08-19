-- ai.lua: unbeatable tic-tac-toe AI (minimax)

local board = require("board")
local HUMAN, AI = board.HUMAN, board.AI

local ai = {}

-- Score from the AI's perspective (positive = good for AI)
local function minimax(b, player)
    local w = board.winner(b)
    if w == AI then return 10 end
    if w == HUMAN then return -10 end
    if board.isFull(b) then return 0 end

    local best
    for r = 1, 3 do
        for c = 1, 3 do
            if b[r][c] == "" then
                b[r][c] = player
                local score = minimax(b, player == AI and HUMAN or AI)
                b[r][c] = ""
                if player == AI then
                    if best == nil or score > best then best = score end
                else
                    if best == nil or score < best then best = score end
                end
            end
        end
    end
    return best
end

-- Plays the AI's move directly on the given board
function ai.move(b)
    local bestScore, moves = nil, {}
    for r = 1, 3 do
        for c = 1, 3 do
            if b[r][c] == "" then
                b[r][c] = AI
                local score = minimax(b, HUMAN)
                b[r][c] = ""
                if bestScore == nil or score > bestScore then
                    bestScore = score
                    moves = {{r, c}}
                elseif score == bestScore then
                    table.insert(moves, {r, c})
                end
            end
        end
    end
    local pick = moves[math.random(#moves)]
    b[pick[1]][pick[2]] = AI
end

return ai
