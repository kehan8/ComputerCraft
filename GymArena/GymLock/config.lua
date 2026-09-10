-- config.lua: your local settings for this puzzle.
-- update.lua does NOT touch this file, so your changes survive a normal update.
-- Run update_full.lua instead if you ever want this file reset back to the repo defaults.

return {
    -- Inputs: reads the "solved" signal coming from each puzzle's own relay.
    SIMON_RELAY_NAME = "redstone_relay_0",     -- relay wired to the SimonSays computer's door signal
    SIMON_SIDE = "front",                       -- side of that relay carrying the signal
    TICTACTOE_RELAY_NAME = "redstone_relay_1", -- relay wired to the TicTacToe computer's door signal
    TICTACTOE_SIDE = "front",                   -- side of that relay carrying the signal

    -- Admin override lever: forces the main door open, doesn't touch the puzzles.
    ADMIN_RELAY_NAME = "redstone_relay_4",
    ADMIN_SIDE = "front",

    -- Outputs: main piston door, once both puzzles (or admin override) are on.
    -- Two relays since the piston door needs signal on two sides.
    DOOR_RELAY_NAME_1 = "redstone_relay_2",
    DOOR_SIDE_1 = "front",
    DOOR_RELAY_NAME_2 = "redstone_relay_3",
    DOOR_SIDE_2 = "front",

    -- Wireless modem to report status to ControlRoom. False if no modem.
    MODEM_NAME = "back",
    MODEM_ENABLED = false,
    HEARTBEAT_INTERVAL = 3, -- seconds between status broadcasts, even if nothing changed

    -- Anti-cheat gate: Player Detector at the exit, resets puzzles if someone
    -- sneaks back through. Set false if you don't have this detector.
    GATE_ENABLED = true,
    GATE_DETECTOR_NAME = "player_detector_0", -- name of your Player Detector peripheral
    GATE_DETECT_RANGE = 3,                   -- blocks; keep tight so it only covers the choke point
    GATE_POLL_INTERVAL = 0.5,                -- seconds between checks (no "in range" event, must poll)
}
