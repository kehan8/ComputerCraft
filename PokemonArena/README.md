# PokemonArena (CC:Tweaked)

VS-battle display for Cobblemon fights: one Environment Detector per podium shows the trainer + active Pokemon + HP on that side, in a Basalt2 UI with colored HP bars and a "New Battle" flow for tracking wins/losses.

![status](https://img.shields.io/badge/status-working-brightgreen)

Core scanning/display, the Basalt2 UI, trainer name locking, win/lose tally, Monitor auto-detect, match history, and the battle-arena restyle (colored headers, VS seam, HP gradient, configurable background, star WINNER banner) are all confirmed working live in-game.

## What it does

- Every `POLL_INTERVAL` seconds, scans every podium's Environment Detector and finds the trainer-owned Pokemon closest to it (its active battler), plus the nearest player (that podium's trainer). Because the scan radius can see the whole arena from any podium (see `RADIUS` below), the same Pokemon uuid is resolved to exactly one podium per cycle -- whichever detector is physically closest to it -- so a podium with no Pokemon of its own never "borrows" the other podium's Pokemon/trainer just because it's the only one on the field.
- Shows, per podium, in a boxed panel: the trainer's name, the active Pokemon's name, a colored HP bar (green >50%, yellow 25-50%, orange 10-25%, red <=10%) and `HP current/max` -- on screen, mirrored automatically onto a wired external **Monitor** if one is present, or the computer's own terminal otherwise (see [Configure](#configure)).
- Filters out anything that isn't a Cobblemon Pokemon (players, Loot Balls, etc. never have a `baby` field) and anything wild-spawned (no trainer), using tags set by a small companion datapack -- see [Datapack](#datapack) below.
- Trainer names only come from real players (tagged `pa_player` by the datapack), never from a wandering mob, and the guess is locked to whichever Pokemon uuid is currently shown -- it's picked once per send-out (nearest tagged player to that Pokemon) and never re-guessed while the same Pokemon stays active, so a bystander walking past the podium can't steal the label.
- A single missed scan (recall animation, scan jitter) doesn't blank the screen; it only clears after 2 consecutive misses.
- Marks `FAINTED` once a shown Pokemon's HP hits 0.
- Tracks how many of each podium's own Pokemon have fainted against that podium's team size, and shows `DEFEAT`/`WINNER` once a side's team is wiped out -- see [Match tracking](#match-tracking-winlose) below.
- Logs every finished match (win/lose/draw + fainted tally) to a browsable, paged **History** screen, capped at the last `HISTORY_MAX_ENTRIES` matches -- see [Match history](#match-history) below.
- Broadcasts a bare "Running" status over rednet so a [ControlRoom](../ControlRoom) computer can show it alongside the other gym devices -- deliberately no podium/trainer/Pokemon details go out, and there's no remote command either, so it's read-only there, no Reset button.

## Look & feel

A soft blue/green/red battle-arena palette (via `setPaletteColor`, where the terminal supports it -- both an Advanced Computer and Advanced Monitor do), a configurable background, replacing the earlier plain gray/white/black look:

- The frame background defaults to light gray (`colors.lightGray`) instead of Basalt's default white, so the empty space around/below the podium cards isn't stark white -- and, since a gym leader might run their own PokemonArena computer for their own themed arena (not just this neutral one), it's configurable per computer via `config.lua`'s `BACKGROUND_COLOR` -- see [Configure](#configure).
- Each podium gets a rotating accent color (blue, red, green, repeating for a 3rd+ podium) shown as a 5-row-thick colored bar where the podium used to just say "Left"/"Right" -- the trainer's name is still shown right below it, tinted the same accent color, so color and name work together instead of one replacing the other.
- With **exactly 2 podiums** (and a wide enough screen -- each podium column needs to be at least 12 characters wide: the 11-column letter pattern plus a 1-column gap), the two columns sit edge-to-edge (no reserved center gap) and a hand-drawn pixel-art "V"/"S" pair is drawn near the seam between the two colored header bars -- built the same way as GymArena/TicTacToe's X/O icons (an 11x5 bitmap, one small black square per filled pixel, layered on top of the header's accent color), not text, so the letters can actually be big and legible instead of a single stretched character. The V and S each sit pulled back 1 column from the seam (V left, S right), opening a small strip of each podium's own header color between the two letters instead of having them touch. With 3+ podiums (e.g. a "Middle" podium added in `locations.lua` for a triple battle), or a screen too narrow for the pattern + gap, there's no single seam to put it at, so no V/S is shown.
- The green winner banner at the bottom of each podium card is also 5 rows thick, matching the header, so the card reads visually balanced top-to-bottom instead of only the header standing out. It now shows a small star pattern across all 5 rows instead of one line of plain text, e.g.:
  ```
  *    *    *    *    *
    *    *    *    *
  * * *  WINNER  * * *
    *    *    *    *
  *    *    *    *    *
  ```
  all in orange against the green background (looks gold).
- HP bar colors now have 4 steps instead of 3 (green >50%, yellow 25-50%, orange 10-25%, red <=10%) -- the extra orange step was added so a low-HP Pokemon reads closer to Cobblemon's own HP bar (a separate, unrelated UI with its own thresholds -- the two bars can legitimately show different colors at the same HP%, that's not a bug). The `HP current/max` text uses that same color instead of staying static black.
- The active Pokemon's name is black normally, and turns red with its `FAINTED` tag once that specific Pokemon's HP hits 0 (matching `*** DEFEAT ***`'s red). The `(X/Y fainted)` tally is black while the team's still full strength, orange once at least one has fainted, and red once the whole team is out. `(no Pokemon detected)` stays gray (unrelated to match state).

## Requirements

- CC:Tweaked (Minecraft mod)
- An **Advanced Computer** (and, if you want the mirrored display, an **Advanced Monitor**) -- Basalt2's UI (buttons, colored labels) needs the Advanced variants, unlike v1's plain text
- Advanced Peripherals' **Environment Detector**, one per podium, each on a Wired Modem network -- see `locations.lua`
- Optionally, a **Monitor** (any size, e.g. 6x8 blocks) on the same network -- it's auto-detected and used automatically, no config needed (see [Configure](#configure))
- Optionally, a **wireless modem**, only if you want it reporting to [ControlRoom](../ControlRoom)
- Cobblemon
- The companion **datapack** in `pokemonarena/` loaded into the world (or merged into another datapack), so ownership tags exist -- see [Datapack](#datapack)
- Internet access on the computer (HTTP API enabled) the first time it runs, so it can download the **Basalt2** UI library -- handled automatically by `install.lua`/`startup.lua`, same as GymArena/SimonSays

## Install

On a fresh CC:Tweaked computer:

```
wget https://raw.githubusercontent.com/kehan8/ComputerCraft/refs/heads/main/PokemonArena/install.lua install
install
```

This downloads `config.lua`, `locations.lua`, `startup.lua`, `scan.lua`, `teamsizes.lua`, `match.lua`, `ui.lua`, `rename.lua`, `history.lua`, `update.lua`, `update_full.lua`, and `uninstall.lua`, and also installs the **Basalt2** UI library if it isn't already present. If `config.lua`/`locations.lua` already exist (e.g. reinstalling after `uninstall.lua` kept them), they're left untouched -- only the other files are refreshed.

The `pokemonarena/` folder is **not** part of this download (it's not CC:Tweaked code) -- copy it into the world's `datapacks/` folder yourself, or merge it into an existing datapack. See [Datapack](#datapack).

## Configure

Open `config.lua`:

```lua
RADIUS = 8, -- scanEntities() radius per detector (half-width, so this
            -- scans a 16x16x16 cube). Confirmed in-game: on a small arena
            -- this is big enough that every podium's detector actually
            -- sees the whole arena, not just its own podium -- startup.lua
            -- resolves that (see "What it does" above), not this value.
            -- 16 is the practical max measured (17+ always returns "no
            -- entities found"); raise this only if the server admin raises
            -- the underlying limit.

OWNED_TAG = "pa_owned", -- set by the datapack on trainer-owned Pokemon
PLAYER_TAG = "pa_player", -- set by the datapack on every real player;
                          -- required for a "Trainer:" candidate, so a
                          -- wandering mob can never be shown as the trainer

POLL_INTERVAL = 2.2, -- seconds between scans

-- Monitor is always auto-detected via peripheral.find("monitor")
-- (same convention as GymArena/SimonSays and GymArena/TicTacToe) --
-- falls back to the computer's own screen only if no monitor is found
-- at all. No setting needed here; there's nothing to configure.
MONITOR_SCALE = 1, -- passed to monitor.setTextScale() when a monitor is in use

HISTORY_MAX_ENTRIES = 20, -- how many recent matches match_history.dat remembers
                          -- (oldest drop off first) -- see "Match history" below.

BACKGROUND_COLOR = colors.lightGray, -- frame background, default light gray.
                          -- Change this if your gym has its own theme.
                          -- MUST be one of CC:Tweaked's 16 named colors.*
                          -- values (colors.white/orange/magenta/lightBlue/
                          -- yellow/lime/pink/gray/lightGray/cyan/purple/
                          -- blue/brown/green/red/black) -- CC:Tweaked/
                          -- Basalt2 can't render arbitrary custom RGB
                          -- backgrounds this way, only these 16 names.

MODEM_NAME = "back",   -- wireless modem used to talk to ControlRoom
MODEM_ENABLED = false, -- set true if you have a wireless modem attached
```

> Updating from an older install? `update.lua` never touches `config.lua`, so `MODEM_NAME`/`MODEM_ENABLED` won't appear on their own -- run `update_full` (see below) or add the lines yourself.

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

Advanced Peripherals' `scanEntities()` has no idea whether a Pokemon belongs to a trainer or is a wild spawn -- that only exists in raw NBT (`Pokemon.PokemonOriginalTrainerType`), which the Lua API doesn't expose. `pokemonarena/` is a small standalone datapack that tags every trainer-owned Cobblemon Pokemon with `pa_owned` every ~1 second based on that NBT field, so `startup.lua` can filter on the tag instead; wild-spawned Pokemon simply never get it. It also tags every online player `pa_player` every cycle, so the "Trainer:" guess only ever picks an actual player, never a wandering mob. See `pokemonarena/NOTES.txt` for exactly what it does, how to merge it into an existing datapack instead of running it standalone, and a folder-naming gotcha if your modpack pins an older Minecraft version.

## Match tracking (win/lose)

Each podium counts how many of its own **distinct** Pokemon (by in-game uuid, so a fainted Pokemon lingering on screen for a scan or two before being recalled isn't counted twice) have been seen at 0 HP. The screen shows this live, e.g.:

```
Right              (2/6 fainted)
Trainer: Player1
Sprigatito
[######----------]
HP 8/27
```

Once a podium's fainted count reaches its team size, that podium shows `*** DEFEAT ***` instead of Pokemon info. If that leaves exactly one other podium still standing, that one shows `*** WINNER ***` under its Pokemon info. If every podium gets defeated at once (mutual KO), no winner is shown -- all podiums just show `DEFEAT`.

Only **owned** Pokemon count (wild-spawned entities are already filtered out before this logic runs, since they never get `pa_owned`), so this only tracks each trainer's own team, not anything else that might wander into scan range.

**Starting a new match ("New Battle"):** click the **New Battle** button (on the computer, or tap it on the Monitor -- both work, Basalt2 handles monitor touch events) to open a setup screen with a `-`/`+` picker per podium (1-6) for that podium's team size, prefilled with whatever was last used. Each picker is labeled `Trainer (<position>):`, e.g. `Trainer (Left):`/`Trainer (Right):`, so it reads as "whose team size is this" instead of a bare direction. Click **Start Battle** to clear both podiums' tallies and start tracking with the chosen sizes -- no key rebind, no timer/countdown needed. Team size is chosen **per podium**, not shared, and is saved to `team_sizes.dat` (not `config.lua`), so it survives `update.lua` and isn't reset by `update_full.lua` either.

**Automatic reset:** if a match is already over (a podium showing `DEFEAT`/`WINNER`) and a brand new Pokemon (never seen this match, by uuid) shows up alive on a podium, the screen automatically jumps to the same New Battle setup screen (prefilled with the current team sizes) -- you still need to click **Start Battle** to actually reset and resume tracking. The manual **New Battle** button always works too, any time, not just after a DEFEAT/WINNER.

Note: lowering a podium's team size below its current fainted count on the setup screen takes effect immediately on Start Battle and can show `DEFEAT` right away -- that's expected, not a bug.

## Match history

Every finished match (a `DEFEAT`/`WINNER`, or a mutual KO with no winner) is logged once to `match_history.dat`, most recent first, capped at `HISTORY_MAX_ENTRIES` (default 20 -- oldest entries drop off). Click **History** (next to **New Battle** on the live screen) to browse it: one line per match, e.g.

```
09-15 20:41  Player1 5/5 vs Player2 0/1  -> Player2 won
```

showing each side's trainer (or podium position, if no trainer was detected that match), its fainted/team-size tally, and the winner -- or `Draw` for a mutual KO. Use **< Prev** / **Next >** to page through older matches, and **Back** to return to the live screen. A match is recorded the moment it resolves (even if you're on the Setup or History screen when it happens), not when you click **New Battle** -- so it survives even if you forget to check the score before starting the next one.

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
| `config.lua` | Your local settings (scan radius, ownership tags, poll interval, optional monitor, history limit, background color, optional modem) -- not touched by `update.lua` |
| `locations.lua` | Podium list: label + Environment Detector name per podium -- not touched by `update.lua` |
| `startup.lua` | Orchestration only: loads config, builds the podium table, bootstraps Basalt2 + the monitor, wires the modules below together, runs the scan loop, and reports a bare "Running" status to ControlRoom |
| `scan.lua` | Turns raw Environment Detector `scanEntities()` output into "active Pokemon + trainer per podium", including the cross-podium dedup fix |
| `teamsizes.lua` | Load/save/clamp helpers for `team_sizes.dat` (per-podium team size, 1-6) |
| `match.lua` | HP-bar/color display helpers + match tracking (winner/defeat detection, resetting a podium's tally, logging a finished match) |
| `ui.lua` | All Basalt2 screen building + render functions (live/setup/history screens), including the color palette/background/header/V-S-seam restyle -- see [Look & feel](#look--feel) |
| `history.lua` | Load/save/add helpers for `match_history.dat` (same load/save/add shape as FossilLab's `fossilhistory.lua`) |
| `install.lua` | First-time setup |
| `rename.lua` | Change this device's label later without reinstalling |
| `update.lua` | Re-downloads the code, keeps your `config.lua`/`locations.lua` |
| `update_full.lua` | Re-downloads everything, including `config.lua`/`locations.lua` |
| `uninstall.lua` | Removes the installed files |
| `pokemonarena/` | Standalone Minecraft datapack tagging Pokemon ownership (not downloaded by `install.lua`, copy manually -- see above) |
| `team_sizes.dat` | Runtime-generated: saved per-podium team sizes, written whenever you click "Start Battle" -- not part of the repo, not downloaded, only created/read on the computer itself |
| `match_history.dat` | Runtime-generated: last `HISTORY_MAX_ENTRIES` completed matches, written whenever a match resolves -- not part of the repo, not downloaded, only created/read on the computer itself |
| `basalt`/`basalt.lua` | The Basalt2 UI library, auto-installed by `install.lua`/`startup.lua` the first time it's missing -- not part of this repo either |

## Related projects

Also check out [turboblitz181/mcdatapacks](https://github.com/turboblitz181/mcdatapacks/releases) -- a bigger standalone Cobblemon datapack project, separate from this repo. Use it on its own, or run it alongside PokemonArena's own `pokemonarena/` companion datapack (see [Datapack](#datapack) above) -- pick whichever fits your world, or both.

## Known limitations

- Can only show the **active** (out-of-ball) Pokemon per side -- a trainer's full 6-Pokemon team can't be read directly, since balled Pokemon aren't entities. The per-podium team size fainted-tally works around this by counting distinct Pokemon seen at 0 HP over time instead of reading the party/PC.
- Scan cooldown (~2s) means the display updates in ~2s steps, not real-time.
- Scan radius is capped at 16 in practice (see `config.lua` comment) -- fine for the current arena (18x17), but a much larger future arena may need this limit raised server-side first.
- "Trainer name" is a locked best-effort guess: the nearest real player (`pa_player`-tagged) to the Pokemon currently shown, picked once when that Pokemon is first sent out and kept until it's swapped for a different one -- not re-guessed every scan, so a second player walking near the podium can't steal the label. If no player is in range at all on the very first scan after a send-out, it keeps trying each scan until one shows up. No level/gender is shown either -- `scanEntities()` doesn't expose those fields for Pokemon entities.
- If a Pokemon's HP is misread as 0 for a moment (scan glitch) it counts as fainted, same risk the existing `FAINTED` label already had -- not new, just worth knowing.
- Requires an Advanced Computer/Monitor for the Basalt2 UI (buttons, colors) -- a regular Computer/Monitor won't render it correctly.
