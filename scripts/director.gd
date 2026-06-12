extends Node
## Spawn director: time-based wave scaling, type unlocks, miniboss schedule,
## and off-screen recycling of stragglers.

const EnemyScript := preload("res://scripts/enemy.gd")

const MAX_ENEMIES := 240
const SPAWN_DIST_MIN := 520.0
const SPAWN_DIST_MAX := 640.0

const BOSS_TIMES := [180.0, 420.0, 660.0, 900.0, 1140.0]
const BOSS_TYPES := ["shambler", "sprinter", "spitter", "brute", "brute"]

var main: Node2D
var spawn_timer := 1.0
var recycle_timer := 1.0
var boss_index := 0


func _physics_process(delta: float) -> void:
	if main.run_over:
		return
	var t: float = main.run_time
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = spawn_interval(t)
		for i in batch_size(t):
			if main.enemies.size() >= MAX_ENEMIES:
				break
			spawn(pick_type(t), false)
	if boss_index < BOSS_TIMES.size() and t >= BOSS_TIMES[boss_index]:
		spawn(BOSS_TYPES[boss_index], true)
		main.hud.show_banner("ALPHA %s INBOUND" % BOSS_TYPES[boss_index].to_upper())
		boss_index += 1
	recycle_timer -= delta
	if recycle_timer <= 0.0:
		recycle_timer = 1.0
		recycle_stragglers()


func spawn_interval(t: float) -> float:
	return lerpf(1.3, 0.28, clampf(t / 900.0, 0.0, 1.0))


func batch_size(t: float) -> int:
	return clampi(1 + int(t / 150.0), 1, 7)


func hp_mult(t: float) -> float:
	var m := t / 60.0
	return 1.0 + m * 0.22 + pow(m, 1.4) * 0.03


func dmg_mult(t: float) -> float:
	return 1.0 + (t / 60.0) * 0.05


func pick_type(t: float) -> String:
	var weights := {"shambler": 100.0}
	if t > 60.0:
		weights["sprinter"] = minf(10.0 + t / 12.0, 55.0)
	if t > 150.0:
		weights["spitter"] = minf(8.0 + t / 18.0, 40.0)
	if t > 270.0:
		weights["brute"] = minf(4.0 + t / 40.0, 25.0)
	var total := 0.0
	for k in weights:
		total += weights[k]
	var roll := randf() * total
	for k in weights:
		roll -= weights[k]
		if roll <= 0.0:
			return k
	return "shambler"


func spawn(etype: String, alpha: bool) -> void:
	var e: Node2D = EnemyScript.new()
	var t: float = main.run_time
	e.setup(main, etype, ring_position(), hp_mult(t), dmg_mult(t), alpha)
	main.register_enemy(e)


func ring_position() -> Vector2:
	var a := randf() * TAU
	var d := randf_range(SPAWN_DIST_MIN, SPAWN_DIST_MAX)
	return main.player.position + Vector2(cos(a), sin(a)) * d


func recycle_stragglers() -> void:
	## Enemies left far behind get teleported back to the spawn ring,
	## keeping pressure on without unbounded wandering.
	var p: Vector2 = main.player.position
	for e in main.enemies:
		if not is_instance_valid(e) or e.dead or e.is_alpha:
			continue
		if e.position.distance_squared_to(p) > 950.0 * 950.0:
			e.position = ring_position()
