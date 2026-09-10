-- update_full.lua: redownloads EVERYTHING from GitHub, including config.lua.
-- Use this instead of update.lua if config.lua ever gets corrupted/deleted, or you
-- want to wipe your local settings back to the repo defaults after a fresh pull.
-- Your MONITOR_NAME / REDSTONE_RELAY_NAME / etc. edits in config.lua WILL be lost.

local REPO_URL = "https://raw.githubusercontent.com/kehan8/ComputerCraft/refs/heads/main/TicTacToe/"

local FILES = { "config.lua", "startup.lua", "board.lua", "ai.lua", "update.lua", "update_full.lua", "install.lua", "uninstall.lua" }

local function downloadFile(name)
    -- Cache-busting query param: raw.githubusercontent.com caches for a few
    -- minutes, so without this, a fresh push might not show up right away.
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
