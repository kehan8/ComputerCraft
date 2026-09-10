-- board.lua: tic-tac-toe board state and win detection

local board = {}

board.HUMAN = "X"
board.AI = "O"

function board.new()
    return {{"", "", ""}, {"", "", ""}, {"", "", ""}}
end

local WIN_LINES = {
    {{1,1},{1,2},{1,3}}, {{2,1},{2,2},{2,3}}, {{3,1},{3,2},{3,3}},
    {{1,1},{2,1},{3,1}}, {{1,2},{2,2},{3,2}}, {{1,3},{2,3},{3,3}},
    {{1,1},{2,2},{3,3}}, {{1,3},{2,2},{3,1}},
}

function board.winner(b)
    for _, line in ipairs(WIN_LINES) do
        local p1, p2, p3 = line[1], line[2], line[3]
        local v = b[p1[1]][p1[2]]
        if v ~= "" and v == b[p2[1]][p2[2]] and v == b[p3[1]][p3[2]] then
            return v
        end
    end
    return nil
end

function board.isFull(b)
    for r = 1, 3 do
        for c = 1, 3 do
            if b[r][c] == "" then return false end
        end
    end
    return true
end

return board
