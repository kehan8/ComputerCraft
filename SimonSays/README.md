# Simon Says (CC:Tweaked)

A Simon Says memory puzzle for [CC:Tweaked](https://tweaked.cc/), built with the [Basalt2](https://basalt.madefor.cc/) UI library, inspired by the Simon Says terminal from Hypixel Skyblock. Watch the growing color pattern, repeat it back on a touchscreen monitor, and a redstone signal fires once you've nailed enough rounds in a row — ready to wire into a door.

![status](https://img.shields.io/badge/status-working-brightgreen)

## What it does

- A 2x2 grid of large color pads (red, blue, green, yellow) fills an Advanced Monitor.
- Press **Start** and the computer flashes one pad for a second, then goes dark.
- Tap the pad you just saw light up. Get it right, and the computer replays the same pattern **plus one more step**.
- Each round adds one step. Reach a pattern of `WIN_LENGTH` steps (default 6) without a mistake and the door opens.
- Tap the wrong pad at any point and the whole board flashes red twice, then the puzzle resets to a fresh 1-step pattern.
- Once a game is running, the **Start** button turns into **New game**. Tap it anytime — mid-round or after solving — to stop and return to the idle "press Start" state. Note that solving the puzzle does *not* automatically turn the door signal back off; hit **New game** first if you want to reset it.

## Requirements

- CC:Tweaked (Minecraft mod)
- An **Advanced Computer** (needs color + touch support)
- An **Advanced Monitor** — regular Monitors don't send touch/click events. Multiple monitors placed adjacent to each other auto-merge into one screen, so a multi-block monitor wall works too.
- A **Redstone Relay**, connected to the computer with a Wired Modem + Networking Cable, wired to whatever the redstone signal should control (a door, dropper, etc.)
- [Basalt2](https://github.com/Pyroxenium/Basalt2) — installed automatically on first run if it's missing.

## Install

On a fresh CC:Tweaked computer:

```
wget https://raw.githubusercontent.com/kehan8/ComputerCraft/refs/heads/main/SimonSays/install.lua install
install
```

This downloads `config.lua`, `startup.lua`, `simon.lua`, `update.lua`, `update_full.lua`, and installs Basalt2 if it isn't already present.

## Configure

Before running, open `config.lua` and set the values to match your build:

```lua
MONITOR_NAME = nil,        -- e.g. "monitor_0" to force a specific monitor; nil = auto-detect
MONITOR_SCALE = 0.5,       -- text scale on the monitor
REDSTONE_RELAY_NAME = "redstone_relay_0", -- name of your Redstone Relay peripheral
REDSTONE_SIDE = "back",                   -- side of the relay that goes high once solved

WIN_LENGTH = 6,            -- pattern length (rounds) needed to solve the puzzle
FLASH_TIME = 0.6,          -- seconds a pad stays lit during playback
GAP_TIME = 0.25,           -- seconds between pads during playback
ROUND_START_DELAY = 1,     -- pause before playback starts each round
NEXT_ROUND_DELAY = 0.8,    -- pause after a correct round before the next one plays
CLICK_FLASH_TIME = 0.15,   -- how long a pad stays lit when the player taps it
WRONG_FLASH_TIME = 0.2,    -- on/off timing for the red "wrong" flash
```

If you're not sure what your relay/monitor is named, run `peripheral.getNames()` from the Lua prompt to list connected peripherals.

## Run

```
startup
```

To pull the latest version later:

```
update
```

`update` re-downloads the code but **leaves `config.lua` alone**, so your monitor/relay/timing settings survive. If you ever want `config.lua` itself reset back to the repo defaults (e.g. it got corrupted, or a new version adds new settings), run:

```
update_full
```

## Files

| File | Purpose |
|---|---|
| `config.lua` | Your local settings (monitor, relay, timings) — not touched by `update.lua` |
| `startup.lua` | UI (Basalt2), game flow, redstone output |
| `simon.lua` | Pattern state (start a new pattern, add a random step) |
| `install.lua` | First-time setup |
| `update.lua` | Re-downloads the code, keeps your `config.lua` |
| `update_full.lua` | Re-downloads everything, including `config.lua` |
