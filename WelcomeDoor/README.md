# WelcomeDoor (CC:Tweaked)

A welcome door for everyone (no whitelist, unlike [AdminDoor](../AdminDoor)): a **Player Detector** watches one or more door boxes and opens whichever door someone just walked up to, sending them a friendly "Welcome to `<building>`" toast. The same detector also scans a box around the whole building and notices when a welcomed player drops out of it again -- however that happens (walked out, teleported away, disconnected) -- and sends them a goodbye toast.

![status](https://img.shields.io/badge/status-working-brightgreen)

## What it does

- Supports **any number of independent doors** (`locations.lua` `DOORS`), e.g. a front door and a back door, or two doors on opposite sides of one room. Each door has its own detection box and its own wiring (relay and/or this computer's own redstone side) -- only the door someone actually walks up to opens, the others stay shut.
- Every `POLL_INTERVAL` seconds, scans the Player Detector separately for each door's box. A door opens for as long as anyone is inside that door's own box, driven only by that door's own relay/redstone side.
- Anyone detected at **any** door who isn't already marked "inside" gets marked inside and a **welcome** toast (one line picked at random from `WELCOME_MESSAGES`, so it's not the exact same message every visit) -- which door they used doesn't matter for this.
- The same detector also scans the `BUILDING_MIN`/`BUILDING_MAX` box covering the **entire building** including every door. Anyone marked "inside" who is no longer detected there gets a **goodbye** toast (random line from `BYE_MESSAGES`) and is immediately reset back to "outside" -- so a later visit triggers a fresh welcome instead of them staying silently stuck as "already inside" forever.
  - That reset happens even if the goodbye toast itself fails to send (e.g. the player already disconnected or got teleported away before it landed) -- nobody ever gets permanently stuck.
  - This is exactly what makes it safe to combine with something like a teleport-out spot at the end of your building: however someone leaves, they get reset and will be welcomed again next time.
  - On startup, the script refuses to run if any door's box doesn't fit entirely inside `BUILDING_MIN`/`BUILDING_MAX` -- a door box sticking outside the building box would otherwise welcome and immediately goodbye the same player every tick (an instant spam loop). The error names the offending door.
- Because welcome only ever adds to the "inside" list and goodbye only ever removes from it, a name can never get a goodbye before its welcome. Unlike a "toggle on crossing a zone" approach, this also survives teleports: a player who gets `/tp`'d away and later `/tp`'d back is just re-checked against the current box contents each tick, never against "did they cross a line."
- A screen button toggles the whole system **ACTIVE / INACTIVE**. Switching to INACTIVE closes every door, stops welcome/goodbye toasts, and sends everyone currently "inside" a one-time "We are closed" toast. While INACTIVE, anyone new who shows up at any door also gets a "We are closed" toast (repeats once per visit, not every tick they stand there). Switching back to ACTIVE just resumes quietly.
- Status (who's inside, last welcome/goodbye, active state) is shown as plain text on the computer's own screen -- no monitor needed. This list stays building-wide (not split per door) since it's just "who's currently inside."
- Broadcasts a status line over rednet naming **which door(s) are currently open** (e.g. `"Open: Front Door, Back Door"`, or `"All doors closed"` / `"Closed"`) -- kept short on purpose so [ControlRoom](../ControlRoom) stays readable even with many people inside. Also accepts a remote toggle of the ACTIVE/INACTIVE button, so ControlRoom can show/toggle it without you walking over.
  - That remote toggle is listened for with `parallel.waitForAny`, not Basalt's own `basalt.schedule`. Basalt only resumes scheduled functions on the events it already pumps for its own UI loop, and `rednet_message` isn't one of them -- a `basalt.schedule`'d listener would just never wake up when ControlRoom sends the toggle. Running the UI and the rednet listener as two `parallel` branches instead means both get every event CC:Tweaked's own event loop delivers, including `rednet_message`.

## Requirements

- CC:Tweaked (Minecraft mod)
- [Advanced Peripherals(CurseForge)](https://www.curseforge.com/minecraft/mc-mods/advanced-peripherals) / [Advanced Peripherals(Modrinth)](https://modrinth.com/mod/advancedperipherals) (for the Player Detectors and Chat Box)
- A **Computer** (regular is fine)
- A **Player Detector** peripheral, either placed directly against the computer (uses a redstone side, e.g. `"left"`) or connected via a Wired Modem + Networking Cable (uses a network name, e.g. `"player_detector_0"`) -- both work the same way, see Configure below. It scans every door box plus the building box, so one is enough regardless of building size or door count.
- A **Chat Box** peripheral, connected the same way (sends the welcome/goodbye/closed toasts)
- For each door: a way to drive it -- this computer's own redstone side, and/or a **Redstone Relay** connected the same way. Different doors can use different wiring (e.g. front door on a relay, back door on the computer's own `"back"` side) -- set per door in `locations.lua`.
- A **wireless modem** attached, for reporting status to [ControlRoom](../ControlRoom)
- [Basalt2](https://github.com/Pyroxenium/Basalt2) for the UI -- installed automatically on first run

## Install

On a fresh CC:Tweaked computer:

```
wget https://raw.githubusercontent.com/kehan8/ComputerCraft/refs/heads/main/WelcomeDoor/install.lua install
install
```

This downloads `config.lua`, `locations.lua`, `startup.lua`, `rename.lua`, `update.lua`, `update_full.lua`, and `uninstall.lua`.

## Configure

### Peripheral names: side or network name, either works

`DETECTOR_NAME`, `CHATBOX_NAME`, and each door's `relay` all get passed straight to `peripheral.wrap(...)`, and CC:Tweaked doesn't actually distinguish "a side" from "a network name" -- both are just strings it looks up in `peripheral.getNames()`. So you can either:

- Place the peripheral directly against the computer (no modem needed) and use the side it's touching, e.g. `DETECTOR_NAME = "left"`, or
- Connect it via a Wired Modem + Networking Cable and use its network name, e.g. `DETECTOR_NAME = "player_detector_0"`.

Not sure which to use? Run `peripheral.getNames()` from the Lua prompt (type `lua` at the shell) to see exactly what your computer currently sees, and copy the name it lists.

### Doors + coordinates: `locations.lua`

Before running, open `locations.lua` and fill in `DOORS` -- one table per door, plus the shared building box (find corners with the F3 debug screen):

```lua
DOORS = {
    {
        name = "Front Door",                  -- shown in status / ControlRoom

        min = { x = 0, y = 0, z = 0 },         -- box at this door: anyone inside = door opens + welcome
        max = { x = 0, y = 0, z = 0 },

        relay = "redstone_relay_0",            -- Redstone Relay name, or nil to skip
        relay_side = "front",                  -- side of that relay driving this door

        computer_side = nil,                   -- this computer's own redstone side, or nil to skip
    },
    -- add as many more doors as you want, each its own { ... } table
},

-- Box covering the whole building (every door included). Leaving it triggers
-- goodbye. Every door box above must fit fully inside this one (checked on startup).
BUILDING_MIN = { x = 0, y = 0, z = 0 },
BUILDING_MAX = { x = 0, y = 0, z = 0 },
```

Each door needs at least one of `relay` / `computer_side` set (both is fine too) -- startup refuses to run and names the offending door if neither is set, or if `relay` is set without a matching `relay_side`.

Because the box, the relay, and the redstone side all live together in the *same* table per door, there's no separate parallel list that a door's wiring can silently fall out of sync with -- a copy-paste mistake shows up as a startup error naming the door, not as the wrong door opening.

Every door's relay is also wrapped as a peripheral immediately at startup (not lazily, the first time someone walks up to it). So a typo'd relay name fails loudly right when you run `startup`, instead of quietly doing nothing the first time a real visitor triggers that door and you're left wondering why it didn't open.

`getPlayersInCoords` still only sees players within the detector's own max range -- a box corner further away than that range simply won't be detected. Keep every door box and the building box within range of the detector.

### Everything else: `config.lua`

```lua
BUILDING_NAME = "Your Building", -- used in the welcome/goodbye/closed messages

DETECTOR_NAME = "player_detector_0", -- Player Detector, checks every door box + BUILDING_MIN/MAX

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

Per-door wiring (`relay` / `relay_side` / `computer_side`) lives in `locations.lua` next to each door's coordinates, not here -- see above.

Feel free to add/remove/edit entries in `WELCOME_MESSAGES` / `BYE_MESSAGES` -- any number of lines works, one is picked at random each time.

### Naming this device

`install` asks you to name this device the first time you run it -- press Enter or type `SKIP` to auto-generate a unique name from the computer's ID instead. If you have more than one WelcomeDoor, this is what lets [ControlRoom](../ControlRoom) tell them apart. Rename it later anytime, without reinstalling, with `rename`.

> Updating from an older install? `update.lua` never touches `config.lua` or `locations.lua`, so new fields won't appear on their own -- run `update_full` (see below) or add the lines yourself. **This is required if you're updating from a version before multi-door support**: the old single `DOOR_MIN`/`DOOR_MAX` fields were replaced by the `DOORS` list, and `startup.lua` refuses to run against a `locations.lua` that still has the old shape (fails fast with a clear error at startup, rather than silently ignoring your door). Run `update_full` and re-enter your coordinates in the new `DOORS` format.

**Known limitation:** if a player is teleported straight into the middle of the building (never walking through a door), they only get marked "inside" -- and thus only get a goodbye when they later leave -- once they happen to pass a door detector box at some point. This is an edge case, not the main scenario.

**Known limitation (building box accuracy):** `BUILDING_MIN`/`BUILDING_MAX` must actually cover the whole building. If it's too small (undershoot), players still inside but outside that box get a false goodbye. If it's a bit too big (overshoot past the walls), that's harmless -- goodbye just fires a little later than ideal. Any door box not fitting inside the building box is caught for you at startup (see above), naming the offending door; undershoot relative to your actual building walls is not, since the script has no way to know where your walls really are.

**Known limitation (thin boxes):** a box with only 1 block of thickness on an axis (e.g. `y` min `97`, max `98`) has been observed in testing to miss players unreliably. Give each axis at least 2-3 blocks of margin (e.g. min `96`, max `99`) so detection doesn't depend on a player's exact sub-block position.

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
| `config.lua` | Your local settings (building name, detector/chat box names, welcome/goodbye/closed messages) -- not touched by `update.lua` |
| `locations.lua` | Your local doors (box + wiring per door) and building box -- not touched by `update.lua` |
| `startup.lua` | Scans the Player Detector for every door box + the building box, drives each door independently, shows status, sends the welcome/goodbye/closed toasts |
| `install.lua` | First-time setup |
| `rename.lua` | Change this device's label later without reinstalling |
| `update.lua` | Re-downloads the code, keeps your `config.lua`/`locations.lua` |
| `update_full.lua` | Re-downloads everything, including `config.lua`/`locations.lua` |
| `uninstall.lua` | Removes the installed files |
