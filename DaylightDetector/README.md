# DaylightDetector (CC:Tweaked)

Tracks the in-game clock and flips a redstone signal at dusk/dawn -- no physical Daylight Detector block needed, just `os.time("ingame")` read straight off the computer.

![status](https://img.shields.io/badge/status-working-brightgreen)

## What it does

- Every `POLL_INTERVAL` seconds, reads the in-game clock and checks dusk (`DUSK_HOUR`:`DUSK_MINUTE`) to dawn (`DAWN_HOUR`:`DAWN_MINUTE`), wrapping past midnight. In-game clock, not IRL time (~20 min/day).
- Drives the signal three ways, each a **list** in `config.lua` so you can wire up as many of each as you need (at least one list must have an entry):
  - **`COMPUTER_SIDES`** -- this computer's own redstone side(s), e.g. `{ "back", "left" }`.
  - **`RELAYS`** -- through one or more Redstone Relay peripherals, for a Wired Modem setup. Each entry is a self-contained `{ name, side }` pair, so name/side can never get mismatched when you add more relays.
  - **`GEARSHIFTS`** -- through one or more Create **Sequenced Gearshifts**, each attached directly to a side (not a network name), rotating a switch (e.g. HV Switch, ~100A) for when redstone's ~16A cap is too low. Each entry is a self-contained `{ side, angle, speed }` table -- angle/speed live per-gearshift since different contraptions may need different rotation amounts. All gearshifts rotate together on dusk, back together on dawn, only on an actual transition.
- Live in-game clock (`HH:MM`) on screen, one fixed line, no scrolling spam. Runs on its own loop, so it never freezes even mid gearshift-rotation.
- Status line (ON/off + day/night) under the clock.
- **AUTO** + **ON/OFF** buttons: AUTO lets the timer decide (default). The ON/OFF button always shows the live signal value and toggles it -- click it to force that value and switch to manual; click AUTO to hand control back to the timer. Rapid clicks are ignored (short cooldown) so the gearshift never gets two rotate commands at once.
- Broadcasts status over rednet to [ControlRoom](../ControlRoom) if `MODEM_ENABLED`.

## Requirements

- CC:Tweaked (Minecraft mod)
- A **Computer** (regular is fine)
- Optionally, one or more **Redstone Relay** peripherals on a Wired Modem network (only if `RELAYS` has entries)
- Optionally, one or more **Create Sequenced Gearshifts** attached directly to computer sides, driving high-amperage switches (only if `GEARSHIFTS` has entries)
- Optionally, a **wireless modem**, for reporting status to [ControlRoom](../ControlRoom) (only if `MODEM_ENABLED`)
- [Basalt2](https://github.com/Pyroxenium/Basalt2) for the UI -- installed automatically on first run

## Install

On a fresh CC:Tweaked computer:

```
wget https://raw.githubusercontent.com/kehan8/ComputerCraft/refs/heads/main/DaylightDetector/install.lua install
install
```

This downloads `config.lua`, `startup.lua`, `rename.lua`, `update.lua`, `update_full.lua`, and `uninstall.lua`. If `config.lua` already exists (e.g. reinstalling after `uninstall.lua` kept it), it's left untouched -- only the other files are refreshed.

## Configure

Before running, open `config.lua` and set the values to match your build:

```lua
-- This computer's own redstone output side(s). Empty list = none.
COMPUTER_SIDES = { "back" },

-- Redstone Relay peripherals (Wired Modem setups). Each relay is its own
-- self-contained {name, side} pair, so name/side can never get mismatched
-- when you add more. Empty list = none.
RELAYS = {
    { name = "redstone_relay_0", side = "front" },
    -- { name = "redstone_relay_1", side = "back" },  -- add as many as you need
},

-- Rotates Create Sequenced Gearshifts instead, e.g. to flip a high-amperage
-- HV Switch that plain redstone can't drive (typically capped around 16A).
-- angle/speed live per-gearshift since different contraptions may need
-- different rotation amounts. Empty list = none.
GEARSHIFTS = {
    { side = "back", angle = 180, speed = 1 },  -- tested: angle 180, speed 1
    -- { side = "top", angle = 90, speed = -1 }, -- add as many as you need
},

MODEM_NAME = "back",  -- wireless modem used to report status to ControlRoom
MODEM_ENABLED = false,

-- Dusk/dawn is Minecraft's own in-game clock, NOT your real/IRL time -- a full
-- in-game day/night cycle only takes ~20 real-life minutes. Format is normal
-- HH:MM (minutes 0-59), no decimals to misread.
DUSK_HOUR = 18,   -- signal turns on at/after this time (evening)
DUSK_MINUTE = 32,
DAWN_HOUR = 5,    -- signal turns off once time reaches this (morning)
DAWN_MINUTE = 27,

POLL_INTERVAL = 1, -- seconds between clock/signal updates
```

If you're not sure what your peripherals are named, run `peripheral.getNames()` from the Lua prompt to list them.

An empty list (`{}`) for `COMPUTER_SIDES`, `RELAYS` or `GEARSHIFTS` means that output method is off -- no separate `_ENABLED` flag anymore, since a list can't desync from a boolean the way parallel settings could. At least one of the three lists needs an entry, or `startup` refuses to run. Each relay/gearshift is wrapped as soon as `startup` runs, so a typo'd name or side fails immediately with an error naming exactly which entry (e.g. `RELAYS[2]`) is wrong, instead of crashing later mid-signal-flip.

**Reversing rotation direction:** the Sequenced Gearshift automatically reverses between "open" (dusk) and "close" (dawn) -- both are derived from the same `speed` number (`+speed` / `-speed`). If a gearshift spins the wrong way for your contraption, just flip the sign of its `speed` in `config.lua` (e.g. `1` -> `-1`); you never need to touch the Motor's own rotation direction in Create, the Sequenced Gearshift compensates for it entirely. With multiple gearshifts, each entry has its own `speed`, so you can flip just one -- e.g. two gearshifts that need to rotate as mirror images of each other.

### Naming this device

`install` asks you to name this device the first time you run it -- press Enter or type `SKIP` to auto-generate a unique name from the computer's ID instead. This is the name ControlRoom shows for it, handy if you ever run more than one. Rename it later anytime, without reinstalling, with `rename`.

> Updating from an older install? `update.lua` never touches `config.lua`, so any new fields won't appear on their own -- run `update_full` (see below) or add the lines yourself.
>
> **Breaking change:** older installs used single-value `COMPUTER_SIDE`/`COMPUTER_ENABLED`, `REDSTONE_RELAY_NAME`/`REDSTONE_SIDE`/`REDSTONE_RELAY_ENABLED` and `GEARSHIFT_SIDE`/`GEARSHIFT_ENABLED`/`GEARSHIFT_ANGLE`/`GEARSHIFT_SPEED` fields. These are now `COMPUTER_SIDES`, `RELAYS` and `GEARSHIFTS` lists (see above), so each output type supports any number of sides/relays/gearshifts. Run `update_full` to pick up the new `config.lua` shape, then re-enter your settings into the new list format.

## Run

```
startup
```

To pull the latest version later:

```
update
```

`update` re-downloads the code but **leaves `config.lua` alone**, so your relay/timing settings survive. If you ever want `config.lua` itself reset back to the repo defaults (e.g. it got corrupted, or a new version adds new settings), run:

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
| `config.lua` | Your local settings (signal sources, relay/gearshift side, modem, dusk/dawn times) -- not touched by `update.lua` |
| `startup.lua` | Reads the in-game clock, drives the redstone signal, shows the clock/status on screen |
| `install.lua` | First-time setup |
| `rename.lua` | Change this device's label later without reinstalling |
| `update.lua` | Re-downloads the code, keeps your `config.lua` |
| `update_full.lua` | Re-downloads everything, including `config.lua` |
| `uninstall.lua` | Removes the installed files |
