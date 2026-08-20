-- update_full.lua: redownloads EVERYTHING from GitHub, including config.lua.
-- Use this instead of update.lua if config.lua ever gets corrupted/deleted, or you
-- want to wipe your local settings back to the repo defaults after a fresh pull.
-- Your MONITOR_NAME / REDSTONE_RELAY_NAME / WIN_LENGTH / etc. edits in config.lua WILL be lost.

local REPO_URL = "https://raw.githubusercontent.com/kehan8/ComputerCraft/refs/heads/main/SimonSays/"

local FILES = { "config.lua", "startup.lua", "simon.lua", "update.lua", "update_full.lua" }

local function downloadFile(name)
    local request = http.get(REPO_URL .. name)
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
