# Tic Tac Toe (CC:Tweaked)

A Tic Tac Toe puzzle for [CC:Tweaked](https://tweaked.cc/), built with the [Basalt2](https://basalt.madefor.cc/) UI library. Play on a touchscreen monitor against an unbeatable AI — win or draw and a redstone signal fires, ready to wire into a door, dispenser, or anything else.

![status](https://img.shields.io/badge/status-working-brightgreen)

## What it does

- 3x3 board on an Advanced Monitor, click to place your `X`.
- The AI (`O`) plays a perfect [minimax](https://en.wikipedia.org/wiki/Minimax) strategy — it can't be beaten, only tied or lost to.
- **Win or draw** opens the door (fires the redstone signal) — since the AI is unbeatable, requiring an outright win would make the puzzle unsolvable.
- Lose, and you can just hit "New game" and try again.

## Requirements

- CC:Tweaked (Minecraft mod)
- An **Advanced Computer** (needs color + touch support)
- An **Advanced Monitor** — regular Monitors don't send touch/click events. Multiple monitors placed adjacent to each other auto-merge into one screen, so a multi-block monitor wall works too.
- A **Redstone Relay**, connected to the computer with a Wired Modem + Networking Cable, wired to whatever the redstone signal should control (a door, dropper, etc.)
- [Basalt2](https://github.com/Pyroxenium/Basalt2) — installed automatically on first run if it's missing.

## Install

On a fresh CC:Tweaked computer:

```
wget https://raw.githubusercontent.com/kehan8/ComputerCraft/refs/heads/main/TicTacToe/install.lua install
install
```

This downloads `config.lua`, `startup.lua`, `board.lua`, `ai.lua`, `update.lua`, `update_full.lua`, `uninstall.lua`, and installs Basalt2 if it isn't already present.

## Configure

Before running, open `config.lua` and set the values to match your build:

```lua
MONITOR_NAME = nil,        -- e.g. "monitor_0" to force a specific monitor; nil = auto-detect
MONITOR_SCALE = 0.5,       -- text scale on the monitor; lower = more resolution for the icons
REDSTONE_RELAY_NAME = "redstone_relay_0", -- name of your Redstone Relay peripheral
REDSTONE_SIDE = "front",                   -- side of the relay that goes high once the player wins
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

`update` re-downloads the code but **leaves `config.lua` alone**, so your monitor/relay settings survive. If you ever want `config.lua` itself reset back to the repo defaults (e.g. it got corrupted, or a new version adds new settings), run:

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
| `config.lua` | Your local settings (monitor, relay) — not touched by `update.lua` |
| `startup.lua` | UI (Basalt2), game flow, redstone output |
| `board.lua` | Board state and win detection |
| `ai.lua` | Minimax AI |
| `install.lua` | First-time setup |
| `update.lua` | Re-downloads the code, keeps your `config.lua` |
| `update_full.lua` | Re-downloads everything, including `config.lua` |
| `uninstall.lua` | Removes the installed files |
