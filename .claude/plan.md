# RUSTPULSE — Project Plan & Working Notes

Context file for future development sessions. Read this before changing code.
The full game design spec lives in `docs/DESIGN.md`; the player-facing docs
(run/export instructions for Linux and macOS) are in `README.md`. The
prioritized improvement roadmap is in `.claude/next-steps.md`.

## What this is

A complete, working Vampire Survivors-style 2D survivor-like in **Godot 4.4**
(GDScript only, GL Compatibility renderer). Linux is the primary target with a
verified headless export pipeline; a macOS preset is also committed and was
verified by cross-exporting from Linux.

## Architecture (the parts you need to know before editing)

- **Scenes are thin.** Every `.tscn` is just a root node + script; all
  children are built in `_ready()`. Don't add node trees to the `.tscn`
  files — build them in code like everything else.
- **No physics engine.** Collisions are manual circle checks using squared
  distances. `scripts/main.gd` owns the live `enemies` array and provides all
  spatial queries (`nearest_enemy`, `enemies_in_range`,
  `densest_cluster_pos`). Enemies mark themselves `dead = true` and are
  filtered out of the array once per frame by `main._physics_process` — never
  erase from `main.enemies` mid-iteration.
- **All art is procedural `_draw()`.** No textures or binary assets exist in
  the repo (only `icon.svg`). Keep it that way unless a milestone explicitly
  introduces an asset pipeline.
- **Service locator pattern:** every spawned node gets `main` (and weapons
  also get `player`) assigned before `add_child`. `Meta` is the only
  autoload (permanent unlocks, JSON save at `user://meta.json`).
- **Weapons** extend `scripts/weapons/weapon_base.gd`: override `cooldown()`,
  `fire()`, `upgrade_desc()`, and per-level stat functions. Scrap Saw is the
  exception — it overrides `_physics_process` entirely (continuous orbit
  damage, no fire/cooldown loop).
- **Upgrade catalog** (`scripts/upgrades.gd`) is the single source of truth
  for weapon/passive IDs, names, evolution pairings, and the level-up card
  generator. Adding a weapon = new script in `scripts/weapons/` + one entry
  in `Upgrades.WEAPONS` + (usually) a paired passive.
- **GDScript gotcha that bit us:** `:=` cannot infer from Variant
  expressions (e.g. anything read off an untyped `player`/`e` reference).
  Use explicit types (`var x: float = e.radius + 1.0`). Also: it's `sin()` /
  `cos()`, not `sinf()`/`cosf()` (the `f`-suffix only exists for
  `maxf`/`minf`/`clampf`/`absf`/`signf`/`lerpf`...).

## Validation workflow (run before every commit)

```sh
godot --headless --import                                    # parse everything
godot --headless res://test/smoke_test.tscn --quit-after 1200  # must print SMOKE OK
godot --headless --export-release "Linux x86_64" build/linux/rustpulse.x86_64
```

The smoke test (`test/smoke_test.gd`) is a frame-staged driver that exercises
all weapons, max levels, evolutions, the enemy roster, the alpha crate, the
level-up UI, pickups, and the end screen with 21 assertions. **Extend it when
adding systems** — it is the only automated safety net.

For longer balance/stability sims:
`godot --headless res://scenes/main.tscn --fixed-fps 60 --quit-after N`
(player stands still and dies; good for spawn-curve and error checking).

## Known caveats / current state

- Balance is formula-tuned, not playtested. Spawn curve in
  `scripts/director.gd` (`spawn_interval`, `hp_mult`, `batch_size`), XP curve
  in `player.xp_for_level`, weapon numbers in each weapon script.
- No audio at all yet (deliberately deferred — see next-steps).
- No object pooling; damage numbers are capped (220 FX children) and gems are
  merged past 400. Fine so far; revisit if perf dips with evolved builds.
- UI is keyboard/mouse; gamepad moves the player but cannot navigate menus.
- `build/` and `.godot/` are gitignored; exported artifacts are never
  committed.
