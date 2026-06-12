# RUSTPULSE — Game Design Spec

A 2D top-down survivor-like (Vampire Survivors-inspired) built in Godot 4.6 for
Linux desktop. You are **UNIT-7**, a maintenance robot in a post-apocalyptic
wasteland, holding out against endless waves of human-like mutants.

## Pillars

1. **Movement is the only input.** All weapons fire automatically; skill is
   positioning, routing through hordes, and build choices.
2. **Readable chaos.** Every enemy type has a distinct silhouette and a
   color-coded attack style so a screen full of mutants stays parseable.
3. **A run is 20 minutes.** Difficulty scales on a timer; survive to win.
4. **Death still pays.** Scrap earned in a run buys permanent unlocks.

## Player

- **Character:** UNIT-7, a squat orange service robot with treads, cyan optics,
  and a side weapon pod. Drawn from a generated PS1-style sprite.
- **Controls:** WASD / arrow keys / gamepad left stick — movement only.
  `Esc` pauses. Menus are mouse/keyboard driven.
- **Base stats:** 100 HP, 0 regen, 0 armor, 150 px/s move speed, 60 px pickup
  radius. Brief invulnerability flash (0.4 s) after taking a hit.
- **Stats modified by upgrades:** max HP, regen, armor (flat damage reduction,
  min 1 damage taken), move speed, pickup radius, damage %, attack speed %,
  cooldown %, area %, +projectiles, +pierce.

## Enemy roster (human-like mutants, color-coded)

| Enemy        | Color        | Silhouette           | Behavior |
|--------------|--------------|----------------------|----------|
| **Shambler** | sickly green | hunched, dragging arms | Slow chaser, contact damage. Backbone of every wave. |
| **Sprinter** | yellow       | tall, lanky, thin limbs | Fast and frail; lunges in straight bursts at the player. |
| **Spitter**  | purple       | bulbous head, squat   | Keeps ~260 px distance and lobs acid globs (purple projectiles). |
| **Brute**    | red          | broad shoulders, massive arms | Tanky; telegraphs (flashes) then charges in a straight line. |
| **Alpha (miniboss)** | type color, larger + crown spikes | 2.5× scale | Scaled-up variant of a base type with a boss HP bar. Spawns at 3:00, 7:00, 11:00, 15:00, 19:00. Drops a **supply crate** (weapon evolution or scrap). |

Spawn director (time-based): Shamblers from 0:00, Sprinters from 1:00,
Spitters from 2:30, Brutes from 4:30. Spawn interval shrinks and enemy
HP/damage multipliers grow continuously with run time. Hard cap ~240 live
enemies (oldest far-off-screen enemies are recycled). Survive **20:00** to win.

## Weapon roster (auto-attacking; max 4 weapon slots)

| Weapon | Behavior | Evolution (max level + paired passive) |
|--------|----------|----------------------------------------|
| **Rivet Gun** (starter) | Fires rivets at the nearest enemy. | + *Tungsten Rounds* → **Railspike Driver**: high-damage piercing spikes. |
| **Scrap Saw** | Saw blades orbit the player. | + *Reactive Plating* → **Buzzkill Halo**: more, bigger, faster blades. |
| **Tesla Arc** | Zaps a random nearby enemy, chains to neighbors. | + *Capacitor Bank* → **Storm Coil**: longer chains, rapid cadence. |
| **Plasma Mortar** | Lobs an AoE shell at the densest cluster. | + *Wide-Area Emitter* → **Sunfire Battery**: bigger blasts that leave burning ground. |
| **Nano Swarm** | Launches homing nano-drones. | + *Targeting Matrix* → **Gray Goo**: bigger volleys, drones pierce. |

Weapons level 1→8 via level-up picks. Evolution requires the weapon at max
level **and** owning its paired passive; it is then offered by the next
miniboss **supply crate** (or as a level-up card).

## Passive upgrades (max 4 passive slots, 5 levels each unless noted)

| Passive | Effect / level |
|---------|----------------|
| **Servo Overclock** | +8% attack speed (fire rate) |
| **Capacitor Bank** | −6% weapon cooldown |
| **Reinforced Chassis** | +20 max HP (heals the same amount) |
| **Auto-Repair Nanites** | +0.4 HP/s regen |
| **Reactive Plating** | +1 armor |
| **Targeting Matrix** | +1 projectile (2 levels) |
| **Tungsten Rounds** | +1 pierce (3 levels) |
| **Wide-Area Emitter** | +10% area of effect |
| **Power Core** | +8% damage |
| **Hydraulic Legs** | +8% move speed |
| **Magnet Coil** | +20% pickup radius |

## Progression loop

1. Kill mutants → they drop **XP gems** (cyan shards; auto-collected within
   pickup radius). Rarely drop **scrap nuggets** (meta currency) and
   **medkits** (+25% HP).
2. XP bar fills → **level up**: game pauses, pick 1 of 3 cards (new weapon,
   weapon level, new passive, passive level, or an evolution if eligible).
   Filled slots constrain offers; if everything is maxed, cards become
   25 scrap each.
3. Minibosses drop **supply crates**: evolve an eligible weapon, else +50 scrap.
4. Run ends at death or 20:00 survival (victory). Scrap is banked either way
   (victory pays +200 bonus).
5. **Workshop (permanent unlocks, between runs):** spend scrap on tiered
   permanent stat upgrades — Max HP (5 tiers), Damage (5), Move Speed (3),
   Armor (3), Regen (3), Magnet (3), Starting Choices +1 (1 tier: level-up
   offers 4 cards). Saved to `user://meta.json`.

## Presentation

- Characters use generated PS1-style animated sprites with nearest-neighbor
  filtering, strong silhouettes, crunchy texture detail, and color-coded enemy
  reads. Backgrounds, props, pickups, weapons, effects, and UI use the same
  generated crunchy wasteland/industrial sprite language.
- Game feel: hit flashes, floating damage numbers, screen shake on big hits,
  enemy death "pop", XP vacuum effect.
- Resolution 1280×720, `canvas_items` stretch, integer-friendly UI.

## Scene tree

```
MainMenu.tscn  (Control + main_menu.gd; builds UI in code)
 └─ Title / Start / Workshop / Quit / scrap label

Workshop.tscn  (Control + workshop.gd; permanent unlock shop)

Main.tscn      (Node2D + main.gd — the run; children built in code)
 ├─ Background        (debris/cracked-earth drawer, follows camera)
 ├─ Player            (player.gd; Camera2D child; WeaponHolder child)
 │    └─ Weapons[]    (weapon_base.gd subclasses; fire on cooldown)
 ├─ Director          (director.gd; spawning, scaling, minibosses)
 ├─ Projectiles/Enemies/Pickups/FX  (plain Node2D buckets, manual
 │                                   circle-collision via squared distances —
 │                                   no physics engine needed at this scale)
 └─ HUD (CanvasLayer) (hp/xp bars, timer, kills, scrap, level)
      ├─ LevelUpPanel (pauses tree, 3–4 cards)
      ├─ PauseMenu / GameOver / Victory overlays
```

Autoloads: `Meta` (permanent unlocks + save/load), `Rng` (seeded helpers).

## Milestones

1. Spec (this document).
2. Project skeleton: project.godot, player movement, camera, wasteland background.
3. Enemies, spawn director, manual collision, XP/level-up loop.
4. Full weapon + passive rosters, evolutions, minibosses, crates, pickups.
5. HUD, level-up UI, pause, game over/victory, damage numbers, shake.
6. Menus, Workshop, persistent saves.
7. Linux export preset, headless validation, export docs, release build.

## Linux export workflow

- Editor: **Project → Export → Add → Linux**, or use the committed
  `export_presets.cfg` (preset 0, `x86_64`, PCK embedded).
- Headless/CI:
  ```sh
  godot --headless --import                      # first import
  godot --headless --export-release "Linux x86_64" build/linux/rustpulse.x86_64
  ```
  Requires export templates matching the editor version
  (`godot --headless --install-export-templates <tpz>` or Editor → Manage
  Export Templates).
- Output is a self-contained native ELF binary (`chmod +x`, run anywhere with
  X11/Wayland + Vulkan or GLES3). Full steps in README.md.
