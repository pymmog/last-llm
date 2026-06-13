# RUSTPULSE

A post-apocalyptic, Vampire Survivors-inspired 2D survivor-like built with
**Godot 4.6**. You are UNIT-7, a lone maintenance robot holding out against
endless waves of color-coded mutants. Move to survive — your weapons fire on
their own. Survive 20 minutes to win; scrap earned in every run buys permanent
Workshop upgrades.

Runs on **Linux, macOS and Windows** (pure GDScript, no platform-specific code).

- Game design spec: [docs/DESIGN.md](docs/DESIGN.md)
- Developer / agent instructions (build, export, CI, testing):
  [.github/copilot-instructions.md](.github/copilot-instructions.md)

## Features

- **Movement-only control** — WASD / arrow keys / gamepad left stick; Esc pauses
- **5 auto-attacking weapons**, 8 levels each, each with a **weapon evolution**
  unlocked by pairing it with the right passive
- **11 passive upgrades** — fire rate, cooldowns, HP, regen, armor,
  projectiles, pierce, AoE, damage, speed, magnet
- **4 mutant types** with readable silhouettes and color-coded behaviors, plus
  **alpha minibosses** that drop evolution supply crates
- **Time-scaled waves**, XP gems, level-up card picks, medkits, magnets, scrap
- **Permanent unlocks** in a scrap-funded Workshop
- Generated PS1-style sprites and fully procedural audio

## Play it

### Download a build (no Godot needed)

Every push to `master` builds all three platforms — grab them from the
**Actions** tab → latest `build` run → *Artifacts*:

| Artifact | Contents |
|----------|----------|
| `rustpulse-linux-appimage` | `RUSTPULSE-x86_64.AppImage` |
| `rustpulse-macos` | `RUSTPULSE.app` (universal, inside a nested zip) |
| `rustpulse-windows` | `rustpulse.exe` |

First-run notes:

- **Linux:** artifact zips strip the executable bit — `chmod +x` the AppImage.
- **macOS:** unzip the inner `rustpulse-macos.zip`, then right-click →
  *Open* (the app is ad-hoc signed, not notarized), or `xattr -cr RUSTPULSE.app`.
- **Windows:** SmartScreen warns on the unsigned exe — *More info → Run anyway*.

### Run from source

Install [Godot 4.6.x](https://godotengine.org/download/) (standard build,
no Mono), then:

```sh
godot --path .   # or open the project in the editor and press Play
```

## Save data

Permanent progress lives at `user://meta.json`
(Linux: `~/.local/share/godot/app_userdata/RUSTPULSE/`,
macOS: `~/Library/Application Support/Godot/app_userdata/RUSTPULSE/`).
Delete it to reset.
