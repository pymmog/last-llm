# RUSTPULSE — Next Steps (prioritized)

Roadmap to take the game from "complete and working" to "genuinely good".
Each item is scoped to be a self-contained session of work. Update this file
as items land.

## P1 — Make it feel good (highest value per hour)

1. **Real balance pass.** Play full 20-minute runs. Tune
   `director.gd` spawn/HP curves, `player.xp_for_level`, and per-weapon
   numbers so that: minutes 0–2 feel dangerous-but-fair, an unupgraded player
   dies around minute 4–6, and a well-built run wins with tension at 18:00+.
   Consider a difficulty spike right before each alpha spawn.
2. **Audio.** Still zero sound. Options, in order of preference:
   (a) tiny CC0 SFX set (kenney.nl) + a `Sound` autoload with pooled
   `AudioStreamPlayer`s; (b) procedural blips via `AudioStreamGenerator`.
   Needs: hit, kill, level-up, pickup, evolve fanfare, player-hurt, UI click,
   plus one looping wasteland-wind ambience. Add volume sliders (see #3).
3. **Settings menu.** Master/SFX volume, fullscreen toggle, screen-shake
   toggle (accessibility), and a "reset save" button. Persist alongside the
   existing `Meta` save.
4. **More juice.** 1–2 frame hit-stop on big hits, enemy knockback on hit
   (the `take_damage(amount, from)` signature already carries the source
   position — currently unused), corpse fade-out instead of instant pop,
   directional damage flash on the HUD when hurt off-screen.

## P2 — Content depth

5. **2–3 new weapons + evolutions.** Candidates from the spec's style:
   Flamethrower cone (DoT), Boomerang blade (out-and-back pierce), Guardian
   turret (stationary, fires while you kite). Pattern: new script extending
   `weapon_base.gd` + entry in `Upgrades.WEAPONS` + smoke-test coverage.
6. **2 new enemy types.** Screamer (cyan): buffs nearby mutants' speed —
   priority target, distinct audio cue. Bloater (orange): slow, explodes on
   death leaving an acid pool (reuse the `burn` FX with a green palette).
7. **Multiple playable characters.** 2–3 robots with different base stats and
   starting weapons (e.g. heavy unit starts with Scrap Saw, +armor, -speed).
   Unlock via Workshop scrap. Character select on the main menu.
8. **Achievement-driven unlocks** (the VS hook): weapons start locked and
   join the in-run pool via feats ("kill 1000 shamblers", "survive 10:00
   without taking damage"). Track counters in `Meta`.
9. **A real final boss at 20:00** instead of a timer cutoff — survive the
   timer, then a multi-phase alpha with telegraphed patterns guards the
   victory screen.

## P3 — Platform & distribution

10. **CI.** GitHub Actions workflow: cache the Godot binary + templates, run
    `--import` and the smoke test on every push, produce Linux/macOS export
    artifacts on tags. The exact commands are in README and `.claude/plan.md`.
11. **Windows preset** (`export_presets.cfg` preset.2) — trivial since the
    project is pure GDScript; verify via cross-export like macOS was.
12. **Packaging:** itch.io butler push for all three OSes; optionally a
    Flatpak manifest for Linux. macOS notarization if distributing outside
    itch.
13. **Gamepad menu navigation** (UI focus neighbors + accept/cancel actions)
    and key rebinding screen.

## P4 — Tech debt / performance (only when needed)

14. **Spatial hash grid** for `enemies_in_range`/projectile collision if
    late-game frame times degrade (current manual O(n·m) scan is fine at the
    240-enemy cap with typical projectile counts).
15. **Object pooling** for projectiles, damage numbers, and FX nodes.
16. **Refactor `enemy.gd`** if the roster grows past ~7 types — split
    behaviors ("brains") into small strategy objects instead of the `match`
    blocks.
17. **Migrate magic numbers to a balance resource** (one `balance.gd` const
    table or custom Resource) so tuning passes don't touch five files.

## Done

- ✅ Design spec, full game loop, 5 weapons + evolutions, 4 enemy types +
  alphas, 11 passives, Workshop meta progression (2026-06)
- ✅ Linux export preset + verified native build; headless smoke test (2026-06)
- ✅ macOS export preset, verified via Linux cross-export; macOS player
  instructions in README (2026-06)
