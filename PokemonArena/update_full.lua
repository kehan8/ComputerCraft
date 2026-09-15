-- update_full.lua: redownloads EVERYTHING, including config.lua/locations.lua.

local REPO_URL = "https://raw.githubusercontent.com/kehan8/ComputerCraft/refs/heads/main/PokemonArena/"

local FILES = { "config.lua", "locations.lua", "startup.lua", "scan.lua", "teamsizes.lua", "match.lua", "ui.lua", "rename.lua", "history.lua", "update.lua", "update_full.lua", "install.lua", "uninstall.lua" }

local function downloadFile(name)
    -- cache-busting
    local request = http.get(REPO_URL .. name .. "?t=" .. os.epoch("utc"))
    if not request then
        print("Failed to download " .. name)
        return false
    end
    local contents = request.readAll()
    request.close()

    local file = fs.open(name, "w")
    file.write(contents)
    file.close()
    return true
end

print("This will also overwrite config.lua/locations.lua with the repo defaults.")
for _, name in ipairs(FILES) do
    print("Updating " .. name .. "...")
    downloadFile(name)
end

print("Done. Re-edit config.lua/locations.lua if needed, then run 'startup' (or reboot) to play.")
