# PokemonArena (CC:Tweaked)

VS-battle display for Cobblemon fights: one Environment Detector per podium shows the trainer + active Pokemon + HP on that side, in a Basalt2 UI with colored HP bars and a "New Battle" flow for tracking wins/losses.

![status](https://img.shields.io/badge/status-core--confirmed--in--game-brightgreen)

Core scanning/display (name, HP, left/right switching mid-battle) confirmed working live in-game. The Basalt2 UI, trainer name, win/lose tally and Monitor output described below are new and not yet in-game tested.

## What it does

- Every `POLL_INTERVAL` seconds, scans each podium's Environment Detector and finds the trainer-owned Pokemon closest to it (its active battler), plus the nearest player (that podium's trainer).
- Shows, per podium, in a boxed panel: the trainer's name, the active Pokemon's name, a colored HP bar (green >50%, yellow 20-50%, red <20%) and `HP current/max` -- on screen, either the computer's own terminal by default, or an optional external **Monitor** if you set one up (see [Configure](#configure)).
- Filters out anything that isn't a Cobblemon Pokemon (players, Loot Balls, etc. never have a `baby` field) and anything wild-spawned (no trainer), using tags set by a small companion datapack -- see [Datapack](#datapack) below.
- A single missed scan (recall animation, scan jitter) doesn't blank the screen; it only clears after 2 consecutive misses.
- Marks `FAINTED` once a shown Pokemon's HP hits 0.
- Tracks how many of each podium's own Pokemon have fainted against that podium's team size, and shows `DEFEAT`/`WINNER` once a side's team is wiped out -- see [Match tracking](#match-tracking-winlose) below.

## Requirements

- CC:Tweaked (Minecraft mod)
- An **Advanced Computer** (and, if you want the mirrored display, an **Advanced Monitor**) -- Basalt2's UI (buttons, colored labels) needs the Advanced variants, unlike v1's plain text
- Advanced Peripherals' **Environment Detector**, one per podium, each on a Wired Modem network -- see `locations.lua`
- Optionally, a **Monitor** (any size, e.g. 6x8 blocks) on the same network if you want the display mirrored off the computer's own screen -- see `MONITOR` in [Configure](#configure)
- Cobblemon
- The companion **datapack** in `datapack/` loaded into the world (or merged into another datapack), so ownership tags exist -- see [Datapack](#datapack)
- Internet access on the computer (HTTP API enabled) the first time it runs, so it can download the **Basalt2** UI library -- handled automatically by `install.lua`/`startup.lua`, same as GymArena/SimonSays

## Install

On a fresh CC:Tweaked computer:

```
wget https://raw.githubusercontent.com/kehan8/ComputerCraft/refs/heads/main/PokemonArena/install.lua install
install
```

This downloads `config.lua`, `locations.lua`, `startup.lua`, `rename.lua`, `update.lua`, `update_full.lua`, and `uninstall.lua`, and also installs the **Basalt2** UI library if it isn't already present. If `config.lua`/`locations.lua` already exist (e.g. reinstalling after `uninstall.lua` kept them), they're left untouched -- only the other files are refreshed.

The `datapack/` folder is **not** part of this download (it's not CC:Tweaked code) -- copy it into the world's `datapacks/` folder yourself, or merge it into an existing datapack. See [Datapack](#datapack).

## Configure

Open `config.lua`:

```lua
RADIUS = 16, -- scanEntities() radius per detector (half-width, so this
             -- scans a 32x32x32 cube). 16 is also the practical max we've
             -- measured (17+ always returns "no entities found").

OWNED_TAG = "pa_owned", -- set by the datapack on trainer-owned Pokemon
WILD_TAG = "pa_wild",   -- set on wild-spawned Pokemon (unused by startup.lua for now)

POLL_INTERVAL = 2.2, -- seconds between scans

TEAM_SIZE = 1, -- default/fallback team size (1-6) used only before you've
               -- ever clicked "New Battle" -> "Start Battle" in-game; the
               -- real per-podium team sizes live in team_sizes.dat once you
               -- have (see "Match tracking" below).

MONITOR = nil, -- optional Monitor peripheral name (e.g. "monitor_0") to
               -- mirror the display onto instead of the computer's own
               -- terminal. Leave nil to keep using the computer's screen.
MONITOR_TEXT_SCALE = 1, -- only used if MONITOR is set; passed to monitor.setTextScale()
```

And `locations.lua`:

```lua
PODIUMS = {
    { position = "Left",  detector = "environment_detector_0" },
    { position = "Right", detector = "environment_detector_1" },
    -- add as many as you want, e.g. a "Middle" podium for a triple battle
},
```

Each podium needs its own Environment Detector placed near that trainer's spot -- the *nearest* owned Pokemon to that specific detector is what gets shown, so keep detectors close enough to their own podium (and far enough from the other) that they don't cross-pick each other's battler. No wiring "side" field is needed: an Environment Detector is wrapped by its network name only, exactly like a Player Detector (unlike a Redstone Relay/computer redstone side used elsewhere in this repo -- different concept, don't confuse the two).

**Peripheral name depends on your Minecraft version:** Advanced Peripherals renamed this block's peripheral from `environmentDetector` (below 1.21.1) to `environment_detector` (1.21.1 and above) to match Minecraft's own snake_case registry convention. `locations.lua` above assumes 1.21.1+; if you're still on an older version, use `environmentDetector_0`/`environmentDetector_1` instead. Either way, don't guess -- run `peripheral.getNames()` from the Lua prompt to see the exact names CC:Tweaked assigned on your world (the numeric suffix depends on placement order, not on which podium is "left" or "right").

### Naming this device

`install` asks you to name this device the first time you run it -- press Enter or type `SKIP` to auto-generate a unique name from the computer's ID instead. Rename it later anytime, without reinstalling, with `rename`.

## Datapack

Advanced Peripherals' `scanEntities()` has no idea whether a Pokemon belongs to a trainer or is a wild spawn -- that only exists in raw NBT (`Pokemon.PokemonOriginalTrainerType`), which the Lua API doesn't expose. `datapack/` is a small standalone datapack that tags every Cobblemon Pokemon with `pa_owned` or `pa_wild` every ~1 second based on that NBT field, so `startup.lua` can filter on the tag instead. See `datapack/NOTES.txt` for exactly what it does, how to merge it into an existing datapack instead of running it standalone, and a folder-naming gotcha if your modpack pins an older Minecraft version.

## Match tracking (win/lose)

Each podium counts how many of its own **distinct** Pokemon (by in-game uuid, so a fainted Pokemon lingering on screen for a scan or two before being recalled isn't counted twice) have been seen at 0 HP. The screen shows this live, e.g.:

```
Right              (2/6 fainted)
Trainer: KnightKehan
Sprigatito
[######----------]
HP 8/27
```

Once a podium's fainted count reaches its team size, that podium shows `*** DEFEAT ***` instead of Pokemon info. If that leaves exactly one other podium still standing, that one shows `*** WINNER ***` under its Pokemon info. If every podium gets defeated at once (mutual KO), no winner is shown -- all podiums just show `DEFEAT`.

Only **owned** Pokemon count (wild-tagged entities are already filtered out before this logic runs), so this only tracks each trainer's own team, not anything else that might wander into scan range.

**Starting a new match ("New Battle"):** click the **New Battle** button (on the computer, or tap it on the Monitor -- both work, Basalt2 handles monitor touch events) to open a setup screen with a `-`/`+` picker per podium (1-6) for that podium's team size, prefilled with whatever was last used. Click **Start Battle** to clear both podiums' tallies and start tracking with the chosen sizes -- no key rebind, no timer/countdown needed. Team size is chosen **per podium**, not shared, and is saved to `team_sizes.dat` (not `config.lua`), so it survives `update.lua` and isn't reset by `update_full.lua` either.

**Automatic reset:** if a match is already over (a podium showing `DEFEAT`/`WINNER`) and a brand new Pokemon (never seen this match, by uuid) shows up alive on a podium, the screen automatically jumps to the same New Battle setup screen (prefilled with the current team sizes) -- you still need to click **Start Battle** to actually reset and resume tracking. The manual **New Battle** button always works too, any time, not just after a DEFEAT/WINNER.

Note: lowering a podium's team size below its current fainted count on the setup screen takes effect immediately on Start Battle and can show `DEFEAT` right away -- that's expected, not a bug.

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
| `config.lua` | Your local settings (scan radius, ownership tags, poll interval, team size, optional monitor) -- not touched by `update.lua` |
| `locations.lua` | Podium list: label + Environment Detector name per podium -- not touched by `update.lua` |
| `startup.lua` | Scans each podium's detector, filters to the active owned Pokemon + trainer, shows a Basalt2 UI with name/HP/fainted tally/WINNER-DEFEAT + the New Battle setup screen |
| `install.lua` | First-time setup |
| `rename.lua` | Change this device's label later without reinstalling |
| `update.lua` | Re-downloads the code, keeps your `config.lua`/`locations.lua` |
| `update_full.lua` | Re-downloads everything, including `config.lua`/`locations.lua` |
| `uninstall.lua` | Removes the installed files |
| `datapack/` | Standalone Minecraft datapack tagging Pokemon ownership (not downloaded by `install.lua`, copy manually -- see above) |
| `todo.txt` | Design notes/history from building this -- not needed to run it, kept for context on why things are the way they are |
| `team_sizes.dat` | Runtime-generated: saved per-podium team sizes, written whenever you click "Start Battle" -- not part of the repo, not downloaded, only created/read on the computer itself |
| `basalt`/`basalt.lua` | The Basalt2 UI library, auto-installed by `install.lua`/`startup.lua` the first time it's missing -- not part of this repo either |

## Known limitations

- Can only show the **active** (out-of-ball) Pokemon per side -- a trainer's full 6-Pokemon team can't be read directly, since balled Pokemon aren't entities. The per-podium team size fainted-tally works around this by counting distinct Pokemon seen at 0 HP over time instead of reading the party/PC.
- Scan cooldown (~2s) means the display updates in ~2s steps, not real-time.
- Scan radius is capped at 16 in practice (see `config.lua` comment) -- fine for the current arena (18x17), but a much larger future arena may need this limit raised server-side first.
- "Trainer name" is a best-effort guess: the nearest non-Pokemon entity to that podium's detector (almost always the player standing there). No level/gender is shown either -- `scanEntities()` doesn't expose those fields for Pokemon entities.
- If a Pokemon's HP is misread as 0 for a moment (scan glitch) it counts as fainted, same risk the existing `FAINTED` label already had -- not new, just worth knowing.
- Requires an Advanced Computer/Monitor for the Basalt2 UI (buttons, colors) -- a regular Computer/Monitor won't render it correctly.
