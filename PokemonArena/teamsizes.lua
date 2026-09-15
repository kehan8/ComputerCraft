-- teamsizes.lua: load/save/clamp helpers for team_sizes.dat (per-podium
-- team size, 1-6, chosen in the "New Battle" setup screen). Split out of
-- startup.lua (session 8 module refactor). Deliberately NOT part of
-- config.lua, so update.lua/update_full.lua never clobber it and a config
-- reset doesn't erase an in-progress event's sizes -- same reasoning as
-- before the split, just moved.

local teamsizes = {}

local FILE = "team_sizes.dat"
local MIN, MAX = 1, 6

function teamsizes.clamp(n)
    n = tonumber(n) or MIN
    if n < MIN then return MIN end
    if n > MAX then return MAX end
    return math.floor(n)
end

-- count = number of podiums, fallback = config.TEAM_SIZE (used only for a
-- podium missing from a stale/missing team_sizes.dat, e.g. before the very
-- first "Start Battle" or after adding a podium to locations.lua).
function teamsizes.load(count, fallback)
    local saved = nil
    if fs.exists(FILE) then
        local file = fs.open(FILE, "r")
        local contents = file.readAll()
        file.close()
        local ok, data = pcall(textutils.unserialize, contents)
        if ok and type(data) == "table" then
            saved = data
        end
    end

    local fallbackClamped = teamsizes.clamp(fallback)
    local sizes = {}
    for i = 1, count do
        sizes[i] = teamsizes.clamp((saved and saved[i]) or fallbackClamped)
    end
    return sizes
end

function teamsizes.save(sizes)
    local file = fs.open(FILE, "w")
    file.write(textutils.serialize(sizes))
    file.close()
end

return teamsizes
