-- Redownloads EVERYTHING from GitHub, including config.lua. Use if config.lua
-- gets corrupted, or to wipe local settings back to repo defaults. Your
-- REDSTONE_RELAY_NAME / GEARSHIFT_SIDE / etc. edits WILL be lost.

local REPO_URL = "https://raw.githubusercontent.com/kehan8/ComputerCraft/refs/heads/main/WelcomeDoor/"

local FILES = { "config.lua", "startup.lua", "update.lua", "update_full.lua", "install.lua", "uninstall.lua" }

local function downloadFile(name)
    -- Cache-bust: raw.githubusercontent.com caches for a few minutes.
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

print("This will also overwrite config.lua with the repo defaults.")
for _, name in ipairs(FILES) do
    print("Updating " .. name .. "...")
    downloadFile(name)
end

print("Done. Re-edit config.lua if needed, then run 'startup' (or reboot) to play.")
