-- history.lua: persists completed matches to match_history.dat, most-recent-
-- first, trimmed to a configurable max. Same shape as FossilLab's
-- fossilhistory.lua. Not part of config.lua, so update.lua/update_full.lua
-- never touch the saved data.

local history = {}

local FILE = "match_history.dat"

-- returns saved history (newest first), or {} if missing/corrupted
function history.load()
    if not fs.exists(FILE) then return {} end
    local f = fs.open(FILE, "r")
    local contents = f.readAll()
    f.close()

    local ok, entries = pcall(textutils.unserialize, contents)
    if ok and type(entries) == "table" then
        return entries
    end
    return {}
end

function history.save(entries)
    local f = fs.open(FILE, "w")
    f.write(textutils.serialize(entries))
    f.close()
end

-- adds one match result to the front, trims to maxEntries, saves
function history.add(entries, entry, maxEntries)
    table.insert(entries, 1, entry)
    while #entries > maxEntries do
        table.remove(entries)
    end
    history.save(entries)
    return entries
end

return history
