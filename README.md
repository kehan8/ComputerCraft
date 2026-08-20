# ComputerCraft Gym

A small "escape room" gym built in [CC:Tweaked](https://tweaked.cc/): two standalone puzzle computers, each guarding its own door, plus a "brain" computer that opens the main entrance once both puzzles are solved.

![status](https://img.shields.io/badge/status-working-brightgreen)

## Layout

```
Simon Says ─┐
            ├─► GymLock ─► main door
Tic Tac Toe ┘
```

- **[Simon Says](SimonSays)** and **[Tic Tac Toe](TicTacToe)** are independent puzzle rooms. Each runs on its own Advanced Computer + Advanced Monitor, and fires a redstone signal through its own Redstone Relay once solved.
- **[GymLock](GymLock)** runs on a separate computer with no monitor. It reads both puzzles' redstone signals and, once both are high, opens the main piston door. If a puzzle gets reset, the main door closes again automatically.

Each puzzle's door signal is independent — wire it to a local door per room if you want, in addition to (or instead of) gating the main door through GymLock.

## Puzzles

| Puzzle | What it is | Solve condition |
|---|---|---|
| [Simon Says](SimonSays) | Memory game — repeat a growing color pattern | Match the pattern for `WIN_LENGTH` rounds in a row |
| [Tic Tac Toe](TicTacToe) | Tic Tac Toe vs. an unbeatable minimax AI | Win or draw (a win isn't required — the AI can't be beaten) |

Each project has its own README with setup, configuration, and file details — the links above go straight there.

## Extras

- **[AdminDoor](AdminDoor)** is a standalone admin-only door — not part of the puzzle chain above. A Player Detector scans for nearby players and only opens the door for names on an admin whitelist; anyone else gets a "NO ACCESS" popup and the door stays shut.

## Requirements

- CC:Tweaked (Minecraft mod)
- Simon Says & Tic Tac Toe: an Advanced Computer + Advanced Monitor each (touch support needed), plus a Redstone Relay
- GymLock: a regular Computer (no monitor needed) plus 4 Redstone Relays (2 reading the puzzle signals, 2 driving the main door)
- AdminDoor: a regular Computer, a Player Detector ([Advanced Peripherals](https://www.curseforge.com/minecraft/mc-mods/advanced-peripherals)), and a Redstone Relay
- All computers/relays connected via Wired Modem + Networking Cable
- [Basalt2](https://github.com/Pyroxenium/Basalt2) for the UIs — installed automatically on first run

## Install

Each project installs independently on its own computer. From that computer's Lua prompt:

```
wget https://raw.githubusercontent.com/kehan8/ComputerCraft/refs/heads/main/<Project>/install.lua install
install
```

Replace `<Project>` with `SimonSays`, `TicTacToe`, `GymLock`, or `AdminDoor`. See each project's README for configuration, running, updating, and uninstalling.
