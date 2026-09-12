# WelcomeDoor (CC:Tweaked)

A welcome door for everyone (no whitelist, unlike [AdminDoor](../GymArena/AdminDoor)): a **Player Detector** at the door opens it and sends whoever just showed up a friendly "Welcome to `<building>`" toast. A 2nd, much wider-range **Player Detector** covering the whole building notices when a welcomed player drops out of range again -- however that happens (walked out, teleported away, disconnected) -- and sends them a goodbye toast.

![status](https://img.shields.io/badge/status-working-brightgreen)

## What it does

- Every `POLL_INTERVAL` seconds, scans the door Player Detector (`DETECT_RANGE` blocks).
- Anyone detected there who isn't already marked "inside" gets marked inside and a **welcome** toast (one line picked at random from `WELCOME_MESSAGES`, so it's not the exact same message every visit).
- The door opens for as long as anyone is within `DETECT_RANGE` of the door -- driven via this computer's own redstone side (`COMPUTER_ENABLED`), a Redstone Relay (`DOOR_RELAY_ENABLED`), or both at once.
- A 2nd Player Detector (`BUILDING_DETECTOR_NAME`, range `BUILDING_DETECT_RANGE`) is scanned the same way, covering the **entire building** including the door. Anyone marked "inside" who is no longer detected there gets a **goodbye** toast (random line from `BYE_MESSAGES`) and is immediately reset back to "outside" -- so a later visit triggers a fresh welcome instead of them staying silently stuck as "already inside" forever.
  - That reset happens even if the goodbye toast itself fails to send (e.g. the player already disconnected or got teleported away before it landed) -- nobody ever gets permanently stuck.
  - This is exactly what makes it safe to combine with something like a teleport-out spot at the end of your building: however someone leaves, they get reset and will be welcomed again next time.
  - Set `BUILDING_DETECTOR_ENABLED = false` to run with just the door detector for both welcome and goodbye -- simpler (no 2nd detector to place) but less accurate, since walking further into the building past the door's small range can look like "left".
- Because welcome only ever adds to the "inside" list and goodbye only ever removes from it, a name can never get a goodbye before its welcome.
- A screen button toggles the whole system **ACTIVE / INACTIVE**. Switching to INACTIVE closes the door, stops welcome/goodbye toasts, and sends everyone currently "inside" a one-time "We are closed" toast. Switching back to ACTIVE just resumes quietly.
- Status (who's inside, last welcome/goodbye, active state) is shown as plain text on the computer's own screen -- no monitor needed.
- Broadcasts that same status over rednet so a [ControlRoom](../GymArena/ControlRoom) computer can show it remotely (read-only -- no controls for this device).

## Requirements

- CC:Tweaked (Minecraft mod)
- [Advanced Peripherals(CurseForge)](https://www.curseforge.com/minecraft/mc-mods/advanced-peripherals) / [Advanced Peripherals(Modrinth)](https://modrinth.com/mod/advancedperipherals) (for the Player Detectors and Chat Box)
- A **Computer** (regular is fine)
- A **Player Detector** peripheral placed right at the door, connected with a Wired Modem + Networking Cable
- A 2nd **Player Detector** peripheral (optional but recommended) with a range covering the whole building, connected the same way
- A **Chat Box** peripheral, connected the same way (sends the welcome/goodbye/closed toasts)
- A way to drive the door: this computer's own redstone side, and/or a **Redstone Relay** connected the same way -- enable whichever (or both) in `config.lua`
- A **wireless modem** attached, for reporting status to [ControlRoom](../GymArena/ControlRoom)
- [Basalt2](https://github.com/Pyroxenium/Basalt2) for the UI -- installed automatically on first run

## Install

On a fresh CC:Tweaked computer:

```
wget https://raw.githubusercontent.com/kehan8/ComputerCraft/refs/heads/main/WelcomeDoor/install.lua install
install
```

This downloads `config.lua`, `startup.lua`, `update.lua`, `update_full.lua`, and `uninstall.lua`.

## Configure

Before running, open `config.lua` and set the values to match your build:

```lua
BUILDING_NAME = "Your Building", -- used in the welcome/goodbye/closed messages

DETECTOR_NAME = "player_detector_0", -- door Player Detector, small range
DETECT_RANGE = 3,

BUILDING_DETECTOR_ENABLED = true,           -- false = door detector alone handles welcome+goodbye
BUILDING_DETECTOR_NAME = "player_detector_1", -- 2nd Player Detector, must cover the whole building
BUILDING_DETECT_RANGE = 100,

COMPUTER_SIDE = "back",  -- this computer's own redstone side driving the door
COMPUTER_ENABLED = false,

DOOR_RELAY_NAME = "redstone_relay_0", -- relay wired to the door
DOOR_SIDE = "front",                   -- side of that relay driving the door
DOOR_RELAY_ENABLED = true, -- enable at least one of COMPUTER_ENABLED / DOOR_RELAY_ENABLED

CHATBOX_NAME = "chat_box_0", -- name of your Chat Box peripheral

WELCOME_TITLE = "Welcome!",
WELCOME_MESSAGES = { "Welcome to %s!", ... }, -- %s = BUILDING_NAME, one picked at random

BYE_TITLE = "Goodbye!",
BYE_MESSAGES = { "Thanks for visiting %s, see you soon!", ... },

CLOSED_TITLE = "Closed",
CLOSED_MESSAGE = "We are closed.", -- sent when the on-screen button is set to INACTIVE

POLL_INTERVAL = 1, -- seconds between detector scans

MODEM_NAME = "back", -- wireless modem used to report status to ControlRoom
MODEM_ENABLED = false, -- set true if you have a wireless modem attached
```

Feel free to add/remove/edit entries in `WELCOME_MESSAGES` / `BYE_MESSAGES` -- any number of lines works, one is picked at random each time.

If you're not sure what your peripherals are named, run `peripheral.getNames()` from the Lua prompt to list them. The Chat Box shows up as `chat_box_N` on MC 1.21.1+ and `chatBox_N` on older versions; the Player Detector as `player_detector_N`.

If you have more than one WelcomeDoor and want [ControlRoom](../GymArena/ControlRoom) to tell them apart, give each a label: `label set WelcomeDoor-Voordeur`.

> Updating from an older install? `update.lua` never touches `config.lua`, so new fields (like `BUILDING_DETECTOR_ENABLED`) won't appear on their own -- run `update_full` (see below) or add the lines yourself.

**Known limitation:** if a player is teleported straight into the middle of the building (never walking through the door), they only get marked "inside" -- and thus only get a goodbye when they later leave -- once they happen to pass the door detector at some point. This is an edge case, not the main scenario.

## Run

```
startup
```

To pull the latest version later:

```
update
```

`update` re-downloads the code but **leaves `config.lua` alone**, so your detector/relay/message settings survive. If you ever want `config.lua` itself reset back to the repo defaults (e.g. it got corrupted, or a new version adds new settings), run:

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
| `config.lua` | Your local settings (building name, detector/relay/chat box names, welcome/goodbye/closed messages) -- not touched by `update.lua` |
| `startup.lua` | Scans both Player Detectors, drives the door, shows status, sends the welcome/goodbye/closed toasts |
| `install.lua` | First-time setup |
| `update.lua` | Re-downloads the code, keeps your `config.lua` |
| `update_full.lua` | Re-downloads everything, including `config.lua` |
| `uninstall.lua` | Removes the installed files |
