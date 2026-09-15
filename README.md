# ComputerCraft

A collection of [CC:Tweaked](https://tweaked.cc/) automation projects for Minecraft. Each project installs independently on its own computer and has its own README with setup, configuration, and file details.

## Projects

| Project | What it is |
|---|---|
| [AdminDoor](AdminDoor) | Admin-only door — a Player Detector + whitelist opens it, anyone else gets a "NO ACCESS" toast |
| [ControlRoom](ControlRoom) | Overview monitor for every other project — live status on one screen, plus remote reset/toggle |
| [DaylightDetector](DaylightDetector) | Tracks the in-game clock and flips a redstone signal at dusk/dawn |
| [FossilLab](FossilLab) | Live status monitor for Cobblemon's Fossil Analyzer / Restoration Tank |
| [GymArena](GymArena) | Puzzle gym: [Simon Says](GymArena/SimonSays) + [Tic Tac Toe](GymArena/TicTacToe) gate the main door via [GymLock](GymArena/GymLock) |
| [PokemonArena](PokemonArena) | VS-battle display — Environment Detectors show name + HP of each side's active Pokemon (v1, untested) |
| [WelcomeDoor](WelcomeDoor) | Welcome door for everyone — welcome/goodbye toasts, ACTIVE/INACTIVE toggle |

Most projects broadcast their status to ControlRoom over rednet — install that one too if you want a single overview screen for everything.

## Install

On a fresh CC:Tweaked computer, from that computer's Lua prompt:

```
wget https://raw.githubusercontent.com/kehan8/ComputerCraft/refs/heads/main/<Project>/install.lua install
install
```

Replace `<Project>` with the folder name from the table above (GymArena's puzzles live one level deeper, e.g. `GymArena/GymLock`). See each project's own README for configuration, running, updating, and uninstalling.
