# RUSTPULSE — agent / contributor instructions

A Vampire Survivors-style 2D survivor-like in **Godot 4.6** (pure GDScript,
no Mono, no physics engine). Player-facing docs live in [README.md](../README.md);
the full game design spec is [docs/DESIGN.md](../docs/DESIGN.md); the
prioritized roadmap is [.claude/next-steps.md](../.claude/next-steps.md).

## Architecture

Scenes are thin roots — **all node trees are built in code**. The run scene
(`scenes/main.tscn` + `scripts/main.gd`) assembles everything in `_ready()`.

```
docs/DESIGN.md            game design spec (enemy/weapon/passive rosters, balance intent)
project.godot             inputs, autoloads, GL Compatibility renderer
export_presets.cfg        Linux x86_64 + macOS + Windows export presets
scripts/main.gd           run orchestrator: state, spatial queries, spawning services
scripts/player.gd         movement-only control, live stats, XP, sprite animation
scripts/enemy.gd          all mutant types; override _run_brain()/_drop_loot() for bosses
scripts/director.gd       wave scaling, type unlocks, alpha schedule, start_finale() hook
scripts/upgrades.gd       weapon/passive catalog + level-up card generator
scripts/weapons/          weapon_base.gd + 5 weapons + friendly projectile
scripts/pickups/          XP gems, medkits, scrap, magnets, crates
scripts/ui/               HUD, debug panel, menus, Workshop, shared ui_theme.gd
scripts/draw_util.gd      shared PS1-sprite/ellipse draw statics
scripts/autoload/         Meta (save), Settings, Sfx, Music (all procedural audio)
tools/                    sprite generators, screenshot.gd dev driver
test/smoke_test.gd        self-checking headless integration test
```

Key conventions:

- **Manual circle collision** via squared distances — never add physics bodies.
  Enemy-vs-enemy separation uses a spatial hash in `main.gd::_separate_enemies`.
- Cross-script references go through `main` (every entity holds `var main`);
  scripts are attached with `preload(...)` consts, not `class_name`.
- Visuals are `_draw()`-based with generated sprites
  (`tools/generate_ps1_sprites.gd` family); `texture_filter = NEAREST` everywhere.
- Tabs for indentation; typed GDScript (`:=`, typed params/returns) throughout.
- Enemy/weapon balance numbers live in const tables at the top of their scripts.

## Validation — run before every commit

```sh
godot --headless res://test/smoke_test.tscn --quit-after 1200
```

Prints `OK`-prefixed checks and exits non-zero on failure (`FAIL` lines).
It exercises weapons, evolutions, the enemy roster, alpha crates, level-up UI,
pickups and the end screen. CI gates on it.

Caveats:

- The smoke test writes to the **real** save (`user://meta.json` →
  `~/.local/share/godot/app_userdata/RUSTPULSE/meta.json`; macOS:
  `~/Library/Application Support/Godot/app_userdata/RUSTPULSE/`), inflating
  scrap with every run.
- RNG is unseeded; if a single check fails, rerun before assuming regression.
- First run on a fresh clone needs `godot --headless --import` once.

To verify visually, run the game windowed and capture frames:

```sh
godot -s tools/screenshot.gd -- res://scenes/main.tscn /tmp/shot.png 120
```

## CI

[`build.yml`](workflows/build.yml) runs on every master push / PR:
headless smoke test, then exports **Linux AppImage / macOS .app / Windows .exe**
and uploads them as artifacts. Godot editor + export templates are cached
(key `godot-4.6-stable-v1` — bump when changing `GODOT_VERSION`).

## Export (local)

One-time template install (must match the editor version):

```sh
curl -LO https://github.com/godotengine/godot/releases/download/4.6-stable/Godot_v4.6-stable_export_templates.tpz
unzip Godot_v4.6-stable_export_templates.tpz   # contains templates/
mkdir -p ~/.local/share/godot/export_templates
mv templates ~/.local/share/godot/export_templates/4.6.stable
# macOS path: ~/Library/Application Support/Godot/export_templates/4.6.stable
```

Then:

```sh
godot --headless --import   # first time only
godot --headless --export-release "Linux x86_64"    build/linux/rustpulse.x86_64
godot --headless --export-release "macOS"           build/macos/rustpulse.zip
godot --headless --export-release "Windows Desktop" build/windows/rustpulse.exe
```

All presets embed the PCK (single-file output). Linux uses the GL
Compatibility renderer (OpenGL 3.3, no Vulkan needed). The macOS preset is
universal + ad-hoc signed and cross-exports from Linux; Windows is unsigned.
For public distribution: Developer ID signing/notarization (macOS) and code
signing (Windows) are not set up — see `codesign/*` in the preset.

## Current focus

The end-boss hooks are in place (see roadmap item 6 in
`.claude/next-steps.md`): the 20:00 timer calls `director.start_finale()`;
a boss extends `enemy.gd`, overrides `_run_brain()` for phased patterns and
`_drop_loot()` to call `main.end_run(true)`.

## In-game dev tools

Debug builds: press `?` in a run for the cheat/stats panel
(`scripts/ui/debug_panel.gd`) — god mode, level skips, crate rewards,
live stat readout.
