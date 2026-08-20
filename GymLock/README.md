# GymLock (CC:Tweaked)

The "brain" computer for the gym: watches the door-signal relays from the [Simon Says](../SimonSays) and [Tic Tac Toe](../TicTacToe) puzzle computers, and once **both** are solved, opens the main entrance (a piston door). No monitor or UI — just plain text status on the computer's own screen.

![status](https://img.shields.io/badge/status-working-brightgreen)

## What it does

- Reads two redstone inputs: one relay wired to the Simon Says computer's door signal, one wired to the Tic Tac Toe computer's door signal.
- The moment **both** are high, it opens the main door — driving two relay outputs high (a piston door needs signal on two sides/pistons).
- If either puzzle gets reset (its signal drops back low, e.g. someone hits "New game"), the main door closes again automatically.
- Fully event-driven — it sits idle until a redstone signal actually changes, then reprints its status:

  ```
  GymLock

  Simon Says:  SOLVED
  Tic Tac Toe: locked

  Main door:   closed
  ```

## Requirements

- CC:Tweaked (Minecraft mod)
- A **Computer** (regular is fine — no color/touch/monitor needed)
- **4 Redstone Relays**, each connected to the computer with a Wired Modem + Networking Cable:
  - 2 as **inputs** — wired to the Simon Says and Tic Tac Toe computers' door-signal relays
  - 2 as **outputs** — wired to your piston door

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

DOOR_RELAY_NAME_1 = "redstone_relay_2",
DOOR_SIDE_1 = "front",
DOOR_RELAY_NAME_2 = "redstone_relay_3",
DOOR_SIDE_2 = "front",
```

If you're not sure what your relays are named, run `peripheral.getNames()` from the Lua prompt to list connected peripherals.

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
| `config.lua` | Your local settings (relay names/sides) — not touched by `update.lua` |
| `startup.lua` | Reads the puzzle signals, drives the main door, prints status |
| `install.lua` | First-time setup |
| `update.lua` | Re-downloads the code, keeps your `config.lua` |
| `update_full.lua` | Re-downloads everything, including `config.lua` |
| `uninstall.lua` | Removes the installed files |
