# AdminDoor (CC:Tweaked)

An admin-only door: a **Player Detector** peripheral scans for nearby players, and the door only opens for names on an admin whitelist. Anyone else gets a "NO ACCESS" popup on screen and the door stays shut.

![status](https://img.shields.io/badge/status-working-brightgreen)

## What it does

- Every `POLL_INTERVAL` seconds, scans for players within `DETECT_RANGE` blocks of the Player Detector.
- If any detected player is on the `ADMIN_NAMES` whitelist, opens the door (one relay output) and shows "Access granted: `<name>`".
- If a detected player is **not** on the whitelist, the door stays closed and a red "NO ACCESS" popup flashes on screen for `WARNING_TIME` seconds, showing the intruder's name.
- The popup only re-triggers when the unauthorized player actually changes — it won't keep re-flashing every poll while the same person just stands there.
- Status (who's nearby, door state) is shown as plain text on the computer's own screen — no monitor needed.

## Requirements

- CC:Tweaked (Minecraft mod)
- [Advanced Peripherals](https://www.curseforge.com/minecraft/mc-mods/advanced-peripherals) (for the Player Detector)
- A **Computer** (regular is fine)
- A **Player Detector** peripheral, connected to the computer with a Wired Modem + Networking Cable
- A **Redstone Relay**, connected the same way, wired to your door
- [Basalt2](https://github.com/Pyroxenium/Basalt2) for the UI — installed automatically on first run

## Install

On a fresh CC:Tweaked computer:

```
wget https://raw.githubusercontent.com/kehan8/ComputerCraft/refs/heads/main/AdminDoor/install.lua install
install
```

This downloads `config.lua`, `startup.lua`, `update.lua`, `update_full.lua`, and `uninstall.lua`.

## Configure

Before running, open `config.lua` and set the values to match your build:

```lua
DETECTOR_NAME = "player_detector_0", -- name of your Player Detector peripheral
DETECT_RANGE = 3,                    -- max range (blocks) the detector scans for nearby players

DOOR_RELAY_NAME = "redstone_relay_0", -- relay wired to the door
DOOR_SIDE = "front",                   -- side of that relay driving the door

ADMIN_NAMES = { "YourAdminName" },   -- whitelist of players allowed through

POLL_INTERVAL = 1, -- seconds between detector scans
WARNING_TIME = 2,  -- seconds the "NO ACCESS" popup stays on screen
```

If you're not sure what your peripherals are named, run `peripheral.getNames()` from the Lua prompt to list them.

## Run

```
startup
```

To pull the latest version later:

```
update
```

`update` re-downloads the code but **leaves `config.lua` alone**, so your relay/admin settings survive. If you ever want `config.lua` itself reset back to the repo defaults (e.g. it got corrupted, or a new version adds new settings), run:

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
| `config.lua` | Your local settings (detector/relay names, admin whitelist, timings) — not touched by `update.lua` |
| `startup.lua` | Scans for nearby players, drives the door, shows status + the "NO ACCESS" popup |
| `install.lua` | First-time setup |
| `update.lua` | Re-downloads the code, keeps your `config.lua` |
| `update_full.lua` | Re-downloads everything, including `config.lua` |
| `uninstall.lua` | Removes the installed files |
