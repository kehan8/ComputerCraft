# FossilLab (CC:Tweaked)

A live status monitor for Cobblemon's **Fossil Analyzer** / **Restoration Tank** multiblock, built with the [Basalt2](https://basalt.madefor.cc/) UI library. Shows what phase the machine is in, live progress %, time remaining, and a running log of recent restorations — all read straight off the block's own data, no coordinates or OP access needed.

![status](https://img.shields.io/badge/status-working-brightgreen)

## What it does

- Reads the Fossil Analyzer / Restoration Tank's state through an **Advanced Peripherals Block Reader** placed directly against it. The multiblock has no redstone/comparator output at all (confirmed dead end — see `test_redstone.lua`) and no useful entity to scan either (`test_entities.lua`); it's purely NBT-driven, which the Block Reader can read without any coordinates or Command Computer.
- Shows a color-coded phase badge: **IDLE** (gray), **ANALYZING...** (orange), **READY -- CLAIM ME!** (blinking green, once a Pokemon has been created and is waiting to be claimed), or **MULTIBLOCK NOT FORMED** (red, if the structure isn't fully built right now).
- A live progress bar + percentage, driven by the block's `OrganicContent` value (0-128 scale).
- A countdown while analyzing (`TimeLeft`), and a separate countdown once a Pokemon is ready (`ProtectedTimeLeft` — the claim window).
- Keeps its own log of completed restorations (species + time) in `fossil_history.txt`, since the block itself forgets which species it made the moment you claim it.
- Broadcasts its status over rednet so a [ControlRoom](../GymArena/ControlRoom) computer can show it alongside the other gym devices. There's nothing to reset here (no game state, just a live readout), so it doesn't get a Reset button on ControlRoom.

## Requirements

- CC:Tweaked (Minecraft mod)
- Cobblemon, with a fully built Fossil Analyzer + Restoration Tank
- **Advanced Peripherals** — specifically a **Block Reader**, placed directly against the Fossil Analyzer (or the Restoration Tank — they share the same underlying data, so one Block Reader on either block is enough). Mind the Block Reader's arrow: it only reads the block its front face points at, not whatever it's mounted on.
- A computer (a plain Computer is enough — nothing on screen is clickable)
- A **Monitor** for the public display — a plain Monitor is fine, no touch support needed
- A **wireless modem**, only if you want it reporting to [ControlRoom](../GymArena/ControlRoom)
- [Basalt2](https://github.com/Pyroxenium/Basalt2) — installed automatically on first run if it's missing

## Install

On a fresh CC:Tweaked computer:

```
wget https://raw.githubusercontent.com/kehan8/ComputerCraft/refs/heads/main/FossilLab/install.lua install
install
```

This downloads `config.lua`, `startup.lua`, `fossildata.lua`, `fossilhistory.lua`, `update.lua`, `update_full.lua`, `uninstall.lua`, and installs Basalt2 if it isn't already present.

## Configure

Before running, open `config.lua` and set the values to match your build:

```lua
BLOCKREADER_NAME = nil,   -- e.g. "block_reader_0" to force a specific one; nil = auto-detect
POLL_INTERVAL = 1,        -- seconds between reads of the Block Reader / UI refreshes

MONITOR_NAME = nil,       -- e.g. "monitor_0" to force a specific monitor; nil = auto-detect
MONITOR_SCALE = 0.5,      -- text scale on the monitor

HISTORY_MAX_ENTRIES = 20, -- how many past restorations fossil_history.txt remembers

MODEM_NAME = "back",      -- wireless modem used to talk to ControlRoom
MODEM_ENABLED = false,    -- set true if you have a wireless modem attached
HEARTBEAT_INTERVAL = 2,   -- seconds between status broadcasts to ControlRoom
```

If you're not sure what your Block Reader/monitor is named, run `peripheral.getNames()` from the Lua prompt to list connected peripherals.

> Updating from an older install? `update.lua` never touches `config.lua`, so new fields won't appear on their own — run `update_full` (see below) or add the lines yourself.

## Run

```
startup
```

To pull the latest version later:

```
update
```

`update` re-downloads the code but **leaves `config.lua` alone**, so your monitor/Block Reader settings survive. If you ever want `config.lua` itself reset back to the repo defaults (e.g. it got corrupted, or a new version adds new settings), run:

```
update_full
```

## Uninstall

```
uninstall
```

Removes everything `install.lua` put on the computer (optionally including `config.lua`, `fossil_history.txt`, and Basalt). Useful for a clean slate before reinstalling.

## Files

| File | Purpose |
|---|---|
| `config.lua` | Your local settings (Block Reader, monitor, modem) — not touched by `update.lua` |
| `startup.lua` | UI (Basalt2), polling loop, ControlRoom heartbeat |
| `fossildata.lua` | Reads the Block Reader and turns the raw NBT into a clean state (phase/percent/time left) |
| `fossilhistory.lua` | Persists the "recent finds" log to `fossil_history.txt` across reboots |
| `install.lua` | First-time setup |
| `update.lua` | Re-downloads the code, keeps your `config.lua` |
| `update_full.lua` | Re-downloads everything, including `config.lua` |
| `uninstall.lua` | Removes the installed files |
| `test_blockreader.lua` | Debug script used to confirm the Block Reader approach against live NBT — not needed for normal use |
| `test_redstone.lua`, `test_entities.lua`, `test_datacommand.lua`, `test.lua` | Earlier, dead-end debug scripts (redstone/entity/command-block approaches) kept for reference — not needed for normal use |
