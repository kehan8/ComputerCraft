-- update.lua: redownloads all game files from GitHub

local REPO_URL = "https://raw.githubusercontent.com/kehan8/ComputerCraft/refs/heads/main/SimonSays/"

local FILES = { "startup.lua", "simon.lua", "update.lua" }

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

for _, name in ipairs(FILES) do
    print("Updating " .. name .. "...")
    downloadFile(name)
end

print("Done. Run 'startup' (or reboot) to play with the new version.")
