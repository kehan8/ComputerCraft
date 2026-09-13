# ControlRoom (CC:Tweaked)

The main overview computer for every other project in this repo: [AdminDoor](../AdminDoor), [GymLock](../GymArena/GymLock), [Tic Tac Toe](../GymArena/TicTacToe), [Simon Says](../GymArena/SimonSays), [WelcomeDoor](../WelcomeDoor), [FossilLab](../FossilLab) and [DaylightDetector](../DaylightDetector). Shows live status for all of them on one monitor, and lets you remotely reset Tic Tac Toe / Simon Says or toggle WelcomeDoor's ACTIVE/INACTIVE state, so you don't have to walk over and press the button yourself.

![status](https://img.shields.io/badge/status-working-brightgreen)

## What it does

- Listens on a wireless [rednet](https://tweaked.cc/module/rednet.html) modem for status broadcasts from every other computer in this repo (each of the other projects broadcasts its own status every few seconds once you've applied their ControlRoom update).
- A row appears **automatically** the first time a device broadcasts — nothing to register or configure per device, no IDs to keep in sync between computers. Devices keep their place in that list (and therefore their page/row) for as long as ControlRoom keeps running, whether they're online or offline.
- Each row is a small card: device name + an **ONLINE**/**OFFLINE** badge on the first line, and on the line below it, the exact same status text that device shows on its own screen (e.g. "Access granted: Steve", "Simon Says: SOLVED | ..."). A device that's gone quiet for `HEARTBEAT_TIMEOUT` seconds flips to OFFLINE, but keeps showing its last known status (dimmed) instead of disappearing.
- `ROWS_PER_PAGE` rows are pre-drawn (blank) at startup and get filled in as devices check in. Once more devices check in than fit on one page, a **"< Prev" / "Next >"** bar appears below the rows with a **"Page X/Y"** counter — click through to see the rest instead of needing a bigger monitor. Devices beyond `ROWS_PER_PAGE` just land on page 2, 3, ... in the order they first checked in.
- Tic Tac Toe and Simon Says rows get a **Reset** button — it tells that computer to run the exact same reset its own "New game"/"Start" button would (board/pattern cleared, door closed), just from here instead of walking over.
- WelcomeDoor's row gets an **ACTIVE**/**INACTIVE** button instead — same colors and text as its own on-screen button, and clicking it sends the exact same toggle, so you can open/close it remotely.
- AdminDoor, GymLock, FossilLab, and DaylightDetector are read-only here — no controls, matching how they work locally.

## Requirements

- CC:Tweaked (Minecraft mod)
- A **Computer** with a **wireless modem** attached
- An **Advanced Monitor** recommended (regular Monitor works too, just no touch needed since Reset is the only button) — optional; falls back to the computer's own screen if none is found
- [Basalt2](https://github.com/Pyroxenium/Basalt2) for the UI — installed automatically on first run
- Every device you want to see here (AdminDoor, GymLock, TicTacToe, SimonSays, WelcomeDoor, FossilLab, DaylightDetector) also needs its own **wireless modem** and the ControlRoom-aware version of its `startup.lua`/`config.lua` (i.e. update those projects too)

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
MODEM_ENABLED = true,  -- ControlRoom needs a modem; startup.lua errors if set to false

MONITOR_NAME = nil,    -- e.g. "monitor_0" to force a specific monitor; nil = auto-detect
MONITOR_SCALE = 0.5,   -- text scale on the monitor

HEARTBEAT_TIMEOUT = 8, -- seconds without a broadcast before a device shows "offline"
ROWS_PER_PAGE = 8,     -- how many device rows to pre-draw per page (raise/lower to fit your monitor)
MAX_DEVICES = 32,      -- safety cap on the TOTAL number of devices tracked, across all pages
```

If you're not sure what your modem/monitor is named, run `peripheral.getNames()` from the Lua prompt to list connected peripherals.

> Updating from an older install? `update.lua` never touches `config.lua`, so new fields (`MODEM_ENABLED`, and as of the pagination update, `ROWS_PER_PAGE`) won't appear on their own — run `update_full` (see below) or add the line(s) yourself. Older configs also have a `MAX_DEVICES` with the *old* meaning ("rows to pre-draw"); the new meaning is "total devices tracked across all pages" — `startup.lua` falls back to sane defaults if either field is missing, but running `update_full` once is the clean way to pick up the new field and meaning together.

### Sizing the monitor

Each device takes 2 lines (name/badge line + status line), plus one extra "< Prev / Page X/Y / Next >" line always drawn right below the last device row. If a device's status text gets cut off on a small monitor, that's a monitor-size problem, not a bug:

- **Status text cut off** (a row is too narrow) → make the monitor **wider**.
- **Rows (or the Prev/Next bar) running off the bottom** → make the monitor **taller**, or lower `ROWS_PER_PAGE` in `config.lua` so fewer rows are drawn per page — extra devices beyond `ROWS_PER_PAGE` are still reachable, just on page 2, 3, ... via the Prev/Next buttons instead of scrolling off-screen.

A 3x6 (width x height) Advanced Monitor at the default `MONITOR_SCALE` comfortably fits all seven devices from this repo (well under the default `ROWS_PER_PAGE = 8`) with room to spare, including the Prev/Next bar.

### More devices than fit on one page

Once more devices check in than `ROWS_PER_PAGE`, a "< Prev" / "Next >" bar with a "Page X/Y" counter appears below the rows automatically — no config needed for this part, it just shows up. Devices are assigned to pages in the order they first broadcast, and keep that same page/row for as long as ControlRoom keeps running (even while offline), so the layout doesn't shuffle around while you're looking at it. If you plan on ever having more than `MAX_DEVICES` devices in total (across all pages), raise that value in `config.lua` too — it's a safety cap on the internal tracking list, separate from `ROWS_PER_PAGE` (which only controls how many rows are visible per page).

### Telling devices apart

Each device reports the label CC:Tweaked gives it (`os.getComputerLabel()`). On every other project in this repo, `install` now asks you to name the device the first time you run it (press Enter or type `SKIP` to auto-generate a unique name from the computer's ID instead), so this is normally already handled by the time it shows up here. If you have two of the same puzzle (e.g. 2x AdminDoor) and want to rename one so you can tell the rows apart, run `rename` on that computer — no reinstalling needed.

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
| `startup.lua` | UI (Basalt2), rednet listener, Reset/toggle command sender |
| `install.lua` | First-time setup |
| `update.lua` | Re-downloads the code, keeps your `config.lua` |
| `update_full.lua` | Re-downloads everything, including `config.lua` |
| `uninstall.lua` | Removes the installed files |
