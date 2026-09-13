-- rename.lua: change this computer's label without reinstalling or resetting
-- anything else. Handy for telling multiple devices of the same type apart
-- in ControlRoom, or to fix a label you skipped/typo'd during install.

local current = os.getComputerLabel() or "(none set)"
print("Current label: " .. current)
io.write("New label (Enter or SKIP = keep it): ")
local input = read() or ""

if input == "" or input:lower() == "skip" then
    print("Kept: " .. current)
else
    os.setComputerLabel(input)
    print("Label set to: " .. input)
end
