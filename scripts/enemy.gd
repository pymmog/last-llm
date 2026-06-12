extends Node2D
## Human-like mutants. One script drives all types; behavior and silhouette
## switch on `type`. Alphas are scaled-up minibosses that drop supply crates.
## Subclass hooks for special enemies (e.g. the final boss): override
## _run_brain() for behavior and _drop_loot() for death rewards.

const EnemyProjectileScript := preload("res://scripts/enemy_projectile.gd")
const PS1_WALK_FRAMES := {
	"shambler": [
		preload("res://assets/sprites/shambler_walk_0.png"),
		preload("res://assets/sprites/shambler_walk_1.png"),
		preload("res://assets/sprites/shambler_walk_2.png"),
		preload("res://assets/sprites/shambler_walk_3.png"),
	],
	"sprinter": [
		preload("res://assets/sprites/sprinter_walk_0.png"),
		preload("res://assets/sprites/sprinter_walk_1.png"),
		preload("res://assets/sprites/sprinter_walk_2.png"),
		preload("res://assets/sprites/sprinter_walk_3.png"),
	],
	"spitter": [
		preload("res://assets/sprites/spitter_walk_0.png"),
		preload("res://assets/sprites/spitter_walk_1.png"),
		preload("res://assets/sprites/spitter_walk_2.png"),
		preload("res://assets/sprites/spitter_walk_3.png"),
	],
	"brute": [
		preload("res://assets/sprites/brute_walk_0.png"),
		preload("res://assets/sprites/brute_walk_1.png"),
		preload("res://assets/sprites/brute_walk_2.png"),
		preload("res://assets/sprites/brute_walk_3.png"),
	],
}
const PS1_HEIGHTS := {
	"shambler": 38.0,
	"sprinter": 40.0,
	"spitter": 36.0,
	"brute": 48.0,
}

const TYPES := {
	"shambler": {"hp": 15.0, "speed": 52.0, "dmg": 8.0, "radius": 11.0, "xp": 1.0,
		"color": Color(0.45, 0.72, 0.30), "scrap_chance": 0.03},
	"sprinter": {"hp": 9.0, "speed": 78.0, "dmg": 6.0, "radius": 9.0, "xp": 1.5,
		"color": Color(0.92, 0.80, 0.25), "scrap_chance": 0.04},
	"spitter": {"hp": 14.0, "speed": 44.0, "dmg": 7.0, "radius": 10.0, "xp": 2.0,
		"color": Color(0.64, 0.36, 0.80), "scrap_chance": 0.05},
	"brute": {"hp": 85.0, "speed": 38.0, "dmg": 18.0, "radius": 16.0, "xp": 6.0,
		"color": Color(0.84, 0.26, 0.20), "scrap_chance": 0.35},
}

# Multipliers applied on top of the base type when spawned as an alpha miniboss.
const ALPHA_MODS := {
	"hp": 16.0,
	"dmg": 1.6,
	"radius": 2.2,
	"speed": 0.85,
	"xp": 10.0,
	"draw_scale": 2.4,
}

var main: Node2D
var type := "shambler"
var hp := 10.0
var max_hp := 10.0
var speed := 50.0
var dmg := 5.0
var radius := 10.0
var xp_value := 1.0
var color := Color.GREEN
var is_alpha := false
var dead := false

var flash := 0.0
var knockback := Vector2.ZERO
var attack_cd := 0.0
var state := "walk"
var state_t := 0.0
var charge_dir := Vector2.ZERO
var shoot_cd := 2.0
var wobble := 0.0
var anim_t := 0.0
var draw_scale := 1.0


func setup(m: Node2D, etype: String, pos: Vector2, hp_mult: float, dmg_mult: float, alpha: bool = false) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	main = m
	type = etype
	position = pos
	var d: Dictionary = TYPES[etype]
	max_hp = d["hp"] * hp_mult
	speed = d["speed"]
	dmg = d["dmg"] * dmg_mult
	radius = d["radius"]
	xp_value = d["xp"]
	color = d["color"]
	is_alpha = alpha
	if alpha:
		max_hp *= ALPHA_MODS["hp"]
		dmg *= ALPHA_MODS["dmg"]
		radius *= ALPHA_MODS["radius"]
		speed *= ALPHA_MODS["speed"]
		xp_value *= ALPHA_MODS["xp"]
		draw_scale = ALPHA_MODS["draw_scale"]
	hp = max_hp
	wobble = randf() * TAU
	anim_t = randf() * TAU


func _physics_process(delta: float) -> void:
	if dead or main.run_over:
		return
	var player: Node2D = main.player
	var to_player: Vector2 = player.position - position
	var dist := to_player.length()
	flash = maxf(flash - delta, 0.0)
	attack_cd = maxf(attack_cd - delta, 0.0)
	state_t += delta
	anim_t += delta * 8.0

	_run_brain(to_player, dist, delta)

	# Knockback from weapon hits decays exponentially.
	if knockback != Vector2.ZERO:
		position += knockback * delta
		knockback *= maxf(1.0 - 8.0 * delta, 0.0)

	# Solid bodies: never overlap the player, stop at its edge.
	var sep := position - player.position
	var min_dist: float = radius + player.radius
	if sep.length_squared() < min_dist * min_dist:
		var d := sep.length()
		var away := sep / d if d > 0.001 else Vector2.from_angle(randf() * TAU)
		position = player.position + away * min_dist
		dist = min_dist

	# Contact damage.
	if attack_cd <= 0.0 and dist < radius + player.radius + 2.0:
		player.take_damage(dmg, position)
		attack_cd = 0.8
	queue_redraw()


func _run_brain(to_player: Vector2, dist: float, delta: float) -> void:
	## Per-type movement/attack behavior. Subclasses override this.
	match type:
		"shambler":
			_shambler_brain(to_player, delta)
		"sprinter":
			_sprinter_brain(to_player, delta)
		"spitter":
			_spitter_brain(to_player, dist, delta)
		"brute":
			_brute_brain(to_player, delta)


func _shambler_brain(to_player: Vector2, delta: float) -> void:
	var side := to_player.orthogonal().normalized() * sin(anim_t * 0.4 + wobble) * 12.0
	position += (to_player.normalized() * speed + side) * delta


func _sprinter_brain(to_player: Vector2, delta: float) -> void:
	match state:
		"walk":
			position += to_player.normalized() * speed * delta
			if state_t > 1.2 and to_player.length() < 320.0:
				state = "aim"
				state_t = 0.0
		"aim":
			if state_t > 0.55:
				state = "lunge"
				state_t = 0.0
				charge_dir = to_player.normalized()
		"lunge":
			position += charge_dir * speed * 3.2 * delta
			if state_t > 0.45:
				state = "walk"
				state_t = 0.0


func _spitter_brain(to_player: Vector2, dist: float, delta: float) -> void:
	var n := to_player.normalized()
	if dist > 290.0:
		position += n * speed * delta
	elif dist < 180.0:
		position -= n * speed * 0.8 * delta
	else:
		position += n.orthogonal() * sin(wobble) * speed * 0.4 * delta
	shoot_cd -= delta
	if shoot_cd <= 0.0 and dist < 340.0:
		shoot_cd = 2.4
		var glob: Node2D = EnemyProjectileScript.new()
		glob.main = main
		glob.position = position
		glob.vel = n * 175.0
		glob.dmg = dmg * 1.2
		glob.color = color
		main.projectiles_node.add_child(glob)
		Sfx.play("spit", -8.0)


func _brute_brain(to_player: Vector2, delta: float) -> void:
	match state:
		"walk":
			position += to_player.normalized() * speed * delta
			if state_t > 4.0 and to_player.length() < 360.0:
				state = "telegraph"
				state_t = 0.0
		"telegraph":
			flash = 0.1
			if state_t > 0.7:
				state = "charge"
				state_t = 0.0
				charge_dir = to_player.normalized()
		"charge":
			position += charge_dir * speed * 3.4 * delta
			if state_t > 1.0:
				state = "walk"
				state_t = 0.0


func take_damage(amount: float, from: Vector2 = Vector2.ZERO) -> void:
	if dead:
		return
	hp -= amount
	flash = 0.12
	Sfx.play("enemy_hit", -10.0)
	if from != Vector2.ZERO and from != position:
		var away := (position - from).normalized()
		var kb := 140.0 * clampf(amount / max_hp, 0.08, 0.6)
		knockback += away * (kb * 0.25 if is_alpha else kb)
		main.spawn_fx("spark", position, radius * 0.8, color.lightened(0.3), PackedVector2Array(), away)
	main.add_damage_number(position - Vector2(0, radius), amount)
	if hp <= 0.0:
		die()


func die() -> void:
	dead = true
	Sfx.play("enemy_die", -7.0, 0.6 if is_alpha else (0.8 if type == "brute" else 1.0))
	main.on_enemy_killed(self)
	main.spawn_fx("pop", position, radius * 1.4, color)
	_drop_loot()
	flash = 0.0
	queue_redraw()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)


func _drop_loot() -> void:
	## Death rewards. Subclasses (final boss) override this.
	main.spawn_xp(position, xp_value)
	if is_alpha:
		main.spawn_pickup("crate", position)
		main.spawn_xp(position + Vector2(30, 0), xp_value)
		main.spawn_xp(position + Vector2(-20, 10), xp_value)
		return
	if randf() < float(TYPES[type]["scrap_chance"]):
		main.spawn_pickup("scrap", position, 1 + randi() % 3)
	if randf() < 0.006:
		main.spawn_pickup("medkit", position)
	if randf() < 0.002:
		main.spawn_pickup("magnet", position)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var s := draw_scale
	var f := signf(main.player.position.x - position.x)
	if f == 0.0:
		f = 1.0
	var edge := Color(0.055, 0.05, 0.045)
	var sprite_modulate := Color(1, 1, 1, 1)
	if flash > 0.0:
		sprite_modulate = Color(1.8, 1.8, 1.8, 1)
	var sprite_height: float = PS1_HEIGHTS[type]
	var frame := current_walk_frame()
	# Source sprites face left; flip when the player is to the right.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-f * s, s))
	# Shadow
	_ellipse(Vector2(0, 13), Vector2(maxf(radius * 0.9, 8.0), 3.8), Color(0, 0, 0, 0.34))
	draw_ps1_sprite(frame, sprite_height, Vector2(0, 16.0 + sin(anim_t * 2.0) * 0.6), sprite_modulate)
	if type == "brute" and (state == "telegraph" or state == "charge"):
		draw_arc(Vector2.ZERO, 17.0, PI * 0.08, PI * 0.92, 18, Color(1.0, 0.75, 0.2, 0.55), 1.4)
	if type == "sprinter" and (state == "aim" or state == "lunge"):
		draw_line(Vector2(-9, 17), Vector2(9, 17), Color(1.0, 0.88, 0.25, 0.5), 1.0)
	if is_alpha:
		_draw_alpha_mark(edge, sprite_height)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Health bar (alphas always; others only when hurt).
	if is_alpha or hp < max_hp:
		var w := radius * 2.0
		var y := minf(-radius - 10.0 * s, (16.0 - sprite_height) * s - 8.0)
		draw_rect(Rect2(-w / 2, y, w, 3), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(-w / 2, y, w * clampf(hp / max_hp, 0, 1), 3), Color(0.9, 0.25, 0.2))


func current_walk_frame() -> Texture2D:
	var frames: Array = PS1_WALK_FRAMES[type]
	if type == "sprinter" and state == "aim":
		return frames[0]
	if type == "brute" and state == "telegraph":
		return frames[0]
	var speed_mult := 1.0
	if type == "sprinter" and state == "lunge":
		speed_mult = 1.7
	elif type == "brute" and state == "charge":
		speed_mult = 1.35
	return frames[int(anim_t * speed_mult) % frames.size()]


func _draw_alpha_mark(edge: Color, sprite_height: float) -> void:
	var gold := Color(0.98, 0.82, 0.22)
	var base_y := 15.0 - sprite_height
	for i in 4:
		var bx := -7.5 + i * 5.0
		_panel(PackedVector2Array([
			Vector2(bx - 1.8, base_y), Vector2(bx, base_y - 7.0), Vector2(bx + 1.8, base_y)
		]), gold, edge, 0.8)
	draw_line(Vector2(-9, base_y - 1.0), Vector2(9, base_y - 1.0), edge, 1.5)
	draw_line(Vector2(-8, base_y - 1.0), Vector2(8, base_y - 1.0), gold.darkened(0.05), 0.9)


func draw_ps1_sprite(texture: Texture2D, target_height: float, foot: Vector2, modulate: Color) -> void:
	var tex_size := texture.get_size()
	var target_width := target_height * tex_size.x / tex_size.y
	var rect := Rect2(
		Vector2(-target_width * 0.5, foot.y - target_height),
		Vector2(target_width, target_height)
	)
	draw_texture_rect(texture, rect, false, modulate)


func _ellipse(center: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		pts.append(center + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)


func _panel(pts: PackedVector2Array, fill: Color, edge: Color, width: float = 1.2) -> void:
	draw_colored_polygon(pts, fill)
	for i in pts.size():
		draw_line(pts[i], pts[(i + 1) % pts.size()], edge, width)
