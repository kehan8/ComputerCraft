-- update.lua: redownloads the game files from GitHub.
-- Leaves config.lua alone so your local settings (monitor, relay, ...) survive the update.
-- Run update_full.lua instead if you want config.lua reset to the repo defaults too.

local REPO_URL = "https://raw.githubusercontent.com/kehan8/ComputerCraft/refs/heads/main/TicTacToe/"

local FILES = { "startup.lua", "board.lua", "ai.lua", "update.lua", "update_full.lua", "install.lua", "uninstall.lua" }

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

for _, name in ipairs(FILES) do
    print("Updating " .. name .. "...")
    downloadFile(name)
end

print("Done. Run 'startup' (or reboot) to play with the new version.")
