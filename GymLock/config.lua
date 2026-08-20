-- config.lua: your local settings for this puzzle.
-- update.lua does NOT touch this file, so your changes survive a normal update.
-- Run update_full.lua instead if you ever want this file reset back to the repo defaults.

return {
    -- Inputs: reads the "solved" signal coming from each puzzle's own relay.
    SIMON_RELAY_NAME = "redstone_relay_0",     -- relay wired to the SimonSays computer's door signal
    SIMON_SIDE = "front",                       -- side of that relay carrying the signal
    TICTACTOE_RELAY_NAME = "redstone_relay_1", -- relay wired to the TicTacToe computer's door signal
    TICTACTOE_SIDE = "front",                   -- side of that relay carrying the signal

    -- Outputs: drives the main piston door once BOTH puzzles are solved.
    -- Two relays because the piston door needs signal on two sides/pistons.
    DOOR_RELAY_NAME_1 = "redstone_relay_2",
    DOOR_SIDE_1 = "front",
    DOOR_RELAY_NAME_2 = "redstone_relay_3",
    DOOR_SIDE_2 = "front",
}
