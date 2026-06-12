extends Node2D
## The run scene: builds the world, tracks run state, and provides
## spatial queries + spawning services to everything else.

const RUN_DURATION := 20.0 * 60.0

const PlayerScript := preload("res://scripts/player.gd")
const DirectorScript := preload("res://scripts/director.gd")
const BackgroundScript := preload("res://scripts/background.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const XpGemScript := preload("res://scripts/pickups/xp_gem.gd")
const PickupScript := preload("res://scripts/pickups/pickup.gd")
const FxScript := preload("res://scripts/fx.gd")
const DamageNumScript := preload("res://scripts/damage_num.gd")

var player: Node2D
var hud: CanvasLayer
var director: Node

var enemies_node: Node2D
var projectiles_node: Node2D
var pickups_node: Node2D
var fx_node: Node2D

var enemies: Array = []
var run_time := 0.0
var kills := 0
var scrap_earned := 0
var run_over := false
var shake_amount := 0.0


func _ready() -> void:
	var background: Node2D = BackgroundScript.new()
	background.name = "Background"
	background.z_index = -10
	add_child(background)

	pickups_node = Node2D.new()
	pickups_node.name = "Pickups"
	add_child(pickups_node)

	enemies_node = Node2D.new()
	enemies_node.name = "Enemies"
	add_child(enemies_node)

	projectiles_node = Node2D.new()
	projectiles_node.name = "Projectiles"
	add_child(projectiles_node)

	player = PlayerScript.new()
	player.name = "Player"
	player.main = self
	add_child(player)

	fx_node = Node2D.new()
	fx_node.name = "FX"
	add_child(fx_node)

	director = DirectorScript.new()
	director.name = "Director"
	director.main = self
	add_child(director)

	hud = HudScript.new()
	hud.name = "HUD"
	hud.main = self
	add_child(hud)

	player.start()


func _physics_process(delta: float) -> void:
	if run_over:
		return
	run_time += delta
	if run_time >= RUN_DURATION:
		end_run(true)
		return
	# Drop dead enemies from the live list once per frame.
	var alive: Array = []
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			alive.append(e)
	enemies = alive
	# Camera shake decay.
	if shake_amount > 0.0:
		shake_amount = maxf(shake_amount - 30.0 * delta, 0.0)
		player.camera.offset = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount))
	else:
		player.camera.offset = Vector2.ZERO


func add_shake(amount: float) -> void:
	shake_amount = minf(shake_amount + amount, 14.0)


# ---------------------------------------------------------------- queries

func nearest_enemy(from: Vector2, max_range: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_range * max_range
	for e in enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = from.distance_squared_to(e.position)
		if d < best_d:
			best_d = d
			best = e
	return best


func enemies_in_range(from: Vector2, radius: float) -> Array:
	var out: Array = []
	var r2 := radius * radius
	for e in enemies:
		if is_instance_valid(e) and not e.dead and from.distance_squared_to(e.position) < r2:
			out.append(e)
	return out


func random_enemy_in_range(from: Vector2, radius: float) -> Node2D:
	var c := enemies_in_range(from, radius)
	if c.is_empty():
		return null
	return c.pick_random()


func densest_cluster_pos(from: Vector2, max_range: float) -> Vector2:
	## Sample a handful of enemies and pick the one with the most neighbors.
	var candidates := enemies_in_range(from, max_range)
	if candidates.is_empty():
		return from
	var best: Node2D = candidates[0]
	var best_score := -1
	for i in mini(candidates.size(), 8):
		var c: Node2D = candidates.pick_random()
		var score := 0
		for e in candidates:
			if c.position.distance_squared_to(e.position) < 120.0 * 120.0:
				score += 1
		if score > best_score:
			best_score = score
			best = c
	return best.position


# ---------------------------------------------------------------- spawning

func register_enemy(e: Node2D) -> void:
	enemies.append(e)
	enemies_node.add_child(e)


func on_enemy_killed(_e: Node2D) -> void:
	kills += 1


func spawn_xp(pos: Vector2, value: float) -> void:
	# Cap live gems: fold value into an existing gem instead of spawning more.
	var gems := get_tree().get_nodes_in_group("xp_gems")
	if gems.size() >= 400:
		var g: Node2D = gems.pick_random()
		g.value += value
		g.queue_redraw()
		return
	var gem: Node2D = XpGemScript.new()
	gem.main = self
	gem.value = value
	gem.position = pos + Vector2(randf_range(-6, 6), randf_range(-6, 6))
	pickups_node.add_child(gem)


func spawn_pickup(kind: String, pos: Vector2, value: int = 0) -> void:
	var p: Node2D = PickupScript.new()
	p.main = self
	p.kind = kind
	p.value = value
	p.position = pos
	pickups_node.add_child(p)


func spawn_fx(kind: String, pos: Vector2, radius: float = 24.0, color: Color = Color.WHITE, points: PackedVector2Array = PackedVector2Array()) -> void:
	var fx: Node2D = FxScript.new()
	fx.main = self
	fx.kind = kind
	fx.radius = radius
	fx.color = color
	fx.points = points
	fx.position = pos
	fx_node.add_child(fx)


func add_damage_number(pos: Vector2, amount: float, color: Color = Color(1, 0.9, 0.5)) -> void:
	if fx_node.get_child_count() > 220:
		return
	var n: Node2D = DamageNumScript.new()
	n.text = str(int(roundf(amount)))
	n.color = color
	n.position = pos + Vector2(randf_range(-8, 8), -10)
	fx_node.add_child(n)


func explode(pos: Vector2, radius: float, damage: float, burn: bool = false, burn_dps: float = 0.0) -> void:
	for e in enemies_in_range(pos, radius):
		e.take_damage(damage, pos)
	spawn_fx("ring", pos, radius, Color(0.4, 0.9, 1.0) if not burn else Color(1.0, 0.6, 0.2))
	add_shake(4.0)
	if burn:
		var fx: Node2D = FxScript.new()
		fx.main = self
		fx.kind = "burn"
		fx.radius = radius * 0.9
		fx.color = Color(1.0, 0.45, 0.1)
		fx.life = 3.0
		fx.burn_dps = burn_dps
		fx.position = pos
		fx_node.add_child(fx)


# ---------------------------------------------------------------- crates / end

func open_crate() -> void:
	for w in player.weapons:
		if w.can_evolve():
			w.evolve()
			hud.show_banner("WEAPON EVOLVED: %s" % w.display_name)
			spawn_fx("ring", player.position, 90.0, Color(1, 0.85, 0.3))
			return
	scrap_earned += 50
	hud.show_banner("SUPPLY CRATE: +50 SCRAP")


func end_run(victory: bool) -> void:
	if run_over:
		return
	run_over = true
	if victory:
		scrap_earned += 200
	Meta.record_run(run_time, kills, scrap_earned, victory)
	hud.show_end_screen(victory)
