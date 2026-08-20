-- install.lua: downloads all game files from GitHub (including your config.lua defaults)
-- and installs Basalt

local REPO_URL = "https://raw.githubusercontent.com/kehan8/ComputerCraft/refs/heads/main/ControlRoom/"

local FILES = { "config.lua", "startup.lua", "update.lua", "update_full.lua", "uninstall.lua" }

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

if not fs.exists("basalt") and not fs.exists("basalt.lua") then
    shell.run("wget run https://raw.githubusercontent.com/Pyroxenium/Basalt2/main/install.lua")
end

for _, name in ipairs(FILES) do
    print("Downloading " .. name .. "...")
    downloadFile(name)
end

print("Done. Run 'startup' to play.")
