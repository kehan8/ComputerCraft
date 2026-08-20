-- uninstall.lua: removes the files installed by install.lua/update.lua.
-- Handy for a clean reinstall (e.g. wget run .../install.lua) instead of deleting files by hand.

local FILES = { "startup.lua", "update.lua", "update_full.lua", "install.lua" }

print("This will remove: " .. table.concat(FILES, ", "))
io.write("Also remove config.lua (your relay settings)? (y/N): ")
local removeConfig = (read() or ""):lower() == "y"
if removeConfig then
    table.insert(FILES, "config.lua")
end

for _, name in ipairs(FILES) do
    if fs.exists(name) then
        fs.delete(name)
        print("Removed " .. name)
    end
end

print("Done. Run install.lua again for a clean reinstall.")
