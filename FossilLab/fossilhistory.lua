-- fossilhistory.lua: persists a log of completed fossil restorations to disk.
--
-- The multiblock itself forgets InsertedFossil/HasCreatedPokemon the instant
-- the Pokemon is claimed (confirmed via test_blockreader.lua -- both fields
-- are just gone from the next getBlockData() read), so FossilLab's UI can't
-- rely on the block for a "recent finds" list. This module keeps its own
-- record instead, saved to a file so it survives a computer reboot.

local fossilhistory = {}

local FILE = "fossil_history.txt"

-- Returns the saved history (newest first), or {} if the file doesn't exist
-- yet or is corrupted.
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

-- Appends one entry to the front (newest first) -- gameTime is os.time()
-- (Minecraft's own clock), same convention test_blockreader.lua uses for its
-- log timestamps, not a real-world epoch. Trims to maxEntries and saves.
function fossilhistory.add(entries, species, maxEntries)
    table.insert(entries, 1, { species = species, gameTime = os.time() })
    while #entries > maxEntries do
        table.remove(entries)
    end
    fossilhistory.save(entries)
    return entries
end

return fossilhistory
