-- install.lua: downloads all game files from GitHub (including your config.lua defaults)

local REPO_URL = "https://raw.githubusercontent.com/kehan8/ComputerCraft/refs/heads/main/GymArena/AdminDoor/"

local FILES = { "config.lua", "locations.lua", "startup.lua", "rename.lua", "update.lua", "update_full.lua", "uninstall.lua" }

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

for _, name in ipairs(FILES) do
    print("Downloading " .. name .. "...")
    downloadFile(name)
end

-- name this device, never overwrites an existing label
if not os.getComputerLabel() then
    local defaultLabel = "AdminDoor-" .. os.getComputerID()
    print("Name this device? (Enter or SKIP = '" .. defaultLabel .. "')")
    io.write("> ")
    local input = read() or ""
    if input == "" or input:lower() == "skip" then
        os.setComputerLabel(defaultLabel)
    else
        os.setComputerLabel(input)
    end
end

print("Done. Run 'startup' to play.")
