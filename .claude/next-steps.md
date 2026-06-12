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
   (Needs human playtesting — the only P1 item left.)

## P2 — Content depth

2. **2–3 new weapons + evolutions.** Candidates from the spec's style:
   Flamethrower cone (DoT), Boomerang blade (out-and-back pierce), Guardian
   turret (stationary, fires while you kite). Pattern: new script extending
   `weapon_base.gd` + entry in `Upgrades.WEAPONS` + smoke-test coverage.
3. **2 new enemy types.** Screamer (cyan): buffs nearby mutants' speed —
   priority target, distinct audio cue. Bloater (orange): slow, explodes on
   death leaving an acid pool (reuse the `burn` FX with a green palette).
4. **Multiple playable characters.** 2–3 robots with different base stats and
   starting weapons (e.g. heavy unit starts with Scrap Saw, +armor, -speed).
   Unlock via Workshop scrap. Character select on the main menu.
5. **Achievement-driven unlocks** (the VS hook): weapons start locked and
   join the in-run pool via feats ("kill 1000 shamblers", "survive 10:00
   without taking damage"). Track counters in `Meta` (`total_kills` etc.
   already persisted there).
6. **A real final boss at 20:00** instead of a timer cutoff — survive the
   timer, then a multi-phase alpha with telegraphed patterns guards the
   victory screen.

## P3 — Platform & distribution

7. **Packaging/distribution:** itch.io butler push for all three OSes
   (CI artifacts exist; wire butler into the workflow on tags); optionally a
   Flatpak manifest for Linux. macOS notarization and Windows signing if
   distributing outside itch.
8. **Key rebinding screen.** (Gamepad/keyboard menu navigation is done:
   focus seeding on every panel, d-pad + left stick on the ui_* actions,
   B/Esc backs out of menus.)

## P4 — Tech debt / performance (only when needed)

9. **Spatial hash grid** for `enemies_in_range`/projectile collision if
   late-game frame times degrade (enemy-vs-enemy separation already uses one
   in `main.gd::_separate_enemies`; the weapon-targeting/projectile scans are
   still O(n·m), fine at the 240-enemy cap with typical projectile counts).
10. **Object pooling** for projectiles, damage numbers, and FX nodes.
11. **Refactor `enemy.gd`** if the roster grows past ~7 types — split
    behaviors ("brains") into small strategy objects instead of the `match`
    blocks.
12. **Migrate magic numbers to a balance resource** (one `balance.gd` const
    table or custom Resource) so tuning passes don't touch five files.

## Done

- ✅ Design spec, full game loop, 5 weapons + evolutions, 4 enemy types +
  alphas, 11 passives, Workshop meta progression (2026-06)
- ✅ Linux export preset + verified native build; headless smoke test (2026-06)
- ✅ macOS export preset, verified via Linux cross-export; macOS player
  instructions in README (2026-06)
- ✅ Windows export preset (unsigned, rcedit-free) verified via cross-export;
  GitHub Actions CI: smoke test gate + Linux AppImage / macOS .app / Windows
  .exe artifacts on every master push and PR (2026-06)
- ✅ Audio: fully procedural `Sfx` + `Music` autoloads — 20+ synthesized SFX
  with a pooled/throttled player set, looping dark-synth track generated on a
  worker thread, routed through Music/SFX buses (2026-06)
- ✅ Settings menu: master/music/SFX volume sliders with live buses, screen
  mode, FPS cap, FPS overlay, screen-shake toggle, reset-save button (armed
  two-press confirm); reachable from title and pause (2026-06)
- ✅ Juice: hit-stop on player damage, directional enemy knockback driven by
  the `take_damage(amount, from)` source position, HUD damage flash, corpse
  fade-out on death (2026-06)
- ✅ Gamepad/keyboard menu navigation: focus seeding on every panel, d-pad +
  left stick, B/Esc backs out (2026-06)
