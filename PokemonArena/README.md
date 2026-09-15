# PokemonArena (CC:Tweaked)

VS-battle display for Cobblemon fights: one Environment Detector per podium shows the name + HP of the closest trainer-owned Pokemon on that side.

![status](https://img.shields.io/badge/status-v1--untested-yellow)

## What it does

- Every `POLL_INTERVAL` seconds, scans each podium's Environment Detector and finds the trainer-owned Pokemon closest to it (its active battler).
- Shows name + `HP current/max` + a plain text bar for each podium, straight on the computer's own screen. No Basalt2, no colors, no chatbox, no toasts -- v1 is deliberately plain to validate the data flow first.
- Filters out anything that isn't a Cobblemon Pokemon (players, Loot Balls, etc. never have a `baby` field) and anything wild-spawned (no trainer), using tags set by a small companion datapack -- see [Datapack](#datapack) below.
- A single missed scan (recall animation, scan jitter) doesn't blank the screen; it only clears after 2 consecutive misses.
- Marks `FAINTED` once a shown Pokemon's HP hits 0.

## Requirements

- CC:Tweaked (Minecraft mod)
- A **Computer** (regular is fine, no Advanced/monitor needed for v1's plain text)
- Advanced Peripherals' **Environment Detector**, one per podium, each on a Wired Modem network -- see `locations.lua`
- Cobblemon
- The companion **datapack** in `datapack/` loaded into the world (or merged into another datapack), so ownership tags exist -- see [Datapack](#datapack)

## Install

On a fresh CC:Tweaked computer:

```
wget https://raw.githubusercontent.com/kehan8/ComputerCraft/refs/heads/main/PokemonArena/install.lua install
install
```

This downloads `config.lua`, `locations.lua`, `startup.lua`, `rename.lua`, `update.lua`, `update_full.lua`, and `uninstall.lua`. If `config.lua`/`locations.lua` already exist (e.g. reinstalling after `uninstall.lua` kept them), they're left untouched -- only the other files are refreshed.

The `datapack/` folder is **not** part of this download (it's not CC:Tweaked code) -- copy it into the world's `datapacks/` folder yourself, or merge it into an existing datapack. See [Datapack](#datapack).

## Configure

Open `config.lua`:

```lua
RADIUS = 16, -- scanEntities() cube radius per detector. 16 is the practical
             -- max we've measured (17+ always returns "no entities found").

OWNED_TAG = "pa_owned", -- set by the datapack on trainer-owned Pokemon
WILD_TAG = "pa_wild",   -- set on wild-spawned Pokemon (unused by startup.lua for now)

POLL_INTERVAL = 2.2, -- seconds between scans
```

And `locations.lua`:

```lua
PODIUMS = {
    { position = "Left",  detector = "environmentDetector_0" },
    { position = "Right", detector = "environmentDetector_1" },
    -- add as many as you want, e.g. a "Middle" podium for a triple battle
},
```

Each podium needs its own Environment Detector placed near that trainer's spot -- the *nearest* owned Pokemon to that specific detector is what gets shown, so keep detectors close enough to their own podium (and far enough from the other) that they don't cross-pick each other's battler. No wiring "side" field is needed: an Environment Detector is wrapped by its network name only, exactly like a Player Detector (unlike a Redstone Relay/computer redstone side used elsewhere in this repo -- different concept, don't confuse the two).

If you're not sure what your peripherals are named, run `peripheral.getNames()` from the Lua prompt to list them.

### Naming this device

`install` asks you to name this device the first time you run it -- press Enter or type `SKIP` to auto-generate a unique name from the computer's ID instead. Rename it later anytime, without reinstalling, with `rename`.

## Datapack

Advanced Peripherals' `scanEntities()` has no idea whether a Pokemon belongs to a trainer or is a wild spawn -- that only exists in raw NBT (`Pokemon.PokemonOriginalTrainerType`), which the Lua API doesn't expose. `datapack/` is a small standalone datapack that tags every Cobblemon Pokemon with `pa_owned` or `pa_wild` every ~1 second based on that NBT field, so `startup.lua` can filter on the tag instead. See `datapack/NOTES.txt` for exactly what it does, how to merge it into an existing datapack instead of running it standalone, and a folder-naming gotcha if your modpack pins an older Minecraft version.

## Run

```
startup
```

To pull the latest version later:

```
update
```

`update` re-downloads the code but **leaves `config.lua`/`locations.lua` alone**. If you ever want them reset back to the repo defaults, run:

```
update_full
```

## Uninstall

```
uninstall
```

Removes everything `install.lua` put on the computer (optionally including `config.lua`/`locations.lua`).

## Files

| File | Purpose |
|---|---|
| `config.lua` | Your local settings (scan radius, ownership tags, poll interval) -- not touched by `update.lua` |
| `locations.lua` | Podium list: label + Environment Detector name per podium -- not touched by `update.lua` |
| `startup.lua` | Scans each podium's detector, filters to the active owned Pokemon, shows name/HP on screen |
| `install.lua` | First-time setup |
| `rename.lua` | Change this device's label later without reinstalling |
| `update.lua` | Re-downloads the code, keeps your `config.lua`/`locations.lua` |
| `update_full.lua` | Re-downloads everything, including `config.lua`/`locations.lua` |
| `uninstall.lua` | Removes the installed files |
| `datapack/` | Standalone Minecraft datapack tagging Pokemon ownership (not downloaded by `install.lua`, copy manually -- see above) |
| `todo.txt` | Design notes/history from building this -- not needed to run it, kept for context on why things are the way they are |

## Known limitations

- Can only show the **active** (out-of-ball) Pokemon per side -- a trainer's full 6-Pokemon team can't be read, since balled Pokemon aren't entities.
- Scan cooldown (~2s) means the display updates in ~2s steps, not real-time.
- Scan radius is capped at 16 in practice (see `config.lua` comment) -- fine for the current arena (18x17), but a much larger future arena may need this limit raised server-side first.
