extends Node
## Spawn director: time-based wave scaling, type unlocks, miniboss schedule,
## and off-screen recycling of stragglers.

const EnemyScript := preload("res://scripts/enemy.gd")

const MAX_ENEMIES := 240
const SPAWN_MARGIN := 60.0    # how far past the view corner enemies appear
const SPAWN_BAND := 120.0     # ring thickness

# Alpha miniboss schedule: one scaled-up variant at each timestamp.
const ALPHA_SCHEDULE := [
	{"time": 180.0, "type": "shambler"},
	{"time": 420.0, "type": "sprinter"},
	{"time": 660.0, "type": "spitter"},
	{"time": 900.0, "type": "brute"},
	{"time": 1140.0, "type": "brute"},
]

var main: Node2D
var spawn_timer := 0.5
var recycle_timer := 1.0
var alpha_index := 0
var opening_done := false
var finale_active := false


func _physics_process(delta: float) -> void:
	if main.run_over:
		return
	var t: float = main.run_time
	if not opening_done:
		# Opening wave: immediate pressure instead of waiting for the timer.
		opening_done = true
		for i in 5:
			spawn("shambler", false)
	if not finale_active:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_timer = spawn_interval(t)
			for i in batch_size(t):
				if main.enemies.size() >= MAX_ENEMIES:
					break
				spawn(pick_type(t), false)
		if alpha_index < ALPHA_SCHEDULE.size() and t >= ALPHA_SCHEDULE[alpha_index]["time"]:
			var atype: String = ALPHA_SCHEDULE[alpha_index]["type"]
			spawn(atype, true)
			main.hud.show_banner("ALPHA %s INBOUND" % atype.to_upper())
			alpha_index += 1
	recycle_timer -= delta
	if recycle_timer <= 0.0:
		recycle_timer = 1.0
		recycle_stragglers()


func start_finale() -> void:
	## Called by main when the run timer elapses. Wave spawning stops here;
	## for now surviving the timer is an instant win. The planned final boss
	## (next-steps #6) spawns here instead and calls main.end_run(true) from
	## its _drop_loot()/death override.
	finale_active = true
	main.end_run(true)


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


func spawn_min_dist() -> float:
	## Half the camera view's diagonal plus a margin: the closest distance
	## from the player that is guaranteed to be off-screen in any direction.
	## Used as the recycle threshold, not for spawning.
	var view: Vector2 = get_viewport().get_visible_rect().size / main.player.camera.zoom
	return view.length() * 0.5 + SPAWN_MARGIN


func edge_dist(a: float) -> float:
	## Distance from the player to the view-rect edge along direction a,
	## so spawns hug the screen instead of sitting on the far diagonal ring.
	var half: Vector2 = get_viewport().get_visible_rect().size / main.player.camera.zoom * 0.5
	return minf(half.x / maxf(absf(cos(a)), 0.001), half.y / maxf(absf(sin(a)), 0.001))


func ring_position() -> Vector2:
	var a := randf() * TAU
	var min_d := edge_dist(a) + SPAWN_MARGIN
	var d := randf_range(min_d, min_d + SPAWN_BAND)
	return main.player.position + Vector2(cos(a), sin(a)) * d


func recycle_stragglers() -> void:
	## Enemies left far behind get teleported back to the spawn ring,
	## keeping pressure on without unbounded wandering.
	var p: Vector2 = main.player.position
	var limit := spawn_min_dist() + SPAWN_BAND + 280.0
	for e in main.enemies:
		if not is_instance_valid(e) or e.dead or e.is_alpha:
			continue
		if e.position.distance_squared_to(p) > limit * limit:
			e.position = ring_position()
