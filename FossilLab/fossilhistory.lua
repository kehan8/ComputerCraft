-- fossilhistory.lua: persists a log of completed fossil restorations to disk
-- (the multiblock itself forgets InsertedFossil once claimed).

local fossilhistory = {}

local FILE = "fossil_history.txt"

-- returns saved history (newest first), or {} if missing/corrupted
function fossilhistory.load()
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

function fossilhistory.save(entries)
    local f = fs.open(FILE, "w")
    f.write(textutils.serialize(entries))
    f.close()
end

-- adds one entry to the front, trims to maxEntries, saves
function fossilhistory.add(entries, species, maxEntries)
    table.insert(entries, 1, { species = species, gameTime = os.time() })
    while #entries > maxEntries do
        table.remove(entries)
    end
    fossilhistory.save(entries)
    return entries
end

return fossilhistory
