# GymLock (CC:Tweaked)

The "brain" computer for the gym: watches the door-signal relays from the [Simon Says](../SimonSays) and [Tic Tac Toe](../TicTacToe) puzzle computers, and once **both** are solved, opens the main entrance (a piston door). No monitor or UI — just plain text status on the computer's own screen.

![status](https://img.shields.io/badge/status-working-brightgreen)

## What it does

- Reads two redstone inputs: one relay wired to the Simon Says computer's door signal, one wired to the Tic Tac Toe computer's door signal.
- The moment **both** are high, it opens the main door — driving two relay outputs high (a piston door needs signal on two sides/pistons).
- If either puzzle gets reset (its signal drops back low, e.g. someone hits "New game"), the main door closes again automatically.
- A third input — an **admin lever** wired through its own relay — force-opens the main door regardless of the puzzles. Flip it off and the door goes back to normal puzzle-controlled behavior. It only affects the main door; it has no effect on the puzzle computers or their signals.
- An **anti-cheat gate** (optional, see `GATE_ENABLED` below): a Player Detector placed between GymLock's exit and the next puzzle's entrance. The moment anyone is spotted there (e.g. sneaking back through a warp plate to redo a puzzle), the main door force-closes and Simon Says + Tic Tac Toe both get reset — broadcast directly over rednet, no ControlRoom needed. Ignored while the admin lever is on, since that's you deliberately holding the door open.
- Fully event-driven — it sits idle until a redstone signal actually changes, then reprints its status:

  ```
  GymLock

  Simon Says:  SOLVED
  Tic Tac Toe: locked
  Admin lever: off

  Main door:   closed
  ```

- Also broadcasts that same status over rednet every `HEARTBEAT_INTERVAL` seconds (and on every change) so a [ControlRoom](../ControlRoom) computer can show it remotely (read-only — no controls for this device).

## Requirements

- CC:Tweaked (Minecraft mod)
- A **Computer** (regular is fine — no color/touch/monitor needed)
- **5 Redstone Relays**, each connected to the computer with a Wired Modem + Networking Cable:
  - 2 as **inputs** — wired to the Simon Says and Tic Tac Toe computers' door-signal relays
  - 1 as an **input** — wired to an admin lever (force-opens the door, independent of the puzzles)
  - 2 as **outputs** — wired to your piston door
- Optional: a **Player Detector** ([Advanced Peripherals](https://www.curseforge.com/minecraft/mc-mods/advanced-peripherals)) for the anti-cheat gate, placed at the choke point between GymLock's exit and the next puzzle's entrance. Don't have one? Set `GATE_ENABLED = false` in `config.lua` and skip it entirely.
- A **wireless modem** attached, for reporting status to [ControlRoom](../ControlRoom) and broadcasting the puzzle-reset command

## Install

On a fresh CC:Tweaked computer:

```
wget https://raw.githubusercontent.com/kehan8/ComputerCraft/refs/heads/main/GymLock/install.lua install
install
```

This downloads `config.lua`, `startup.lua`, `update.lua`, `update_full.lua`, and `uninstall.lua`.

## Configure

Before running, open `config.lua` and set the values to match your build:

```lua
SIMON_RELAY_NAME = "redstone_relay_0",     -- relay wired to the SimonSays computer's door signal
SIMON_SIDE = "front",                       -- side of that relay carrying the signal
TICTACTOE_RELAY_NAME = "redstone_relay_1", -- relay wired to the TicTacToe computer's door signal
TICTACTOE_SIDE = "front",                   -- side of that relay carrying the signal

ADMIN_RELAY_NAME = "redstone_relay_4",     -- relay wired to the admin override lever
ADMIN_SIDE = "front",                       -- side of that relay carrying the signal

DOOR_RELAY_NAME_1 = "redstone_relay_2",
DOOR_SIDE_1 = "front",
DOOR_RELAY_NAME_2 = "redstone_relay_3",
DOOR_SIDE_2 = "front",

MODEM_NAME = "back",       -- wireless modem used to report status to ControlRoom
HEARTBEAT_INTERVAL = 3,    -- seconds between status broadcasts, even without a change

GATE_ENABLED = true,                     -- set to false if you don't have the Player Detector below
GATE_DETECTOR_NAME = "player_detector_0", -- name of your Player Detector peripheral
GATE_DETECT_RANGE = 3,                   -- blocks; keep tight so it only covers the choke point
GATE_POLL_INTERVAL = 0.5,                -- seconds between checks (no "in range" event, must poll)
```

If you're not sure what your relays are named, run `peripheral.getNames()` from the Lua prompt to list connected peripherals.

> Updating from an older install? `update.lua` never touches `config.lua`, so the new `MODEM_NAME`/`HEARTBEAT_INTERVAL` fields won't appear on their own — run `update_full` (see below) or add the lines yourself.

## Run

```
startup
```

To pull the latest version later:

```
update
```

`update` re-downloads the code but **leaves `config.lua` alone**, so your relay settings survive. If you ever want `config.lua` itself reset back to the repo defaults (e.g. it got corrupted, or a new version adds new settings), run:

```
update_full
```

## Uninstall

```
uninstall
```

Removes everything `install.lua` put on the computer (optionally including `config.lua`). Useful for a clean slate before reinstalling.

## Files

| File | Purpose |
|---|---|
| `config.lua` | Your local settings (relay names/sides, gate detector) — not touched by `update.lua` |
| `startup.lua` | Reads the puzzle signals, drives the main door, watches the anti-cheat gate, prints status |
| `install.lua` | First-time setup |
| `update.lua` | Re-downloads the code, keeps your `config.lua` |
| `update_full.lua` | Re-downloads everything, including `config.lua` |
| `uninstall.lua` | Removes the installed files |
