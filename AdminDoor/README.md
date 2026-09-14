# AdminDoor (CC:Tweaked)

An admin-only door: a **Player Detector** peripheral watches one or more door boxes, and each door only opens for names on **that door's own** admin whitelist. Anyone else gets a real in-game "NO ACCESS" toast popup (via a **Chat Box** peripheral) and that door stays shut.

![status](https://img.shields.io/badge/status-working-brightgreen)

## What it does

- Supports **any number of independent doors** (`locations.lua` `DOORS`), e.g. a front door and a back door, or two doors on opposite sides of one room. Each door has its own detection box, its own wiring (relay and/or this computer's own redstone side), and its own admin whitelist -- someone allowed through the front door doesn't automatically get the back door too, and only the door they actually walk up to opens.
- Every `POLL_INTERVAL` seconds, scans the Player Detector separately for each door's box. If a detected player is on **that door's** whitelist, opens **only that door** (its own relay/redstone side) and shows "Access granted: `<name>`" on that door's line.
- If a detected player is **not** on that door's whitelist, that door stays closed and the player gets an in-game toast popup (title `TOAST_TITLE`, message `TOAST_MESSAGE`) sent straight to their screen via the Chat Box. The toast only re-sends when the unauthorized player *at that door* actually changes -- it won't spam the same person every poll while they stand there, and a denial at one door never affects the toast cooldown of another door.
- Set a door's `admin_names` to `nil` (or just leave the field out) to skip the whitelist for that door only: it opens for anyone detected there, no toast is ever sent. Other doors keep their own whitelists untouched -- this is a per-door setting, not a global one.
- Status (per-door: who's there, granted/denied) is shown as plain text on the computer's own screen, one line per door -- no monitor needed.
- Broadcasts a short status line over rednet naming **which door(s) granted or denied access** (e.g. `"Granted: Front Door | Denied: Back Door"`, or `"All doors closed"`) so a [ControlRoom](../ControlRoom) computer can show it remotely -- kept to door names on purpose, not a player list, so it stays readable regardless of how many people are around. This is **read-only** -- no remote controls for this device (unlike [WelcomeDoor](../WelcomeDoor)'s remote ACTIVE/INACTIVE toggle), since a shared "let anyone in" switch across several independent doors with different whitelists wouldn't map cleanly to any one action. Worth revisiting later as a per-door toggle if ControlRoom's UI grows to support it.

## Requirements

- CC:Tweaked (Minecraft mod)
- [Advanced Peripherals(CurseForge)](https://www.curseforge.com/minecraft/mc-mods/advanced-peripherals) / [Advanced Peripherals(Modrinth)](https://modrinth.com/mod/advancedperipherals) (for the Player Detector and Chat Box)
- A **Computer** (regular is fine)
- A **Player Detector** peripheral, either placed directly against the computer (uses a redstone side) or connected via a Wired Modem + Networking Cable (uses a network name) -- it scans every door box, so one is enough regardless of door count.
- A **Chat Box** peripheral, connected the same way (sends the "NO ACCESS" toast)
- For each door: a way to drive it -- this computer's own redstone side, and/or a **Redstone Relay** connected the same way. Different doors can use different wiring -- set per door in `locations.lua`.
- A **wireless modem** attached, for reporting status to [ControlRoom](../ControlRoom)
- [Basalt2](https://github.com/Pyroxenium/Basalt2) for the UI -- installed automatically on first run

## Install

On a fresh CC:Tweaked computer:

```
wget https://raw.githubusercontent.com/kehan8/ComputerCraft/refs/heads/main/AdminDoor/install.lua install
install
```

This downloads `config.lua`, `locations.lua`, `startup.lua`, `rename.lua`, `update.lua`, `update_full.lua`, and `uninstall.lua`. If `config.lua`/`locations.lua` already exist (e.g. reinstalling after `uninstall.lua` kept them), they're left untouched -- only the other files are refreshed.

## Configure

### Doors + coordinates + whitelist: `locations.lua`

Before running, open `locations.lua` and fill in `DOORS` -- one table per door (find corners with the F3 debug screen):

```lua
DOORS = {
    {
        name = "Front Door",                  -- shown in status / ControlRoom

        min = { x = 0, y = 0, z = 0 },         -- box at this door: admin inside = this door opens
        max = { x = 0, y = 0, z = 0 },

        relay = "redstone_relay_0",            -- Redstone Relay name, or nil to skip
        relay_side = "front",                  -- side of that relay driving this door

        computer_side = nil,                   -- this computer's own redstone side, or nil to skip

        admin_names = { "YourAdminName" },     -- whitelist for this door, or nil to skip the check
    },
    -- add as many more doors as you want, each its own { ... } table
},
```

Each door needs at least one of `relay` / `computer_side` set (both is fine too) -- startup refuses to run and names the offending door if neither is set, or if `relay` is set without a matching `relay_side`.

Because the box, the wiring, and the whitelist all live together in the *same* table per door, there's no separate parallel list that a door's admins can silently fall out of sync with -- a copy-paste mistake shows up as a startup error naming the door, not as the wrong door opening for the wrong people.

Every door's relay is also wrapped as a peripheral immediately at startup (not lazily, the first time someone walks up to it). So a typo'd relay name fails loudly right when you run `startup`, instead of quietly doing nothing the first time a real visitor triggers that door and you're left wondering why it didn't open.

**`admin_names`: `nil` vs. empty `{}` -- these are *not* the same.** `nil` (or just leaving the field out) disables the whitelist check for that door entirely: anyone detected there gets in, no toast is ever sent. An empty `{ }`, on the other hand, is a whitelist that's **active with zero names in it** -- that door locks out everyone, admin or not, since nobody matches an empty list. If you want to make a door temporarily public without losing your list, comment the line out (`-- admin_names = { "Name" }`) rather than emptying it -- that leaves the field `nil` (check disabled) while keeping your names ready to restore.

`getPlayersInCoords` still only sees players within the detector's own max range -- a box corner further away than that range simply won't be detected. Keep every door box within range of the detector.

> Known limitation: keep at least 2-3 blocks of margin on each axis. A box only 1 block thick on an axis can miss players standing right at the edge.

### Everything else: `config.lua`

```lua
DETECTOR_NAME = "player_detector_0", -- Player Detector, checks every door box from locations.lua

CHATBOX_NAME = "chat_box_0", -- name of your Chat Box peripheral

TOAST_TITLE = "NO ACCESS",
TOAST_MESSAGE = "You are not authorized to enter.",

POLL_INTERVAL = 1, -- seconds between detector scans

MODEM_NAME = "back", -- wireless modem used to report status to ControlRoom
MODEM_ENABLED = false, -- set true if you have a wireless modem attached
```

Per-door wiring (`relay` / `relay_side` / `computer_side`) and each door's `admin_names` whitelist live in `locations.lua` next to its coordinates, not here -- see above.

If you're not sure what your peripherals are named, run `peripheral.getNames()` from the Lua prompt to list them. The Chat Box shows up as `chat_box_N` on MC 1.21.1+ and `chatBox_N` on older versions.

### Naming this device

`install` asks you to name this device the first time you run it -- press Enter or type `SKIP` to auto-generate a unique name from the computer's ID instead. If you have more than one AdminDoor, this is what lets [ControlRoom](../ControlRoom) tell them apart. Rename it later anytime, without reinstalling, with `rename`.

> Updating from an older install? `update.lua` never touches `config.lua` or `locations.lua`, so new fields won't appear on their own -- run `update_full` (see below) or add the lines yourself. **This is required if you're updating from a version before multi-door support**: the old shared `BOXES` list plus global `ADMIN_NAMES`/`ADMIN_ENABLED`/`DOOR_RELAY_NAME`/`DOOR_SIDE` fields were replaced by the per-door `DOORS` list (box + wiring + whitelist together), and `startup.lua` refuses to run against a `locations.lua` that still has the old shape (fails fast with a clear error at startup, rather than silently ignoring your doors or admins). Run `update_full` and re-enter your coordinates/wiring/whitelist in the new `DOORS` format.

## Run

```
startup
```

To pull the latest version later:

```
update
```

`update` re-downloads the code but **leaves `config.lua` and `locations.lua` alone**, so your detector/whitelist/door settings survive. If you ever want those files themselves reset back to the repo defaults (e.g. one got corrupted, or a new version adds new settings), run:

```
update_full
```

## Uninstall

```
uninstall
```

Removes everything `install.lua` put on the computer (optionally including `config.lua`/`locations.lua`). Useful for a clean slate before reinstalling.

## Files

| File | Purpose |
|---|---|
| `config.lua` | Your local settings (detector/chat box names, toast text) -- not touched by `update.lua` |
| `locations.lua` | Your local doors (box + wiring + admin whitelist per door) -- not touched by `update.lua` |
| `startup.lua` | Scans the Player Detector for every door box, drives each door independently, shows status, sends the "NO ACCESS" toast |
| `install.lua` | First-time setup |
| `rename.lua` | Change this device's label later without reinstalling |
| `update.lua` | Re-downloads the code, keeps your `config.lua`/`locations.lua` |
| `update_full.lua` | Re-downloads everything, including `config.lua`/`locations.lua` |
| `uninstall.lua` | Removes the installed files |
