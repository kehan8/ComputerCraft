-- AdminDoor: opens each door independently for whitelisted admins; anyone
-- else gets a "NO ACCESS" toast. See README for the multi-door design.

-- ====================== CONFIG ======================
local config = require("config")
local DETECTOR_NAME = config.DETECTOR_NAME
local CHATBOX_NAME = config.CHATBOX_NAME
local TOAST_TITLE = config.TOAST_TITLE
local TOAST_MESSAGE = config.TOAST_MESSAGE
local POLL_INTERVAL = config.POLL_INTERVAL
local MODEM_NAME = config.MODEM_NAME
local MODEM_ENABLED = config.MODEM_ENABLED

local locations = require("locations")

-- normalizes each axis so MIN <= MAX
local function normalizeBox(min, max)
    local nmin, nmax = {}, {}
    for _, axis in ipairs({ "x", "y", "z" }) do
        nmin[axis] = math.min(min[axis], max[axis])
        nmax[axis] = math.max(min[axis], max[axis])
    end
    return nmin, nmax
end

if not locations.DOORS or #locations.DOORS == 0 then
    error("locations.lua must define DOORS with at least one door table (see locations.lua).")
end

-- self-contained door tables: box + wiring + whitelist together (see README)
local doors = {}
for i, raw in ipairs(locations.DOORS) do
    local name = raw.name or ("Door " .. i)

    if not raw.relay and not raw.computer_side then
        error("locations.lua: door '" .. name .. "' needs a relay or a computer_side (or both).")
    end
    if raw.relay and not raw.relay_side then
        error("locations.lua: door '" .. name .. "' has a relay but no relay_side.")
    end

    local nmin, nmax = normalizeBox(raw.min, raw.max)

    -- nil admin_names = whitelist disabled for this door; {} = active with 0 names (locks it)
    local adminSet = nil
    if raw.admin_names then
        adminSet = {}
        for _, adminName in ipairs(raw.admin_names) do
            adminSet[adminName:lower()] = true
        end
    end

    doors[i] = {
        name = name,
        min = nmin,
        max = nmax,
        relay = raw.relay,
        relay_side = raw.relay_side,
        computer_side = raw.computer_side,
        adminSet = adminSet,
        relayPeripheral = nil, -- wrapped below, once peripherals are set up
        lastIntruder = nil, -- re-sends toast only when the intruder at this door changes
    }
end
-- ======================================================

-- Reports status to ControlRoom (see ../ControlRoom).
local PROTOCOL = "controlroom"
local DEVICE_TYPE = "AdminDoor"

if not fs.exists("basalt") and not fs.exists("basalt.lua") then
    print("Installing Basalt UI library...")
    shell.run("wget run https://raw.githubusercontent.com/Pyroxenium/Basalt2/main/install.lua")
end
local basalt = require("basalt")

local function wrapPeripheral(name, label)
    local p = peripheral.wrap(name)
    if not p then
        error("Could not find " .. label .. " '" .. name .. "'. Check the cable/name.")
    end
    return p
end

local detector = wrapPeripheral(DETECTOR_NAME, "Player Detector")
local chatBox = wrapPeripheral(CHATBOX_NAME, "Chat Box")

-- wrap relays now so a typo fails fast at startup
for _, door in ipairs(doors) do
    if door.relay then
        door.relayPeripheral = wrapPeripheral(door.relay, "redstone relay for door '" .. door.name .. "'")
    end
end

if MODEM_ENABLED then
    if not peripheral.isPresent(MODEM_NAME) then
        error("Could not find modem '" .. MODEM_NAME .. "'. Check the wireless modem is attached and named correctly.")
    end
    rednet.open(MODEM_NAME)
end

local function isAdmin(door, name)
    if not door.adminSet then
        return true -- whitelist disabled for this door
    end
    return door.adminSet[name:lower()] == true
end

local function setDoorRelay(door, open)
    if door.relayPeripheral then
        door.relayPeripheral.setOutput(door.relay_side, open)
    end
    if door.computer_side then
        redstone.setOutput(door.computer_side, open)
    end
end

-- pcall: player may leave before the toast lands.
local function warnIntruder(name)
    pcall(function()
        chatBox.sendToastToPlayer(TOAST_MESSAGE, TOAST_TITLE, name)
    end)
end

-- ====================== UI ======================
local screen = basalt.getMainFrame()
local w, _ = screen:getSize()

screen:addLabel()
    :setText("AdminDoor")
    :setPosition(2, 1)
    :setSize(w - 2, 1)
    :setForeground(colors.white)

-- one status line per door
local doorLabels = {}
for i, door in ipairs(doors) do
    doorLabels[i] = screen:addLabel()
        :setText(door.name .. ": closed")
        :setPosition(2, 2 + i)
        :setSize(w - 2, 1)
        :setForeground(colors.white)
end

-- ====================== DETECTION LOOP ======================
local function update()
    local grantedNames, deniedNames = {}, {}

    for i, door in ipairs(doors) do
        local playersAtDoor = detector.getPlayersInCoords(door.min, door.max)

        local admin, intruder = nil, nil
        for _, name in ipairs(playersAtDoor) do
            if isAdmin(door, name) then
                admin = admin or name
            else
                intruder = intruder or name
            end
        end

        setDoorRelay(door, admin ~= nil)

        if admin then
            local prefix = door.adminSet and "Access granted: " or "Open to all (no whitelist): "
            doorLabels[i]:setText(door.name .. ": " .. prefix .. admin):setForeground(colors.lime)
            grantedNames[#grantedNames + 1] = door.name
        elseif intruder then
            doorLabels[i]:setText(door.name .. ": ACCESS DENIED: " .. intruder):setForeground(colors.red)
            deniedNames[#deniedNames + 1] = door.name
        else
            doorLabels[i]:setText(door.name .. ": closed"):setForeground(colors.white)
        end

        if intruder and intruder ~= door.lastIntruder then
            warnIntruder(intruder)
        end
        door.lastIntruder = intruder
    end

    if MODEM_ENABLED then
        local parts = {}
        if #grantedNames > 0 then
            parts[#parts + 1] = "Granted: " .. table.concat(grantedNames, ", ")
        end
        if #deniedNames > 0 then
            parts[#parts + 1] = "Denied: " .. table.concat(deniedNames, ", ")
        end
        local statusText = #parts > 0 and table.concat(parts, " | ") or "All doors closed"
        rednet.broadcast({ label = os.getComputerLabel(), type = DEVICE_TYPE, status = statusText }, PROTOCOL)
    end
end

basalt.schedule(function()
    while true do
        update()
        os.sleep(POLL_INTERVAL)
    end
end)

basalt.run()
