# DaylightDetector (CC:Tweaked)

Tracks the in-game clock and flips a redstone signal at dusk/dawn -- no physical Daylight Detector block needed, just `os.time("ingame")` read straight off the computer.

![status](https://img.shields.io/badge/status-working-brightgreen)

## What it does

- Every `POLL_INTERVAL` seconds, reads the in-game clock and checks whether it's between dusk (`DUSK_HOUR`:`DUSK_MINUTE`) and dawn (`DAWN_HOUR`:`DAWN_MINUTE`), wrapping past midnight. Note this is Minecraft's own daylight-cycle clock, not your real/IRL time -- a full in-game day only takes ~20 real-life minutes.
- Drives the signal three ways, toggled independently in `config.lua` (at least one must be enabled):
  - **`COMPUTER_ENABLED`** -- straight off this computer's own redstone side (`COMPUTER_SIDE`). No peripheral needed, but only works if the computer is physically wired to what you want to drive.
  - **`REDSTONE_RELAY_ENABLED`** -- through a Redstone Relay peripheral (`REDSTONE_RELAY_NAME` / `REDSTONE_SIDE`) instead, for when the computer can't be wired directly and you route through a Wired Modem + relay.
  - **`GEARSHIFT_ENABLED`** -- through a Create **Sequenced Gearshift** (`GEARSHIFT_NAME`), physically rotating a switch (e.g. a Create HV Switch, rated up to ~100A) instead of driving redstone. Handy since plain redstone-triggered switches typically cap around 16A -- too low for some circuits. Rotates `GEARSHIFT_ANGLE` degrees at `GEARSHIFT_SPEED` on dusk, and back (negative speed) on dawn, only on an actual day/night transition (not every poll).
- Shows a live in-game clock (`HH:MM`) on the computer's own screen -- a single fixed line that's only ever updated in place, never reprinted, so it just keeps counting with no scrolling spam.
- Shows current signal status (ON/off + day/night) right under the clock.
- Broadcasts that same status over rednet so a [ControlRoom](../ControlRoom) computer can show it remotely, if `MODEM_ENABLED`. Set it to `false` on a computer with no wireless modem attached -- rednet is skipped entirely instead of crashing.

## Requirements

- CC:Tweaked (Minecraft mod)
- A **Computer** (regular is fine)
- Optionally, a **Redstone Relay** peripheral, connected with a Wired Modem + Networking Cable (only needed if `REDSTONE_RELAY_ENABLED`)
- Optionally, a **Create Sequenced Gearshift** peripheral (Create mod), connected with a Wired Modem + Networking Cable, driving whatever high-amperage switch you're using (e.g. a Create HV Switch) -- only needed if `GEARSHIFT_ENABLED`
- Optionally, a **wireless modem** attached, for reporting status to [ControlRoom](../ControlRoom) (only needed if `MODEM_ENABLED`)
- [Basalt2](https://github.com/Pyroxenium/Basalt2) for the UI -- installed automatically on first run

## Install

On a fresh CC:Tweaked computer:

```
wget https://raw.githubusercontent.com/kehan8/ComputerCraft/refs/heads/main/DaylightDetector/install.lua install
install
```

This downloads `config.lua`, `startup.lua`, `update.lua`, `update_full.lua`, and `uninstall.lua`.

## Configure

Before running, open `config.lua` and set the values to match your build:

```lua
COMPUTER_SIDE = "back",  -- side of this computer that goes high during the signal
COMPUTER_ENABLED = true,

REDSTONE_RELAY_NAME = "redstone_relay_0", -- name of your Redstone Relay peripheral
REDSTONE_SIDE = "front",                   -- side of the relay that goes high during the signal
REDSTONE_RELAY_ENABLED = false,

-- Rotates a Create Sequenced Gearshift instead, e.g. to flip a high-amperage
-- HV Switch that plain redstone can't drive (typically capped around 16A).
GEARSHIFT_NAME = "right",  -- side or peripheral name of the Sequenced Gearshift
GEARSHIFT_ENABLED = false,
GEARSHIFT_ANGLE = 180,     -- degrees to rotate on each transition (tested: 180)
GEARSHIFT_SPEED = 1,       -- rotation speed; sign is direction (tested: 1)

MODEM_NAME = "back",  -- wireless modem used to report status to ControlRoom
MODEM_ENABLED = true,

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

> Updating from an older install? `update.lua` never touches `config.lua`, so any new fields won't appear on their own -- run `update_full` (see below) or add the lines yourself.

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
| `config.lua` | Your local settings (signal sources, relay/gearshift name, modem, dusk/dawn times) -- not touched by `update.lua` |
| `startup.lua` | Reads the in-game clock, drives the redstone signal, shows the clock/status on screen |
| `install.lua` | First-time setup |
| `update.lua` | Re-downloads the code, keeps your `config.lua` |
| `update_full.lua` | Re-downloads everything, including `config.lua` |
| `uninstall.lua` | Removes the installed files |
