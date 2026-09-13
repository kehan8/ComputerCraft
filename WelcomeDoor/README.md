# WelcomeDoor (CC:Tweaked)

A welcome door for everyone (no whitelist, unlike [AdminDoor](../GymArena/AdminDoor)): a **Player Detector** at the door opens it and sends whoever just showed up a friendly "Welcome to `<building>`" toast. A 2nd Player Detector covering a box around the whole building notices when a welcomed player drops out of that box again -- however that happens (walked out, teleported away, disconnected) -- and sends them a goodbye toast.

![status](https://img.shields.io/badge/status-working-brightgreen)

## What it does

- Every `POLL_INTERVAL` seconds, scans the door Player Detector for players inside the `DOOR_MIN`/`DOOR_MAX` box (coordinates, from `locations.lua`).
- Anyone detected there who isn't already marked "inside" gets marked inside and a **welcome** toast (one line picked at random from `WELCOME_MESSAGES`, so it's not the exact same message every visit).
- The door opens for as long as anyone is inside that door box -- driven via this computer's own redstone side (`COMPUTER_ENABLED`), a Redstone Relay (`DOOR_RELAY_ENABLED`), or both at once.
- A 2nd Player Detector (`BUILDING_DETECTOR_NAME`) is scanned the same way, checking the `BUILDING_MIN`/`BUILDING_MAX` box covering the **entire building** including the door. Anyone marked "inside" who is no longer detected there gets a **goodbye** toast (random line from `BYE_MESSAGES`) and is immediately reset back to "outside" -- so a later visit triggers a fresh welcome instead of them staying silently stuck as "already inside" forever.
  - That reset happens even if the goodbye toast itself fails to send (e.g. the player already disconnected or got teleported away before it landed) -- nobody ever gets permanently stuck.
  - This is exactly what makes it safe to combine with something like a teleport-out spot at the end of your building: however someone leaves, they get reset and will be welcomed again next time.
  - Set `BUILDING_DETECTOR_ENABLED = false` to run with just the door detector -- no 2nd physical detector needed. The door detector then reads the `BUILDING_MIN`/`BUILDING_MAX` box itself instead. Make sure that box actually covers the whole building, or people still inside will get a false goodbye. A little overshoot past the building's walls is harmless (goodbye just fires a bit later than ideal, and welcome can't repeat until someone actually walks back through the door box).
- Because welcome only ever adds to the "inside" list and goodbye only ever removes from it, a name can never get a goodbye before its welcome. Unlike a "toggle on crossing a zone" approach, this also survives teleports: a player who gets `/tp`'d away and later `/tp`'d back is just re-checked against the current box contents each tick, never against "did they cross a line."
- A screen button toggles the whole system **ACTIVE / INACTIVE**. Switching to INACTIVE closes the door, stops welcome/goodbye toasts, and sends everyone currently "inside" a one-time "We are closed" toast. Switching back to ACTIVE just resumes quietly.
- Status (who's inside, last welcome/goodbye, active state) is shown as plain text on the computer's own screen -- no monitor needed.
- Broadcasts that same status over rednet so a [ControlRoom](../GymArena/ControlRoom) computer can show it remotely (read-only -- no controls for this device).

## Requirements

- CC:Tweaked (Minecraft mod)
- [Advanced Peripherals(CurseForge)](https://www.curseforge.com/minecraft/mc-mods/advanced-peripherals) / [Advanced Peripherals(Modrinth)](https://modrinth.com/mod/advancedperipherals) (for the Player Detectors and Chat Box)
- A **Computer** (regular is fine)
- A **Player Detector** peripheral for the door, either placed directly against the computer (uses a redstone side, e.g. `"left"`) or connected via a Wired Modem + Networking Cable (uses a network name, e.g. `"player_detector_0"`) -- both work the same way, see Configure below
- A 2nd **Player Detector** peripheral (optional but recommended), same rule, covering the whole building via `locations.lua`'s `BUILDING_MIN`/`BUILDING_MAX` box
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

This downloads `config.lua`, `locations.lua`, `startup.lua`, `update.lua`, `update_full.lua`, and `uninstall.lua`.

## Configure

### Peripheral names: side or network name, either works

`DETECTOR_NAME`, `BUILDING_DETECTOR_NAME`, `CHATBOX_NAME`, and `DOOR_RELAY_NAME` all get passed straight to `peripheral.wrap(...)`, and CC:Tweaked doesn't actually distinguish "a side" from "a network name" -- both are just strings it looks up in `peripheral.getNames()`. So you can either:

- Place the peripheral directly against the computer (no modem needed) and use the side it's touching, e.g. `DETECTOR_NAME = "left"`, or
- Connect it via a Wired Modem + Networking Cable and use its network name, e.g. `DETECTOR_NAME = "player_detector_0"`.

Not sure which to use? Run `peripheral.getNames()` from the Lua prompt (type `lua` at the shell) to see exactly what your computer currently sees, and copy the name it lists.

### Coordinates: `locations.lua`

Before running, open `locations.lua` and set the two boxes to match your build (find corners with the F3 debug screen):

```lua
-- Small box right at the door. Anyone inside it: door opens + welcome.
DOOR_MIN = { x = 0, y = 0, z = 0 },
DOOR_MAX = { x = 0, y = 0, z = 0 },

-- Box covering the whole building. Anyone who drops out of it gets a goodbye.
BUILDING_MIN = { x = 0, y = 0, z = 0 },
BUILDING_MAX = { x = 0, y = 0, z = 0 },
```

`getPlayersInCoords` still only sees players within the scanning peripheral's own max range -- a box corner further away than that range simply won't be detected. Keep both boxes within range of whichever detector reads them.

### Everything else: `config.lua`

```lua
BUILDING_NAME = "Your Building", -- used in the welcome/goodbye/closed messages

DETECTOR_NAME = "player_detector_0", -- door Player Detector, checks the DOOR_MIN/MAX box

BUILDING_DETECTOR_ENABLED = true,             -- false = door detector alone handles welcome+goodbye
BUILDING_DETECTOR_NAME = "player_detector_1", -- 2nd Player Detector, checks BUILDING_MIN/MAX

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

If you have more than one WelcomeDoor and want [ControlRoom](../GymArena/ControlRoom) to tell them apart, give each a label: `label set WelcomeDoor-Voordeur`.

> Updating from an older install? `update.lua` never touches `config.lua` or `locations.lua`, so new fields won't appear on their own -- run `update_full` (see below) or add the lines yourself.

**Known limitation:** if a player is teleported straight into the middle of the building (never walking through the door), they only get marked "inside" -- and thus only get a goodbye when they later leave -- once they happen to pass the door detector at some point. This is an edge case, not the main scenario.

**Known limitation (no 2nd detector):** with `BUILDING_DETECTOR_ENABLED = false`, the `BUILDING_MIN`/`BUILDING_MAX` box must actually cover the whole building. If it's too small (undershoot), players still inside but outside that box get a false goodbye. If it's a bit too big (overshoot past the walls), that's harmless -- goodbye just fires a little later than ideal.

## Run

```
startup
```

To pull the latest version later:

```
update
```

`update` re-downloads the code but **leaves `config.lua` and `locations.lua` alone**, so your detector/relay/message settings and coordinates survive. If you ever want those files themselves reset back to the repo defaults (e.g. one got corrupted, or a new version adds new settings), run:

```
update_full
```

## Uninstall

```
uninstall
```

Removes everything `install.lua` put on the computer (optionally including `config.lua` and `locations.lua`). Useful for a clean slate before reinstalling.

## Files

| File | Purpose |
|---|---|
| `config.lua` | Your local settings (building name, detector/relay/chat box names, welcome/goodbye/closed messages) -- not touched by `update.lua` |
| `locations.lua` | Your local coordinates (door box, building box) -- not touched by `update.lua` |
| `startup.lua` | Scans both Player Detectors, drives the door, shows status, sends the welcome/goodbye/closed toasts |
| `install.lua` | First-time setup |
| `update.lua` | Re-downloads the code, keeps your `config.lua`/`locations.lua` |
| `update_full.lua` | Re-downloads everything, including `config.lua`/`locations.lua` |
| `uninstall.lua` | Removes the installed files |
