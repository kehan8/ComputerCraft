-- Removes the files installed by install.lua/update.lua. Handy for a clean reinstall.

local FILES = { "startup.lua", "rename.lua", "fossildata.lua", "fossilhistory.lua", "update.lua", "update_full.lua", "install.lua" }

print("This will remove: " .. table.concat(FILES, ", "))
io.write("Also remove config.lua (your monitor/Block Reader settings)? (y/N): ")
local removeConfig = (read() or ""):lower() == "y"
if removeConfig then
    table.insert(FILES, "config.lua")
end

if fs.exists("fossil_history.txt") then
    io.write("Also remove fossil_history.txt (your restoration log)? (y/N): ")
    if (read() or ""):lower() == "y" then
        table.insert(FILES, "fossil_history.txt")
    end
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
