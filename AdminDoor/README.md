# AdminDoor (CC:Tweaked)

An admin-only door: a **Player Detector** peripheral scans for nearby players, and the door only opens for names on an admin whitelist. Anyone else gets a real in-game "NO ACCESS" toast popup (via a **Chat Box** peripheral) and the door stays shut.

![status](https://img.shields.io/badge/status-working-brightgreen)

## What it does

- Every `POLL_INTERVAL` seconds, scans for players within `DETECT_RANGE` blocks of the Player Detector.
- If any detected player is on the `ADMIN_NAMES` whitelist, opens the door (one relay output) and shows "Access granted: `<name>`".
- If a detected player is **not** on the whitelist, the door stays closed and that player gets an in-game toast popup (title `TOAST_TITLE`, message `TOAST_MESSAGE`) sent straight to their screen via the Chat Box.
- The toast only re-sends when the unauthorized player actually changes — it won't spam the same person with a toast every single poll while they just stand there.
- Status (who's nearby, door state) is shown as plain text on the computer's own screen — no monitor needed.
- Broadcasts that same status over rednet so a [ControlRoom](../ControlRoom) computer can show it remotely (read-only — no controls for this device).

## Requirements

- CC:Tweaked (Minecraft mod)
- [Advanced Peripherals](https://www.curseforge.com/minecraft/mc-mods/advanced-peripherals) (for the Player Detector and Chat Box)
- A **Computer** (regular is fine)
- A **Player Detector** peripheral, connected to the computer with a Wired Modem + Networking Cable
- A **Chat Box** peripheral, connected the same way (sends the "NO ACCESS" toast)
- A **Redstone Relay**, connected the same way, wired to your door
- A **wireless modem** attached, for reporting status to [ControlRoom](../ControlRoom)
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

CHATBOX_NAME = "chat_box_0",  -- name of your Chat Box peripheral
TOAST_TITLE = "NO ACCESS",
TOAST_MESSAGE = "You are not authorized to enter.",

MODEM_NAME = "back", -- wireless modem used to report status to ControlRoom
```

If you're not sure what your peripherals are named, run `peripheral.getNames()` from the Lua prompt to list them. The Chat Box shows up as `chat_box_N` on MC 1.21.1+ and `chatBox_N` on older versions.

If you have more than one AdminDoor and want [ControlRoom](../ControlRoom) to tell them apart, give each a label: `label set AdminDoor-Achterdeur`.

> Updating from an older install? `update.lua` never touches `config.lua`, so the new `MODEM_NAME` field won't appear on its own — run `update_full` (see below) or add the line yourself.

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
| `config.lua` | Your local settings (detector/relay/chat box names, admin whitelist, toast text) — not touched by `update.lua` |
| `startup.lua` | Scans for nearby players, drives the door, shows status, sends the "NO ACCESS" toast |
| `install.lua` | First-time setup |
| `update.lua` | Re-downloads the code, keeps your `config.lua` |
| `update_full.lua` | Re-downloads everything, including `config.lua` |
| `uninstall.lua` | Removes the installed files |
