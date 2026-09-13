-- config.lua: local settings, not touched by update.lua (see README).

return {
    -- Inputs: "solved" signal from each puzzle's own relay
    SIMON_RELAY_NAME = "redstone_relay_0",
    SIMON_SIDE = "front",
    TICTACTOE_RELAY_NAME = "redstone_relay_1",
    TICTACTOE_SIDE = "front",

    -- admin override lever, doesn't touch the puzzles
    ADMIN_RELAY_NAME = "redstone_relay_4",
    ADMIN_SIDE = "front",

    -- Outputs: main piston door, 2 relays (needs signal on two sides)
    DOOR_RELAY_NAME_1 = "redstone_relay_2",
    DOOR_SIDE_1 = "front",
    DOOR_RELAY_NAME_2 = "redstone_relay_3",
    DOOR_SIDE_2 = "front",

    -- Wireless modem to report status to ControlRoom. False if no modem.
    MODEM_NAME = "back",
    MODEM_ENABLED = false,
    HEARTBEAT_INTERVAL = 3, -- seconds between status broadcasts, even if nothing changed

    -- anti-cheat gate: resets puzzles if someone sneaks back through
    GATE_ENABLED = true,
    GATE_DETECTOR_NAME = "player_detector_0", -- Player Detector peripheral
    GATE_DETECT_RANGE = 3,                   -- blocks
    GATE_POLL_INTERVAL = 0.5,                -- seconds between checks
}
