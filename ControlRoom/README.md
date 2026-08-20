# ControlRoom (CC:Tweaked)

The main overview computer for [AdminDoor](../AdminDoor), [GymLock](../GymLock), [Tic Tac Toe](../TicTacToe) and [Simon Says](../SimonSays): shows live status for all of them on one monitor, and lets you remotely reset Tic Tac Toe / Simon Says so you don't have to walk over and press "New game"/"Start" yourself.

![status](https://img.shields.io/badge/status-working-brightgreen)

## What it does

- Listens on a wireless [rednet](https://tweaked.cc/module/rednet.html) modem for status broadcasts from every other computer in this repo (each of the other four projects broadcasts its own status every few seconds once you've applied their ControlRoom update).
- A row appears **automatically** the first time a device broadcasts — nothing to register or configure per device, no IDs to keep in sync between computers. Up to `MAX_DEVICES` rows are pre-drawn (blank) at startup and get claimed as devices check in.
- Each row is a small card: device name + an **ONLINE**/**OFFLINE** badge on the first line, and on the line below it, the exact same status text that device shows on its own screen (e.g. "Access granted: Steve", "Simon Says: SOLVED | ..."). A device that's gone quiet for `HEARTBEAT_TIMEOUT` seconds flips to OFFLINE, but keeps showing its last known status (dimmed) instead of disappearing.
- Tic Tac Toe and Simon Says rows get a **Reset** button — it tells that computer to run the exact same reset its own "New game"/"Start" button would (board/pattern cleared, door closed), just from here instead of walking over.
- AdminDoor and GymLock are read-only here — no controls, matching how they work locally.

## Requirements

- CC:Tweaked (Minecraft mod)
- A **Computer** with a **wireless modem** attached
- An **Advanced Monitor** recommended (regular Monitor works too, just no touch needed since Reset is the only button) — optional; falls back to the computer's own screen if none is found
- [Basalt2](https://github.com/Pyroxenium/Basalt2) for the UI — installed automatically on first run
- Every device you want to see here (AdminDoor x2, GymLock, TicTacToe, SimonSays) also needs its own **wireless modem** and the ControlRoom-aware version of its `startup.lua`/`config.lua` (i.e. update those projects too)

## Install

On a fresh CC:Tweaked computer:

```
wget https://raw.githubusercontent.com/kehan8/ComputerCraft/refs/heads/main/ControlRoom/install.lua install
install
```

This downloads `config.lua`, `startup.lua`, `update.lua`, `update_full.lua`, and `uninstall.lua`, and installs Basalt2 if it isn't already present.

## Configure

Before running, open `config.lua` and set the values to match your build:

```lua
MODEM_NAME = "back",   -- wireless modem used to talk to the other computers

MONITOR_NAME = nil,    -- e.g. "monitor_0" to force a specific monitor; nil = auto-detect
MONITOR_SCALE = 0.5,   -- text scale on the monitor

HEARTBEAT_TIMEOUT = 8, -- seconds without a broadcast before a device shows "offline"
MAX_DEVICES = 8,       -- how many device rows to pre-draw (raise if you add more devices)
```

If you're not sure what your modem/monitor is named, run `peripheral.getNames()` from the Lua prompt to list connected peripherals.

### Sizing the monitor

Each device takes 2 lines (name/badge line + status line). If a device's status text gets cut off on a small monitor, that's a monitor-size problem, not a bug:

- **Status text cut off** (a row is too narrow) → make the monitor **wider**.
- **Rows running off the bottom** (you have several devices) → make the monitor **taller**.

A 3x6 (width x height) Advanced Monitor at the default `MONITOR_SCALE` comfortably fits all five devices from this repo with room to spare.

### Telling devices apart

Each device reports the label CC:Tweaked gives it (`os.getComputerLabel()`). If you have two of the same puzzle (e.g. 2x AdminDoor), rename one so you can tell the rows apart — on that computer, run:

```
label set AdminDoor-Achterdeur
```

## Run

```
startup
```

To pull the latest version later:

```
update
```

`update` re-downloads the code but **leaves `config.lua` alone**, so your modem/monitor settings survive. If you ever want `config.lua` itself reset back to the repo defaults (e.g. it got corrupted, or a new version adds new settings), run:

```
update_full
```

## Uninstall

```
uninstall
```

Removes everything `install.lua` put on the computer (optionally including `config.lua` and Basalt). Useful for a clean slate before reinstalling.

## Files

| File | Purpose |
|---|---|
| `config.lua` | Your local settings (modem, monitor, offline timeout) — not touched by `update.lua` |
| `startup.lua` | UI (Basalt2), rednet listener, Reset command sender |
| `install.lua` | First-time setup |
| `update.lua` | Re-downloads the code, keeps your `config.lua` |
| `update_full.lua` | Re-downloads everything, including `config.lua` |
| `uninstall.lua` | Removes the installed files |
