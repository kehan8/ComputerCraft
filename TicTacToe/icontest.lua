-- icontest.lua: debug script, NOT part of the game.
-- Run this on its own (separate from startup.lua) to figure out why plain
-- colored Labels weren't showing up. Look at the monitor and tell me exactly
-- which numbered boxes you can and can't see, then check the terminal
-- output for the method list.

local basalt = require("basalt")

local mon = peripheral.find("monitor")
local screen
if mon then
    mon.setTextScale(1)
    screen = basalt.createFrame():setTerm(mon)
else
    screen = basalt.getMainFrame()
end

-- Box 1: Label, empty text, explicit background + size
screen:addLabel():setText(""):setPosition(2, 2):setSize(6, 3):setBackground(colors.red)

-- Box 2: Label, space-padded text, explicit background + size
screen:addLabel():setText("      "):setPosition(10, 2):setSize(6, 3):setBackground(colors.orange)

-- Box 3: Button, empty text, for comparison (this style is known to work)
screen:addButton():setText(""):setPosition(18, 2):setSize(6, 3):setBackground(colors.green)

-- Box 4: Label with real text AND a background, for comparison
local t4 = screen:addLabel():setText("HI"):setPosition(2, 8):setSize(6, 3):setBackground(colors.blue):setForeground(colors.white)

print("Look at the monitor. Which boxes do you actually see?")
print("1 = red box, top-left")
print("2 = orange box, next to it")
print("3 = green box (a Button, for comparison)")
print("4 = blue box with 'HI' text, below")
print("")
print("--- Method check on a Label ---")

local function check(name)
    local ok = type(t4[name]) == "function"
    print(name .. ": " .. (ok and "exists" or "MISSING"))
end

check("setAutoSize")
check("setBackground")
check("setForeground")
check("setSize")
check("setPosition")
check("setText")
check("centerIn")
check("getSize")

print("")
print("--- Image element check ---")
print("addImage on screen: " .. (type(screen.addImage) == "function" and "exists" or "MISSING"))

print("")
print("Press any key to open the UI (boxes 1-4 above)...")
os.pullEvent("key")

basalt.run()
