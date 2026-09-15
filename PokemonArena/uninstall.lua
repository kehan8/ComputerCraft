-- uninstall.lua: removes the files installed by install.lua/update.lua.

local FILES = { "startup.lua", "rename.lua", "update.lua", "update_full.lua", "install.lua" }

print("This will remove: " .. table.concat(FILES, ", "))
io.write("Also remove config.lua/locations.lua (your detector/podium settings)? (y/N): ")
local removeConfig = (read() or ""):lower() == "y"
if removeConfig then
    table.insert(FILES, "config.lua")
    table.insert(FILES, "locations.lua")
end

io.write("Also remove team_sizes.dat (your saved per-podium team sizes)? (y/N): ")
if (read() or ""):lower() == "y" then
    table.insert(FILES, "team_sizes.dat")
end

for _, name in ipairs(FILES) do
    if fs.exists(name) then
        fs.delete(name)
        print("Removed " .. name)
    end
end

if fs.exists("basalt") or fs.exists("basalt.lua") then
    io.write("Also remove the Basalt UI library? (y/N): ")
    if (read() or ""):lower() == "y" then
        if fs.exists("basalt") then fs.delete("basalt") end
        if fs.exists("basalt.lua") then fs.delete("basalt.lua") end
        print("Removed basalt")
    end
end

print("Done. Run install.lua again for a clean reinstall.")
