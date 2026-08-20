-- simon.lua: Simon Says pattern state

local simon = {}

function simon.new()
    return {}
end

-- Appends one random pad (1-4) to the pattern.
function simon.addStep(pattern)
    table.insert(pattern, math.random(1, 4))
    return pattern
end

return simon
