# RUSTPULSE

A post-apocalyptic, Vampire Survivors-inspired 2D survivor-like built with
**Godot 4.6** for **Linux desktop**. You are UNIT-7, a lone maintenance robot
holding out against endless waves of color-coded human-like mutants. Move to
survive — your weapons fire on their own. Survive 20 minutes to win; scrap
earned in every run buys permanent Workshop upgrades.

Full design spec: [docs/DESIGN.md](docs/DESIGN.md)

## Features

- **Movement-only control** — WASD / arrow keys / gamepad left stick; Esc pauses
- **5 auto-attacking weapons** (Rivet Gun, Scrap Saw, Tesla Arc, Plasma Mortar,
  Nano Swarm), 8 levels each, each with a **weapon evolution** unlocked by
  pairing it with the right passive
- **11 passive upgrades**: fire rate, cooldown reduction, max HP, regen, armor,
  extra projectiles, pierce, AoE, damage, move speed, pickup magnet
- **4 mutant types** with readable silhouettes and color-coded behaviors
  (green shambler, yellow sprinter, purple spitter, red brute) plus **alpha
  minibosses** that drop evolution supply crates
- **Time-scaled waves**, XP gems, level-up card picks, medkits, magnets, scrap
- **Permanent unlocks**: a scrap-funded Workshop persisted to `user://meta.json`
- Generated PS1-style animated character sprites with procedural background,
  pickups, weapons, and effects

## Running from source

Requires [Godot 4.6.x](https://godotengine.org/download/linux/) (standard
build, no Mono needed).

```sh
godot --path . scenes/main_menu.tscn   # or just open the project in the editor
```

## Linux export workflow

The repo ships a ready-made export preset (`export_presets.cfg`, preset
`Linux x86_64`: embedded PCK, x86_64, test files excluded).

### One-time setup: export templates

Export templates must match your editor version. Either:

- **Editor:** *Editor → Manage Export Templates → Download and Install*, or
- **CLI:**
  ```sh
  curl -LO https://github.com/godotengine/godot/releases/download/4.6-stable/Godot_v4.6-stable_export_templates.tpz
  unzip Godot_v4.6-stable_export_templates.tpz   # contains a templates/ dir
  mkdir -p ~/.local/share/godot/export_templates
  mv templates ~/.local/share/godot/export_templates/4.6.stable
  ```
  (Only `linux_release.x86_64`, `macos.zip` and `windows_release_x86_64.exe`
  are needed for the presets in this repo.)

### Export a release build

From the editor: *Project → Export → Linux x86_64 → Export Project*.

Headless / CI:

```sh
godot --headless --import                                              # first time only
godot --headless --export-release "Linux x86_64" build/linux/rustpulse.x86_64
```

The output is a single self-contained native ELF binary (the game data PCK is
embedded). Run it on any reasonably recent x86_64 Linux with X11 or Wayland:

```sh
chmod +x build/linux/rustpulse.x86_64   # already executable when exported locally
./build/linux/rustpulse.x86_64
```

The project uses the **GL Compatibility** renderer, so it runs on OpenGL 3.3
class hardware/drivers — no Vulkan required. For distribution, zip the binary
(`zip rustpulse-linux-x86_64.zip rustpulse.x86_64`) or feed it to your
packaging format of choice (AppImage, Flatpak, etc.).

## Playing on macOS

The project is pure GDScript with no platform-specific code, so it runs on
macOS as-is. Two options:

### Option 1 — run from source (easiest)

1. Install Godot 4.6.x:
   ```sh
   brew install --cask godot
   ```
   or download the universal `.dmg` from
   [godotengine.org/download/macos](https://godotengine.org/download/macos/)
   (standard build, no Mono needed).
2. Clone this repo and run it:
   ```sh
   git clone <repo-url> && cd last-llm
   godot --path .        # or open the project in the Godot editor and press Play
   ```

### Option 2 — export a native .app

A ready-made **macOS** preset is committed in `export_presets.cfg`
(universal Intel + Apple Silicon binary, ad-hoc signed, `.zip` output).

1. One-time: install the matching export templates — *Editor → Manage Export
   Templates → Download and Install*, or the manual CLI install shown in the
   Linux section above (the path is
   `~/Library/Application Support/Godot/export_templates/4.6.stable` on macOS).
2. Export — *Project → Export → macOS → Export Project*, or:
   ```sh
   godot --headless --export-release "macOS" build/macos/rustpulse.zip
   ```
3. Unzip and launch `RUSTPULSE.app`.

**First launch / Gatekeeper:** the app is ad-hoc signed (not notarized), so
macOS will warn on first open. Either right-click the app → *Open* → *Open*,
or allow it under *System Settings → Privacy & Security → Open Anyway*
(needed on macOS 15+), or clear the quarantine flag from a terminal:

```sh
xattr -cr RUSTPULSE.app
```

This preset also cross-exports from a Linux host (that's how it was verified
here). For public distribution you'd want Developer ID signing + notarization —
see `codesign/*` and `notarization/*` in the preset.

## Windows

A `Windows Desktop` preset is committed as well (x86_64, embedded PCK,
unsigned). Export it the same way:

```sh
godot --headless --export-release "Windows Desktop" build/windows/rustpulse.exe
```

SmartScreen will warn on first run of the unsigned exe — *More info → Run
anyway*.

## CI builds (download & play without installing Godot)

Every push to `master` (and every PR) runs the
[`build` workflow](.github/workflows/build.yml): it executes the headless
smoke test, then exports all three platforms and uploads them as artifacts:

| Artifact | Contents |
|----------|----------|
| `rustpulse-linux-appimage` | `RUSTPULSE-x86_64.AppImage` |
| `rustpulse-macos` | `rustpulse-macos.zip` → `RUSTPULSE.app` (universal, ad-hoc signed) |
| `rustpulse-windows` | `rustpulse.exe` |

Grab them from the **Actions** tab → select a run → *Artifacts*. Notes:

- GitHub artifact downloads are zips that **strip the executable bit** — on
  Linux run `chmod +x RUSTPULSE-x86_64.AppImage` (or `chmod +x` the raw
  binary) after unzipping.
- macOS: unzip the artifact, then unzip the inner `rustpulse-macos.zip` (the
  inner zip preserves the app bundle's permissions), then see the Gatekeeper
  notes above.

## Headless validation / smoke test

A self-checking smoke test exercises the whole game loop (weapons, levels,
evolutions, enemy roster, miniboss crate, level-up UI, pickups, end screen):

```sh
godot --headless res://test/smoke_test.tscn --quit-after 1200
```

It prints `SMOKE OK` on success.

## Save data

Permanent progress lives at `user://meta.json`, i.e.
`~/.local/share/godot/app_userdata/RUSTPULSE/meta.json`. Delete it to reset.

## Project layout

```
docs/DESIGN.md            game design spec
project.godot             project config (inputs, autoloads, GL compatibility)
export_presets.cfg        Linux x86_64 + macOS + Windows export presets
.github/workflows/        CI: smoke test + AppImage/macOS/Windows artifacts
scenes/                   thin scene roots (children are built in code)
scripts/main.gd           run orchestrator: state, queries, spawning services
scripts/player.gd         movement, stats, XP, PS1 robot sprite animation
scripts/enemy.gd          all mutant types: behaviors + PS1 sprite animation
scripts/director.gd       wave scaling, type unlocks, miniboss schedule
scripts/weapons/          weapon base + 5 weapons + friendly projectile
assets/sprites/           generated PS1 character sprite assets
scripts/upgrades.gd       weapon/passive catalog + level-up card generator
scripts/pickups/          XP gems, medkits, scrap, magnets, crates
scripts/ui/               HUD, level-up picker, menus, Workshop
scripts/autoload/meta.gd  permanent unlocks + save/load
test/smoke_test.gd        headless integration test
```
